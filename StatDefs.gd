class_name StatDefs
extends RefCounted

# 성장 스탯 표. 설계 근거는 docs/STATS.md 에 있고, 여기가 그 표의 코드판이다.
#
# 해금을 스테이지에 묶는 이유(docs/STATS.md 4b): 방치형의 핵심은 성장에 따른 콘텐츠
# 해금이다. 그래서 잠긴 칸도 **감추지 않고 회색으로 보여 준다** — 감추면 있는 줄도
# 몰라 목표가 안 되고, 보이면 "저기까지 가면 저게 열린다"가 스테이지를 미는 이유가 된다.
#
# `impl` 이 false 면 스테이지를 넘겨도 안 열린다. 효과가 아직 전투에 안 붙은 스탯을
# 사게 두면 피만 버리기 때문이다. 해당 마일스톤에서 효과를 붙일 때 true 로 바꾼다.

const STATS := [
	{"key": "damage", "name": "공격력", "icon": "stat_damage",
		"unlock": 1, "impl": true, "base": 10.0, "exp": 1.15},
	{"key": "gold", "name": "흡혈량", "icon": "stat_drain",
		"unlock": 1, "impl": true, "base": 14.0, "exp": 1.16},
	{"key": "speed", "name": "공격속도", "icon": "stat_speed",
		"unlock": 3, "impl": true, "base": 20.0, "exp": 1.22, "cap": 1000},
	{"key": "crit", "name": "치명타 확률", "icon": "stat_crit",
		"unlock": 12, "impl": true, "base": 50.0, "exp": 1.35, "cap": 100},
	{"key": "critdmg", "name": "치명타 피해", "icon": "stat_critdmg",
		"unlock": 15, "impl": true, "base": 40.0, "exp": 1.28},
	{"key": "tough", "name": "체력", "icon": "stat_tough",
		"unlock": 8, "impl": true, "base": 12.0, "exp": 1.15},
	{"key": "regen", "name": "체력회복", "icon": "stat_regen",
		"unlock": 20, "impl": true, "base": 15.0, "exp": 1.16},
]


static func of(key: String) -> Dictionary:
	for s in STATS:
		if s["key"] == key:
			return s
	return {}


# 잠긴 이유를 한 줄로. 없으면 열려 있다는 뜻.
static func lock_reason(key: String, stage: int) -> String:
	var s := of(key)
	if s.is_empty():
		return ""
	if not bool(s.get("impl", true)):
		return "준비 중"
	if stage < int(s["unlock"]):
		return "%d단계 해금" % int(s["unlock"])
	return ""


static func is_open(key: String, stage: int) -> bool:
	return lock_reason(key, stage) == ""


# 상한이 있는 스탯은 만렙에서 멈춘다(docs/STATS.md 1장 — 곱연산은 반드시 유한).
static func at_cap(key: String, level: int) -> bool:
	var s := of(key)
	return s.has("cap") and level >= int(s["cap"])
