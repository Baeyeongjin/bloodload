class_name AchieveDefs
extends RefCounted

# 누적 업적 — **한 번뿐인 보상**으로 초·중반의 배급을 두껍게 깐다
# (2026-08-20, 사장님: "퀘스트 및 업적 보상 좀 촘촘하게").
#
# 가이드(GoalDefs)와 무엇이 다른가: 가이드는 **지금 목표 하나**를 보여 주고
# 깨면 다음 것이 나온다. 업적은 **지금까지 한 것 전부**를 한 판에 늘어놓는다.
# 같은 값을 세지만 역할이 다르다 — 가이드는 "뭘 할까", 업적은 "얼마나 왔나".
# 예전에 "업적 화면을 따로 안 만든다"고 적어 뒀던 이유는 표를 두 벌 만들면
# 어긋나기 때문이었는데, 여기는 **표를 안 만든다**: 값의 출처가 Main 의
# `_goal_value` 하나뿐이고(가이드와 같은 함수), 계단만 여기 적는다.
#
# 왜 누적인가: 일일·주간은 매일 같은 양이라 "오늘 하루치"밖에 못 준다.
# 초반에 소환을 굴릴 뭉치가 필요한데 그건 **지나온 거리**로 줘야 한다 —
# 갓 시작한 사람에게 하루치를 열 배 주면 후반이 통째로 인플레된다.
#
# 계단은 **한 눈에 읽히는 수**로 적는다. 사다리 공식을 쓰면 3,278 같은 수가
# 나오는데 업적은 목록으로 한꺼번에 보는 것이라 그러면 판이 안 읽힌다.

# kind 는 Main._goal_value() 가 "지금 값"을 아는 열쇠다 — 가이드와 공유한다.
# 새 kind 를 넣으려면 거기 한 줄을 같이 추가해야 한다(AchieveCheck 가 잡는다).
#
# reward 는 Main._grant_reward() 가 아는 이름. 소환권은 **여섯 종류를 흩는다** —
# 한 종류만 주면 나머지의 천장이 안 찬다(TicketDefs 와 같은 이유).
const TRACKS := [
	{"kind": "kills", "name": "사냥", "unit": "마리", "icon": "quest_kill",
		"steps": [500, 2000, 10000, 50000, 200000, 1000000, 5000000],
		"reward": "ticket_weapon", "amounts": [3, 5, 8, 12, 20, 30, 50]},
	{"kind": "stage", "name": "진군", "unit": "구간", "icon": "stat_damage",
		"steps": [10, 30, 60, 100, 200, 350, 500, 750],
		"reward": "ticket_armor", "amounts": [3, 5, 8, 12, 20, 30, 40, 60]},
	{"kind": "pulls", "name": "소환", "unit": "회", "icon": "quest_summon",
		"steps": [50, 200, 600, 1500, 4000, 10000],
		"reward": "ticket_trinket", "amounts": [3, 6, 10, 18, 30, 50]},
	{"kind": "hero_lv", "name": "군주", "unit": "레벨", "icon": "stat_tough",
		"steps": [10, 25, 50, 90, 150, 250, 400],
		"reward": "ticket_skill", "amounts": [3, 5, 8, 12, 20, 30, 45]},
	{"kind": "damage_lv", "name": "훈련", "unit": "레벨", "icon": "stat_rage",
		"steps": [150, 600, 1500, 3000, 6000, 10000],
		"reward": "gem", "amounts": [150, 300, 600, 1000, 1800, 3000]},
	{"kind": "knowledge", "name": "지식", "unit": "레벨", "icon": "stat_regen",
		"steps": [10, 30, 60, 100, 160, 240],
		"reward": "ticket_pet", "amounts": [2, 4, 6, 10, 16, 25]},
	{"kind": "dungeon", "name": "미궁", "unit": "층", "icon": "quest_maze",
		"steps": [5, 15, 30, 50, 70, 90, 100],
		"reward": "crystal", "amounts": [200, 500, 1200, 2500, 5000, 9000, 15000]},
	{"kind": "trial", "name": "시련", "unit": "단계", "icon": "badge_mastery",
		"steps": [3, 8, 15, 25, 40, 60],
		"reward": "ticket_petgear", "amounts": [2, 4, 6, 10, 16, 25]},
]


static func track(kind: String) -> Dictionary:
	for t in TRACKS:
		if str(t["kind"]) == kind:
			return t
	return {}


# 이 트랙에서 지금 값으로 **받을 수 있는 계단 수**. got 은 이미 받은 수다.
static func reached(kind: String, value: int) -> int:
	var t := track(kind)
	if t.is_empty():
		return 0
	var n := 0
	for s in t["steps"]:
		if value >= int(s):
			n += 1
	return n


# step 번째(0부터) 계단의 필요값·보상. 범위를 넘으면 빈 사전 — 다 받았다는 뜻이다.
static func at(kind: String, step: int) -> Dictionary:
	var t := track(kind)
	if t.is_empty() or step < 0 or step >= t["steps"].size():
		return {}
	return {"need": int(t["steps"][step]),
		"reward": str(t["reward"]), "amount": float(t["amounts"][step]),
		"name": "%s %s%s" % [str(t["name"]), _n(int(t["steps"][step])),
			str(t["unit"])],
		"icon": str(t["icon"])}


static func total_steps() -> int:
	var n := 0
	for t in TRACKS:
		n += t["steps"].size()
	return n


# 큰 수 축약 — GoalDefs 와 같은 규칙이다. 이 파일도 Main 없이 검사할 수 있어야
# 해서 따로 둔다(검사가 씬을 안 띄운다).
static func _n(v: int) -> String:
	if v < 1000:
		return str(v)
	var f := float(v)
	var units := ["k", "m", "b"]
	var i := -1
	while f >= 1000.0 and i < units.size() - 1:
		f /= 1000.0
		i += 1
	return ("%.1f" % f).trim_suffix(".0") + units[i]
