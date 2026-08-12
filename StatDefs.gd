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
const TRAIN_CAP := [[0, 60], [20, 120], [40, 220], [80, 400]]


static func train_cap(dungeon_best: int) -> int:
	var cap := 0
	for t in TRAIN_CAP:
		if dungeon_best >= int(t[0]):
			cap = int(t[1])
	return cap


# 다음 상한이 열리는 미궁 층. 마지막 상한이면 0 — 더 열 게 없다.
static func next_cap_floor(dungeon_best: int) -> int:
	for t in TRAIN_CAP:
		if dungeon_best < int(t[0]):
			return int(t[0])
	return 0
