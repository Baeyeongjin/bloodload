class_name Balance
extends RefCounted

# 수치가 코드로 들어오는 유일한 자리. 설계 근거는 docs/STATS.md 에 있다.
#
# 여기 모으는 이유: 스탯 계산이 Main 안에 흩어져 있으면 테스트하려고 씬을 통째로
# 띄워야 한다. 순수 함수로 빼 두면 headless 로 수치만 검증할 수 있다.

const UP_BASE := 10.0
const UP_EXP := 1.15


# 한 단계 올리는 비용. level 은 "지금 레벨"이고, 그 다음 단계를 사는 값이다.
# base/exp 는 스탯마다 다르다(StatDefs). 안 주면 무한 스탯 기본값을 쓴다.
#
# **조정은 지수로 한다, 레벨당 효과로 하지 않는다**(docs/STATS.md 6장) —
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


# 공격력. **레벨당 +2% 합연산**이다 — `4 × 레벨`(레벨당 +100%)이 아니다.
#
# 코드가 STATS.md 4장 첫 줄의 `4 × 공격력Lv` 를 그대로 베끼고 있었는데, 그 줄이
# 오타다. **같은 문서 2-1 표는 "+2%(합)"이라 적혀 있고, 4장의 검산표(DPS 배수
# 첫날 x3 / 1주 x15 / 1개월 x180 / 3개월 x4,000)를 역산하면 +2% 합연산이 나온다** —
# 아래 공식으로 계산하면 x2.5 / x11.9 / x177.7 / x3,949 로 1% 안에서 맞는다.
# 곱연산으로 두면 x70 / x479 / x8,212 / x191,210 이라 표와 50배 어긋난다.
#
# 이걸 고치면 STATS 1장의 "합연산은 무한, 곱연산은 유한" 규칙도 다시 지켜진다.
#
# 기준값 4.0 -> 14.0 은 60마리/60초 구간에서 역산한 값이다. 마리당 쓸 수 있는 시간이
# 1초인데 **그중 0.55초는 다음 몹에게 달려가는 데 쓴다**(APPROACH_SECONDS) —
# 실제로 때리는 시간은 0.45초뿐이라 그 안에 몹을 눕힐 만큼 세야 한다.
const DMG_BASE := 14.0
const DMG_PER_LEVEL := 0.02


static func hero_damage(damage_level: int, gear_damage: float, hero_level: int) -> float:
	return (DMG_BASE * (1.0 + DMG_PER_LEVEL * float(maxi(1, damage_level) - 1))
		+ maxf(0.0, gear_damage)) * hero_mult(hero_level)


# 몹 한 대의 피해. `enemy_power × 4` 였는데 그러면 적 강화를 **그대로** 타서
# 지수로 오르는 반면 체력은 합연산이라, 후반에 한 대에 여러 번 죽었다.
# 지수를 0.85 로 눌러 체력 성장이 따라갈 수 있게 한다.
const FOE_DMG_BASE := 1.0
const FOE_DMG_EXP := 0.85


static func foe_damage(power: float) -> float:
	return pow(maxf(0.0, power), FOE_DMG_EXP) * FOE_DMG_BASE


static func attack_interval(speed_level: int) -> float:
	return maxf(0.10, 0.60 * pow(0.9982, float(maxi(1, speed_level) - 1)))


# 피해 스킬은 모션 동안 놓친 기본공격 수만큼 최소 피해를 보장한다.
static func skill_hit_mult(interval: float, action_duration: float) -> float:
	return maxf(1.0, maxf(0.0, action_duration) / maxf(0.001, interval))


# 단일 대상 장기 DPS. 피해 스킬은 위 보정으로 기본공격을 대체하므로 여기서는
# 소환 시전 중 손실과 지속 버프만 평균낸다.
static func auto_dps(hit_damage: float, interval: float, action_duration: float,
		summon_cooldown: float, summon_duration: float, summon_bonus: float) -> float:
	var cooldown := maxf(0.001, summon_cooldown)
	var cast_uptime := clampf(maxf(0.0, action_duration) / cooldown, 0.0, 1.0)
	var buff_uptime := clampf(maxf(0.0, summon_duration) / cooldown, 0.0, 1.0)
	return maxf(0.0, hit_damage) / maxf(0.001, interval) \
		* (1.0 - cast_uptime) * (1.0 + maxf(0.0, summon_bonus) * buff_uptime)


# 전투력 — 성장 전체를 숫자 하나로 압축한 값.
#
# 방치형에 이게 있는 이유: 스탯이 6~7개가 되면 "내가 세졌나"를 스스로 못 잰다.
# 하나로 묶어 주면 스테이지를 못 넘을 때 "전투력을 더 올려야겠다"가 바로 나온다.
# 정확한 전투 계산이 아니라 **비교용 지표**라 단순한 게 낫다.
#
# **생존 쪽 인자가 장비 방어구뿐이었다.** 그래서 체력 스탯을 아무리 올려도 전투력이
# 1도 안 움직였고, 회복은 아예 안 들어 있었다 — 성장했는데 지표가 그대로면
# 플레이어는 그 스탯을 안 산다. 실제 최대 체력과 초당 회복을 그대로 받는다.
#
# 흡혈량(gold)은 **일부러 뺐다.** 그건 전투 능력이 아니라 재화 획득량이다.
# 전투력에 섞으면 "전투력을 올렸는데 왜 안 이기지"가 된다 — 대신 그 스탯을 사면
# 별도 알림이 뜬다(Main._notify_stat).
static func combat_power(dps: float, max_hp: float, regen_per_sec: float) -> float:
	return dps * 10.0 + maxf(0.0, max_hp) * 0.5 + maxf(0.0, regen_per_sec) * 5.0


# ── 생존 ──────────────────────────────────────────────────────────────────
# 체력 스탯과 방어구 실효 수치를 한 공식에 넣는다. 방어구의 base/등급/강화가 이미
# GearDefs.power() 하나로 합쳐지므로 여기서는 그 값을 "방어구 강화합"으로 받는다.
# 체력 레벨당 +2% 였는데, 몹 피해가 적 강화를 그대로 타는 동안 체력만 합연산이라
# 체력 스탯이 장식이었다(실제로 100단계에서 한 대에 9번 죽었다). 몹 피해 지수를
# 누르고(foe_damage) 이쪽을 +6% 로 올려 양쪽에서 벌린다.
static func hero_max_hp(tough_level: int, armor_power: float) -> float:
	return 100.0 * (1.0
		+ 0.06 * float(maxi(1, tough_level) - 1)
		+ 0.12 * maxf(0.0, armor_power))


# 체력회복은 최대 체력의 비율이다. Lv1은 아직 추가 효과가 없는 기준 레벨이다.
#
# **상한이 있어야 한다.** 레벨당 +1.5%p 를 무한으로 두면 Lv67 에서 초당 100% 회복이라
# 그 뒤로는 아무리 맞아도 안 죽는다 — survival_seconds 가 INF 를 돌려주므로 오프라인
# 판정도 생존을 아예 안 보게 된다. 이건 STATS 1장의 "곱연산은 반드시 상한" 규칙에
# 걸리는 종류다: 회복은 생존시간을 무한대로 보내므로 실질 곱연산이다.
#
# 레벨당 +0.1%p / 상한 5%(20초에 풀피)로 잡았다. 몹에게 맞는 양이 대략 초당 최대
# 체력의 1~2% 라 Lv15 언저리가 손익분기이고, 그 위는 여유분이다.
# 상한이 생겼으므로 비용 지수도 무한 스탯(1.16)이 아니라 상한 스탯 쪽으로 올린다
# (StatDefs, STATS 6장).
const REGEN_PER_LEVEL := 0.001
const REGEN_CAP := 0.05
const REGEN_CAP_LEVEL := 51   # 0.001 x 50 = 0.05


static func hero_regen_per_sec(max_hp: float, regen_level: int) -> float:
	var rate := minf(REGEN_CAP, REGEN_PER_LEVEL * float(maxi(1, regen_level) - 1))
	return maxf(0.0, max_hp) * rate


# 몹마다 별도 공격속도 표를 만들지 않는다. 이미 있는 hp_mult로 단단한 몹일수록
# 느리고 무겁게 치는 차이가 자동으로 생긴다.
#
# 기본을 1.2 -> 1.0 으로 내렸다. 1.2 면 가장 무른 몹도 1.5초, 단단한 놈은 2.3초라
# 영웅 처치시간(초반 1.9초)보다 느려서 **한 대도 못 치고 죽는** 몹이 대부분이었다.
static func foe_attack_interval(hp_mult: float) -> float:
	return 1.0 + maxf(0.0, hp_mult) * 0.3


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


# 한 마리를 잡을 때마다 **다음 놈에게 달려가는 시간**이 더 든다. DPS 로는 줄일 수
# 없는 고정비이고, 아무리 세게 때려도 구간이 이보다 짧아지지 않는다 — 오프라인이
# 이걸 안 물리면 실시간으로는 몇 분 걸리는 구간을 껐다 켜면 넘어가 있다.
#
# 값은 `Main.FOE_GAP / Main.TRAVEL_SPEED`(줄 간격 / 전진 속도)에 처치 뒤 정리 시간이
# 붙은 것이다. **처리량 상한 인자(칸 수 / 걷는 시간)를 지웠다**(2026-08-06) — 몹이
# 서 있고 영웅이 한 마리씩 찾아가므로 동시 마릿수가 처리량에 영향이 없다. 예전엔
# 몹이 화면 밖에서 여러 칸으로 동시에 걸어 들어와서 그게 병렬 상한이었다.
#
# 0.47초는 실측값이다 — 1-1(맨몸 세이브)을 60초 돌려 82마리(0.73초/마리)를 세고,
# 거기서 모델 처치시간(0.26초/마리)을 뺐다. 설계값 FOE_GAP/TRAVEL_SPEED = 0.8초보다
# 작은 이유: 사망 연출 동안에도 전진하고, **공격 쿨다운이 전진 중에 돈다**
# (`_tick_hero_attack`) — 그래서 마주치면 대개 즉시 첫 스윙이 나간다.
#
# 이 값이 얼마나 크게 움직이는지: 0.55(영웅이 제자리에서 팼을 때) -> 0.89(고정 칸으로
# 옮겨 영웅이 걸어 나가게 한 직후) -> 0.76(전열 가속 + 마주 걷기) -> 0.83(마주 나가는
# 거리를 제한) -> 0.57(찾아가는 모델) -> 0.47(전진 중에도 공격 쿨다운이 돌게).
# 짐작으로 못 맞춘다.
# ponytail: `Main.FOE_GAP` · `Main.TRAVEL_SPEED` · `Foe.DIE_DUR` 를 바꾸면
# tests/EngageCheck.gd 로 다시 재야 한다.
const APPROACH_SECONDS := 0.47


static func stage_seconds(kills_needed: int, foe_hp: float, hero_dps: float) -> float:
	return push_seconds(kills_needed, foe_hp, hero_dps) \
		+ float(maxi(0, kills_needed)) * APPROACH_SECONDS


# time_limit: 구간 제한 시간. 0 이하면 제한 없음.
# **살아남는 것만으로는 부족하다** — 제한 시간이 생긴 뒤로는 버티기만 하면 재시작이라
# 오프라인도 같은 벽 앞에서 멈춰야 한다. 안 그러면 실시간으로는 못 넘는 구간을
# 껐다 켜면 넘어가 있다.
static func can_clear_stage(hp: float, regen_per_sec: float, hero_dps: float,
		kills_needed: int, foe_hp: float, foe_count: int, foe_damage: float,
		foe_interval: float, time_limit := 0.0) -> bool:
	var push := stage_seconds(kills_needed, foe_hp, hero_dps)
	if time_limit > 0.0 and push >= time_limit:
		return false
	return push < survival_seconds(hp, regen_per_sec, foe_count, foe_damage, foe_interval)


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
