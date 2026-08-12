class_name StageDefs
extends RefCounted

# 스테이지 진행. 방치형이라 "몇 마리 잡으면 다음"이 유일한 게이트다.
#
# 서사: 봉인당한 흡혈귀 군주가 밤마다 사냥터를 넓혀 힘을 되찾는다.
#
# 큰 단계 1~100마다 세부 구간 1~10이 있고, 보유한 5개 테마를 순환 재사용한다.
# 내부 저장값은 1~1000의 정수라 기존 저장 형식을 바꾸지 않는다.

const MAJOR_STAGE_COUNT := 100   # 표시되는 큰 단계: 1..100
const STEPS_PER_STAGE := 10      # 각 큰 단계의 세부 구간: 1..10
const MIDBOSS_STEP := 5          # 5번째 구간은 승격 잡몹 한 마리
const BOSS_EVERY := 10           # 10번째 구간은 보스
# 일반 구간 통과에 필요한 처치 수. **이게 구간 길이를 정하는 유일한 레버다.**
#
# 한 마리에 약 1.15초 걸린다(실측). 그중 0.89초는 대기 몹이 전열로 걸어오는
# 고정비라(Balance.APPROACH_SECONDS) **DPS 로 안 줄어든다** — 세져도 구간이 안
# 짧아진다. 그래서 길이를 줄이려면 마릿수를 줄이는 것 말고는 방법이 없다.
#
# 100 -> 40 -> 60 (2026-08-06, 사장님). 100 은 "초당 1마리 x 제한 100초"에서 나온
# 값인데 제한이 없어졌으니 근거가 남지 않았고, 실제로는 120초가 걸려 늘어졌다.
# 40 은 그때 한 마리에 1.09초가 걸려 약 46초였다.
#
# **웨이브를 접고 영웅이 찾아가는 모델로 바꾸자 한 마리가 0.83초가 됐다** — 몹이
# 천천히 걸어오기를 기다리지 않고 영웅이 달려가므로 고정비가 줄었다. 그래서 40마리는
# 33초로 짧아졌고, 사장님이 말한 **50초**에 맞추려면 60마리다.
# 목표는 마릿수가 아니라 구간 길이다(레퍼런스 방치형 40~60초 대역).
const KILLS_PER_STAGE := 60
const MIDBOSS_PREFIXES := ["타락한", "굶주린", "피에 젖은"]

# 막 5개. roster는 그 막에 나오는 몹 키.
# bg는 가로로 긴 도트 한 장(768x208)이고 화면에는 2배(1536x416)로 그린다.
#   - 세로 416 = 전투 띠 높이 전체. 그림 하나가 띠를 통째로 덮는다.
#   - 가로 1536 = 화면 폭의 2.6배라 같은 그림이 금방 되돌아오지 않는다.
#   - 좌우 끝에 같은 세로 기둥을 세워 그려서, 옆으로 이어 붙이면 기둥 둘이 만나
#     굵은 기둥 하나로 읽힌다 — 이음매 없이 무한 스크롤된다.
# 생성 공식과 job id는 docs/BG_RECIPE.md 에 적어 뒀다(추가 맵도 같은 틀로 뽑는다).
# 몹 키는 arrow-rpg GameConfig.enemy_tiers()의 key를 그대로 쓴다(자산 재사용).

# 바닥 윗면이 있는 행. **막마다 같다** — 지면선이 막이 바뀔 때마다 오르내리면
# 안 되기 때문이다(사장님). 생성 결과는 지면이 그림마다 아무 데나 오므로
# 320줄로 넉넉히 뽑아 tools/fit_ground.py 가 이 행 기준으로 208줄을 떠낸다.
# 코드가 배경을 밀어서 맞추면 반대쪽에 빈 자리가 생기고, 그걸 메우려고 하늘
# 그라데이션 같은 보정이 다시 붙는다 — 그림 쪽을 맞추는 게 맞다.
const GROUND_ROW := 145
const ACTS := [
	{"name": "깨어난 무덤", "bg": "res://assets/bg/wide_graveyard.png",
		"roster": ["slime", "goblin", "bat", "zombie", "skeleton"],
		"boss": "wraith_knight", "boss_name": "망령 기사", "boss_anim": "boss_1"},
	{"name": "화형의 언덕", "bg": "res://assets/bg/wide_hell.png",
		"roster": ["fire_imp", "lava_toad", "hellhound", "orc", "demon"],
		"boss": "gargoyle", "boss_name": "가고일 군주", "boss_anim": "boss_2"},
	{"name": "서리 봉인지", "bg": "res://assets/bg/wide_glacier.png",
		"roster": ["frost_spider", "ice_wisp", "frost_golem", "bat", "ghoul"],
		"boss": "frost_golem", "boss_name": "프로스트 골렘", "boss_anim": "boss_3"},
	{"name": "핏빛 성소", "bg": "res://assets/bg/wide_sanctum.png",
		"roster": ["void_wraith", "eye_mass", "spider", "cultist", "mushroom"],
		"boss": "eye_mass", "boss_name": "눈알 덩어리", "boss_anim": "boss_4"},
	{"name": "빼앗긴 본성", "bg": "res://assets/bg/wide_castle.png",
		"roster": ["dark_knight", "wraith_knight", "cultist", "demon", "orc"],
		"boss": "dark_knight", "boss_name": "다크 나이트", "boss_anim": "boss_5"},
]


static func act_count() -> int:
	return ACTS.size()


static func total_stages() -> int:
	return MAJOR_STAGE_COUNT * STEPS_PER_STAGE


# 개발 플래그는 기존 내부 숫자와 새 `큰단계-구간` 표기를 둘 다 받는다.
static func parse(value: String) -> int:
	var parts := value.split("-", false, 1)
	if parts.size() == 2:
		var major := clampi(int(parts[0]), 1, MAJOR_STAGE_COUNT)
		var step := clampi(int(parts[1]), 1, STEPS_PER_STAGE)
		return (major - 1) * STEPS_PER_STAGE + step
	return clampi(int(value), 1, total_stages())


static func label(stage: int) -> String:
	return "%d-%d" % [major_stage(stage), step_in_act(stage)]


# 내부 진행값 -> 화면에 표시되는 큰 단계(1..100).
static func major_stage(stage: int) -> int:
	return clampi((stage - 1) / STEPS_PER_STAGE + 1, 1, MAJOR_STAGE_COUNT)


# 큰 단계마다 5개 테마를 순환한다.
static func act_of(stage: int) -> int:
	return (major_stage(stage) - 1) % ACTS.size()


static func act_data(stage: int) -> Dictionary:
	return ACTS[act_of(stage)]


# 큰 단계 안에서 몇 번째 구간인가 (1..STEPS_PER_STAGE).
static func step_in_act(stage: int) -> int:
	return (stage - 1) % STEPS_PER_STAGE + 1


static func is_boss_stage(stage: int) -> bool:
	return step_in_act(stage) == BOSS_EVERY


static func is_midboss_stage(stage: int) -> bool:
	return step_in_act(stage) == MIDBOSS_STEP


static func midboss_prefix(stage: int) -> String:
	return MIDBOSS_PREFIXES[(major_stage(stage) - 1) % MIDBOSS_PREFIXES.size()]


# 단계별 적 강화 배수. 방치형은 "숫자가 오르는 게 보상"이라 곡선이 완만하고 끝이 없다.
#
# 선형항(1 + p×0.35)을 없애고 **순수 지수**로 바꿨다. 선형+지수 혼합이면 초반에
# 적이 급격히 세지는데(첫날→1주 ×49.2), 그 사이 영웅 DPS 는 ×5 밖에 안 올라
# 첫 일주일에만 벽이 몰리고 그 뒤로는 성장 체감이 0이었다 — DESIGN 13-1 의
# "초반 폭발 → 중반 해금 → 후반 누적"과 정반대였고 하필 D+1~D+7 구간이다.
# 큰 단계마다 ×1.038 이면 100단계 누적 ×40 으로, STATS 4장의 DPS 곡선과 나란히 간다.
#
# **두 값은 `static var` 다** — 곡선을 고르는 계측기(`tests/CurveSweep.gd`)가 여러
# 값을 넣어 보고 벽이 어디 서는지 표로 뽑는다. 게임 코드는 절대 안 바꾼다.
# 눈으로 고르는 값이라 후보를 넣어 볼 수 있어야 한다.
# 1.038 -> 1.064 (2026-08-12, 사장님 플레이 실측). 레벨 43·공격 43 으로 45단계
# 보스가 기본 스킬만으로 잡혔다 — "아무것도 안 해도 돌파가 된다. 지금보다 3배
# 어렵게." 지수를 세워 **45단계에서 정확히 x3** 이 되게 잡았다:
#   1.038 x 3^(1/44) = 1.0642 -> 1단계는 그대로(신규 유저 무풍), 45단계 x2.97,
#   100단계 x12.4. 멀수록 더 어려워져 "매일 벌어서 벽을 민다"가 구조가 된다.
# 이전 결정(1.045 후보 기각, 벽 500 목표)은 이 실측으로 뒤집혔다 — 시뮬 벽은
# 전부-투자 정책 기준이라, 실플레이(공격 43만)로도 뚫리는 곡선은 벽이 아니었다.
static var POWER_STEP := 1.064      # 큰 단계(10구간)마다 적이 세지는 배수
# 0.55 -> 1.10 (2026-08-11, EXPANSION 6단계 최종 조정). 새 축(혈맥·군림·칭호)이
# 다 들어온 상태에서 CurveSweep 으로 5개 조합을 재측정한 결과다:
#
#     적 x1.038 돈 0.55   전부 350 / 전부+혈맥 450
#     적 x1.038 돈 1.10   전부 400 / 전부+혈맥 500   <- 목표(500) 정중앙. 채택
#     적 x1.045 돈 1.10   전부 300 / 전부+혈맥 400   <- 몹을 세우면 나빠지기만
#
# 안 찍는 길(공격 제외 10 / 스킬만 100 / 무투자 10)은 어느 조합에서도 그대로
# 막혀 있다 — 보상을 올려도 투자 강제는 안 풀린다.
static var GOLD_SLOPE := 1.10       # 큰 단계마다 처치 보상에 더해지는 몫


static func enemy_power(stage: int) -> float:
	return pow(POWER_STEP, float(maxi(1, stage) - 1) / float(STEPS_PER_STAGE))


# 처치로 얻는 피. 적 강화보다 조금 느리게 올려 후반에 방치가 필요해지게 한다.
#
# **지수로 바꿔 봤다가 되돌렸다**(2026-08-11). 1000구간에서 같은 값(x56)이 되게
# 지수를 잡으면 **중반이 훨씬 가난해진다** — 500구간에서 선형 28.5 vs 지수 7.4.
# 그래서 벽이 250 -> 150 으로 당겨졌다(`tests/CurveSweep` 실측). 선형이 중반을
# 받쳐 주고 있었다.
static func gold_per_kill(stage: int) -> float:
	return 1.0 + float(maxi(1, stage) - 1) / float(STEPS_PER_STAGE) * GOLD_SLOPE


# 첫 보스가 일반 장비 첫 강화 1회를 열고, 이후 큰 단계마다 5씩 오른다.
static func boss_essence(stage: int) -> float:
	return 25.0 + float(major_stage(stage) - 1) * 5.0


# 이 단계를 넘는 데 필요한 처치 수. 보스 단계는 보스 1마리.
static func kills_needed(stage: int) -> int:
	return 1 if is_boss_stage(stage) or is_midboss_stage(stage) else KILLS_PER_STAGE


# 구간 제한 시간. **보스·중간보스에만 건다**(2026-08-06, 사장님 결정).
#
# 한동안 모든 구간에 걸었었다. 이유는 "일반 구간이 아무리 약해도 언젠가는 넘어가면
# 벽이 아니다"였는데, 벽은 이미 **5구간마다 중간보스, 10구간마다 보스**로 서 있다.
# 일반 구간까지 시계로 막으면 벽이 아니라 **처리량 상한**이 된다: 몹이 화면 밖에서
# 걸어오는 시간이 고정비라, 몹을 천천히 걸어오게 하는 순간 어떤 수치로도 못 넘는
# 구간이 생겼다(걷기 120 -> 80 으로 늦추자 60초 처치가 69 -> 48, 100마리에 125초).
# 연출을 밸런스가 거부하는 구조여서 시계를 뺐다.
#
# 시계가 빠진 뒤 일반 구간의 게이트는 **생존 하나**다(Balance.can_clear_stage 가
# time_limit <= 0 이면 생존만 본다). 약하면 못 넘는 게 아니라 **느려진다** — 그게
# 방치형의 정상 압력이고, 오프라인도 같은 값으로 시간을 물린다(Main._grant_offline).
#
# 시계는 전진(걸어가는 구간)에도 돈다 — 멈추면 화면의 숫자가 얼어붙어 고장으로 보이고,
# 무리를 잘게 쪼개 시간을 버는 구멍도 생긴다. 대신 **처음** 걸어 들어오는 시간만
# 예산에서 빼 준다: 그 뒤로는 죽은 칸을 바로 채우므로 걷기와 싸움이 겹친다.
const TIME_MIDBOSS := 45.0
const TIME_BOSS := 60.0
# 일반 구간의 **목표 소요 시간**. 제한이 아니라 페이스다 — 넘겨도 실패하지 않지만,
# 이보다 한참 길어지면 구간이 늘어져 죽은 화면이 된다. BalanceTest 가 설계 성장점
# 마다 이 값을 넘는지 본다.
#
# **60 = 레퍼런스 방치형 일반 구간 대역(40~60초)의 상한이다.** 목표 길이는 50초이고
# (60마리 x 0.83), 설계 성장점에서 53~56초가 나온다 — 55 로 두면 그 중 하나가 1초
# 넘어 늘 빨간불이라 상한을 대역 끝에 맞췄다. 레버는 KILLS_PER_STAGE 하나뿐이다.
const PACE_NORMAL := 60.0
const WAVE_WALK_SECONDS := 2.3   # 첫 무리가 화면 밖에서 제 자리까지 걸어오는 시간


# 0 이하 = 제한 없음. Balance.can_clear_stage 와 같은 약속이다.
static func time_limit(stage: int) -> float:
	if is_boss_stage(stage):
		return TIME_BOSS
	return TIME_MIDBOSS if is_midboss_stage(stage) else 0.0
