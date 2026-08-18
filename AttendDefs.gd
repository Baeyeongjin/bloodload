class_name AttendDefs

# 출석 — **하루 한 번 여는 이유**.
#
# 왜 필요한가: 지금 시계가 방치 8시간·일일 24시간·주간 7일뿐이라, 하루 한 번
# 들어와 다 처리하면 그날 할 게 없다. 출석은 그 자체로 컨텐츠는 아니지만
# **접속 자체에 값을 매기는** 가장 싼 장치다(업계 공통).
#
# **연속을 요구하지 않는다.** 이게 이 표의 유일한 설계 판단이다 — 연속 출석은
# 하루 놓친 유저를 처음으로 되돌리는데, 그 순간이 정확히 이탈 지점이다.
# 우리는 누적으로 센다: 30일을 채우는 데 며칠이 걸리든 상관없다.
#
# 한 바퀴(30칸)를 돌면 다시 1일로 돌아간다 — 끝이 있으면 끝난 뒤에 할 게 없다.
const DAYS := 30

# 7·14·21·30 이 큰 날이다. 나머지는 소소하게 — 매일이 잔칫날이면 잔치가 아니다.
# 보상 종류는 **소환권 위주**다: 보석으로 주면 소환 아닌 곳으로 샌다
# (QuestDefs 가 같은 이유로 보석을 25 로 줄였다).
const REWARDS := {
	7: {"reward": "ticket_weapon", "amount": 5},
	14: {"reward": "ticket_armor", "amount": 5},
	21: {"reward": "ticket_skill", "amount": 5},
	30: {"reward": "ticket_trinket", "amount": 10},
}

# 큰 날이 아닌 보통 날. 3일마다 소환권 하나, 나머지는 보석·혈정을 번갈아 —
# 한 종류만 주면 손에 남는 게 한 줄이라 눈에 안 띈다.
static func of(day: int) -> Dictionary:
	var d := clampi(day, 1, DAYS)
	if REWARDS.has(d):
		var r: Dictionary = REWARDS[d]
		return {"day": d, "reward": str(r["reward"]), "amount": int(r["amount"]),
			"big": true}
	if d % 3 == 0:
		return {"day": d, "reward": "ticket_weapon", "amount": 1, "big": false}
	if d % 2 == 0:
		return {"day": d, "reward": "crystal", "amount": 30, "big": false}
	return {"day": d, "reward": "gem", "amount": 20, "big": false}


# 30일을 다 받으면 다음 바퀴의 1일로. 0 은 "아직 하나도 안 받음"이다.
static func next_day(claimed: int) -> int:
	return claimed % DAYS + 1
