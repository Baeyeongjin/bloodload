class_name QuestDefs

# 일일 임무 (REFERENCE_TEARDOWN 4장-1). 참고작 원칙 그대로 — 임무는 전부
# **어차피 하는 행동의 기록**이다. 새 추적 축을 만들지 않는다: 훅은 Main 의
# 기존 4곳(처치·훈련 구매·소환·미궁 층 돌파)뿐이고, 접속은 날짜가 바뀌는
# 순간 자동으로 찬다.
#
# 보상 규모: 보석 합 75/일 = 소환 2.5회(GachaDefs.COST 30). 소환이 스킬·장비의
# 수도꼭지라 "매일 접속하면 매일 뽑는다"가 하루 루프의 뼈대가 된다. 미궁 임무만
# 혈정을 준다 — 혈정은 미궁 전용 재화(EXPANSION 6장)라 임무도 미궁이 준다.
#
# "all"(마무리 임무)의 need 는 4 다 — 미궁은 본편 30구간이 열어서(교차 잠금)
# 그 전에는 기본 임무가 4개뿐이다. 4로 두면 미궁 전에도 하루를 닫을 수 있고,
# 미궁이 열리면 다섯 중 넷이라 여유가 생긴다.
# 아이콘: 전용판 5종 (2026-08-12 사장님 세트 승인).
const QUESTS := [
	{"id": "login", "name": "핏빛 성에 접속", "need": 1,
		"reward": "gem", "amount": 10, "icon": "quest_login"},
	{"id": "kills", "name": "몬스터 50마리 처치", "need": 50,
		"reward": "gem", "amount": 15, "icon": "quest_kill"},
	{"id": "train", "name": "훈련 5회", "need": 5,
		"reward": "gem", "amount": 10, "icon": "quest_forge"},
	{"id": "summon", "name": "소환 3회", "need": 3,
		"reward": "gem", "amount": 10, "icon": "quest_summon"},
	{"id": "dungeon", "name": "미궁 1층 돌파", "need": 1,
		"reward": "crystal", "amount": 20, "icon": "quest_maze"},
	{"id": "all", "name": "임무 4개 완료", "need": 4,
		"reward": "gem", "amount": 30, "icon": "badge_mastery"},
]


# 새 날의 진행표. 접속 임무는 태어나면서 차 있다 — "오늘 처음 열었다"가 곧 달성이다.
static func fresh_prog() -> Dictionary:
	return {"login": 1}


static func of(id: String) -> Dictionary:
	for q in QUESTS:
		if str(q["id"]) == id:
			return q
	return {}
