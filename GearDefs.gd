class_name GearDefs
extends RefCounted

# 장비. 방치형의 "돌아올 이유"를 담당한다 —
# 스탯 업글은 피만 있으면 되지만 장비는 운이 필요해서 접속할 이유가 된다.
#
# 아이콘은 arrow-rpg에서 넘어온 64종을 그대로 쓴다(gw_ 무기 / ga_ 방어 / gt_ 장신구).
# 이름을 따로 쓰지 않는 이유: 64개를 손으로 짓지 않는다. 접두어(등급) + 명사(파일명)로
# 조합하면 등급이 바뀔 때 이름도 따라 바뀌어 "같은 물건의 더 좋은 판"이 읽힌다.

const SLOTS := ["weapon", "armor", "trinket"]
const SLOT_NAME := {"weapon": "무기", "armor": "방어구", "trinket": "장신구"}
const SLOT_PREFIX := {"weapon": "gw_", "armor": "ga_", "trinket": "gt_"}

# 등급. power는 스탯 배수이자 드랍 가중치의 역수 역할을 한다.
const RARITY := [
	{"key": "common", "name": "평범한", "power": 1.0, "weight": 60.0, "col": Color(0.72, 0.72, 0.76)},
	{"key": "rare", "name": "핏빛", "power": 1.8, "weight": 26.0, "col": Color(0.62, 0.45, 0.95)},
	{"key": "epic", "name": "고대의", "power": 3.2, "weight": 11.0, "col": Color(1.0, 0.78, 0.34)},
	{"key": "legend", "name": "군주의", "power": 5.5, "weight": 3.0, "col": Color(1.0, 0.32, 0.30)},
]

# 슬롯이 올리는 스탯. 무기=피해, 방어구=체력(=생존 대신 방치 안정성), 장신구=흡혈량.
const SLOT_STAT := {"weapon": "damage", "armor": "tough", "trinket": "gold"}

# 파일명 -> 표시용 명사. 없으면 파일명 뒷부분을 그대로 쓴다.
const NOUN := {
	"sword": "검", "axe": "도끼", "blade": "칼날", "hammer": "망치", "spear": "창",
	"scythe": "낫", "staff": "지팡이", "cane": "단장", "crossbow": "석궁", "dart": "표창",
	"glaive": "언월도", "whip": "채찍", "torch": "횃불", "lantern": "등불",
	"boomerang": "부메랑", "coffin": "관", "claw": "발톱", "cloak": "망토",
	"gauntlet": "건틀릿", "plate": "판금", "scale": "비늘갑", "heart": "심장",
	"amulet": "부적", "ring": "반지", "orb": "구슬", "crown": "왕관", "mask": "가면",
	"sigil": "인장", "tome": "마도서", "chalice": "성배", "potion": "물약",
	"flask": "플라스크", "skull": "해골", "wings": "날개", "comet": "혜성",
	"eclipse": "월식", "snowflake": "눈송이", "snow": "서리", "sun": "태양",
	"cross": "십자", "idol": "우상", "hand": "손", "wisp": "도깨비불",
	"chain": "사슬", "bolt": "화살", "arrow": "화살", "burst": "파열",
	"dragon": "용", "coin": "금화", "medal": "훈장",
}


# 이 슬롯에 쓸 수 있는 아이콘 파일명 목록. 파일 스캔은 실행 중 한 번만 한다.
static var _pool := {}


static func icon_pool(slot: String) -> Array:
	if _pool.has(slot):
		return _pool[slot]
	var prefix: String = SLOT_PREFIX[slot]
	var out: Array = []
	var dir := DirAccess.open("res://assets/items")
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			# 내보낸 빌드에서는 .png 가 .png.import 로만 남을 수 있어 확장자를 정리해 본다.
			var name := f.trim_suffix(".import")
			if name.begins_with(prefix) and name.ends_with(".png"):
				var key := name.trim_suffix(".png")
				if not out.has(key):
					out.append(key)
			f = dir.get_next()
		dir.list_dir_end()
	out.sort()
	_pool[slot] = out
	return out


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
	var pool := icon_pool(slot)
	if pool.is_empty():
		return {}
	var icon: String = pool[randi() % pool.size()]
	var rarity := roll_rarity(luck)
	var base := 1.0 + float(stage) * 0.4
	return {
		"slot": slot,
		"icon": icon,
		"rarity": rarity["key"],
		"name": "%s %s" % [rarity["name"], _noun_of(icon)],
		"stat": SLOT_STAT[slot],
		"base": base * float(rarity["power"]),
		"lv": 0,
		"col": rarity["col"],
	}


# 강화 반영 실효 수치. 저장본에는 base 와 lv 만 두고 여기서 계산한다 —
# 수치를 저장해 두면 곡선을 고칠 때 이미 저장된 장비만 옛 값으로 남는다.
static func power(item: Dictionary) -> float:
	return float(item.get("base", 0.0)) * (1.0 + 0.25 * float(item.get("lv", 0)))


# 강화 비용. 등급이 높을수록 비싸다 — 안 그러면 흔한 걸 무한 강화하는 게 최적이 된다.
static func upgrade_cost(item: Dictionary) -> float:
	var mult := 1.0
	for r in RARITY:
		if r["key"] == item.get("rarity", ""):
			mult = float(r["power"])
	return 25.0 * mult * pow(1.45, float(item.get("lv", 0)))


static func icon_path(item: Dictionary) -> String:
	return "res://assets/items/%s.png" % str(item.get("icon", ""))


static func slot_frame(item: Dictionary) -> String:
	return "res://assets/ui/slot_%s.png" % str(item.get("rarity", "common"))


# 파일명 gw_sword_azure -> "검". 접두어와 색 수식어를 떼고 명사만 찾는다.
static func _noun_of(icon: String) -> String:
	for part in icon.split("_"):
		if NOUN.has(part):
			return str(NOUN[part])
	return "유물"
