class_name QuestDefs

# 일일 임무 (REFERENCE_TEARDOWN 4장-1). 참고작 원칙 그대로 — 임무는 전부
# **어차피 하는 행동의 기록**이다. 새 그라인드를 만들지 않는다: 훅은 이미
# Main 에 있는 행동(처치·훈련·소환·미궁·소탕·펫·구간·강화·계약·상자)뿐이고,
# 접속은 날짜가 바뀌는 순간 자동으로 찬다.
#
# ── 규모 (2026-08-20 개편, 사장님: "보상이 너무 적어 소환권을 충당 못 한다")
#
# 실측이 먼저였다: PaceProbe 가 표를 직접 읽게 고쳐서 재니 **하루 12.2회**였다.
# 그런데 뽑기는 종류가 여섯(무기·방어·장신구·스킬·펫·펫장비)이라 나누면
# **종류당 하루 2회**고, 소환 레벨 만렙은 누적 4,500회라 500일이 걸렸다.
# 어느 갈래도 진척이 안 보이는 게 당연했다. 목표를 하루 30회로 잡는다.
#
# 임무가 그중 절반을 댄다: **소환권 12장 + 보석 170**(= 5.7회) = 하루 17.7회.
# 보석 액수는 손으로 정한 게 아니라 PaceProbe 를 세 번 돌려 맞춘 값이다
# (12.2 -> 21.6 -> 27.9 -> 30). 표를 만지면 그 자가 바로 답을 준다.
# 나머지는 주간·출석·업적·광고가 나눠 낸다.
#
# **보석보다 소환권으로 준다** — 보석은 상점으로도 새지만 소환권은 소환에만
# 쓰인다. "소환하라"고 준 보상은 소환권이어야 의도가 안 샌다(TicketDefs).
# 남긴 보석은 상점 통화다.
#
# **여섯 종류를 흩는다.** 한 종류만 주면 나머지 다섯의 천장이 안 찬다.
# 12장 = 여섯 종류 x 2장이고, 그래서 어느 갈래든 매일 두 칸씩 움직인다.
#
# "all"(마무리 임무)의 need 는 6 이다 — 미궁은 본편 30구간이, 재화 던전은
# 그 전 구간이 열어서 초반에는 임무가 여섯쯤만 뜬다. 6 이면 첫날에도 하루를
# 닫을 수 있고, 다 열리면 열하나 중 여섯이라 여유가 생긴다.
const QUESTS := [
	{"id": "login", "name": "핏빛 성에 접속", "need": 1,
		"reward": "ticket_weapon", "amount": 2, "icon": "quest_login"},
	{"id": "kills", "name": "몬스터 300마리 처치", "need": 300,
		"reward": "gem", "amount": 50, "icon": "quest_kill"},
	{"id": "train", "name": "훈련 30회", "need": 30,
		"reward": "gem", "amount": 40, "icon": "quest_forge"},
	{"id": "summon", "name": "소환 10회", "need": 10,
		"reward": "ticket_skill", "amount": 2, "icon": "quest_summon"},
	{"id": "dungeon", "name": "미궁 1층 돌파", "need": 1,
		"reward": "crystal", "amount": 40, "icon": "quest_maze"},
	{"id": "raid", "name": "재화 던전 2회 격파", "need": 2,
		"reward": "ticket_armor", "amount": 2, "icon": "raid_blood"},
	{"id": "pet", "name": "동행의 그릇 받기", "need": 1,
		"reward": "ticket_pet", "amount": 2, "icon": "raid_hunt"},
	{"id": "stage", "name": "구간 5회 돌파", "need": 5,
		"reward": "ticket_trinket", "amount": 2, "icon": "stat_damage"},
	{"id": "gear", "name": "장비 조합 1회", "need": 1,
		"reward": "gem", "amount": 40, "icon": "raid_essence"},
	{"id": "oath", "name": "핏빛 계약 1회", "need": 1,
		"reward": "oath_card", "amount": 1, "icon": "oath_card"},
	{"id": "chest", "name": "방치 상자 열기", "need": 1,
		"reward": "ticket_petgear", "amount": 2, "icon": "chest"},
	{"id": "all", "name": "임무 6개 완료", "need": 6,
		"reward": "gem", "amount": 40, "icon": "badge_mastery"},
]


# ── 주간 임무 (참고작 ⑫ — 일일과 별도 목록, 사장님) ─────────────────────────
# 일일과 같은 훅을 쓰되 **주간 규모**다. kind 가 훅 열쇠라 일일 kind 와 겹쳐도
# 카운터는 따로 쌓인다(quest_wprog).
#
# 합: 소환권 30(여섯 종류) + 보석 200 + 혈정 400 — 하루로 펴면 약 5.2회.
# 일일이 늘어난 만큼 필요값도 같이 올렸다: 일일 12종이면 주 84개가 쌓이므로
# "일일 임무 60개"가 성실히 하면 닿고 며칠 빠지면 못 닿는 자리다.
const WEEKLY := [
	{"id": "wkills", "kind": "kills", "name": "몬스터 3000마리 처치", "need": 3000,
		"reward": "ticket_trinket", "amount": 6, "icon": "quest_kill"},
	{"id": "wtrain", "kind": "train", "name": "훈련 300회", "need": 300,
		"reward": "gem", "amount": 100, "icon": "quest_forge"},
	{"id": "wsummon", "kind": "summon", "name": "소환 150회", "need": 150,
		"reward": "ticket_weapon", "amount": 6, "icon": "quest_summon"},
	{"id": "wdungeon", "kind": "dungeon", "name": "미궁 10층 돌파", "need": 10,
		"reward": "crystal", "amount": 400, "icon": "quest_maze"},
	{"id": "wraid", "kind": "raid", "name": "재화 던전 12회 격파", "need": 12,
		"reward": "ticket_armor", "amount": 6, "icon": "raid_blood"},
	{"id": "wdaily", "kind": "daily", "name": "일일 임무 60개 받기", "need": 60,
		"reward": "ticket_skill", "amount": 6, "icon": "badge_mastery"},
	{"id": "wpet", "kind": "pet", "name": "동행의 그릇 20회", "need": 20,
		"reward": "ticket_petgear", "amount": 3, "icon": "raid_hunt"},
	{"id": "wstage", "kind": "stage", "name": "구간 100회 돌파", "need": 100,
		"reward": "ticket_pet", "amount": 3, "icon": "stat_damage"},
	{"id": "wgear", "kind": "gear", "name": "장비 조합 10회", "need": 10,
		"reward": "gem", "amount": 100, "icon": "raid_essence"},
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
