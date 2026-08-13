class_name RelicDefs

# 유물 — **후반의 곱연산 축** (MONETIZATION_PLAN 9-6 의 간극을 메우는 자리).
#
# 왜 필요한가: 요구는 지수인데 스탯 성장은 합연산이라 뒤로 갈수록 반드시
# 평평해진다(실측: 30일 -> 90일 1.35배, 목표 2배). 곱연산이 하나(혈맥 x1.26)뿐이라
# 후반에 밀 힘이 없었다. 유물이 그 몫을 진다.
#
# **예산 원칙을 고친다**: "곱연산은 혈맥 전담"이던 것을 **혈맥 + 유물 둘**로 나눈다
# (EXPANSION 8장). 혈맥은 꾸준히 크는 축(혈정 소탕), 유물은 뽑기로 띄엄띄엄 크는
# 축이라 성격이 달라 겹치지 않는다.
#
# 획득은 **소환**이다 (사장님 2026-08-13). 보스 드랍도 후보였지만 소환이 낫다:
# 화면이 이미 있어 배울 게 없고, 소환권·보석이 그대로 유물 수요가 되어 상점·과금과
# 한 줄로 이어진다. 보스는 이미 정수를 주므로 잡을 이유가 따로 있다.
#
# 아이콘은 assets/items/relic_*.png 12종이 이미 들어와 있다 — 새로 뽑지 않는다.
const OPEN_STAGE := 100     # 후반 축이라 중반에 연다
const MAX_LV := 5           # 조각으로 올린다
const SHARDS_PER_LV := 5    # 중복 5개 = 1레벨 (소환 장비와 같은 문법)

# 등급은 뽑기 무게를 GachaDefs 와 공유한다 — 유물마다 고정 등급이고, 굴린 등급
# 안에서 하나를 고른다(_receive_gacha_relic). 표시 이름은 우리 세계관으로 갈았다:
# 아이콘은 다른 프로젝트에서 온 자산이라 원래 이름을 그대로 쓰면 남의 게임이 된다.
#
# value 는 **만렙 기준 총량**이고 레벨당 1/5 씩 붙는다(혈맥과 같은 규칙).
# 공격 계열이 넷인 이유: 메우려는 간극이 공격력 쪽이다.
# 18종 (전설 3 · 에픽 6 · 레어 9).
const RELICS := [
	{"id": "abyss_eye", "name": "심연의 눈", "rarity": "legend",
		"kind": "damage", "value": 0.25, "icon": "relic_abyss_eye"},
	{"id": "yellow_sign", "name": "노란 표식", "rarity": "legend",
		"kind": "critdmg", "value": 0.25, "icon": "relic_yellow_sign"},
	{"id": "hungry_heart", "name": "굶주린 심장", "rarity": "epic",
		"kind": "damage", "value": 0.15, "icon": "relic_hungry_heart"},
	{"id": "great_gospel", "name": "피의 금서", "rarity": "epic",
		"kind": "damage", "value": 0.15, "icon": "relic_great_gospel"},
	{"id": "metaglio", "name": "봉인의 방패", "rarity": "epic",
		"kind": "hp", "value": 0.15, "icon": "relic_metaglio"},
	{"id": "soul_lantern", "name": "영혼 등불", "rarity": "epic",
		"kind": "hours", "value": 3.0, "icon": "relic_soul_lantern"},
	{"id": "black_chalice", "name": "검은 성배", "rarity": "rare",
		"kind": "damage", "value": 0.10, "icon": "relic_black_chalice"},
	{"id": "fallen_halo", "name": "타락한 후광", "rarity": "rare",
		"kind": "hp", "value": 0.10, "icon": "relic_fallen_halo"},
	{"id": "golden_mask", "name": "황금 가면", "rarity": "rare",
		"kind": "gold", "value": 0.10, "icon": "relic_golden_mask"},
	{"id": "silver_ring", "name": "은빛 반지", "rarity": "rare",
		"kind": "gold", "value": 0.10, "icon": "relic_silver_ring"},
	{"id": "witch_tear", "name": "마녀의 눈물", "rarity": "rare",
		"kind": "speed", "value": 0.10, "icon": "relic_witch_tear"},
	{"id": "milky_map", "name": "별의 지도", "rarity": "rare",
		"kind": "sweep", "value": 0.10, "icon": "relic_milky_map"},
	# 2026-08-13 추가분 6종 (사장님: "유물 종류 몇 개 더"). 아이콘은 새로 뽑았다 —
	# 앞의 12종과 달리 이건 우리 것이라 이름과 그림이 처음부터 맞는다.
	# 공격 계열을 둘만 더한 이유: 넷이 이미 x1.82 라, 더 얹으면 곱연산 예산
	# (RelicCheck 이 지키는 1.5~2.5)을 넘어 혈맥 몫까지 먹는다.
	{"id": "broken_crown", "name": "부러진 왕관", "rarity": "legend",
		"kind": "damage", "value": 0.20, "icon": "relic_broken_crown"},
	{"id": "heart_stone", "name": "굳은 심장석", "rarity": "epic",
		"kind": "hp", "value": 0.15, "icon": "relic_heart_stone"},
	{"id": "blood_hourglass", "name": "피의 모래시계", "rarity": "epic",
		"kind": "hours", "value": 2.0, "icon": "relic_blood_hourglass"},
	{"id": "raven_feather", "name": "갈까마귀 깃", "rarity": "rare",
		"kind": "speed", "value": 0.08, "icon": "relic_raven_feather"},
	{"id": "green_candle", "name": "푸른 촛대", "rarity": "rare",
		"kind": "critdmg", "value": 0.12, "icon": "relic_green_candle"},
	{"id": "sealed_coffin", "name": "봉인된 관", "rarity": "rare",
		"kind": "damage", "value": 0.08, "icon": "relic_sealed_coffin"},
]


static func of(id: String) -> Dictionary:
	for r in RELICS:
		if str(r["id"]) == id:
			return r
	return {}


static func icon_path(r: Dictionary) -> String:
	return "res://assets/items/%s.png" % str(r.get("icon", ""))


# 그 등급의 유물들. 뽑기가 등급을 굴린 뒤 이 안에서 하나를 고른다.
static func of_rarity(rarity: String) -> Array:
	var out: Array = []
	for r in RELICS:
		if str(r["rarity"]) == rarity:
			out.append(r)
	return out


# 곱배수 갈래 (damage·hp·critdmg·speed·gold·sweep). hours 는 합산이라 따로 본다.
static func mult(kind: String, owned: Dictionary) -> float:
	var out := 1.0
	for r in RELICS:
		if str(r["kind"]) != kind:
			continue
		var lv := level_of(str(r["id"]), owned)
		if lv <= 0:
			continue
		out *= 1.0 + float(r["value"]) * float(lv) / float(MAX_LV)
	return out


# 합산 갈래 (hours: 방치 상한 시간).
static func add(kind: String, owned: Dictionary) -> float:
	var out := 0.0
	for r in RELICS:
		if str(r["kind"]) != kind:
			continue
		var lv := level_of(str(r["id"]), owned)
		out += float(r["value"]) * float(lv) / float(MAX_LV)
	return out


static func level_of(id: String, owned: Dictionary) -> int:
	return clampi(int(owned.get(id, 0)), 0, MAX_LV)


static func effect_text(r: Dictionary, lv: int) -> String:
	var v := float(r["value"]) * float(maxi(lv, 1)) / float(MAX_LV)
	# **짧게 쓴다.** 유물 칸이 좁아서 "치명타 피해 +5%"는 잘린다(실측) —
	# 그 자리에서 긴 이름은 정보가 아니라 잘린 글자다.
	match str(r["kind"]):
		"damage": return "공격 +%d%%" % int(v * 100.0)
		"hp": return "체력 +%d%%" % int(v * 100.0)
		"critdmg": return "치명피해 +%d%%" % int(v * 100.0)
		"speed": return "공속 +%d%%" % int(v * 100.0)
		"gold": return "흡혈 +%d%%" % int(v * 100.0)
		"sweep": return "소탕 +%d%%" % int(v * 100.0)
		"hours": return "방치 +%.1f시간" % v
	return ""
