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
# anim 은 전부 **자리표시**다(기존 몹 walk 재활용). 아트 배치에서 25종을
# 오리지널로 뽑아 교체한다(idle 4~6프레임, 후보는 사장님이 고른다).

const CAP_HOURS := 6.0        # 그릇이 차는 시간 — "한 번 더 들를 이유"의 크기
const PET_OPEN := 10          # 펫 소환이 열리는 구간

# 승급(별) — 중복 뽑기 조각. 유물과 같은 문법이라 따로 배울 게 없다.
const MAX_STAR := 5
const SHARDS_PER_STAR := 4

# 레벨 — 먹이(전용 재화, 야수 우리가 준다). 상한은 승급이 연다:
# 별 하나당 10레벨. 조각만으로도 먹이만으로도 끝까지 못 가는 게 의도다.
const FEED_BASE := 40.0
const FEED_EXP := 1.18


static func lv_cap(star: int) -> int:
	return 10 * clampi(star, 1, MAX_STAR)


static func feed_cost(lv: int) -> float:
	return FEED_BASE * pow(FEED_EXP, float(lv - 1))


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
		"gain": "essence", "per_hour": 5.0, "stat": "speed", "value": 0.03,
		"desc": "주인을 여섯 번 갈아치웠다."},
	{"id": "embermote", "name": "불티", "rarity": "common", "anim": "pet_embermote",
		"gain": "crystal", "per_hour": 15.0, "stat": "gold", "value": 0.03,
		"desc": "꺼진 화로에서 주웠다."},
	{"id": "webling", "name": "거미새끼", "rarity": "common", "anim": "pet_webling",
		"gain": "sigil", "per_hour": 3.0, "stat": "damage", "value": 0.03,
		"desc": "제 그물에 자주 걸린다."},
	# 언커먼 — 5%.
	{"id": "frostwisp", "name": "서리혼불", "rarity": "uncommon", "anim": "ice_wisp",
		"gain": "crystal", "per_hour": 24.0, "stat": "speed", "value": 0.05,
		"desc": "얼음 위에서만 켜진다. 손을 대면 차갑다."},
	{"id": "sporeling", "name": "홀씨돌이", "rarity": "uncommon", "anim": "mushroom",
		"gain": "feed", "per_hour": 16.0, "stat": "gold", "value": 0.05,
		"desc": "밟으면 는다. 정말로 는다."},
	{"id": "cinderhound", "name": "잿불 사냥개", "rarity": "uncommon", "anim": "hellhound",
		"gain": "essence", "per_hour": 8.0, "stat": "damage", "value": 0.05,
		"desc": "불을 물어오라면 불을 물어온다."},
	{"id": "ashtoad", "name": "재두꺼비", "rarity": "uncommon", "anim": "lava_toad",
		"gain": "crystal", "per_hour": 26.0, "stat": "tough", "value": 0.05,
		"desc": "삼킨 것을 절대 말하지 않는다."},
	{"id": "palegnaw", "name": "창백한 이빨", "rarity": "uncommon", "anim": "ghoul",
		"gain": "sigil", "per_hour": 6.0, "stat": "speed", "value": 0.05,
		"desc": "씹는 소리가 먼저 들린다."},
	# 레어 — 7%.
	{"id": "sneakfang", "name": "송곳니 도둑", "rarity": "rare", "anim": "goblin",
		"gain": "crystal", "per_hour": 36.0, "stat": "damage", "value": 0.07,
		"desc": "훔친 것을 자랑하러 돌아온다."},
	{"id": "rotshuffle", "name": "끌신", "rarity": "rare", "anim": "zombie",
		"gain": "feed", "per_hour": 24.0, "stat": "tough", "value": 0.07,
		"desc": "서두르는 법을 잊었다. 도착은 한다."},
	{"id": "tuskbrute", "name": "엄니 짐승", "rarity": "rare", "anim": "orc",
		"gain": "essence", "per_hour": 12.0, "stat": "gold", "value": 0.07,
		"desc": "제 엄니를 세다가 잠든다."},
	{"id": "hornling", "name": "뿔돋이", "rarity": "rare", "anim": "demon",
		"gain": "crystal", "per_hour": 38.0, "stat": "speed", "value": 0.07,
		"desc": "뿔이 가려울 때가 제일 위험하다."},
	{"id": "rimeweaver", "name": "서리 길쌈꾼", "rarity": "rare", "anim": "frost_spider",
		"gain": "sigil", "per_hour": 9.0, "stat": "damage", "value": 0.07,
		"desc": "짜 놓은 그물이 녹지 않는다."},
	# 에픽 — 10%.
	{"id": "frosthulk", "name": "서리 거인", "rarity": "epic", "anim": "frost_golem",
		"gain": "crystal", "per_hour": 52.0, "stat": "tough", "value": 0.10,
		"desc": "천 년을 서 있었다. 급할 게 없다."},
	{"id": "veilchanter", "name": "장막 읊는 자", "rarity": "epic", "anim": "cultist",
		"gain": "feed", "per_hour": 34.0, "stat": "gold", "value": 0.10,
		"desc": "낮은 목소리로 값을 깎는다."},
	{"id": "hagspawn", "name": "마녀의 씨", "rarity": "epic", "anim": "plague_hag",
		"gain": "essence", "per_hour": 18.0, "stat": "damage", "value": 0.10,
		"desc": "심은 적 없는 곳에서 돋는다."},
	{"id": "alleye", "name": "온눈", "rarity": "epic", "anim": "eye_mass",
		"gain": "crystal", "per_hour": 55.0, "stat": "speed", "value": 0.10,
		"desc": "감는 법을 모른다. 전부 본다."},
	{"id": "choirbone", "name": "뼈의 성가대", "rarity": "epic", "anim": "bone_choir",
		"gain": "sigil", "per_hour": 14.0, "stat": "tough", "value": 0.10,
		"desc": "한 몸에서 여러 목소리가 난다."},
	# 전설 — 13%.
	{"id": "duskknight", "name": "황혼 기사", "rarity": "legend", "anim": "dark_knight",
		"gain": "crystal", "per_hour": 75.0, "stat": "damage", "value": 0.13,
		"desc": "해가 지는 쪽으로만 걷는다."},
	{"id": "wraithlord", "name": "망령 군주", "rarity": "legend", "anim": "wraith_knight",
		"gain": "feed", "per_hour": 48.0, "stat": "speed", "value": 0.13,
		"desc": "신하를 잃고도 왕관을 안 벗었다."},
	{"id": "voidmaw", "name": "공허 아가리", "rarity": "legend", "anim": "void_wraith",
		"gain": "essence", "per_hour": 26.0, "stat": "gold", "value": 0.13,
		"desc": "삼킨 자리에 이름이 남지 않는다."},
	{"id": "fleshreaper", "name": "살점 수확자", "rarity": "legend", "anim": "butcher",
		"gain": "crystal", "per_hour": 78.0, "stat": "tough", "value": 0.13,
		"desc": "수확철이 끝나지 않는다고 믿는다."},
	{"id": "stonewing", "name": "돌날개", "rarity": "legend", "anim": "gargoyle",
		"gain": "sigil", "per_hour": 20.0, "stat": "damage", "value": 0.13,
		"desc": "낮에는 지붕이고 밤에는 이빨이다."},
]


# ── 펫 장비(무기) 25 ───────────────────────────────────────────────────────
# 두 갈래만 있다: gather(수집 시급 +%) / amp(장착 펫 버프 +%). 영웅 장비와
# 겹치지 않는 축이라 파워 예산 충돌이 없다. icon 은 아트 배치에서 채운다.
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
