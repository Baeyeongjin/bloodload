class_name RaidDefs

# 재화 던전 (REFERENCE_TEARDOWN 4장-2). 참고작의 "재화마다 전용 던전" 구조:
# 한 판 승부 — 제한 시간 안에 웨이브를 비우면 재화 뭉치를 받고 다음 도전
# 단계가 열린다. 입장은 **하루 한 번**(참고작의 입장권) — 이 상한이 "오늘 할
# 일"을 만들고, 난이도 x3 이 세운 벽을 미는 하루치 배급이 된다.
#
# 미궁과의 역할 분담: 미궁 = 기록(혈맥의 열쇠), 재화 던전 = 배급(혈액·정수).
# 미궁 혈액이 본편 시세인 것과 반대로, 여기 보상은 **등가 구간 시세**다 —
# 더 깊은 곳의 시세를 하루 한 뭉치만 준다. 무한 사냥터가 아니라 배급이라
# 재화 격리(EXPANSION 6장)를 안 깬다.
# **콘텐츠는 막힐 때쯤 하나씩 열린다** (사장님 2026-08-12: "조금만 진행해도
# 열린다"). 다만 재화 던전은 그 원칙만으로는 안 됐다 — **쓸 곳이 먼저 열리고
# 재화가 며칠 뒤에 나오면** 그 사이는 "올릴 수 있는데 재화가 0인 칸"이다
# (사장님 2026-08-26). 무기 슬롯은 1구간, 혈맹은 잠금 자체가 없다.
#     15 제련의 성소 -> 20 야수 우리 -> 25 혈액의 동굴 -> 35 미궁 -> 40 계약의 제단
#
# 아래 "첫 벽 30구간" 전제는 **낡았다**: POWER_STEP 1.064 -> 1.55,
# KILLS_PER_STAGE 60 -> 36, HP_BASE 5.5 -> 16.5, gold_mult x6 이후로 다시
# 안 쟀다. 벽 위치를 근거로 쓰려면 PaceProbe 부터 돌릴 것.
const OPEN_STAGE := 25        # 혈액의 동굴 — 첫 벽 직전, 혈액이 마를 때
# 하루 3판. **클리어할 때만 깎인다**(사장님 2026-08-12) — 못 깨고 나온 판은
# 세지 않는다. 실패에 표를 물리면 "아직 못 이길 것 같은데 눌러 볼까"가 손해가
# 되어, 도전 자체를 안 하게 된다.
const TRIES_PER_DAY := 3
# 광고 보상 자리. 지금은 붙일 광고가 없어 **버튼도 안 만든다**(YAGNI) —
# 붙일 때 이 상수를 쓰고 UI 한 줄만 더하면 된다.
const AD_BONUS_TRIES := 1
const KILLS := 8              # 한 판의 웨이브
const TIME_LIMIT := 60.0      # 늘 시계가 돈다 — 도전이니까
const STEP_PER_STAGE := 6     # 도전 단계당 등가 본편 구간 상승

# 아이콘: 사장님 선택 — 동굴 입구 A · 보석 제단 C · 룬 제단 C (2026-08-12).
#
# **던전마다 목표가 다르다** (사장님 2026-08-14: "각 던전별 테마가 있어야 함").
# 셋 다 "웨이브를 비운다"였는데, 그러면 이름과 보상만 다른 같은 판이 셋이다.
#   swarm  — 물량. 제한 시간 안에 **많이** 잡는다(동굴: 벌이의 자리)
#   slay   — 단일 강적. 한 마리를 **제한 시간 안에** 눕힌다(성소: 화력 시험)
#   endure — 버티기. 시간이 다 갈 때까지 **살아남는다**(제단: 생존 시험)
# 몹 세기는 판정과 따로 논다(_c_enemy_power) — 목표만 바뀐다.
const RAIDS := {
	"blood": {"name": "혈액의 동굴", "currency": "혈액", "goal": "swarm",
		"goal_text": "제한 시간 안에 %d마리",
		"icon": "res://assets/ui/raid_blood.png"},
	# 제련의 성소 — 단일 강적 판(slay)은 여기 하나뿐이다. 보상은 **연마석**:
	# 장비 레벨업 재화의 수도꼭지가 이 판이다(사장님 2026-08-25).
	"forge": {"name": "제련의 성소", "currency": "연마석", "goal": "slay",
		"goal_text": "수호자 %d마리 격파",
		"icon": "res://assets/ui/raid_essence.png"},
	"pact": {"name": "계약의 제단", "currency": "인장", "goal": "endure",
		"goal_text": "%d초를 버틴다",
		"icon": "res://assets/ui/raid_pact.png"},
	# 펫 먹이(사장님 2026-08-18, PET_DESIGN v2). 이름 후보 중 "야수 우리" 채택 —
	# 바꾸려면 이 한 줄이다. goal 은 swarm 재사용(사냥 테마와 맞고, 새 규칙을
	# 만들지 않는다). 아이콘·배경은 자리표시(blood 복사) — 아트 배치에서 교체.
	"hunt": {"name": "야수 우리", "currency": "먹이", "goal": "swarm",
		"goal_text": "제한 시간 안에 %d마리",
		"icon": "res://assets/ui/raid_hunt.png"},
}

# 목표별 판 규격. swarm 은 수가 많고, slay 는 한 마리가 두껍고, endure 는
# 처치가 아니라 **시계**가 판정이라 목표 수가 없다.
const SLAY_KILLS := 1         # 성소의 수호자 — 한 마리
# 수호자는 **웨이브 몫**을 혼자 짊어진다(물량 던전 12마리치). 다만 그놈은
# 보스 판정을 받으므로 FoeTiers 의 보스 배수(105)가 이미 곱해져 있다 —
# 그걸 되나눠야 45초 안에 잡을 수 있는 판이 된다. 상수를 그냥 곱해 뒀더니
# 630배가 되어 아무리 때려도 안 죽는 판이었다.
const SLAY_WAVE_WORTH := 100.0
# 제단 — 버티는 시간. **다른 판보다 길어야 한다**(RaidCheck 이 지킨다):
# 물량이 60초라 60이면 셋이 같은 길이가 되어 "버티기"라는 이름이 무의미해진다.
# 90초 동안 잡졸이 계속 밀려오는 판이다 — 처치가 아니라 생존이 판정이라
# 화력이 아니라 체력·재생을 묻는다(EXPANSION 의 축 분리).
const ENDURE_TIME := 90.0
# **100마리 / 60초** (2026-08-20, 사장님: "12마리 잡는데 왜 이리 쉽노").
# 12마리는 실측 3초였다 — 이름만 던전이지 판이 아니었다.
const SWARM_KILLS := 100
# 물량 던전의 몹은 **잡졸**이다. 본편 몹 그대로면 100마리에 75초가 걸려
# 60초 안에 못 끝낸다. 약하게 만드는 게 아니라 **물량 던전의 정체**가 그거다 —
# 한 마리를 오래 붙드는 판은 성소(slay)가 따로 있다.
# 0.25 = 본편 몹의 1/4. 실측 마리당 처치 0.19초 + 달려가기 0.30초(간격 60 /
# 속도 200) = 0.49초 x 100마리 = 49초로 60초 안에 든다. 여유가 11초뿐이라
# 도전 단계를 하나 올리면 곧 빠듯해진다 — 그게 이 판의 난이도 곡선이다.
const SWARM_HP_MULT := 0.25
# 화면에 서는 몹 수와 줄 간격 — 물량 판은 빽빽해야 한다(사장님: "몬스터 줜나
# 나오게"). 간격이 넓으면 100마리가 곧 **달리기 100번**이 된다.
const SWARM_FOES := 10
# **간격은 시체 대기를 줄인 뒤에야 레버가 된다.** 마리당 주기는
#   임팩트 지연 + max(시체 대기, 간격 / 전진속도)
# 라서 둘이 **병렬**이다. 대기가 0.42 이던 시절에는 간격이 84 아래면 어떤 값을
# 넣어도 0.42 가 이겨서 **간격을 0 으로 해도 한 마리도 안 늘었다**
# (사장님 제안 "몹들이 좀 겹치게" 가 그때는 안 먹혔을 자리다).
const SWARM_GAP := 50.0

# 물량·버티기 판에서만 시체를 덜 기다린다(본편 0.42 는 그대로).
#
# **이 판이 수학적으로 불가능했다.** 마리당 최소 주기가
#   0.34(스윙) x 0.759(임팩트 프레임) + max(0.42, 60/200) = 0.678초
# 라 60초에 **88.5마리**인데 요구가 100마리였다 — 공격력을 무한대로 올려도,
# 한 방 컷이어도 못 깼다. 설계 때 쓴 모델(주석의 "0.49초 x 100 = 49초")이
# 시체 대기와 임팩트 지연을 빼먹어서 **38% 낙관**이었다.
#
# 0.18 은 간격(50/200 = 0.25)보다 작다 — 일부러다. 이래야 위 max 에서 간격이
# 이기고, "겹치게 세우면 빨라진다"가 실제로 성립한다.
# 마리당 0.258 + 0.25 = 0.508초 -> 60초에 **118마리**(여유 18%).
#
# 본편을 안 건드리는 이유: 그 박자에 **수입 곡선이 걸려 있다**(마리당 시간이
# 곧 혈액 시급이다). 재화 던전은 처치가 아니라 격파 뭉치로 주므로 안 걸린다.
const SWARM_PAUSE := 0.18


# 이 판에서 시체를 얼마나 기다리나. 물량·버티기만 짧다.
# ── 버티기 처치 보너스 (2026-09-02 사장님: "버티기도 세지면 뭐라도 되게") ──
# 버티기는 처치가 판정이 아니라서 세져도 90초가 1프레임도 안 줄고, 몹이 잡졸이라
# 동굴을 깨는 영웅은 죽을 수도 없다 — 강함이 어디에도 안 이어지는 90초였다.
# 그 90초 동안 실제로 하고 있는 일(처치)을 인장으로 이어 준다.
#
# **상한이 있다.** 인장은 혈맹(합연산 %)을 사는 재화라 무한히 늘면 곡선이
# 밀린다. 120마리(마리당 최소 주기 0.508초로 90초면 약 177마리라, 공속을
# 안 키운 영웅도 닿는 자리)에 +50% 로 막는다. 기본 뭉치는 그대로다 — 지금
# 깨는 사람이 손해 보는 일은 없고, 세지면 그 위에 얹힌다.
const ENDURE_BONUS_KILLS := 120
const ENDURE_BONUS_MAX := 0.5


static func endure_bonus(k: int) -> float:
	return ENDURE_BONUS_MAX * clampf(float(k) / float(ENDURE_BONUS_KILLS), 0.0, 1.0)


static func engage_pause(kind: String, base: float) -> float:
	return SWARM_PAUSE if goal(kind) in ["swarm", "endure"] else base


static func goal(kind: String) -> String:
	return str(RAIDS.get(kind, {}).get("goal", "swarm"))


# 그 던전을 깨는 데 필요한 처치 수. endure 는 처치가 판정이 아니라 0 이다.
static func kills_needed(kind: String) -> int:
	match goal(kind):
		"slay": return SLAY_KILLS
		"endure": return 0
	return SWARM_KILLS


static func time_limit(kind: String) -> float:
	return ENDURE_TIME if goal(kind) == "endure" else TIME_LIMIT


# 몹 체력 배수 — slay 의 한 마리는 웨이브 몫을 혼자 짊어진다.
static func hp_mult(kind: String) -> float:
	match goal(kind):
		"slay":
			# 수호자는 잡졸 100마리 몫을 혼자 짊어진다. 다만 그놈은 보스 판정을
			# 받아 FoeTiers 의 보스 배수가 이미 곱해져 있으므로 되나눈다.
			return SLAY_WAVE_WORTH * SWARM_HP_MULT / FoeTiers.BOSS_HP_MULT
		"swarm", "endure":
			return SWARM_HP_MULT
	return 1.0


# 이 던전에서 화면에 서는 몹 수. 물량·버티기는 빽빽하게 밀려온다.
static func wave_size(kind: String, base: int) -> int:
	# **단일 강적은 한 마리다.** slay 인데 base(MAX_FOES)를 그대로 돌려주면
	# 수호자가 여섯 서고, 그 여섯이 각자 보스 체력을 지녀 판이 안 끝난다
	# (사장님 2026-08-25 "공격을 멈추는 버그"의 정체 — _c_is_boss 로 보스
	# 판정만 고치고 **스폰 수**는 안 고쳤던 자리다).
	if goal(kind) == "slay":
		return SLAY_KILLS
	return SWARM_FOES if goal(kind) in ["swarm", "endure"] else base


static func foe_gap(kind: String, base: float) -> float:
	return SWARM_GAP if goal(kind) in ["swarm", "endure"] else base


# 카드·판에 적는 목표 한 줄.
static func goal_line(kind: String) -> String:
	var t := str(RAIDS.get(kind, {}).get("goal_text", ""))
	if goal(kind) == "endure":
		return t % int(ENDURE_TIME)
	return t % kills_needed(kind)


# 축이 세 개 한꺼번에 열리면 새 유저가 어디에 써야 할지 못 고른다 — 계단은
# 위 OPEN_STAGE 주석에 적어 뒀다.
# **다 당겼다** (사장님 2026-08-26: "재화 던전은 좀 빨리 열려야 할 듯. 50구간이
# 아니라"). 병은 "50이 멀다"가 아니라 **쓸 곳은 1구간에 열리는데 재화는 4~9일째
# 나온다**였다: 무기 슬롯이 1구간(GearDefs), 혈맹은 잠금 자체가 없는데(Main 이
# `sigil < cost` 만 본다) 연마석은 4.1일 · 인장은 8.7일째 나왔다.
# 실측 페이스 환산: 15구간=0.6일 · 20=0.95일 · 40=2.8일.
#
# **등가 구간은 안 건드린다.** 해금 순간에는 eq = max(open, best-15) = open = best
# 라 식에서 open 이 소거된다 — 15에 열든 50에 열든 열리는 순간의 상대 난이도가
# 같다. 판수도 안 는다(지금도 4종 x 3판 = 12판, 시작 시점만 당겨진다).
static func open_stage(kind: String) -> int:
	match kind:
		"forge": return 15      # 연마석. 소모처(무기 슬롯)가 1구간이고 획득처가 여기뿐이다
		"hunt": return 20       # 먹이. 펫 소환 10구간과 열 구간 차 — 뽑은 날 안에 붙는다
		"pact": return 40       # 인장. 혈맹은 잠금이 없어 1구간부터 화면에 있다
	return OPEN_STAGE
# 등가 구간은 **그 던전이 열리는 구간**에서 출발한다 — 제단(40)이 동굴(20)과
# 같은 세기로 시작하면 늦게 열리는 던전이 공짜가 된다.
# best 를 주면 **내 진행도를 따라 세진다** (2026-08-20, 사장님: "던전이
# 너무 쉽다"). 고정 계단(open + 6/단계)만으로는 본편이 앞서갈수록 던전이
# 공짜가 됐다 — 계단과 (내 최고 구간 - 15) 중 높은 쪽에서 출발한다.
# -15 는 여유다: 막 열린 유저에게는 계단이 그대로이고, 앞서간 유저에게는
# 제 화력 언저리의 판이 된다. 보상도 같은 등가 구간 시세라 따라 오른다.
static func eq_stage(n: int, kind := "blood", best := 0) -> int:
	var base := maxi(open_stage(kind), best - 15)
	return mini(base + (n - 1) * STEP_PER_STAGE, StageDefs.total_stages())


# 혈액 = 등가 구간 시세 400킬 분량.
# 인장 = 도전 단계 선형(60 + 15/단계) — 혈맹 비용도 선형이라 나란히 간다.
# 킬 수가 아니라 뭉치로 주는 이유: 판이 45초라 킬 시세로는 티가 안 난다.
static func reward(kind: String, n: int, best := 0) -> float:
	if kind == "blood":
		# **KILL_WORTH 로 되나눈다.** 마리당 값이 3배가 됐는데(몹 체력 3배)
		# 여기는 나눌 처치시간이 없어서 그대로 두면 뭉치가 3배가 된다 —
		# 방치 수입은 `보상/처치시간` 이라 중립이지만 뭉치는 아니다.
		# 뜻은 그대로 "등가 구간 400킬 분량의 시간"이다.
		return StageDefs.gold_per_kill(eq_stage(n, kind, best)) * 400.0 			/ StageDefs.KILL_WORTH
	if kind == "pact":
		return 60.0 + 15.0 * float(n - 1)
	# 먹이·연마석 — **선형 x 구간 지수**. 예전엔 도전 단계 n 의 선형이었는데
	# n 은 5~7 에서 동결되고 소모처는 지수라(장비 1.45^lv · 펫 1.18^lv) 기울기가
	# 사실상 0 이었다. 그래서 "배급을 정확히 2배로 올려도 90일차 장비가
	# Lv12 -> Lv14" 였다(2026-08-26 실측). 양이 아니라 기울기가 문제였다.
	# blood 만 gold_per_kill 지수를 타고 나머지 셋은 best_stage 를 아예 안 봤다 —
	# 거기가 구조적 결손이다.
	if kind == "hunt":
		return (80.0 + 20.0 * float(n - 1)) * mat_step(n, kind, best)
	if kind == "forge":
		# **x3.3 으로 올렸다** (사장님 2026-08-26: "배급을 올려").
		# PaceProbe 실측이 14일차 3.9K/일이었는데 장비 만렙 일수(레전더리 15일 ·
		# 신화 60일)는 하루 12,700 을 전제로 잡힌 값이다 — 기울기는 mat_step 이
		# 주고, 절대량은 여기 base 가 준다. 400/200 이면 14일차 약 12.9K 다.
		return (400.0 + 200.0 * float(n - 1)) * mat_step(n, kind, best)
	return 0.0


# 큰 단계(10구간)마다 재화 뭉치가 커지는 배수. 해금 직후에는 1.0 이라 값이
# 안 변하고 뒤로만 자란다 — 앞을 안 건드리면서 기울기만 주는 자리다.
const MAT_STEP := 1.08


static func mat_step(n: int, kind: String, best: int) -> float:
	return pow(MAT_STEP, float(eq_stage(n, kind, best) - open_stage(kind))
		/ float(StageDefs.STEPS_PER_STAGE))


static func label(kind: String, n: int) -> String:
	return "%s %d단계" % [str(RAIDS[kind]["name"]), n]
