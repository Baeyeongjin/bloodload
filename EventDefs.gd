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

# **단계** (사장님 2026-08-13). 재화 던전은 격파할 때마다 도전 단계가 올라 계속
# 세지는데 주간 보스만 제자리였다 — 이정표 넷을 다 받으면 그걸로 끝이라, 그 주에
# 더 할 일이 없어진다. 이제 넷을 다 받으면 **다음 단계**가 열리고 누적이 0 에서
# 다시 시작한다. 단계는 주가 바뀌어도 남는다(주마다 얼굴만 바뀌는 같은 사다리다).
const TIER_STEP := 1.6      # 단계마다 요구·보상 배수


static func tier_mult(tier: int) -> float:
	return pow(TIER_STEP, float(maxi(1, tier) - 1))

# 주마다 도는 보스. 이름과 결만 다르고 체력은 아래 식이 정한다 — 표를 늘리면
# 그만큼 주기가 길어진다(지금 4주 순환).
# key/anim 은 본편 막 보스 자산을 그대로 빌린다 — 이벤트용 몹을 새로 뽑을 이유가
# 없다(이름과 결이 다르면 다른 놈으로 읽힌다). 새 자산이 생기면 여기만 바꾼다.
# **4종으로 마무리한다** (사장님 2026-08-13): 매주 얼굴이 바뀌고 넉 주에 한 바퀴.
# 본편 보스를 빌려 쓰던 옛 넷은 뺐다 — 같은 놈이 본편에도 나오면 "주간 보스"라는
# 자리가 안 선다. 지금 넷은 걷기·공격·특수까지 전용이라 여기서만 볼 수 있다.
# 단계(TIER_STEP)가 무한이므로 종수가 적어도 도전은 계속 세진다.
const BOSSES := [
	{"name": "역병의 산파", "key": "plague_hag", "anim": "plague_hag",
		"art": "boss_hag"},
	{"name": "뼈의 합창단", "key": "bone_choir", "anim": "bone_choir",
		"art": "boss_choir"},
	{"name": "피의 여왕", "key": "blood_queen", "anim": "blood_queen",
		"art": "boss_queen"},
	{"name": "잊힌 도살자", "key": "butcher", "anim": "butcher",
		"art": "boss_butcher"},
]

# 마일스톤 — 그 주 누적 피해가 이 배수(내 dps x 초)를 넘으면 하나씩 열린다.
# 기준을 절대 수치가 아니라 **내 화력 대비**로 잡는 이유: 절대값이면 초반엔
# 영영 못 닿고 후반엔 첫 판에 전부 열린다.
# 2026-08-13: 뒤 둘을 소환권으로 바꿨다(MONETIZATION_PLAN 4-1 의 "다음 손질").
# 주간 보스는 **못 죽여도 쌓이는** 컨텐츠라 벽 앞에서도 돌아가는데, 보상이 전부
# 범용 재화면 그 노력이 상점으로 새어 나간다. 뒤 이정표일수록 도달이 어려우므로
# 거기에 고급권을 둔다 — 소환권 설계에서 고급권 발행처는 "닷새를 빠짐없이"급
# 자리로 정해 뒀다.
const MILESTONES := [
	{"need": 30.0, "reward": "gem", "amount": 60},
	{"need": 90.0, "reward": "crystal", "amount": 80},
	{"need": 200.0, "reward": "ticket", "amount": 10},
	{"need": 400.0, "reward": "ticket_hi", "amount": 3},
]


# 판에 거는 초상화. 몹 스프라이트(32px)를 빌려 쓰면 판이 초라해서 전용으로 뽑았다.
static func art_path(b: Dictionary) -> String:
	return "res://assets/ui/%s.png" % str(b.get("art", ""))


static func boss_of(week_index: int) -> Dictionary:
	return BOSSES[week_index % BOSSES.size()]


# 보스 체력 — 한 판(40초)에 못 죽이는 게 정상이라 넉넉히 잡는다. 도전 자체가
# 목적이 아니라 **피해 누적**이 목적이다.
static func boss_hp(dps: float, tier := 1) -> float:
	return maxf(1.0, dps) * TIME_LIMIT * 20.0 * tier_mult(tier)


# 이번 주 이정표의 절대 피해량. dps 는 도전 시점의 화력이다.
static func milestone_damage(i: int, dps: float, tier := 1) -> float:
	return maxf(1.0, dps) * float(MILESTONES[i]["need"]) * tier_mult(tier)


# 그 단계의 보상량. 요구가 오른 만큼 준다 — 안 그러면 단계를 올릴 이유가 없다.
static func milestone_amount(i: int, tier := 1) -> int:
	return int(round(float(MILESTONES[i]["amount"]) * tier_mult(tier)))
