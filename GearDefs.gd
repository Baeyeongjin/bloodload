class_name GearDefs
extends RefCounted

# 장비. 방치형의 "돌아올 이유"를 담당한다 —
# 스탯 업글은 피만 있으면 되지만 장비는 운이 필요해서 접속할 이유가 된다.
#
# 무기·방어구·장신구마다 6등급 × 4개를 고정한다. 아이콘과 이름을 따로 굴리면
# 그림은 망치인데 이름은 검인 식으로 어긋나므로 카탈로그가 둘을 함께 소유한다.

const SLOTS := ["weapon", "armor", "trinket"]
const SLOT_NAME := {"weapon": "무기", "armor": "방어구", "trinket": "장신구"}
const SLOT_UNLOCK := {"weapon": 1, "armor": 5, "trinket": 10}
const STAT_NAME := {"damage": "공격력", "tough": "최대 체력", "critdmg": "치명타 피해"}

# 등급. power는 스탯 배수이자 드랍 가중치의 역수 역할을 한다.
const RARITY := GachaDefs.RARITIES

# 슬롯이 올리는 스탯. 무기=피해, 방어구=체력(=생존 대신 방치 안정성).
# 장신구는 **치명타 피해**다(사장님 2026-08-25: "피 획득/흡혈량은 없애고
# 공격력이나 치명타 피해량으로"). 공격력은 무기·스탯·혈맥이 이미 밀고 있어
# 또 붙이면 밋밋하다 — 축을 갈라야 "무기냐 장신구냐"가 선택이 된다.
const SLOT_STAT := {"weapon": "damage", "armor": "tough", "trinket": "critdmg"}

const CATALOG := {
	"weapon": {
		"common": [["gw_sword_worn", "낡은 검"], ["gw_hammer_iron", "철 망치"],
			["gw_axe_broad", "벌목 도끼"], ["gw_crossbow", "낡은 석궁"]],
		"uncommon": [["gw_sword_steel", "강철 검"], ["gw_spear_blue", "푸른 창"],
			["gw_dart_jade", "비취 표창"], ["gw_boomerang", "사냥 부메랑"]],
		"rare": [["gw_sword_azure", "청명검"], ["gw_blade_rose", "장미 칼날"],
			["gw_cane_serpent", "독사 단장"], ["gw_staff_emerald", "에메랄드 지팡이"]],
		"epic": [["gw_blade_crimson", "핏빛 칼날"], ["gw_whip_crimson", "혈편 채찍"],
			["gw_scythe_purple", "망령 낫"], ["gw_cane_dark", "암야 단장"]],
		"legend": [["gw_axe_gold", "황금 전투도끼"], ["gw_glaive_gold", "태양 언월도"],
			["gw_hammer_rune", "룬 파쇄망치"], ["gw_torch_flame", "영겁의 성화"]],
		"mythic": [["gw_coffin_blade", "관통 장송검"], ["gw_lantern_rod", "혼등 지팡이"],
			["gw_scythe_green", "종말의 낫"], ["gw_staff_bone", "시조의 뼈지팡이"]],
	},
	"armor": {
		"common": [["ga_leather_vest_worn", "낡은 가죽 조끼"],
			["ga_chainmail_rusted", "녹슨 사슬 갑옷"], ["ga_guard_cuirass", "경비병 흉갑"],
			["ga_apprentice_robe", "수습생 로브"]],
		"uncommon": [["ga_hunter_coat", "사냥꾼 코트"], ["ga_graveguard_mail", "묘지 경비갑"],
			["ga_vampire_leathers", "흡혈귀 가죽옷"], ["ga_bone_pauldrons", "뼈 견갑옷"]],
		"rare": [["gear_plate", "흑철 판금"], ["gear_scale", "자수정 비늘갑"],
			["ga_frost_plate", "서리 기사 갑옷"], ["ga_blood_cuirass", "핏빛 흉갑"]],
		"epic": [["gear_cloak", "진홍 망토"], ["gear_robe", "심연 로브"],
			["ga_spectral_armor", "망령 갑옷"], ["ga_fallen_paladin", "타락 성기사 갑옷"]],
		"legend": [["ga_dragon_scale", "용비늘 갑주"], ["ga_abyss_raiment", "심연의 예복"],
			["ga_inferno_plate", "지옥불 갑주"], ["ga_eclipse_mantle", "월식 망토"]],
		"mythic": [["ga_primordial_vampire", "시조 흡혈귀 갑주"],
			["ga_void_lord_plate", "공허 군주 판금"], ["ga_apocalypse_dragon", "종말의 용갑"],
			["ga_immortal_shroud", "불멸자의 장례복"]],
	},
	"trinket": {
		"common": [["gt_coin_gold", "낡은 금화"], ["gt_potion_azure", "푸른 물약"],
			["gt_flask_toxic", "독 플라스크"], ["gt_skull_jade", "비취 해골"]],
		"uncommon": [["gt_amulet_blood", "피의 부적"], ["gt_ring_fire", "불꽃 반지"],
			["gt_ring_skull", "해골 반지"], ["gt_snowflake", "서리 결정"]],
		"rare": [["gt_chalice", "은빛 성배"], ["gt_cross_holy", "성스러운 십자가"],
			["gt_mask_gold", "황금 가면"], ["gt_sigil_gold", "태양 인장"]],
		"epic": [["gt_crown_thorn", "가시 왕관"], ["gt_orb_dark", "암흑 구슬"],
			["gt_orb_violet", "보랏빛 구슬"], ["gt_tome_arcane", "비전 마도서"]],
		"legend": [["gt_comet", "혜성 조각"], ["gt_dragon_fire", "용의 불씨"],
			["gt_eclipse", "월식의 눈"], ["gt_sun_medal", "태양 훈장"]],
		"mythic": [["gt_ring_void", "공허 반지"], ["gt_snow_sigil", "영원의 설인장"],
			["gt_wings_pale", "창백한 날개"], ["gt_wisp_violet", "시조의 혼불"]],
	},
}


# 이 슬롯에 쓸 수 있는 아이콘 파일명 목록. 파일 스캔은 실행 중 한 번만 한다.
static var _pool := {}


static func icon_pool(slot: String) -> Array:
	if _pool.has(slot):
		return _pool[slot]
	var out: Array = []
	for rarity in GachaDefs.RARITIES:
		for spec in items_of(slot, str(rarity["key"])):
			out.append(str(spec[0]))
	_pool[slot] = out
	return out


static func items_of(slot: String, rarity_key: String) -> Array:
	return CATALOG.get(slot, {}).get(rarity_key, [])


static func lock_reason(slot: String, stage: int) -> String:
	var unlock := int(SLOT_UNLOCK.get(slot, 1))
	return "" if stage >= unlock else "%d단계 해금" % unlock


static func normalize_catalog_item(item: Dictionary) -> void:
	var rarity := GachaDefs.rarity(str(item.get("rarity", "common")))
	var variants := items_of(str(item.get("slot", "weapon")), str(rarity["key"]))
	if variants.is_empty():
		return
	var chosen: Array = variants[absi(str(item.get("icon", "")).hash()) % variants.size()]
	for spec in variants:
		if str(spec[0]) == str(item.get("icon", "")):
			chosen = spec
			break
	item["icon"] = str(chosen[0])
	item["name"] = str(chosen[1])
	item["col"] = rarity["col"]


static func roll_rarity(luck: float = 0.0) -> Dictionary:
	# luck 은 상위 등급 가중치를 키운다. 0이면 표 그대로.
	var total := 0.0
	for r in RARITY:
		total += float(r["weight"]) * (1.0 + luck * float(r["power"]) * 0.1)
	var roll := randf() * total
	var acc := 0.0
	for r in RARITY:
		acc += float(r["weight"]) * (1.0 + luck * float(r["power"]) * 0.1)
		if roll <= acc:
			return r
	return RARITY[0]


# 장비 하나를 굴린다. stage 가 높을수록 기본 수치가 커진다.
static func roll(slot: String, stage: int, luck: float = 0.0) -> Dictionary:
	return make(slot, stage, roll_rarity(luck))


static func make(slot: String, stage: int, rarity: Dictionary) -> Dictionary:
	var pool := items_of(slot, str(rarity["key"]))
	if pool.is_empty():
		return {}
	var spec: Array = pool[randi() % pool.size()]
	var base := 1.0 + float(stage) * 0.4
	return {
		"slot": slot,
		"icon": str(spec[0]),
		"rarity": rarity["key"],
		"name": str(spec[1]),
		"stat": SLOT_STAT[slot],
		"base": base * float(rarity["power"]),
		"lv": 0,
		"col": rarity["col"],
	}


# ── 만렙 (사장님 2026-08-26) ────────────────────────────────────────────
# **등급이 뚜껑이다** — 펫이 "별 하나당 10레벨"인 것과 같은 문법이고, 커먼을
# 무한히 올리는 대신 조합해서 등급을 올릴 이유가 여기서 생긴다.
# 상한이 없던 시절엔 장착 배수가 lv 에 선형(x0.25)이라 곱연산 예산(x4)을
# 뚫는 유일한 축이었다 — EXPANSION 2장 "곱연산은 상한 필수"의 구멍이었다.
const MAX_LV := [50, 100, 150, 200, 250, 400]

# 레벨당 증가율도 **등급마다 다르다.** 만렙이 등급마다 다른데 증가율이 같으면
# 만렙 배수가 등급마다 8배씩 벌어진다. 만렙에서 장착 x4 · 보유 x2 로 모으므로
# 값은 3/만렙 · 1/만렙 이다 — 이 둘이 곱연산 예산의 자물쇠다.
#
# 비용 지수도 등급마다 다르다. 지수는 레벨마다 곱해지므로 만렙이 50 -> 400 으로
# 8배가 되면 비용은 8배가 아니라 e^350 배다 — 하나로 두면 상위 등급 만렙이
# 우주 나이를 넘는다(1.45 로 두면 커먼 50렙조차 150만 일이었다).
# 목표 일수에서 역산한 값이다(하루 12,700 기준):
#   커먼 0.5일 · 언커먼 1.5일 · 레어 4일 · 에픽 8일 · 레전더리 15일 · 신화 60일
const LV_EXP := [1.0559, 1.0289, 1.0219, 1.0152, 1.0113, 1.0085]


static func max_lv(item: Dictionary) -> int:
	return MAX_LV[clampi(GachaDefs.rarity_index(
		str(item.get("rarity", "common"))), 0, MAX_LV.size() - 1)]


# **신화는 100렙부터 조각도 먹는다** (사장님 2026-08-26). 연마석만으로 끝까지
# 가면 최고 등급의 끝이 그냥 시간 문제가 된다 — 뽑기에서만 나오는 조각을 섞어
# "돈으로 못 사는 구간"을 만든다.
# 30렙마다 한 장이라 100 -> 400 이 총 10장이다. 신화 조각은 신화 소환 중복
# 에서만 나오고(조합 실패 보상은 최고 등급엔 없다) 그 확률이 0.1% 라, 장당
# 무게가 커먼 조각 수백 장과 맞먹는다. 열 장도 가볍지 않다.
const SHARD_FROM_LV := 100
const SHARD_EVERY := 30


# 이번 한 칸에 드는 조각. 0 이면 연마석만 낸다.
static func upgrade_shards(item: Dictionary) -> int:
	if GachaDefs.rarity_index(str(item.get("rarity", "common"))) < RARITY.size() - 1:
		return 0
	var lv := int(item.get("lv", 0))
	if lv < SHARD_FROM_LV:
		return 0
	return 1 if (lv - SHARD_FROM_LV) % SHARD_EVERY == 0 else 0


static func is_max_lv(item: Dictionary) -> bool:
	return int(item.get("lv", 0)) >= max_lv(item)


# 강화 반영 실효 수치. 저장본에는 base 와 lv 만 두고 여기서 계산한다 —
# 수치를 저장해 두면 곡선을 고칠 때 이미 저장된 장비만 옛 값으로 남는다.
# **만렙에서 x4** — 그 위로는 안 자란다(옛 저장본이 상한 위에 있어도 안전).
static func power(item: Dictionary) -> float:
	var cap := max_lv(item)
	var lv := clampi(int(item.get("lv", 0)), 0, cap)
	return float(item.get("base", 0.0)) * (1.0 + (3.0 / float(cap)) * float(lv))


# 레벨업 비용 — 연마석. 등급이 높을수록 비싸고(안 그러면 흔한 걸 올리는 게
# 최적이 된다) 레벨마다 등급별 지수로 오른다. 던전 한 판이 초반엔 몇 레벨,
# 뒤로 갈수록 한 레벨이 된다 — 던전 단계를 밀 이유가 거기서 생긴다.
static func upgrade_cost(item: Dictionary) -> float:
	var i := clampi(GachaDefs.rarity_index(str(item.get("rarity", "common"))),
		0, LV_EXP.size() - 1)
	return ceilf(25.0 * float(RARITY[i]["power"])
		* pow(LV_EXP[i], float(item.get("lv", 0))))


# 조합 (사장님 2026-08-25): 조각 FUSE_SHARDS 개로 1회 **시도**, 등급별 성공
# 확률(FUSE_RATE)과 등급별 천장(FUSE_PITY — 그 회차째 시도는 확정). 실패해도
# 조각은 소모된다 — 천장이 받친다. 표는 등급 인덱스 순서다.
#
# **천장은 등급이 오를수록 가까워진다**(10/10/8/7/5/3). 확률이 낮은 쪽일수록
# 천장이 멀면 상위 등급이 사실상 잠긴다 — 확률로 조이고 천장으로 푼다.
const FUSE_SHARDS := 3
const FUSE_RATE := [0.8, 0.6, 0.45, 0.3, 0.2, 0.15]
const FUSE_PITY := [10, 10, 8, 7, 5, 3]


static func fuse_rate(item: Dictionary) -> float:
	var i := GachaDefs.rarity_index(str(item.get("rarity", "common")))
	return float(FUSE_RATE[clampi(i, 0, FUSE_RATE.size() - 1)])


static func fuse_pity(item: Dictionary) -> int:
	var i := GachaDefs.rarity_index(str(item.get("rarity", "common")))
	return int(FUSE_PITY[clampi(i, 0, FUSE_PITY.size() - 1)])


# 수집(보유) 효과는 장착과 무관하다. 최고 등급 한 벌만 남기므로 중복 수에는 곱하지 않는다.
# **레벨을 올리면 보유 효과도 같이 오른다.** 안 그러면 "장착 안 할 장비는
# 올릴 이유가 없다"가 된다. **만렙에서 x2** — 장착(x4)의 절반이라 장착이
# 여전히 주력이다. 등급마다 만렙이 다르므로 비율도 1/만렙 이다.
static func collection_rate(item: Dictionary) -> float:
	var cap := max_lv(item)
	var lv := clampi(int(item.get("lv", 0)), 0, cap)
	return [0.005, 0.01, 0.02, 0.04, 0.08, 0.16][GachaDefs.rarity_index(
		str(item.get("rarity", "common")))] \
		* (1.0 + float(lv) / float(cap))


static func promote(item: Dictionary) -> bool:
	var index := GachaDefs.rarity_index(str(item.get("rarity", "common")))
	if index >= GachaDefs.RARITIES.size() - 1:
		return false
	var old_rarity: Dictionary = GachaDefs.RARITIES[index]
	var next_rarity: Dictionary = GachaDefs.RARITIES[index + 1]
	var current := items_of(str(item.get("slot", "weapon")), str(old_rarity["key"]))
	var lane := 0
	for i in current.size():
		if str(current[i][0]) == str(item.get("icon", "")):
			lane = i
			break
	var next_items := items_of(str(item.get("slot", "weapon")), str(next_rarity["key"]))
	if next_items.is_empty():
		return false
	var next_spec: Array = next_items[mini(lane, next_items.size() - 1)]
	item["base"] = float(item.get("base", 0.0)) / float(old_rarity["power"]) \
		* float(next_rarity["power"])
	item["rarity"] = next_rarity["key"]
	item["icon"] = str(next_spec[0])
	item["name"] = str(next_spec[1])
	item["col"] = next_rarity["col"]
	return true


static func icon_path(item: Dictionary) -> String:
	return "res://assets/items/%s.png" % str(item.get("icon", ""))


static func slot_frame(_item: Dictionary) -> String:
	return "res://assets/ui/slot_common.png"
