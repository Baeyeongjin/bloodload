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
const ITEMS := [
	{"id": "blood", "name": "핏빛 주머니", "sub": "혈액", "cost": 30, "per_day": 3,
		"icon": "res://assets/ui/res_blood.png"},
	{"id": "crystal", "name": "혈정 원석", "sub": "혈정", "cost": 45, "per_day": 2,
		"icon": "res://assets/ui/res_crystal.png"},
	{"id": "essence", "name": "정수 결정", "sub": "정수", "cost": 45, "per_day": 2,
		"icon": "res://assets/items/gem.png"},
	{"id": "sigil", "name": "봉인 인장", "sub": "인장", "cost": 45, "per_day": 2,
		"icon": "res://assets/ui/res_sigil.png"},
	{"id": "ticket", "name": "던전 입장권", "sub": "재화 던전 3종 +1판", "cost": 60,
		"per_day": 1, "icon": "res://assets/ui/tab_raid.png"},
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
		"essence": return RaidDefs.open_stage("essence")
		"sigil": return RaidDefs.open_stage("pact")
		"ticket": return RaidDefs.OPEN_STAGE
		# 광고는 처음부터 보인다 — 초반이 가장 재화가 마른 구간이다.
		"ad_ticket", "ad_gem", "ad_chest": return 1
	return 1


# 한 번 살 때 들어오는 양. 던전 한 판의 절반~2/3 — 상점이 던전보다 후하면
# 던전을 안 돌게 된다. 입장권은 수량이 아니라 판 수라 여기서 0 이다.
#
# 혈정만 미궁 층을 본다(소탕 시급이 그 층에서 나오므로). **최소 5층으로 받친다** —
# 미궁이 열렸는데 아직 안 돈 사람에게 0 을 파는 판이 뜬다(실측: 화면에 "혈정 0").
# 소탕 배율(혈맥 탐욕·군림)은 일부러 안 태운다: 상점은 배급이지 소탕이 아니다.
static func amount(id: String, stage: int, dungeon_floor: int) -> float:
	match id:
		# KILL_WORTH 로 되나눈다 — RaidDefs.reward 와 같은 이유(뭉치라 나눌
		# 처치시간이 없다). 안 나누면 몹 체력을 올릴 때마다 상점이 3배로 후해진다.
		"blood": return StageDefs.gold_per_kill(stage) * 200.0 			/ StageDefs.KILL_WORTH   # 동굴 1판 = 400
		"crystal":                                               # 소탕 8시간분
			# 4시간분이면 20층에서 16 이 뜬다 — 노드 한 레벨이 180 인데 45보석짜리
			# 물건이 그 1/11 이면 살 이유가 없다(화면 실측). 하루 2회 = 소탕 2/3일치.
			return DungeonDefs.sweep_per_hour(maxi(dungeon_floor, 5)) * 8.0
		"essence": return StageDefs.boss_essence(stage) * 2.0    # 성소 1판 = 3
		"sigil": return 40.0                                     # 제단 1판 = 60+
		"ad_ticket": return 2.0
		"ad_gem": return 50.0
	return 0.0
