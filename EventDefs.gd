class_name EventDefs

# 주간 보스 (참고작 ⑮ 월드보스의 1인용 축소판, REFERENCE_TEARDOWN 4장-8).
#
# 참고작과 다른 점 하나: **랭킹을 뺐다.** 이 게임은 서버가 없다 — 남과 겨루는
# 자리에 남이 없으면 순위판은 빈 액자다. 대신 참고작 구조에서 **혼자서도
# 도는 부분**만 가져온다: 기간제 보스 · 피해량 기록 · 마일스톤 보상 트랙.
#
# 규칙: 주마다 보스가 바뀐다(월요일). 하루 3번 도전, 한 번에 40초 —
# **못 죽여도 된다.** 넣은 피해가 그 주 기록에 누적되고, 누적이 이정표를
# 넘을 때마다 보상이 열린다. 이 "못 깨도 진행된다"가 벽 앞의 유저에게
# 남는 마지막 할 일이다(난이도 x3 이후 특히).
const TRIES_PER_DAY := 3
const TIME_LIMIT := 40.0

# 주마다 도는 보스. 이름과 결만 다르고 체력은 아래 식이 정한다 — 표를 늘리면
# 그만큼 주기가 길어진다(지금 4주 순환).
# key/anim 은 본편 막 보스 자산을 그대로 빌린다 — 이벤트용 몹을 새로 뽑을 이유가
# 없다(이름과 결이 다르면 다른 놈으로 읽힌다). 새 자산이 생기면 여기만 바꾼다.
const BOSSES := [
	{"name": "피에 굶주린 군주", "key": "wraith_knight", "anim": "boss_1"},
	{"name": "심연의 감시자", "key": "eye_mass", "anim": "boss_4"},
	{"name": "뒤틀린 성녀", "key": "gargoyle", "anim": "boss_2"},
	{"name": "재의 폭군", "key": "dark_knight", "anim": "boss_5"},
]

# 마일스톤 — 그 주 누적 피해가 이 배수(내 dps x 초)를 넘으면 하나씩 열린다.
# 기준을 절대 수치가 아니라 **내 화력 대비**로 잡는 이유: 절대값이면 초반엔
# 영영 못 닿고 후반엔 첫 판에 전부 열린다.
const MILESTONES := [
	{"need": 30.0, "reward": "gem", "amount": 60},
	{"need": 90.0, "reward": "crystal", "amount": 80},
	{"need": 200.0, "reward": "sigil", "amount": 120},
	{"need": 400.0, "reward": "gem", "amount": 200},
]


static func boss_of(week_index: int) -> Dictionary:
	return BOSSES[week_index % BOSSES.size()]


# 보스 체력 — 한 판(40초)에 못 죽이는 게 정상이라 넉넉히 잡는다. 도전 자체가
# 목적이 아니라 **피해 누적**이 목적이다.
static func boss_hp(dps: float) -> float:
	return maxf(1.0, dps) * TIME_LIMIT * 20.0


# 이번 주 이정표의 절대 피해량. dps 는 도전 시점의 화력이다.
static func milestone_damage(i: int, dps: float) -> float:
	return maxf(1.0, dps) * float(MILESTONES[i]["need"])
