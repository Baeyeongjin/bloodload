class_name StageDefs
extends RefCounted

# 스테이지 진행. 방치형이라 "몇 마리 잡으면 다음"이 유일한 게이트다.
#
# 서사: 봉인당한 흡혈귀 군주가 밤마다 사냥터를 넓혀 힘을 되찾는다.
#
# 큰 단계 1~100마다 세부 구간 1~10이 있고, 보유한 5개 테마를 순환 재사용한다.
# 내부 저장값은 1~1000의 정수라 기존 저장 형식을 바꾸지 않는다.

# 500구간으로 줄였다 (2026-08-13 사장님). 1000 은 "언젠가 채울 자리"였지 도달
# 가능한 끝이 아니었다 — 끝을 반으로 당기면 그 안에서 곡선이 실제로 완주 가능해지고,
# 해금 계단도 500 안에 다 들어온다(군림 마지막 450 이 끝 직전에 선다).
const MAJOR_STAGE_COUNT := 50    # 표시되는 큰 단계: 1..50 (총 500구간)
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
# 60 -> 36 (2026-08-20). 몹 체력이 3배가 됐으니 마리 수를 줄여 구간 시간을
# 지킨다.
#
# **1/3 인 20 이 아니다.** 처음엔 20 으로 뒀는데 구간이 43초 -> 24초로 빨라졌다
# (실측). 한 마리에 드는 시간은 `처치 + 달려가기` 인데 달려가는 시간은 체력과
# 상관없이 일정하다 — 그래서 체력을 3배 해도 한 마리가 3배 오래 걸리지는 않는다.
# 실측 마리당 1.2초로 43초를 채우는 수가 36 이다.
const KILLS_PER_STAGE := 36
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
	# ── 6~10막 (2026-08-27 사장님: "10개 딱 맞추고 계속 돌리는거지") — 막은
	# act_of() 의 나머지 연산으로 돌므로 여기 줄만 늘리면 순환이 늘어난다.
	# 막마다 신규 몹 둘 + 재사용 셋, 보스는 전원 신규(픽: 전부 A 안).
	{"name": "봉인된 심연", "bg": "res://assets/bg/wide_abyss.png",
		"roster": ["crystal_crab", "crystal_wisp", "ice_wisp", "frost_spider", "void_wraith"],
		"boss": "crystal_golem", "boss_name": "결정 골렘", "boss_anim": "crystal_golem"},
	{"name": "달빛 유적", "bg": "res://assets/bg/wide_ruins.png",
		"roster": ["vine_statue", "moon_moth", "skeleton", "ghoul", "spider"],
		"boss": "vine_colossus", "boss_name": "덩굴 거상", "boss_anim": "vine_colossus"},
	{"name": "혈월 제단", "bg": "res://assets/bg/wide_altar.png",
		"roster": ["blood_acolyte", "blood_raven", "cultist", "bat", "demon"],
		"boss": "bloodmoon_avatar", "boss_name": "혈월의 화신",
		"boss_anim": "bloodmoon_avatar"},
	{"name": "잠긴 습지", "bg": "res://assets/bg/wide_marsh.png",
		"roster": ["swamp_leech", "bog_wisp", "mushroom", "zombie", "lava_toad"],
		"boss": "drowned_king", "boss_name": "익사한 왕", "boss_anim": "drowned_king"},
	{"name": "핏빛 왕좌", "bg": "res://assets/bg/wide_throne.png",
		"roster": ["royal_guard", "royal_hound", "dark_knight", "wraith_knight",
			"gargoyle"],
		"boss": "usurper", "boss_name": "찬탈자", "boss_anim": "usurper"},
]


static func act_count() -> int:
	return ACTS.size()


static func total_stages() -> int:
	return MAJOR_STAGE_COUNT * STEPS_PER_STAGE


# 보스 구간 **첫 격파** 보상 (2026-08-27 사장님: "이긴 보람" — 6~10단계를
# 세게 두기로 한 결정과 짝이다. 벽에 보상이 걸려야 벽이 목표가 된다).
#
# 보석은 예전부터 줬는데 **조용히 줬다** — 배너가 없어서 받은 줄도 몰랐다.
# 이제 소환권을 얹고 배너로 알린다(부르는 쪽 Main._advance_stage).
#
#   보석    GachaDefs.COST (한 번 뽑기 값). 늘리지 않는다 — 보석은 상점과
#           얽혀 있어 여기서 불리면 경제가 흔들린다
#   소환권  종류는 대단계마다 돌고(무기->방어구->장신구->스킬), 장수는
#           순환이 돌 때마다 +1 (1~10단계 1장, 11~20단계 2장 … 41~50단계 5장).
#           평생 합 150장 — 도감이 평생 주는 93장과 같은 자릿수다.
#           천장이 종류별로 쌓이므로 순환이 네 종을 고르게 채운다
static func boss_first_reward(at_stage: int) -> Dictionary:
	if not is_boss_stage(at_stage):
		return {}
	var major := major_stage(at_stage)
	return {"gem": GachaDefs.COST,
		"kind": TicketDefs.KINDS[(major - 1) % TicketDefs.KINDS.size()],
		"n": 1 + (major - 1) / 10}


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
# 1.038 -> 1.064 (2026-08-12). "45단계에서 3배" 를 노렸는데 **지수 자리를 잘못
# 잡았다**: 지수는 (stage-1)/10 이라 45단계에서 4.4 승이다. 3^(1/44) 이 아니라
# 3^(1/4.4) 를 곱했어야 했고, 실제로 오른 것은 45단계에서 **x1.11** 뿐이었다
# (후반은 크게 올랐다 — 500구간 x3.4, 1000구간 x11.8). 사장님이 "2배 더"라고
# 한 것은 그래서다.
#
# **곡선을 더 세우는 대신 배율 상수를 둔다.** 45단계에서 2배가 되게 지수를
# 세우면(1.245) 500구간이 x56000 이 되어 후반이 무의미해진다 — 지수 하나로
# "앞을 세우고 뒤는 완만"을 동시에 못 잡는다. 상수는 전 구간을 고르게 올린다.
# 1.064 -> 1.40 (2026-08-13). 총 구간을 500 으로 줄이고 비용 지수를 내리자
# (C안) 성장이 훨씬 빨라져서, 옛 배수로는 14일에 500 을 완주했다. 목표 페이스
# (1달 150 · 2달 250 · 3달 300)에 가장 가까운 값을 PaceProbe 스윕으로 골랐다:
#
#     x1.30  30일 315 · 60일 350 · 90일 365
#     x1.35  30일 250 · 60일 300 · 90일 315
#     x1.40  30일 210 · 60일 250 · 90일 265   <- 채택 (2달이 정확히 250)
#     x1.45  30일 200 · 60일 225 · 90일 240
#
# 어느 값도 목표 **모양**(30일 150 -> 90일 300, 두 배)에는 못 닿는다. 요구는
# 지수인데 스탯 성장은 합연산이라 후반이 반드시 평평해진다 — 그 간극은 곡선이
# 아니라 **후반 곱연산 축**(혈맥 강화 또는 새 축)이 메워야 한다.
# 1.42 -> 1.55 (2026-08-20, 사장님 "적 곡선 강화"). 보상 3배 개편 뒤 30일차가
# 250(목표 150)까지 밀려서 적을 세운다. PaceProbe 실측:
#   1.42: 250 · 1.55: 175(멤버십 +15) · 1.65: 160(멤버십 +0 — 과금 효과가
#   죽어서 탈락. 다 같이 벽에 막히면 시간을 사는 뜻이 없다)
# GOLD_STEP 은 1.42 그대로 — 수입은 안 건드리고 적만 세게, 그게 "강화"다.
static var POWER_STEP := 1.55       # 큰 단계(10구간)마다 적이 세지는 배수
# 2026-08-18 곡선 재측정 — 시련·펫·출석·은총·천장까지 넣은 PaceProbe 4차 스윕.
# 멤버십 30/60/90일 = 200/250/280 (목표 150/250/300, 60일 정중앙). 30일 +50 은
# 새 축(시련·칭호)의 초반 몫이라 곡선으로 더 누르면 꼬리가 무너진다(3차 실측).
# **선형항을 되살렸다** (2026-08-12, 사장님: "래38 8-8 인데 공격력을 하나도
# 안 찍었다 — 스탯을 안 찍고서는 못 넘게"). 진짜 뿌리는 여기였다:
# 순수 지수(x1.064/10구간)는 **초반 100구간이 거의 평지**다 — 78구간 몹이
# 1구간의 1.6배뿐이라 아무것도 안 찍어도 걸어서 지나간다.
#
#     power = (1 + LINEAR x p) x STEP^p          (p = (구간-1)/10)
#     1구간 x1.0 · 78구간 x4.9 · 300구간 x16 · 1000구간 x51
#
# 2026-08-11 에 선형항을 뺀 이유는 "첫 주에 벽이 몰린다"였는데, 그때는 0.35 에
# **지수도 훨씬 가팔랐다**. 0.5 + 완만한 지수면 1~10구간은 그대로 걷고
# (x1.0 -> x1.5) 벽은 사장님이 서 있던 부근부터 선다.
#
# **전 구간 배율(POWER_MULT 2.0)은 뺐다.** 같은 날 넣었다가 되돌린다: 배율은
# 1구간까지 2배로 만들어 **첫 구간이 죽는 자리**가 됐다(NoAttackProbe 로
# 네 정책 전부 1구간 벽). 한 구간이 60마리고 그 사이 30대 넘게 맞는 구조라
# 초반은 여유가 없다 — 세울 곳은 앞이 아니라 뒤고, 그 일은 선형항이 한다.
#
# **0.25 는 실측으로 고른 값이다** (tests/NoAttackProbe, 벽 = 못 넘는 구간):
#     선형 0     전부 400 / 공격제외 10 / 스킬+공격제외 100   <- 옛 곡선
#     선형 0.25  전부  50 / 공격제외 10 / 스킬+공격제외  24   <- 채택
#     선형 0.5   전부  30 / 공격제외 10 / 스킬+공격제외  10   <- 앞이 너무 아프다
# 이 계측기는 **스탯만** 사므로 실제(장비·소환·혈맥·도감·던전)는 훨씬 멀리 간다.
# 사장님 상황(스킬 있고 공격력 0)에 가장 가까운 줄이 "스킬+공격제외"다:
# 100 -> 24 로 내려왔으니, 78구간까지 걸어오던 길이 실제로 막힌다.
# 0.25 -> 0.0 (2026-08-13). 선형항은 **초반을 눌러 곡선 전체를 아래로 당기는**
# 손잡이인데, 목표 페이스가 "처음 빠르고 점점 감속"이라 초반을 누르면 모양이
# 거꾸로 간다. 세울 곳은 뒤이고 그 일은 지수항이 한다.
static var POWER_LINEAR := 0.0
# 지수에 들어가는 p 의 지수. 1.0 = 순수 지수(뒤가 폭발), 낮을수록 후반이 완만.
#
# 0.90 (2026-08-13 PaceProbe 스윕). 1.0 으로는 90일차가 245 에서 멈췄다 —
# 후반 요구가 성장보다 빨리 커져서 곱연산 축(유물 x1.35)을 넣어도 9구간밖에
# 안 늘었다. 0.90 이면 60일 280 · 90일 295 로 목표(250 · 300)에 붙는다.
#
#     곡1.00  30일 190 · 60일 230 · 90일 245
#     곡0.90  30일 210 · 60일 280 · 90일 295   <- 채택
#     곡0.82  30일 280 · 60일 380 · 90일 400   (너무 빠르다)
#
# 30일이 목표(150)보다 빠른 것은 남는다: 초반만 늦추는 손잡이가 선형항인데
# 그건 전 구간에 곱해져서 후반까지 같이 끌어내린다(선 0.6 을 넣으면 90일이
# 295 -> 190). 앞뒤 중 하나를 고른다면 **뒤가 맞는 쪽**이 낫다 — 초반이 조금
# 빠른 것은 첫인상이 좋은 것이고, 후반이 막히는 것은 게임이 끝나는 것이다.
#
# ── 0.90 -> 0.97 (2026-08-14 재측정) ────────────────────────────────────────
# 과금·패스·던전 테마가 다 들어온 뒤 다시 재니 **14일에 150** 이었다 — 1달
# 목표를 2주에 당겼다. 그 사이 늘어난 배급(패스·소탕·구독)이 초반을 밀었다.
#
#     곡0.90  30일 230 · 60일 280 · 90일 300   (증분 50 · 20 — 초반이 이미 끝)
#     곡0.94  30일 190 · 60일 240 · 90일 260
#     곡0.97  30일 160 · 60일 230 · 90일 260   <- 채택 (증분 70 · 30)
#     곡1.00  30일 170 · 60일 230 · 90일 250
#
# **모양으로 고른다.** 목표의 증분비는 150->250->300, 즉 100:50 = 2:1 이다.
# 0.97 이 70:30 으로 그 비에 가장 가깝다 — 0.90 은 30일에 이미 230 이라
# "처음 빠르고 점점 감속"이 아니라 "처음에 다 오르고 멈춤"이 된다.
# 90일 절대값(260 vs 300)은 남는데, 이 프로브는 **소환·장비를 뺀 하한**이라
# 실제 플레이는 그만큼 더 빠르다(PaceProbe 머리 주석).
static var POWER_CURVE := 1.02
# 0.55 -> 1.10 (2026-08-11, EXPANSION 6단계 최종 조정). 새 축(혈맥·군림·칭호)이
# 다 들어온 상태에서 CurveSweep 으로 5개 조합을 재측정한 결과다:
#
#     적 x1.038 돈 0.55   전부 350 / 전부+혈맥 450
#     적 x1.038 돈 1.10   전부 400 / 전부+혈맥 500   <- 목표(500) 정중앙. 채택
#     적 x1.045 돈 1.10   전부 300 / 전부+혈맥 400   <- 몹을 세우면 나빠지기만
#
# 안 찍는 길(공격 제외 10 / 스킬만 100 / 무투자 10)은 어느 조합에서도 그대로
# 막혀 있다 — 보상을 올려도 투자 강제는 안 풀린다.
static var GOLD_SLOPE := 1.10       # 큰 단계마다 처치 보상에 더해지는 몫(선형항)
# 큰 단계마다 보상에 곱해지는 배수. **POWER_STEP 바로 아래**에 둔다 — 같으면
# 시간당 수입이 평평해지고(방치할 이유가 사라진다), 훨씬 낮으면 지금처럼 후반에
# 아무것도 못 산다. 값은 tests/PaceProbe 로 고른다.
static var GOLD_STEP := 1.42


# p 를 그대로 지수에 넣으면 **뒤로 갈수록 요구가 폭발한다** — 30일 150구간을
# 맞추는 배수(x1.36)와 90일 300구간을 맞추는 배수(x1.23)가 다르기 때문에, 지수
# 하나로는 사장님 페이스의 앞뒤를 동시에 못 맞춘다(PaceProbe 실측).
#
# 그래서 지수에 들어가는 p 자체를 눌러 준다(p^POWER_CURVE). 1.0 이면 순수 지수고,
# 낮출수록 **초반은 그대로 가파르고 후반만 완만해진다** — 사장님이 말한 "점진적인
# 곡선"이 이 자리다. 곱연산 축(혈맥·유물)이 후반에 따라올 수 있는 폭도 여기서 난다.
static func enemy_power(stage: int) -> float:
	var p := float(maxi(1, stage) - 1) / float(STEPS_PER_STAGE)
	return (1.0 + POWER_LINEAR * p) * pow(POWER_STEP, pow(p, POWER_CURVE))


# 처치로 얻는 피.
#
# **선형만으로는 안 된다** (2026-08-13, tests/PaceProbe 실측). 몹 체력은 지수인데
# 수입이 선형이면 **시간당 수입이 구간이 오를수록 줄어든다** — 킬 시간이 지수로
# 늘고 킬당 값은 선형으로만 느니까. 30일차 진단이 그 증상이었다:
#
#     구간 100 · 남은 혈액 78.9K · 다음 공격 레벨 540K
#
# 돈이 모자란 게 아니라 **영영 못 사는** 상태다. 재화를 더 줘도 안 팔리므로
# 멤버십(방치 +4시간 · 던전 +1판)의 효과가 실측에서 **정확히 0** 이었다 —
# 과금이 진행을 못 사는 구조였다.
#
# 그래서 enemy_power 와 **같은 꼴**로 만든다: 선형항이 중반을 받치고(2026-08-11
# 에 지수 단독이 중반을 가난하게 만든 그 실패를 피한다), 지수항이 후반에 몹을
# 따라간다. GOLD_STEP 을 POWER_STEP 바로 아래에 두면 시간당 수입이 완만히
# 줄어들어 "후반엔 방치가 필요하다"는 원래 의도도 남는다.
# 한 마리의 몸값 배수 — 체력을 올린 만큼 여기도 올린다(FoeTiers.HP_BASE 3배).
# **둘을 따로 만지면 안 된다.** 하나만 바꾸면 방치 수입이 조용히 어긋난다.
const KILL_WORTH := 3.0


static func gold_per_kill(stage: int) -> float:
	var p := float(maxi(1, stage) - 1) / float(STEPS_PER_STAGE)
	# **적과 같은 꼴로 눌러 준다** — 적만 완만해지고 수입이 계속 폭발하면 후반이
	# 거저가 된다. 둘이 같은 모양이어야 "시간당 수입"의 뜻이 유지된다.
	#
	# BLOOD_UNIT 은 **혈액이 세상에 생기는 유일한 자리**라 여기서 곱한다 — 방치
	# 배급·상자·소탕·상점이 전부 이 값의 배수라 한 줄로 눈금이 옮겨진다.
	# KILL_WORTH: 한 마리가 3배 무거워졌으니 한 마리 값도 3배다. 이게 없으면
	# 방치 수입이 통째로 1/3 이 된다(수입 = 보상 / 처치시간).
	return (1.0 + GOLD_SLOPE * p) * pow(GOLD_STEP, pow(p, POWER_CURVE)) \
		* Balance.BLOOD_UNIT * KILL_WORTH


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
