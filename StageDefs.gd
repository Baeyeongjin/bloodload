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
const KILLS_PER_STAGE := 20      # 일반 단계 통과에 필요한 처치 수
const MIDBOSS_PREFIXES := ["타락한", "굶주린", "피에 젖은"]

# 막 5개. roster는 그 막에 나오는 몹 키.
# bg는 가로로 긴 도트 한 장(768x160)이고 화면에는 2배(1536x320)로 그린다.
#   - 세로 320 = 전투 띠 높이라 딱 맞는다.
#   - 가로 1536 = 화면 폭의 2.6배라 같은 그림이 금방 되돌아오지 않는다.
#   - 좌우 끝에 같은 세로 기둥을 세워 그려서, 옆으로 이어 붙이면 기둥 둘이 만나
#     굵은 기둥 하나로 읽힌다 — 이음매 없이 무한 스크롤된다.
# 생성 공식과 job id는 docs/BG_RECIPE.md 에 적어 뒀다(추가 맵도 같은 틀로 뽑는다).
# ground = 원본에서 바닥 윗면이 있는 행. 그림마다 달라서 눈으로 맞추면 캐릭터가
# 공중에 뜬다 — tools/measure_ground.py 로 실측한 값이다.
# 몹 키는 arrow-rpg GameConfig.enemy_tiers()의 key를 그대로 쓴다(자산 재사용).
const ACTS := [
	{"name": "깨어난 무덤", "bg": "res://assets/bg/wide_graveyard.png", "ground": 141,
		"roster": ["slime", "goblin", "bat", "zombie", "skeleton"],
		"boss": "wraith_knight", "boss_name": "망령 기사", "boss_anim": "boss_1"},
	{"name": "화형의 언덕", "bg": "res://assets/bg/wide_hell.png", "ground": 140,
		"roster": ["fire_imp", "lava_toad", "hellhound", "orc", "demon"],
		"boss": "gargoyle", "boss_name": "가고일 군주", "boss_anim": "boss_2"},
	{"name": "서리 봉인지", "bg": "res://assets/bg/wide_glacier.png", "ground": 153,
		"roster": ["frost_spider", "ice_wisp", "frost_golem", "bat", "ghoul"],
		"boss": "frost_golem", "boss_name": "프로스트 골렘", "boss_anim": "boss_3"},
	{"name": "핏빛 성소", "bg": "res://assets/bg/wide_sanctum.png", "ground": 145,
		"roster": ["void_wraith", "eye_mass", "spider", "cultist", "mushroom"],
		"boss": "eye_mass", "boss_name": "눈알 덩어리", "boss_anim": "boss_4"},
	{"name": "빼앗긴 본성", "bg": "res://assets/bg/wide_castle.png", "ground": 147,
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
# 지수(1.14^n)면 20단계에서 15배가 돼 방치 시간이 급격히 늘어난다 — 선형+완만한 지수 혼합.
static func enemy_power(stage: int) -> float:
	var progress := float(maxi(1, stage) - 1) / float(STEPS_PER_STAGE)
	return (1.0 + progress * 0.35) * pow(1.045, progress)


# 처치로 얻는 피. 적 강화보다 조금 느리게 올려 후반에 방치가 필요해지게 한다.
static func gold_per_kill(stage: int) -> float:
	return 1.0 + float(maxi(1, stage) - 1) / float(STEPS_PER_STAGE) * 0.55


# 첫 보스가 일반 장비 첫 강화 1회를 열고, 이후 큰 단계마다 5씩 오른다.
static func boss_essence(stage: int) -> float:
	return 25.0 + float(major_stage(stage) - 1) * 5.0


# 이 단계를 넘는 데 필요한 처치 수. 보스 단계는 보스 1마리.
static func kills_needed(stage: int) -> int:
	return 1 if is_boss_stage(stage) or is_midboss_stage(stage) else KILLS_PER_STAGE
