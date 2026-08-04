class_name GachaDefs
extends RefCounted

const COST := 30.0
const RARE_INDEX := 2
const LEGEND_INDEX := 4
const RARITIES := [
	{"key": "common", "name": "커먼", "power": 1.0, "weight": 50.0,
		"col": Color(0.72, 0.72, 0.76)},
	{"key": "uncommon", "name": "언커먼", "power": 1.35, "weight": 30.0,
		"col": Color(0.42, 0.82, 0.55)},
	{"key": "rare", "name": "레어", "power": 1.8, "weight": 14.0,
		"col": Color(0.45, 0.62, 1.0)},
	{"key": "epic", "name": "에픽", "power": 3.2, "weight": 5.0,
		"col": Color(0.72, 0.45, 0.95)},
	{"key": "legend", "name": "레전더리", "power": 5.5, "weight": 0.9,
		"col": Color(1.0, 0.62, 0.22)},
	{"key": "mythic", "name": "신화", "power": 9.0, "weight": 0.1,
		"col": Color(1.0, 0.28, 0.38)},
]


static func rarity(key: String) -> Dictionary:
	for value in RARITIES:
		if value["key"] == key:
			return value
	return RARITIES[0]


static func rarity_index(key: String) -> int:
	for i in RARITIES.size():
		if RARITIES[i]["key"] == key:
			return i
	return 0


# 반환 pity는 다음 뽑기 전에 쌓여 있는 횟수다. 99면 이번 한 번이 전설이다.
static func pull(count: int, pity: int) -> Dictionary:
	var out: Array[String] = []
	var has_rare := false
	for i in count:
		var min_index := RARE_INDEX if count == 10 and i == 9 and not has_rare else 0
		var index := LEGEND_INDEX if pity >= 99 else _roll_index(min_index)
		out.append(str(RARITIES[index]["key"]))
		has_rare = has_rare or index >= RARE_INDEX
		pity = 0 if index == LEGEND_INDEX else pity + 1
	return {"rarities": out, "pity": pity}


static func _roll_index(min_index: int) -> int:
	var total := 0.0
	for i in range(min_index, RARITIES.size()):
		total += float(RARITIES[i]["weight"])
	var value := randf() * total
	for i in range(min_index, RARITIES.size()):
		value -= float(RARITIES[i]["weight"])
		if value <= 0.0:
			return i
	return RARITIES.size() - 1
