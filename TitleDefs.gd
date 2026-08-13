class_name TitleDefs
extends RefCounted
# =====================================================================
#  칭호 — 장기 수집 축 (EXPANSION 5장, 5단계)
#
#  조건은 **이미 기록하고 있는 것만** 쓴다(도감·구간·미궁 층·혈맥·스킬 보유) —
#  새 추적 코드가 없어야 이 축이 싸다. 참고작처럼 조건 두 개가 짝이다.
#
#  보상은 **스탯 훈련 공짜 레벨**이다. 합연산 축(1층)에 얹히므로 곱연산
#  예산(혈맥 전담)을 안 건드리고, 효과에만 붙고 **비용에는 안 붙는다** —
#  비용에 붙으면 칭호를 딸수록 다음 강화가 비싸지는 벌이 된다(Main._stat_eff).
# =====================================================================

# cond kind 와 그 값이 보는 기록:
#   stage    본편 돌파 (best_stage > n)
#   floor    미궁 최고층 (dungeon_best >= n)
#   hero     영웅 레벨 (hero_lv >= n)
#   kills    도감 처치 합계 >= n
#   species  도감 발견 종 >= n
#   knowledge 도감 지식 합계 >= n
#   skills   보유 스킬 종수 >= n
#   traits   혈맥 노드 수 >= n
const TITLES := [
	{"id": "awaken", "name": "깨어난 군주", "stat": "damage", "levels": 2,
		"conds": [{"kind": "stage", "n": 10}, {"kind": "kills", "n": 100}]},
	{"id": "firstblood", "name": "피맛", "stat": "gold", "levels": 2,
		"conds": [{"kind": "kills", "n": 500}, {"kind": "species", "n": 5}]},
	{"id": "gatekeeper", "name": "미궁의 문", "stat": "tough", "levels": 2,
		"conds": [{"kind": "floor", "n": 5}, {"kind": "stage", "n": 30}]},
	{"id": "scholar", "name": "선혈 학자", "stat": "damage", "levels": 3,
		"conds": [{"kind": "knowledge", "n": 10}, {"kind": "species", "n": 10}]},
	{"id": "sixhands", "name": "여섯 개의 손", "stat": "speed", "levels": 2,
		"conds": [{"kind": "skills", "n": 6}, {"kind": "hero", "n": 10}]},
	{"id": "hundred", "name": "백 걸음", "stat": "damage", "levels": 4,
		"conds": [{"kind": "stage", "n": 100}, {"kind": "hero", "n": 25}]},
	{"id": "depth20", "name": "스무 층의 어둠", "stat": "tough", "levels": 4,
		"conds": [{"kind": "floor", "n": 20}, {"kind": "kills", "n": 3000}]},
	{"id": "veins", "name": "핏줄 각성", "stat": "gold", "levels": 4,
		"conds": [{"kind": "traits", "n": 3}, {"kind": "floor", "n": 10}]},
	{"id": "twohundred", "name": "이백 고지", "stat": "damage", "levels": 6,
		"conds": [{"kind": "stage", "n": 200}, {"kind": "knowledge", "n": 30}]},
	{"id": "slayer", "name": "학살자", "stat": "speed", "levels": 4,
		"conds": [{"kind": "kills", "n": 10000}, {"kind": "species", "n": 15}]},
	{"id": "veinlord", "name": "혈맥의 주인", "stat": "tough", "levels": 6,
		"conds": [{"kind": "traits", "n": 12}, {"kind": "floor", "n": 60}]},
	{"id": "king", "name": "군림하는 왕", "stat": "damage", "levels": 8,
		"conds": [{"kind": "stage", "n": 450}, {"kind": "floor", "n": 80}]},
]


static func title(id: String) -> Dictionary:
	for t in TITLES:
		if str(t["id"]) == id:
			return t
	return {}


# state 는 Main 이 만든 기록 스냅샷이다(Main._title_state) — 조건이 새 종류를
# 원하면 여기 kind 하나와 그 스냅샷 키 하나가 같이 늘어야 한다.
static func cond_met(cond: Dictionary, state: Dictionary) -> bool:
	var n := int(cond["n"])
	match str(cond["kind"]):
		"stage": return int(state.get("stage", 1)) > n
		"floor": return int(state.get("floor", 0)) >= n
		"hero": return int(state.get("hero", 1)) >= n
		"kills": return int(state.get("kills", 0)) >= n
		"species": return int(state.get("species", 0)) >= n
		"knowledge": return int(state.get("knowledge", 0)) >= n
		"skills": return int(state.get("skills", 0)) >= n
		"traits": return int(state.get("traits", 0)) >= n
	return false


static func earned(id: String, state: Dictionary) -> bool:
	var t := title(id)
	if t.is_empty():
		return false
	for c in t["conds"]:
		if not cond_met(c, state):
			return false
	return true


# 딴 칭호(got)가 그 스탯에 주는 공짜 레벨 합.
# ── 수집 이정표 (MONETIZATION_PLAN 4-3) ────────────────────────────────────
# 칭호 하나하나는 이미 "공짜 스탯 레벨"이 보상이라, 거기에 소환권을 또 얹으면
# 이중이다. 대신 **몇 개를 모았는가**에 따로 상을 건다 — 칭호는 조건이 제각각이라
# 하나씩 보면 순서가 안 보이는데, 개수 이정표가 그 줄을 세워 준다.
const MILESTONES := [
	{"n": 3, "reward": "ticket_weapon", "amount": 10},
	{"n": 5, "reward": "ticket_armor", "amount": 10},
	{"n": 8, "reward": "ticket_trinket", "amount": 20},
	{"n": 10, "reward": "ticket_skill", "amount": 20},
]


# 지금 개수로 받을 수 있는 이정표 번호들 (아직 안 받은 것만).
static func claimable_milestones(count: int, got: Dictionary) -> Array:
	var out: Array = []
	for i in MILESTONES.size():
		if count >= int(MILESTONES[i]["n"]) and not got.has(i):
			out.append(i)
	return out


static func bonus(stat: String, got: Dictionary) -> int:
	var out := 0
	for t in TITLES:
		if str(t["stat"]) == stat and got.has(str(t["id"])):
			out += int(t["levels"])
	return out


static func cond_text(cond: Dictionary) -> String:
	var n := int(cond["n"])
	match str(cond["kind"]):
		"stage": return "본편 %d 돌파" % n
		"floor": return "미궁 %d층" % n
		# "Lv" 금지 — 블랙레터 폰트에서 "LD" 로 읽힌다(Main 3318줄의 그 함정).
		"hero": return "영웅 %d레벨" % n
		"kills": return "처치 %s" % ("%d" % n if n < 1000 else "%.0fK" % (n / 1000.0))
		"species": return "도감 %d종" % n
		"knowledge": return "지식 %d" % n
		"skills": return "스킬 %d종" % n
		"traits": return "혈맥 %d노드" % n
	return ""


static func stat_name(stat: String) -> String:
	match stat:
		"damage": return "공격력"
		"speed": return "공격속도"
		"tough": return "체력"
		"gold": return "흡혈량"
	return stat
