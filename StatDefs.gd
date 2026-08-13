class_name StatDefs
extends RefCounted

# 성장 스탯 표. 설계 근거는 docs/STATS.md 에 있고, 여기가 그 표의 코드판이다.
#
# 해금을 스테이지에 묶는 이유(docs/STATS.md 4b): 방치형의 핵심은 성장에 따른 콘텐츠
# 해금이다. 그래서 잠긴 칸도 **감추지 않고 회색으로 보여 준다** — 감추면 있는 줄도
# 몰라 목표가 안 되고, 보이면 "저기까지 가면 저게 열린다"가 스테이지를 미는 이유가 된다.
#
# **문턱이 둘이다: 단계 + 선행 스탯 레벨**(2026-08-06, 사장님).
# 단계만으로 열면 해금이 "기다리면 된다"가 되고, 방치형에서 그건 성장이 아니라
# 대기표다. 지금 가진 스탯을 올려야 다음 칸이 열리면 해금이 **성장의 결과**가 되고,
# 무엇부터 올릴지도 표가 알려 준다.
#
# 그래서 단계 문턱은 통째로 앞으로 당겼다(8/12/15/20 -> 1/2/4/5/6). 특히 **체력은
# 1단계다** — 일반 구간의 제한 시간을 뺀 뒤로 게이트가 **생존 하나**인데
# (StageDefs.time_limit), 죽어도 살 게 없으면 그냥 막힌다. 8단계는 40분 넘게
# 걸렸다. 선행은 공격력 Lv5(누적 약 50 혈액)라 첫 1분 안에 열린다.
#
# 선행 레벨은 **가르치는 문턱**이지 벽이 아니다 — 누적 비용을 첫 판에 닿는 자리로
# 잡았다: 공격력5 약 50 · 체력5 약 60 · 공속10 약 470 · 치확5 약 330 · 체력15 약 490.
#
# `impl` 이 false 면 스테이지를 넘겨도 안 열린다. 효과가 아직 전투에 안 붙은 스탯을
# 사게 두면 피만 버리기 때문이다. 해당 마일스톤에서 효과를 붙일 때 true 로 바꾼다.

const STATS := [
	{"key": "damage", "name": "공격력", "icon": "stat_damage",
		"unlock": 1, "impl": true, "base": 10.0, "exp": 1.15},
	{"key": "gold", "name": "흡혈량", "icon": "stat_drain",
		"unlock": 1, "impl": true, "base": 14.0, "exp": 1.16},
	# 체력이 공격력 다음이다. 순서가 곧 "먼저 살아남아라"를 가르친다.
	{"key": "tough", "name": "체력", "icon": "stat_tough",
		"unlock": 1, "need": ["damage", 5], "impl": true, "base": 12.0, "exp": 1.15},
	{"key": "speed", "name": "공격속도", "icon": "stat_speed",
		"unlock": 2, "need": ["tough", 5], "impl": true,
		"base": 20.0, "exp": 1.22, "cap": 1000},
	{"key": "crit", "name": "치명타 확률", "icon": "stat_crit",
		"unlock": 4, "need": ["speed", 10], "impl": true,
		"base": 50.0, "exp": 1.35, "cap": 100},
	{"key": "critdmg", "name": "치명타 피해", "icon": "stat_critdmg",
		"unlock": 5, "need": ["crit", 5], "impl": true, "base": 40.0, "exp": 1.28},
	# 회복은 **상한 스탯**이다(Balance.REGEN_CAP). 생존시간을 무한대로 보내는
	# 실질 곱연산이라 STATS 1장 규칙에 걸린다. 상한이 있으니 비용 지수도 무한
	# 스탯(1.16)이 아니라 상한 스탯 쪽(1.22)으로 올린다 — STATS 6장.
	{"key": "regen", "name": "체력회복", "icon": "stat_regen",
		"unlock": 6, "need": ["tough", 15], "impl": true, "base": 15.0, "exp": 1.22,
		"cap": Balance.REGEN_CAP_LEVEL},
]


static func of(key: String) -> Dictionary:
	for s in STATS:
		if s["key"] == key:
			return s
	return {}


# 잠긴 이유를 한 줄로. 없으면 열려 있다는 뜻.
#
# `levels` 는 스탯별 현재 레벨(Main.lv). **기본값을 안 준다** — 안 넘긴 호출부가
# 생기면 파싱에서 걸리게 하려는 것이다. 기본 `{}` 를 두면 모든 선행이 Lv1 로 읽혀서
# 잠긴 칸이 조용히 열리거나 열린 칸이 조용히 잠긴다.
#
# 단계 문턱을 먼저 본다. 단계가 모자라면 선행을 채워도 안 열리므로, 그 상태에서
# 선행을 보여 주면 **못 여는 조건을 하라고 시키는** 셈이다.
static func lock_reason(key: String, stage: int, levels: Dictionary) -> String:
	var s := of(key)
	if s.is_empty():
		return ""
	if not bool(s.get("impl", true)):
		return "준비 중"
	if stage < int(s["unlock"]):
		return "%d단계 해금" % int(s["unlock"])
	var need: Array = s.get("need", [])
	if need.size() == 2 and int(levels.get(str(need[0]), 1)) < int(need[1]):
		# **"Lv" 를 쓰지 않는다** — 이 블랙레터 폰트에서 "Lv5" 는 "LD5" 로 읽힌다
		# (화면 실측, 같은 함정을 네 번째 밟았다).
		return "%s %d레벨" % [str(of(str(need[0]))["name"]), int(need[1])]
	return ""


static func is_open(key: String, stage: int, levels: Dictionary) -> bool:
	return lock_reason(key, stage, levels) == ""


# 상한이 있는 스탯은 만렙에서 멈춘다(docs/STATS.md 1장 — 곱연산은 반드시 유한).
static func at_cap(key: String, level: int) -> bool:
	var s := of(key)
	return s.has("cap") and level >= int(s["cap"])


# ── 승급 — 훈련 공통 상한 (REFERENCE_TEARDOWN 4장-3) ───────────────────────
# 참고작 전투술의 "최대 레벨 + N단계 달성 필요" 자리. 여는 열쇠는 미궁 층이다
# (EXPANSION 7장 교차 잠금: 미궁 → 훈련). 스탯 고유 cap 이 더 작으면 그쪽이
# 이긴다 — 이 표는 무한 성장 스탯(공격력 등)의 고삐다.
# [미궁 최고층, 훈련 상한]. 0층 = 시작부터.
# 상한을 키웠다 (2026-08-13, MONETIZATION_PLAN C안). 비용 지수를 1.037 로 내리면
# 하루 벌이로 **수백 레벨**이 팔린다 — 60/120/220/400 은 그 아래라 반나절이면
# 천장을 치고, 그 뒤로는 혈액이 갈 곳을 잃는다(옛 증상: 30일차 잉여 209K).
#
# 500구간 완주에 필요한 배수에서 역산한 값이다. 몹이 10구간마다 x1.15 면
# 500구간 누적 x1067 이고, 성장은 스탯 600레벨(x21.9) x 장비 x9 x 혈맹 x6.5 x
# 혈맥 x1.26 x 도감 x1.2 = x1900 이라 넘어선다.
# **상한은 미궁 층에 연속으로 묶는다.** 계단으로 두면 그 사이에서 자물쇠가 걸린다:
# 훈련이 상한에 막혀 성장이 멈추고 -> 미궁을 못 올라가고 -> 다음 계단이 안 열린다
# (실측: 90일차에 상한 300 · 미궁 46층에서 교착, 혈액 3만M 잉여).
# 층마다 조금씩 열리면 그 교착이 원천적으로 안 생긴다 — 한 층만 올라도 살 게 생긴다.
#
# 그리고 **미궁 층과 본편 구간 중 큰 쪽**이 연다. 미궁 하나에만 묶었더니 미궁이
# 막히는 순간 훈련도 같이 멈췄다(실측: 90일차 미궁 46층 · 상한 336 교착).
# 둘 중 하나만 움직여도 열리므로 자물쇠가 원천적으로 안 걸린다 — 교차 잠금의
# 뜻은 "둘 다 키워라"이지 "하나 막히면 다 멈춰라"가 아니다.
#
# **상한은 브레이크가 아니라 안전장치다.** 페이스를 상한에 맡기면 반드시 교착이
# 생긴다 — 한 구간 오를 때 열리는 상한(+1.2)이 그 구간의 요구 증가(+3.4%)와
# 비슷하면, 조금만 모자라도 둘이 서로를 기다리며 멈춘다(실측: 90일차 상한 406에
# 딱 붙은 채 혈액 78,477M 잉여). 넉넉히 열어 두고 **페이스는 비용 지수가 쥔다**
# (COST_EXP_SCALE) — 그쪽은 아무리 조여도 교착이 안 생긴다.
#
# 60 + 10/층: 100층 1060 · 60 + 2.5/구간: 500구간 1307
const CAP_BASE := 60
const CAP_PER_FLOOR := 10
const CAP_PER_STAGE := 2.5

# 승급 단계는 **표시용**으로 남는다(배지·안내). 상한 계산은 위 식이 한다.
const PROMO_FLOORS := [0, 20, 40, 80]

# 승급 보상 (MONETIZATION_PLAN 4-4). 예전엔 승급이 상한만 열어서 그 순간 손에
# 쥐는 게 없었다 — 이정표로 안 읽힌다. 단계마다 소환권 뭉치를 준다.
# 0단계(시작)는 없다.
const PROMO_REWARDS := [
	{},
	{"reward": "ticket", "amount": 10},
	{"reward": "ticket", "amount": 20},
	{"reward": "ticket_hi", "amount": 10},
]


# 승급 단계 (0..3).
static func promo_index(dungeon_best: int) -> int:
	var idx := 0
	for i in PROMO_FLOORS.size():
		if dungeon_best >= int(PROMO_FLOORS[i]):
			idx = i
	return idx


# **승급은 상한만 열지 않는다 — 비용 지수도 낮춘다** (2026-08-13, PaceProbe 실측).
#
# 상한만 열면 상한이 장식이 된다: 비용이 지수 1.15 라 하루 벌이로 살 수 있는
# 레벨이 90 근처에서 멈추고, 그 위로는 재화가 얼마든 안 팔린다(60일차에 혈액
# 209K 가 남은 채로 다음 레벨이 2.2M 이었다). 상한 400 은 도달할 수 없는 숫자였다.
#
# 지수를 낮추면 **그 위 레벨이 실제로 팔린다** — 미궁을 밀어 승급하면 스탯이
# 다시 싸져서 본편이 밀리고, 그게 다시 미궁을 연다. 교차 잠금이 순환이 아니라
# 나선이 되는 자리다. 이미 산 레벨까지 싸지는 건 의도다: 승급은 도약이어야 한다.
# 비용 지수 손잡이 하나. **표의 값(1.15 등)에 이 배수를 물린다** — 곡선을 맞출 때
# 스탯마다 숫자를 고치면 서로 어긋나므로, 흔드는 자리는 여기 하나다.
#
# 1.0 = 표 그대로 (2026-08-13 실측으로 되돌림). C안의 목적("그 위가 안 팔린다")은
# **지수가 아니라 상한**이 범인이었다 — 상한을 넉넉히 열자 원래 지수로도 후반까지
# 계속 팔린다. 지수는 그대로 두는 게 낫다: 페이스가 가장 목표에 가깝고(30일 170),
# 낮출수록 초반이 빨라지기만 한다(0.35 면 30일 230).
#
#     값 1.00  30일 170 · 60일 200 · 90일 230   <- 채택
#     값 0.80  30일 190 · 60일 230 · 90일 250
#     값 0.35  30일 230 · 60일 270 · 90일 290
static var COST_EXP_SCALE := 1.0


# 이 스탯의 실제 비용 지수. 1 을 뺀 몫(성장분)에만 배수를 물린다 — 지수 자체에
# 곱하면 1 아래로 내려가 비용이 거꾸로 줄어든다.
static func cost_exp(key: String) -> float:
	return 1.0 + (float(of(key).get("exp", 1.15)) - 1.0) * COST_EXP_SCALE


# 승급이 비용까지 깎던 장치는 **뺐다** (2026-08-13). 무한 스탯의 지수 자체를
# 1.15 -> 1.037 로 내렸으므로 상한까지 실제로 팔린다 — 같은 일을 두 곳에서 하면
# 조정할 때마다 두 곳을 봐야 한다. 승급은 이제 상한만 연다.


static func train_cap(dungeon_best: int, best_stage := 1) -> int:
	return CAP_BASE + maxi(CAP_PER_FLOOR * maxi(0, dungeon_best),
		int(CAP_PER_STAGE * float(maxi(0, best_stage - 1))))


# 다음 승급이 열리는 미궁 층. 마지막 단계면 0 — 더 열 게 없다.
# (상한 자체는 층마다 열리므로 이건 배지가 바뀌는 자리를 말한다.)
static func next_cap_floor(dungeon_best: int) -> int:
	for f in PROMO_FLOORS:
		if dungeon_best < int(f):
			return int(f)
	return 0
