class_name SkinDefs

# 의상실 — 얼굴만 같고 옷·무기가 통째로 바뀌는 스킨 (사장님 2026-08-24,
# 레퍼런스: 타 방치형의 의상실 문법). 그림은 assets/anim/<id>_<motion>/ 에
# 산다 — Main 의 영웅 모션 경로가 skin 접두 하나로 갈리므로 표에 줄을
# 추가하고 그림만 깔면 스킨이 늘어난다.
#
# 보유 효과는 **산 것 전부 합산**이다 — 갈아입어도 효과는 남으니 치장이
# 수집이 된다(레퍼런스의 "보유효과" 문법 그대로).
const SKINS := [
	{"id": "valentino_1", "name": "기본 의상", "price": 0,
		"bonus": {}, "desc": "군주의 평상복"},
	{"id": "demon_king", "name": "마왕의 위엄", "price": 1200,
		"bonus": {"attack": 0.10}, "desc": "보유 시 공격 +10%"},
	{"id": "shadow", "name": "그림자 자객", "price": 1200,
		"bonus": {"attack": 0.05, "tough": 0.05},
		"desc": "보유 시 공격 +5% · 체력 +5%"},
	{"id": "dragon", "name": "용기사의 갑주", "price": 1200,
		"bonus": {"tough": 0.10}, "desc": "보유 시 체력 +10%"},
	{"id": "emperor", "name": "암흑 황제", "price": 1200,
		"bonus": {"gold": 0.10}, "desc": "보유 시 혈액 +10%"},
	{"id": "grim", "name": "사신 대군주", "price": 1200,
		"bonus": {"attack": 0.10}, "desc": "보유 시 공격 +10%"},
]


static func of(id: String) -> Dictionary:
	for x in SKINS:
		if str(x["id"]) == id:
			return x
	return {}


# 산 스킨들의 보유 효과 합. 기본 의상은 효과가 없어서 안 세도 같다.
static func bonus(stat: String, owned: Dictionary) -> float:
	var v := 0.0
	for x in SKINS:
		if owned.has(str(x["id"])):
			v += float(x["bonus"].get(stat, 0.0))
	return v
