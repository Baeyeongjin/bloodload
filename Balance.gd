class_name Balance
extends RefCounted

# 수치가 코드로 들어오는 유일한 자리. 설계 근거는 STATS.md 에 있다.
#
# 여기 모으는 이유: 스탯 계산이 Main 안에 흩어져 있으면 테스트하려고 씬을 통째로
# 띄워야 한다. 순수 함수로 빼 두면 headless 로 수치만 검증할 수 있다.

const UP_BASE := 10.0
const UP_EXP := 1.15


# 한 단계 올리는 비용. level 은 "지금 레벨"이고, 그 다음 단계를 사는 값이다.
# base/exp 는 스탯마다 다르다(StatDefs). 안 주면 무한 스탯 기본값을 쓴다.
#
# **조정은 지수로 한다, 레벨당 효과로 하지 않는다**(STATS.md 6장) —
# 효과를 만지면 이미 올린 플레이어의 수치가 바뀌어 체감이 어긋난다.
static func upgrade_cost(level: int, base := UP_BASE, e := UP_EXP) -> float:
	return base * pow(e, float(level - 1))


# level 에서 n 단계를 한 번에 살 때의 총액.
#
# **배수만 곱하면 안 된다.** 비용이 지수라 `upgrade_cost(lv) * n` 은 실제보다
# 훨씬 싸다 — x100 버튼이 그 계산을 쓰면 100단계를 헐값에 파는 셈이 된다.
static func buy_cost(level: int, n: int, base := UP_BASE, e := UP_EXP) -> float:
	var sum := 0.0
	for k in n:
		sum += upgrade_cost(level + k, base, e)
	return sum


# 치명타 배수. 확률과 피해가 **서로를 증폭하는** 유일한 축이라 둘 다 올려야 값이 난다.
#
# 확률을 굴리지 않고 기댓값을 곱하는 이유: 전투에 난수가 끼면 오프라인 보상을
# 같은 공식으로 계산할 수 없다(DESIGN 1장). 평균을 곱하면 결정론이 유지되면서
# 성장 체감은 똑같다.
static func crit_mult(chance_lv: int, dmg_lv: int) -> float:
	var chance := minf(1.0, 0.01 * float(chance_lv - 1))
	var dmg := 1.5 + 0.05 * float(dmg_lv - 1)
	return 1.0 + chance * (dmg - 1.0)


# 전투력 — 성장 전체를 숫자 하나로 압축한 값.
#
# 방치형에 이게 있는 이유: 스탯이 6~7개가 되면 "내가 세졌나"를 스스로 못 잰다.
# 하나로 묶어 주면 스테이지를 못 넘을 때 "전투력을 더 올려야겠다"가 바로 나온다.
# 정확한 전투 계산이 아니라 **비교용 지표**라 단순한 게 낫다.
static func combat_power(dps: float, tough: float) -> float:
	return dps * 10.0 + tough * 5.0


# ── 생존 ──────────────────────────────────────────────────────────────────
# 체력 스탯과 방어구 실효 수치를 한 공식에 넣는다. 방어구의 base/등급/강화가 이미
# GearDefs.power() 하나로 합쳐지므로 여기서는 그 값을 "방어구 강화합"으로 받는다.
static func hero_max_hp(tough_level: int, armor_power: float) -> float:
	return 100.0 * (1.0
		+ 0.02 * float(maxi(1, tough_level) - 1)
		+ 0.12 * maxf(0.0, armor_power))


# 체력회복은 최대 체력의 비율이다. Lv1은 아직 추가 효과가 없는 기준 레벨이고,
# 첫 구매(Lv2)부터 초당 1.5%가 붙는다.
static func hero_regen_per_sec(max_hp: float, regen_level: int) -> float:
	return maxf(0.0, max_hp) * 0.015 * float(maxi(1, regen_level) - 1)


# 몹마다 별도 공격속도 표를 만들지 않는다. 이미 있는 hp_mult로 단단한 몹일수록
# 느리고 무겁게 치는 차이가 자동으로 생긴다.
static func foe_attack_interval(hp_mult: float) -> float:
	return 1.2 + maxf(0.0, hp_mult) * 0.3


# 오프라인 판정도 실시간 전투와 같은 결정론적 수치를 쓴다. 회복이 받은 DPS 이상이면
# 버티는 시간은 무한(INF)이다.
static func survival_seconds(hp: float, regen_per_sec: float, foe_count: int,
		foe_damage: float, foe_interval: float) -> float:
	var incoming := float(maxi(0, foe_count)) * maxf(0.0, foe_damage) \
		/ maxf(0.001, foe_interval)
	var net := incoming - maxf(0.0, regen_per_sec)
	return INF if net <= 0.0 else maxf(0.0, hp) / net


static func push_seconds(kills_needed: int, foe_hp: float, hero_dps: float) -> float:
	return float(maxi(0, kills_needed)) * maxf(0.0, foe_hp) / maxf(0.001, hero_dps)


static func can_clear_stage(hp: float, regen_per_sec: float, hero_dps: float,
		kills_needed: int, foe_hp: float, foe_count: int, foe_damage: float,
		foe_interval: float) -> bool:
	return push_seconds(kills_needed, foe_hp, hero_dps) \
		< survival_seconds(hp, regen_per_sec, foe_count, foe_damage, foe_interval)


# ── 영웅 레벨 ──────────────────────────────────────────────────────────────
# 처치로 경험치가 쌓여 **자동으로** 오른다. 피를 쓰는 스탯 훈련과 역할이 겹치지
# 않게 하려고 수동 레벨업을 안 둔다 — 같은 자원을 두 군데서 쓰게 하면
# "뭘 올릴까"가 선택이 아니라 계산 문제가 된다.
#
# 자동인 덕에 방치 중에도 오르고, 스탯·콘텐츠 해금 조건으로도 쓸 수 있다.
const EXP_BASE := 20.0
const EXP_EXP := 1.12
const HERO_LV_BONUS := 0.01   # 레벨당 전 스탯 +1%


static func exp_need(level: int) -> float:
	return EXP_BASE * pow(EXP_EXP, float(level - 1))


# 한 마리당 경험치. 단계에 비례해서 후반에도 레벨이 계속 오른다.
static func exp_per_kill(stage: int) -> float:
	return 1.0 + float(stage) * 0.5


static func hero_mult(level: int) -> float:
	return 1.0 + HERO_LV_BONUS * float(level - 1)
