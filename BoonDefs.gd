class_name BoonDefs

# 은총 — **주마다 바뀌는 특전**.
#
# 왜 필요한가: 컨텐츠를 아무리 쌓아도 매주 같은 것을 돌면 신선함이 없다.
# 은총은 새 컨텐츠를 만들지 않고 **이미 있는 것의 값을 주마다 다르게** 매긴다 —
# 이번 주는 사냥이 잘 되고 다음 주는 미궁이 잘 돈다. "이번 주는 뭐지"가 생긴다.
#
# 이름이 EventDefs 가 아닌 이유: 그쪽은 주간 보스다(같은 월요일을 쓰지만 다른 것).
#
# **여섯 주에 한 바퀴** — 넷이면 한 달마다 같은 게 돌아와 로테이션이 안 느껴진다.
# 값은 전부 "하루 벌이의 절반쯤"으로 맞췄다: 은총이 있는 주와 없는 주가 두 배
# 차이 나면 없는 주가 손해로 읽혀서, 안 오는 주에 접속을 쉬게 만든다.
const BOONS := [
	{"id": "moon", "name": "핏빛 만월", "kind": "gold", "value": 0.5,
		"text": "사냥 혈액 +50%"},
	{"id": "tide", "name": "혈정의 물결", "kind": "sweep", "value": 1.0,
		"text": "미궁 소탕 2배"},
	{"id": "sleep", "name": "긴 잠", "kind": "hours", "value": 6.0,
		"text": "방치 상한 +6시간"},
	{"id": "vein", "name": "풍요의 광맥", "kind": "raid", "value": 1.0,
		"text": "재화 던전 보상 2배"},
	{"id": "star", "name": "소환의 별", "kind": "ticket", "value": 3.0,
		"text": "매일 소환권 +3"},
	{"id": "rite", "name": "피의 의식", "kind": "essence", "value": 1.0,
		"text": "보스 정수 2배"},
]


# 그 주의 은총. week_key 는 Main._quest_week_key() 가 주는 **월요일 날짜**
# 문자열이라, 주간 임무·주간 보스와 같은 월요일에 바뀐다.
static func of(week_key: String) -> Dictionary:
	if week_key == "":
		return BOONS[0]
	# 날짜 문자열을 주 수로. 문자열을 그대로 해싱하면 순서가 뒤죽박죽이라
	# **다음 주에 뭐가 오는지 못 적는다** — 시간으로 세야 차례가 선다.
	var t := Time.get_unix_time_from_datetime_string(week_key)
	var weeks := int(floor(t / 604800.0))
	return BOONS[posmod(weeks, BOONS.size())]


# 이 주 은총이 그 종류면 값을, 아니면 0. 훅마다 한 줄로 붙는다.
static func bonus(week_key: String, kind: String) -> float:
	var b := of(week_key)
	return float(b["value"]) if str(b["kind"]) == kind else 0.0


# 다음 주 은총 — 판에 미리 적어 둔다. "다음 주에 올 것"이 이번 주에 접속할
# 이유는 아니지만, 다음 주에 돌아올 이유는 된다.
static func next_of(week_key: String) -> Dictionary:
	if week_key == "":
		return BOONS[1]
	var t := Time.get_unix_time_from_datetime_string(week_key)
	var weeks := int(floor(t / 604800.0)) + 1
	return BOONS[posmod(weeks, BOONS.size())]
