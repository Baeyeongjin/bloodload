class_name ShopDefs

# 상점 = **보석의 소비처**, 파는 것은 물건이 아니라 시간이다
# (사장님 2026-08-12: "현질을 해서 시간을 사서 스펙업을 해서 스테이지를 뚫는
# 구조"). 벽 앞에서 할 수 있는 일이 "내일까지 기다린다" 하나뿐이면 그날의
# 게임이 거기서 끝난다 — 상점은 그 기다림을 보석으로 건너뛰는 자리다.
#
# **재화 격리(EXPANSION 6장)를 안 깬다.** 여기서 파는 재화는 전부 그 재화의
# 전용 던전이 주는 것과 같은 물건이고, 사는 건 **하루 배급의 일부를 앞당기는
# 것**이지 무한 우회가 아니다. 지키는 장치가 둘:
#   1. 품목마다 하루 한도(아래 per_day) — 보석이 남아돌아도 오늘치는 정해져 있다
#   2. 보석 자체가 하루 수급 제한 — 일일 임무 75 + 주간 300/7 ≈ 118/일
# 하루치를 다 사면 420 보석이라 **절대 다 못 산다.** 그래서 상점은 "무엇을
# 앞당길까"를 고르는 곳이 된다. 소환(1회 30)과 경쟁하는 것도 의도다.
#
# 수량은 **그 재화의 던전 한 판 대비**로 잡는다 — 절대값으로 박으면 구간이
# 오를 때마다 상점이 조용히 쓸모없어진다.
#
# 아직 안 만든 것 두 개, 자리만 적어 둔다:
#   - 광고 시청 (하루 N회 무료) — 붙일 광고 SDK 가 없다. RaidDefs.AD_BONUS_TRIES
#     와 같은 원칙: 붙일 때 줄 하나만 더한다
#   - 현질 패키지 — 결제 SDK 가 없다. 붙으면 보석 획득처가 되므로 이 표는 안 바뀐다
# 시간 왜곡 한 장이 앞당기는 방치 시간.
const WARP_HOURS := 2.0

const ITEMS := [
	# **핏빛 주머니(혈액 30보석)는 지웠다**(2026-08-27 사장님). 시간 왜곡이 같은
	# 물건을 정직한 요율로 이미 팔고 있어서 살 이유가 없었다 — 30보석짜리 뭉치가
	# 가만히 **10~20초** 방치하면 들어오는 양이었다(구간과 무관한 상수 배율:
	# 상점 혈액은 `gold_per_kill x 200 / KILL_WORTH` 로 킬 수를 세고, 방치는
	# `gold_per_kill x gold_mult / 처치시간` 이라 gold_per_kill 이 소거된다).
	# 보석당으로는 시간 왜곡에 160배 밀렸다. 혈액을 다시 팔려면 **킬 수가 아니라
	# 방치 시간**을 단위로 잡아야 한다.
	{"id": "crystal", "name": "혈정 원석", "sub": "혈정", "cost": 45, "per_day": 2,
		"icon": "res://assets/ui/res_crystal.png"},
	{"id": "sigil", "name": "봉인 인장", "sub": "인장", "cost": 45, "per_day": 2,
		"icon": "res://assets/ui/res_sigil.png"},
	# **숫자를 안 박는다.** 야수 우리가 2026-08-18 에 늘면서 "3종" 이 거짓이
	# 됐다(실제 지급은 `for k in RaidDefs.RAIDS` 라 늘 전부다). 위 open_stage
	# 주석이 세운 규칙("숫자를 여기 박지 않는다")이 이 줄만 예외였다.
	{"id": "ticket", "name": "던전 입장권", "sub": "재화 던전 전부 +1판", "cost": 60,
		"per_day": 1, "icon": "res://assets/ui/tab_raid.png"},
	# 시간 왜곡 — "상점은 시간을 판다"의 정중앙. 방치 2시간을 즉시 상자에
	# 담는다(요율은 방치 적립과 같은 식 — Main 이 같은 함수를 태운다).
	# 90/2회로 멤버십(방치 +4h 상시)보다 비싸게 — 상시 효과의 가치를 안 깎는다.
	{"id": "warp", "name": "시간 왜곡", "sub": "방치 2시간 즉시 적립", "cost": 90,
		"per_day": 2, "icon": "res://assets/ui/chest.png"},
	# ── 광고 (2026-08-20, 사장님 "광고 보상 확대") ──────────────────────────
	# cost 0 · ad true 면 보석이 아니라 광고를 낸다. **표를 하나로 둔다** —
	# 광고를 따로 판으로 만들면 "오늘 뭐 남았지"를 한 군데 더 열어 봐야 한다.
	# 붙일 SDK 가 아직 없어서 화면에는 "준비 중"으로 뜬다(잠금은 Main 이 건다).
	#
	# 보상은 **같은 물건의 무료판**이라 상품 가치를 안 깎는다: 소환권은 정기권의
	# 1/6, 보석은 충전 최소 단위의 1/6 이다(설계서 9-4 "광고는 하위 호환").
	{"id": "ad_ticket", "name": "[광고] 소환권", "sub": "소환권 2장", "cost": 0,
		"per_day": 3, "ad": true, "icon": "res://assets/ui/quest_summon.png"},
	{"id": "ad_gem", "name": "[광고] 보석", "sub": "보석 50", "cost": 0,
		"per_day": 3, "ad": true, "icon": "res://assets/items/gem.png"},
	{"id": "ad_chest", "name": "[광고] 방치 상자", "sub": "그때 받은 혈액만큼 한 번 더",
		"cost": 0, "per_day": 2, "ad": true,
		"icon": "res://assets/ui/chest.png"},
]


# 광고로 여는 줄인가. SDK 가 붙기 전에는 Main 이 버튼을 잠근다.
static func is_ad(id: String) -> bool:
	return bool(of(id).get("ad", false))


static func of(id: String) -> Dictionary:
	for it in ITEMS:
		if str(it["id"]) == id:
			return it
	return {}


# 품목이 보이기 시작하는 구간. **숫자를 여기 박지 않는다** — 해금 계단을 옮길
# 때마다 상점만 딴 소리를 하게 된다(던전 표가 그 실수로 두 번 깨졌다).
# 그 재화를 쓸 곳이 열리기 전에 파는 건 빈 지갑에 돈을 넣어 주는 것과 같다.
static func open_stage(id: String) -> int:
	match id:
		"crystal": return DungeonDefs.OPEN_STAGE          # 혈맥 = 미궁이 연다
		"sigil": return RaidDefs.open_stage("pact")
		"ticket": return RaidDefs.OPEN_STAGE
		# 광고는 처음부터 보인다 — 초반이 가장 재화가 마른 구간이다.
		"ad_ticket", "ad_gem", "ad_chest": return 1
	return 1


# 한 번 살 때 들어오는 양. 던전 한 판의 절반~2/3 — 상점이 던전보다 후하면
# 던전을 안 돌게 된다. 입장권·시간 왜곡은 수량이 아니라 판 수·시간이라 0 이다.
#
# **자는 시간 왜곡이다.** 그 상품만 방치 적립과 글자 그대로 같은 식을 타므로
# (Main._shop_buy 의 warp 갈래), 새 상품의 값을 정할 때는 "방치 몇 초치인가"를
# 그 식으로 먼저 재 본다. 핏빛 주머니가 그 자로 재서 10~20초로 나와 지워졌다.
# `pact_best` 는 계약의 제단 최고 도전 단계다 — 인장 수량이 그 보상을 따라간다.
static func amount(id: String, stage: int, dungeon_floor: int,
		pact_best := 0) -> float:
	match id:
		"crystal":
			# 소탕 8시간분 + **바닥 45**. 바닥이 없으면 미궁이 막 열린 사람에게
			# 45보석짜리 물건이 혈정 8 을 판다(sweep_per_hour = 0.2 x 층이라
			# 바닥 5층이면 시간당 1.0 이다). 혈맥 1티어 노드가 180 이니
			# **노드 0.04레벨**이다 — "살 수 있을 때는 이미 쓸모없다" 그 병이다.
			# 45 = 노드 한 레벨의 1/4. 층이 오르면 소탕분이 곧 바닥을 넘어선다
			# (28층부터). 소탕 배율(혈맥 탐욕·군림)은 일부러 안 태운다 —
			# 상점은 배급이지 소탕이 아니다.
			return maxf(45.0, DungeonDefs.sweep_per_hour(dungeon_floor) * 8.0)
		"sigil":
			# **제단 한 판의 절반.** 40 고정이던 동안 8종 중 유일하게 아무것도
			# 안 보는 상수였고, 제단 보상은 `60 + 15 x (단계-1)` 로 자라서 후반엔
			# 한 판의 27% 까지 녹았다. 혈맹 한 레벨이 100렙에서 220 이라 40 으로는
			# 한 레벨도 못 샀다. 이제 도전 단계를 따라간다(1단계 30 -> 7단계 75).
			return RaidDefs.reward("pact", maxi(1, pact_best)) * 0.5
		"ad_ticket": return 2.0
		"ad_gem": return 50.0
	return 0.0
