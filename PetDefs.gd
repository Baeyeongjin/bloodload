class_name PetDefs

# 펫 v2 — **등급 5x5 = 25종 로스터** (docs/PET_DESIGN.md v2, 사장님 확정 2026-08-18).
#
# v1(구간이 펫을 직접 주던 6종)에서 바뀐 것:
#   - 획득은 **펫 소환권 뽑기**다. 풀은 처음부터 25종 전부고 등급이 희귀도다.
#   - 성장이 두 축이다: **레벨(먹이)** x **승급(중복 조각)**. 방치형 표준 문법.
#   - 펫 장비(무기 25종)가 생겼다 — 수집 증폭 / 버프 증폭 두 갈래.
#
# 변하지 않은 원칙:
#   - 물어오는 재화는 방치 상자(혈액)와 **안 겹친다** — 혈정·정수·인장·먹이.
#   - 버프는 **데리고 다니는 하나만** 준다. 수집은 가진 전부가 한다.
#
# anim 은 25종 전부 **오리지널**이다(pet_*_idle, 5프레임). 등급마다 A/B 후보를
# 뽑아 사장님이 골랐다(2026-08-18, 아트 배치 1~5).

const CAP_HOURS := 6.0        # 그릇이 차는 시간 — "한 번 더 들를 이유"의 크기
const PET_OPEN := 10          # 펫 소환이 열리는 구간

# 승급(별) — 중복 뽑기 조각. 유물과 같은 문법이라 따로 배울 게 없다.
const MAX_STAR := 5
const SHARDS_PER_STAR := 4

# 레벨 — 먹이(전용 재화, 야수 우리가 준다). 상한은 승급이 연다:
# 별 하나당 10레벨. 조각만으로도 먹이만으로도 끝까지 못 가는 게 의도다.
const FEED_BASE := 40.0
const FEED_EXP := 1.18


# ── 원정 ────────────────────────────────────────────────────────────────
# 펫을 내보내 **조각**을 받아 온다. 재화가 아니라 조각인 이유: 재화는 던전 넷과
# 둥지가 이미 다 나눠 갖고 있어서 뭘 줘도 중복이고, 조각만 유일하게 소환 중복
# 에서만 나온다. 특정 전설을 5성으로 올리려면 같은 펫 17장이 필요한데 확률이
# 0.18% 라 기대 9,434연 — 승급 축이 사실상 잠겨 있었다. 원정이 그 자물쇠다.
#
# 시간은 **나올 조각의 등급**이 정한다(보낸 펫이 아니다). 5성 펫은 제가 낀
# 장비의 조각을 파므로, 커먼 펫을 4시간에 보내 전설 장비 조각을 캐는 구멍이
# 여기서 막힌다. 눈금은 기존 상수에서 빌린다 — 6=CAP_HOURS, 8=방치 기본,
# 16=IDLE_CAP_MAX. 새 시계를 하나 더 배우게 하지 않는다.
const TRIP_OPEN := 30
const TRIP_HOURS := {"common": 4.0, "uncommon": 6.0, "rare": 8.0,
	"epic": 12.0, "legend": 16.0}


static func trip_hours(rarity: String) -> float:
	return float(TRIP_HOURS.get(rarity, 4.0))


# 동시 파견 칸 — 보유 5종 2칸, 13종 3칸, 21종 4칸. 표도 저장키도 필요 없다.
static func trip_slots(owned: int) -> int:
	return clampi(2 + (owned - 5) / 8, 2, 4)


static func lv_cap(star: int) -> int:
	return 10 * clampi(star, 1, MAX_STAR)


static func feed_cost(lv: int) -> float:
	return FEED_BASE * pow(FEED_EXP, float(lv - 1))


# 강화 성공 확률 (사장님 2026-08-18: 먹이를 모으면 **확률로** 오른다).
# 1레벨은 100% — 첫 경험이 실패면 규칙을 오해한다("먹이가 모자랐나?").
# 레벨당 1.2%p 씩 내려가 만렙 근처 41%. 바닥이 있는 건 0%대가 나오는 순간
# 강화가 복권이 되기 때문이다. **실패해도 먹이는 소모된다** — 그게 확률의 값.
static func feed_chance(lv: int) -> float:
	return clampf(1.0 - 0.012 * float(lv - 1), 0.40, 1.0)


# 성장 배수 — 수집 시급과 버프에 같이 곱한다.
# 레벨은 잘게(+6%/레벨), 승급은 굵게(+25%/별). 만렙 만별이면 약 x7.8.
static func growth_mult(lv: int, star: int) -> float:
	return (1.0 + 0.06 * float(clampi(lv, 1, lv_cap(star)) - 1)) \
		* star_mult(star)


static func star_mult(star: int) -> float:
	return 1.0 + 0.25 * float(clampi(star, 1, MAX_STAR) - 1)


# ── 로스터 25 ──────────────────────────────────────────────────────────────
# 등급마다 다섯. gain 은 [혈정, 먹이, 정수, 혈정, 인장] 순환 — 등급마다 먹이
# 펫이 하나씩 있다(설계: "펫 수집 소량"이 먹이의 곁수입이다).
const RARITY_KEYS := ["common", "uncommon", "rare", "epic", "legend"]

const PETS := [
	# 커먼 — 시급 낮고 버프 3%.
	{"id": "nightwing", "name": "밤날개", "rarity": "common", "anim": "pet_nightwing",
		"gain": "crystal", "per_hour": 14.0, "stat": "damage", "value": 0.03,
		"desc": "동굴 천장에서 떨어져 나왔다."},
	{"id": "gravemoss", "name": "무덤이끼", "rarity": "common", "anim": "pet_gravemoss",
		"gain": "feed", "per_hour": 10.0, "stat": "tough", "value": 0.03,
		"desc": "비석 밑에서 자랐다. 뭐든 천천히 삼킨다."},
	{"id": "bonerattle", "name": "뼈울림", "rarity": "common", "anim": "pet_bonerattle",
		"gain": "sigil", "per_hour": 4.0, "stat": "speed", "value": 0.03,
		"desc": "주인을 여섯 번 갈아치웠다."},
	{"id": "embermote", "name": "불티", "rarity": "common", "anim": "pet_embermote",
		"gain": "crystal", "per_hour": 15.0, "stat": "damage", "value": 0.03,
		"desc": "꺼진 화로에서 주웠다."},
	{"id": "webling", "name": "거미새끼", "rarity": "common", "anim": "pet_webling",
		"gain": "sigil", "per_hour": 3.0, "stat": "damage", "value": 0.03,
		"desc": "제 그물에 자주 걸린다."},
	# 언커먼 — 5%.
	{"id": "frostwisp", "name": "서리혼불", "rarity": "uncommon", "anim": "pet_frostwisp",
		"gain": "crystal", "per_hour": 24.0, "stat": "speed", "value": 0.05,
		"desc": "얼음 위에서만 켜진다. 손을 대면 차갑다."},
	{"id": "sporeling", "name": "홀씨돌이", "rarity": "uncommon", "anim": "pet_sporeling",
		"gain": "feed", "per_hour": 16.0, "stat": "damage", "value": 0.05,
		"desc": "밟으면 는다. 정말로 는다."},
	{"id": "cinderhound", "name": "잿불 사냥개", "rarity": "uncommon", "anim": "pet_cinderhound",
		"gain": "sigil", "per_hour": 7.0, "stat": "damage", "value": 0.05,
		"desc": "불을 물어오라면 불을 물어온다."},
	{"id": "ashtoad", "name": "재두꺼비", "rarity": "uncommon", "anim": "pet_ashtoad",
		"gain": "crystal", "per_hour": 26.0, "stat": "tough", "value": 0.05,
		"desc": "삼킨 것을 절대 말하지 않는다."},
	{"id": "palegnaw", "name": "창백한 이빨", "rarity": "uncommon", "anim": "pet_palegnaw",
		"gain": "sigil", "per_hour": 6.0, "stat": "speed", "value": 0.05,
		"desc": "씹는 소리가 먼저 들린다."},
	# 레어 — 7%.
	{"id": "sneakfang", "name": "송곳니 도둑", "rarity": "rare", "anim": "pet_sneakfang",
		"gain": "crystal", "per_hour": 36.0, "stat": "damage", "value": 0.07,
		"desc": "훔친 것을 자랑하러 돌아온다."},
	{"id": "rotshuffle", "name": "끌신", "rarity": "rare", "anim": "pet_rotshuffle",
		"gain": "feed", "per_hour": 24.0, "stat": "tough", "value": 0.07,
		"desc": "서두르는 법을 잊었다. 도착은 한다."},
	{"id": "tuskbrute", "name": "엄니 짐승", "rarity": "rare", "anim": "pet_tuskbrute",
		"gain": "feed", "per_hour": 12.0, "stat": "damage", "value": 0.07,
		"desc": "제 엄니를 세다가 잠든다."},
	{"id": "hornling", "name": "뿔돋이", "rarity": "rare", "anim": "pet_hornling",
		"gain": "crystal", "per_hour": 38.0, "stat": "speed", "value": 0.07,
		"desc": "뿔이 가려울 때가 제일 위험하다."},
	{"id": "rimeweaver", "name": "서리 길쌈꾼", "rarity": "rare", "anim": "pet_rimeweaver",
		"gain": "sigil", "per_hour": 9.0, "stat": "damage", "value": 0.07,
		"desc": "짜 놓은 그물이 녹지 않는다."},
	# 에픽 — 10%.
	{"id": "frosthulk", "name": "서리 거인", "rarity": "epic", "anim": "pet_frosthulk",
		"gain": "crystal", "per_hour": 52.0, "stat": "tough", "value": 0.10,
		"desc": "천 년을 서 있었다. 급할 게 없다."},
	{"id": "veilchanter", "name": "장막 읊는 자", "rarity": "epic", "anim": "pet_veilchanter",
		"gain": "feed", "per_hour": 34.0, "stat": "damage", "value": 0.10,
		"desc": "낮은 목소리로 값을 깎는다."},
	{"id": "hagspawn", "name": "마녀의 씨", "rarity": "epic", "anim": "pet_hagspawn",
		"gain": "feed", "per_hour": 20.0, "stat": "damage", "value": 0.10,
		"desc": "심은 적 없는 곳에서 돋는다."},
	{"id": "alleye", "name": "온눈", "rarity": "epic", "anim": "pet_alleye",
		"gain": "crystal", "per_hour": 55.0, "stat": "speed", "value": 0.10,
		"desc": "감는 법을 모른다. 전부 본다."},
	{"id": "choirbone", "name": "뼈의 성가대", "rarity": "epic", "anim": "pet_choirbone",
		"gain": "sigil", "per_hour": 14.0, "stat": "tough", "value": 0.10,
		"desc": "한 몸에서 여러 목소리가 난다."},
	# 전설 — 13%.
	{"id": "duskknight", "name": "황혼 기사", "rarity": "legend", "anim": "pet_duskknight",
		"gain": "crystal", "per_hour": 75.0, "stat": "damage", "value": 0.13,
		"desc": "해가 지는 쪽으로만 걷는다."},
	{"id": "wraithlord", "name": "망령 군주", "rarity": "legend", "anim": "pet_wraithlord",
		"gain": "feed", "per_hour": 48.0, "stat": "speed", "value": 0.13,
		"desc": "신하를 잃고도 왕관을 안 벗었다."},
	{"id": "voidmaw", "name": "공허 아가리", "rarity": "legend", "anim": "pet_voidmaw",
		"gain": "crystal", "per_hour": 26.0, "stat": "damage", "value": 0.13,
		"desc": "삼킨 자리에 이름이 남지 않는다."},
	{"id": "fleshreaper", "name": "살점 수확자", "rarity": "legend", "anim": "pet_fleshreaper",
		"gain": "crystal", "per_hour": 78.0, "stat": "tough", "value": 0.13,
		"desc": "수확철이 끝나지 않는다고 믿는다."},
	{"id": "stonewing", "name": "돌날개", "rarity": "legend", "anim": "pet_stonewing",
		"gain": "sigil", "per_hour": 20.0, "stat": "damage", "value": 0.13,
		"desc": "낮에는 지붕이고 밤에는 이빨이다."},
]


# ── 펫 장비(무기) 25 ───────────────────────────────────────────────────────
# 두 갈래만 있다: gather(수집 시급 +%) / amp(장착 펫 버프 +%). 영웅 장비와
# 겹치지 않는 축이라 파워 예산 충돌이 없다. 아이콘은 assets/items/petw_<id>.png
# 규약이다(2026-08-18 아트 배치, 25종 전부).
const GEAR := [
	{"id": "bone_dirk", "name": "뼈 단검", "rarity": "common", "kind": "gather", "value": 0.10},
	{"id": "rust_hook", "name": "녹슨 갈고리", "rarity": "common", "kind": "amp", "value": 0.08},
	{"id": "blood_bell", "name": "핏빛 방울", "rarity": "common", "kind": "gather", "value": 0.10},
	{"id": "thorn_leash", "name": "가시 목줄", "rarity": "common", "kind": "amp", "value": 0.08},
	{"id": "ash_cane", "name": "재의 지팡이", "rarity": "common", "kind": "gather", "value": 0.10},
	{"id": "frost_pick", "name": "서리 송곳", "rarity": "uncommon", "kind": "amp", "value": 0.12},
	{"id": "moon_whistle", "name": "달빛 호루라기", "rarity": "uncommon", "kind": "gather", "value": 0.15},
	{"id": "heart_chain", "name": "심장 사슬", "rarity": "uncommon", "kind": "amp", "value": 0.12},
	{"id": "shade_whip", "name": "그늘 채찍", "rarity": "uncommon", "kind": "gather", "value": 0.15},
	{"id": "ember_brand", "name": "잿불 낙인", "rarity": "uncommon", "kind": "amp", "value": 0.12},
	{"id": "silver_bit", "name": "은 재갈", "rarity": "rare", "kind": "gather", "value": 0.22},
	{"id": "storm_quill", "name": "폭풍 깃털", "rarity": "rare", "kind": "amp", "value": 0.18},
	{"id": "blood_horn", "name": "핏빛 나팔", "rarity": "rare", "kind": "gather", "value": 0.22},
	{"id": "fang_spear", "name": "어금니 창", "rarity": "rare", "kind": "amp", "value": 0.18},
	{"id": "rime_chime", "name": "서리 종", "rarity": "rare", "kind": "gather", "value": 0.22},
	{"id": "abyss_claw", "name": "심연 갈퀴", "rarity": "epic", "kind": "amp", "value": 0.25},
	{"id": "crown_shard", "name": "왕관 파편", "rarity": "epic", "kind": "gather", "value": 0.30},
	{"id": "grail_sip", "name": "성혈 잔", "rarity": "epic", "kind": "amp", "value": 0.25},
	{"id": "shadow_noose", "name": "그림자 올가미", "rarity": "epic", "kind": "gather", "value": 0.30},
	{"id": "thunder_torc", "name": "뇌우 목걸이", "rarity": "epic", "kind": "amp", "value": 0.25},
	{"id": "doom_fang", "name": "종말의 이빨", "rarity": "legend", "kind": "gather", "value": 0.40},
	{"id": "redmoon_scythe", "name": "붉은 달 낫", "rarity": "legend", "kind": "amp", "value": 0.35},
	{"id": "void_chain", "name": "공허 사슬", "rarity": "legend", "kind": "gather", "value": 0.40},
	{"id": "eternal_horn", "name": "영원의 뿔피리", "rarity": "legend", "kind": "amp", "value": 0.35},
	{"id": "kings_vein", "name": "왕의 핏줄", "rarity": "legend", "kind": "gather", "value": 0.40},
]


static func of(id: String) -> Dictionary:
	for p in PETS:
		if str(p["id"]) == id:
			return p
	return {}


static func gear_of(id: String) -> Dictionary:
	for g in GEAR:
		if str(g["id"]) == id:
			return g
	return {}


static func of_rarity(rarity: String) -> Array:
	var out: Array = []
	for p in PETS:
		if str(p["rarity"]) == rarity:
			out.append(p)
	return out


static func gear_of_rarity(rarity: String) -> Array:
	var out: Array = []
	for g in GEAR:
		if str(g["rarity"]) == rarity:
			out.append(g)
	return out


# 등급 굴림 — GachaDefs 의 무게를 그대로 쓰되 우리 다섯 등급만 본다
# (신화는 펫에 없다). 표를 복사하지 않는 건 확률을 두 곳에서 관리하지
# 않으려는 것이다.
static func roll_rarity() -> String:
	var total := 0.0
	for r in GachaDefs.RARITIES:
		if str(r["key"]) in RARITY_KEYS:
			total += float(r["weight"])
	var pick := randf() * total
	for r in GachaDefs.RARITIES:
		if not (str(r["key"]) in RARITY_KEYS):
			continue
		pick -= float(r["weight"])
		if pick <= 0.0:
			return str(r["key"])
	return "common"


static func per_hour(id: String, lv: int, star: int) -> float:
	var p := of(id)
	return 0.0 if p.is_empty() \
		else float(p["per_hour"]) * growth_mult(lv, star)


static func cap(id: String, lv: int, star: int) -> float:
	return per_hour(id, lv, star) * CAP_HOURS


static func accrue(id: String, have: float, hours: float, lv: int,
		star: int, gather := 0.0) -> float:
	if of(id).is_empty() or hours <= 0.0:
		return have
	var rate := per_hour(id, lv, star) * (1.0 + gather)
	return minf(cap(id, lv, star) * (1.0 + gather), have + rate * hours)


# 데리고 다니는 하나만 버프를 준다. amp 는 그 펫이 든 장비의 증폭이다.
static func bonus(worn: String, stat: String, lv: int, star: int,
		amp := 0.0) -> float:
	var p := of(worn)
	if p.is_empty() or str(p["stat"]) != stat:
		return 0.0
	return float(p["value"]) * growth_mult(lv, star) * (1.0 + amp)


static func icon_dir(id: String) -> String:
	var p := of(id)
	if p.is_empty():
		return ""
	var a := str(p["anim"])
	# 전용 아트(pet_*)는 idle 폴더, 자리표시(몹 재활용)는 walk 폴더다 —
	# 아트 배치가 등급 단위로 오므로 한동안 둘이 섞여 산다.
	return ("res://assets/anim/%s_idle" if a.begins_with("pet_") 		else "res://assets/anim/%s_walk") % a
