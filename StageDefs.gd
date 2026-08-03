class_name StageDefs
extends RefCounted

# 스테이지 진행. 방치형이라 "몇 마리 잡으면 다음"이 유일한 게이트다.
#
# 서사: 봉인당한 흡혈귀 군주가 밤마다 사냥터를 넓혀 힘을 되찾고, 마지막에
# 빼앗긴 자기 성으로 돌아간다. 마지막 막이 "남의 성"이 아니라 "내 성 탈환"이라야
# 50단계를 미는 데 끝이 생긴다.
#
# arrow-rpg의 5막(묘지·지옥·빙하·공허·마왕성)을 그대로 쓰되, 한 막을 여러 단계로
# 쪼개 방치형의 "숫자가 계속 오르는" 리듬을 만든다. 배경은 막당 1장이라 단계가
# 바뀌어도 그림은 그대로고 몹 구성과 배수만 바뀐다 — 배경 5장으로 50단계를 굴린다.

const STAGES_PER_ACT := 10       # 한 막당 단계 수
const BOSS_EVERY := 10           # 막의 마지막 단계는 보스
const KILLS_PER_STAGE := 20      # 일반 단계 통과에 필요한 처치 수

# 막 5개. roster는 그 막에 나오는 몹 키.
# bg는 가로로 긴 도트 한 장(768x160)이고 화면에는 2배(1536x320)로 그린다.
#   - 세로 320 = 전투 띠 높이라 딱 맞는다.
#   - 가로 1536 = 화면 폭의 2.6배라 같은 그림이 금방 되돌아오지 않는다.
#   - 좌우 끝에 같은 세로 기둥을 세워 그려서, 옆으로 이어 붙이면 기둥 둘이 만나
#     굵은 기둥 하나로 읽힌다 — 이음매 없이 무한 스크롤된다.
# 생성 공식과 job id는 assets/bg/BG_RECIPE.md 에 적어 뒀다(추가 맵도 같은 틀로 뽑는다).
# ground = 원본에서 바닥 윗면이 있는 행. 그림마다 달라서 눈으로 맞추면 캐릭터가
# 공중에 뜬다 — tools/measure_ground.py 로 실측한 값이다.
# 몹 키는 arrow-rpg GameConfig.enemy_tiers()의 key를 그대로 쓴다(자산 재사용).
const ACTS := [
	{"name": "깨어난 무덤", "bg": "res://assets/bg/wide_graveyard.png", "ground": 141,
		"roster": ["slime", "goblin", "bat", "zombie", "skeleton"],
		"boss": "wraith_knight"},
	{"name": "화형의 언덕", "bg": "res://assets/bg/wide_hell.png", "ground": 140,
		"roster": ["fire_imp", "lava_toad", "hellhound", "orc", "demon"],
		"boss": "gargoyle"},
	{"name": "서리 봉인지", "bg": "res://assets/bg/wide_glacier.png", "ground": 153,
		"roster": ["frost_spider", "ice_wisp", "frost_golem", "bat", "ghoul"],
		"boss": "frost_golem"},
	{"name": "핏빛 성소", "bg": "res://assets/bg/wide_sanctum.png", "ground": 145,
		"roster": ["void_wraith", "eye_mass", "spider", "cultist", "mushroom"],
		"boss": "eye_mass"},
	{"name": "빼앗긴 본성", "bg": "res://assets/bg/wide_castle.png", "ground": 147,
		"roster": ["dark_knight", "wraith_knight", "cultist", "demon", "orc"],
		"boss": "dark_knight"},
]


static func act_count() -> int:
	return ACTS.size()


static func total_stages() -> int:
	return ACTS.size() * STAGES_PER_ACT


# 1부터 세는 통합 단계 번호 -> 막 인덱스(0부터).
static func act_of(stage: int) -> int:
	return clampi((stage - 1) / STAGES_PER_ACT, 0, ACTS.size() - 1)


static func act_data(stage: int) -> Dictionary:
	return ACTS[act_of(stage)]


# 막 안에서 몇 번째 단계인가 (1..STAGES_PER_ACT).
static func step_in_act(stage: int) -> int:
	return (stage - 1) % STAGES_PER_ACT + 1


static func is_boss_stage(stage: int) -> bool:
	return step_in_act(stage) == BOSS_EVERY


# 단계별 적 강화 배수. 방치형은 "숫자가 오르는 게 보상"이라 곡선이 완만하고 끝이 없다.
# 지수(1.14^n)면 20단계에서 15배가 돼 방치 시간이 급격히 늘어난다 — 선형+완만한 지수 혼합.
static func enemy_power(stage: int) -> float:
	return (1.0 + float(stage - 1) * 0.35) * pow(1.045, float(stage - 1))


# 처치로 얻는 피. 적 강화보다 조금 느리게 올려 후반에 방치가 필요해지게 한다.
static func gold_per_kill(stage: int) -> float:
	return 1.0 + float(stage - 1) * 0.55


# 이 단계를 넘는 데 필요한 처치 수. 보스 단계는 보스 1마리.
static func kills_needed(stage: int) -> int:
	return 1 if is_boss_stage(stage) else KILLS_PER_STAGE
