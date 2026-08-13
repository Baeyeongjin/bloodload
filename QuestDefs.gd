class_name QuestDefs

# 일일 임무 (REFERENCE_TEARDOWN 4장-1). 참고작 원칙 그대로 — 임무는 전부
# **어차피 하는 행동의 기록**이다. 새 추적 축을 만들지 않는다: 훅은 Main 의
# 기존 4곳(처치·훈련 구매·소환·미궁 층 돌파)뿐이고, 접속은 날짜가 바뀌는
# 순간 자동으로 찬다.
#
# 보상 규모(2026-08-13 개편): **소환권 4(무기1·스킬1·방어구2) + 보석 25/일**.
# 예전엔 보석 75 였는데, 상점·과금이 붙으면 그 보석이 소환 아닌 곳으로 샌다 —
# "소환하라"고 준 보상은 소환권으로 줘야 의도가 안 샌다(TicketDefs).
# 남긴 보석 25 는 상점 통화다. 미궁 임무만 혈정을 준다 — 혈정은 미궁 전용
# 재화(EXPANSION 6장)라 임무도 미궁이 준다.
#
# "all"(마무리 임무)의 need 는 4 다 — 미궁은 본편 30구간이 열어서(교차 잠금)
# 그 전에는 기본 임무가 4개뿐이다. 4로 두면 미궁 전에도 하루를 닫을 수 있고,
# 미궁이 열리면 다섯 중 넷이라 여유가 생긴다.
# 아이콘: 전용판 5종 (2026-08-12 사장님 세트 승인).
const QUESTS := [
	{"id": "login", "name": "핏빛 성에 접속", "need": 1,
		"reward": "ticket_weapon", "amount": 1, "icon": "quest_login"},
	{"id": "kills", "name": "몬스터 50마리 처치", "need": 50,
		"reward": "gem", "amount": 15, "icon": "quest_kill"},
	{"id": "train", "name": "훈련 5회", "need": 5,
		"reward": "gem", "amount": 10, "icon": "quest_forge"},
	{"id": "summon", "name": "소환 3회", "need": 3,
		"reward": "ticket_skill", "amount": 1, "icon": "quest_summon"},
	{"id": "dungeon", "name": "미궁 1층 돌파", "need": 1,
		"reward": "crystal", "amount": 20, "icon": "quest_maze"},
	{"id": "all", "name": "임무 4개 완료", "need": 4,
		"reward": "ticket_armor", "amount": 2, "icon": "badge_mastery"},
]


# ── 주간 임무 (참고작 ⑫ — 일일과 별도 목록, 사장님) ─────────────────────────
# 일일과 같은 훅을 쓰되 **주간 규모**다. kind 가 훅 열쇠라 일일 kind 와 겹쳐도
# 카운터는 따로 쌓인다(quest_wprog). "daily" 는 일일 임무를 받을 때 차는
# 연동 임무 — 하루 루프가 주간의 기둥인 건 그대로다.
# 보상 합: 소환권 15(장신구5·무기5·스킬5) + 보석 80 + 혈정 60 — 주 1회 뭉치.
# **종류를 흩는다**: 한 종류만 주면 나머지 셋의 천장이 안 찬다(TicketDefs).
const WEEKLY := [
	{"id": "wkills", "kind": "kills", "name": "몬스터 500마리 처치", "need": 500,
		"reward": "ticket_trinket", "amount": 5, "icon": "quest_kill"},
	{"id": "wtrain", "kind": "train", "name": "훈련 30회", "need": 30,
		"reward": "gem", "amount": 40, "icon": "quest_forge"},
	{"id": "wsummon", "kind": "summon", "name": "소환 20회", "need": 20,
		"reward": "gem", "amount": 40, "icon": "quest_summon"},
	{"id": "wdungeon", "kind": "dungeon", "name": "미궁 5층 돌파", "need": 5,
		"reward": "crystal", "amount": 60, "icon": "quest_maze"},
	{"id": "wraid", "kind": "raid", "name": "재화 던전 5회 격파", "need": 5,
		"reward": "ticket_weapon", "amount": 5, "icon": "raid_blood"},
	{"id": "wdaily", "kind": "daily", "name": "일일 임무 25개 받기", "need": 25,
		"reward": "ticket_skill", "amount": 5, "icon": "badge_mastery"},
]


static func wof(id: String) -> Dictionary:
	for q in WEEKLY:
		if str(q["id"]) == id:
			return q
	return {}


# 새 날의 진행표. 접속 임무는 태어나면서 차 있다 — "오늘 처음 열었다"가 곧 달성이다.
static func fresh_prog() -> Dictionary:
	return {"login": 1}


static func of(id: String) -> Dictionary:
	for q in QUESTS:
		if str(q["id"]) == id:
			return q
	return {}
