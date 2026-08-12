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
# 열린다"). 새 곡선의 첫 벽이 30구간 부근이므로 그 **직전**에 첫 던전을 연다 —
# 벽 뒤에 두면 애초에 도달을 못 해서 구제가 안 된다.
#     25 혈액의 동굴  ->  35 미궁  ->  50 정수의 성소  ->  80 계약의 제단
# 20 에 둘(혈액·정수)이 한꺼번에 열리던 것이 "다 열렸다"의 정체였다.
const OPEN_STAGE := 25        # 혈액의 동굴 — 첫 벽 직전, 혈액이 마를 때
# 하루 3판. **클리어할 때만 깎인다**(사장님 2026-08-12) — 못 깨고 나온 판은
# 세지 않는다. 실패에 표를 물리면 "아직 못 이길 것 같은데 눌러 볼까"가 손해가
# 되어, 도전 자체를 안 하게 된다.
const TRIES_PER_DAY := 3
# 광고 보상 자리. 지금은 붙일 광고가 없어 **버튼도 안 만든다**(YAGNI) —
# 붙일 때 이 상수를 쓰고 UI 한 줄만 더하면 된다.
const AD_BONUS_TRIES := 1
const KILLS := 8              # 한 판의 웨이브
const TIME_LIMIT := 45.0      # 늘 시계가 돈다 — 도전이니까
const STEP_PER_STAGE := 6     # 도전 단계당 등가 본편 구간 상승

# 아이콘: 사장님 선택 — 동굴 입구 A · 보석 제단 C · 룬 제단 C (2026-08-12).
const RAIDS := {
	"blood": {"name": "혈액의 동굴", "currency": "혈액",
		"icon": "res://assets/ui/raid_blood.png"},
	"essence": {"name": "정수의 성소", "currency": "정수",
		"icon": "res://assets/ui/raid_essence.png"},
	"pact": {"name": "계약의 제단", "currency": "인장",
		"icon": "res://assets/ui/raid_pact.png"},
}


# 축이 세 개 한꺼번에 열리면 새 유저가 어디에 써야 할지 못 고른다 — 계단은
# 위 OPEN_STAGE 주석에 적어 뒀다.
static func open_stage(kind: String) -> int:
	match kind:
		"essence": return 50    # 장비 강화가 필요해지는 자리
		"pact": return 80       # 혈맹은 장기 축이라 제일 뒤
	return OPEN_STAGE
# 등가 구간은 **그 던전이 열리는 구간**에서 출발한다 — 제단(40)이 동굴(20)과
# 같은 세기로 시작하면 늦게 열리는 던전이 공짜가 된다.
static func eq_stage(n: int, kind := "blood") -> int:
	return mini(open_stage(kind) + (n - 1) * STEP_PER_STAGE, StageDefs.total_stages())


# 혈액 = 등가 구간 시세 400킬 분량. 정수 = 등가 구간 보스 3마리 분량.
# 인장 = 도전 단계 선형(60 + 15/단계) — 혈맹 비용도 선형이라 나란히 간다.
# 킬 수가 아니라 뭉치로 주는 이유: 판이 45초라 킬 시세로는 티가 안 난다.
static func reward(kind: String, n: int) -> float:
	if kind == "blood":
		return StageDefs.gold_per_kill(eq_stage(n, kind)) * 400.0
	if kind == "pact":
		return 60.0 + 15.0 * float(n - 1)
	return StageDefs.boss_essence(eq_stage(n, kind)) * 3.0


static func label(kind: String, n: int) -> String:
	return "%s %d단계" % [str(RAIDS[kind]["name"]), n]
