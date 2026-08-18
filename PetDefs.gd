class_name PetDefs

# 펫 — **자원을 물어오고, 데리고 다니면 힘이 붙는다** (docs/PET_DESIGN.md).
#
# 왜 이 둘을 같이 하나:
#
# 1. **짧은 시계가 없었다.** 방치 8시간 · 일일 24시간 · 주간 7일뿐이라 하루 한
#    번 들어와 다 처리하면 그날 할 게 없다. 펫은 상한이 차면 멈추므로 **한 번
#    더 들를 이유**가 된다(업계 공통 문법: 주기가 다른 시계를 섞는다).
#
# 2. **성장이 눈에 안 보였다.** 장비를 아무리 껴도 캐릭터 그림이 그대로다.
#    스킨으로 풀려다 접었는데(108장 문제), 펫은 **몸에 안 붙어서** 모션과
#    무관하다 — 그래서 자산도 몹 스프라이트를 그대로 쓴다.
#
# 물어오는 재화는 **방치 상자와 겹치지 않게** 골랐다. 상자가 혈액이므로 펫은
# 혈정·정수·인장 쪽이다 — 같은 걸 주면 방치 상자의 값이 깎인다.

# 상한이 차면 멈춘다. 이 값이 "한 번 더 들를 이유"의 크기다 — 짧으면 숙제가
# 되고, 길면 하루 한 번으로 충분해져 짧은 시계라는 목적이 사라진다.
const CAP_HOURS := 6.0

const PETS := [
	{"id": "bat", "name": "핏빛 박쥐", "anim": "bat", "open": 10,
		"gain": "crystal", "per_hour": 18.0, "stat": "damage", "value": 0.04,
		"desc": "동굴에서 따라왔다. 피 냄새를 먼저 맡는다."},
	{"id": "wisp", "name": "서리 불씨", "anim": "ice_wisp", "open": 40,
		"gain": "crystal", "per_hour": 40.0, "stat": "speed", "value": 0.05,
		"desc": "얼음 위에서만 켜진다. 손을 대면 차갑다."},
	{"id": "imp", "name": "잿불 임프", "anim": "fire_imp", "open": 80,
		"gain": "essence", "per_hour": 12.0, "stat": "damage", "value": 0.07,
		"desc": "불을 훔쳐 먹고 산다. 자주 말썽을 부린다."},
	{"id": "spider", "name": "서리 거미", "anim": "frost_spider", "open": 130,
		"gain": "sigil", "per_hour": 8.0, "stat": "gold", "value": 0.08,
		"desc": "그물에 걸린 것을 제 것으로 안다."},
	{"id": "slime", "name": "굳은 점액", "anim": "slime", "open": 200,
		"gain": "essence", "per_hour": 26.0, "stat": "tough", "value": 0.10,
		"desc": "무엇이든 삼키고 아무것도 소화하지 않는다."},
	{"id": "wraith", "name": "공허 망령", "anim": "void_wraith", "open": 300,
		"gain": "sigil", "per_hour": 20.0, "stat": "damage", "value": 0.12,
		"desc": "이름을 잊은 자리에 생긴다. 뒤를 자꾸 돌아본다."},
]


static func of(id: String) -> Dictionary:
	for p in PETS:
		if str(p["id"]) == id:
			return p
	return {}


static func unlocked(id: String, best_stage: int) -> bool:
	var p := of(id)
	return not p.is_empty() and best_stage >= int(p["open"])


# 상한. 펫마다 시급이 달라 상한도 따라 다르다 — 시간으로 재야 "여섯 시간마다
# 들르면 된다"가 모든 펫에서 같은 말이 된다.
static func cap(id: String) -> float:
	var p := of(id)
	return 0.0 if p.is_empty() else float(p["per_hour"]) * CAP_HOURS


# hours 만큼 지났을 때 쌓이는 양. 이미 있던 것에 더하고 상한에서 자른다.
static func accrue(id: String, have: float, hours: float) -> float:
	var p := of(id)
	if p.is_empty() or hours <= 0.0:
		return have
	return minf(cap(id), have + float(p["per_hour"]) * hours)


# 장착한 펫이 그 능력치에 주는 몫. 안 데리고 다니면 0 이다 —
# **가진 것 전부가 아니라 장착한 하나만** 준다(그래야 고를 이유가 생긴다).
static func bonus(worn: String, stat: String) -> float:
	var p := of(worn)
	if p.is_empty() or str(p["stat"]) != stat:
		return 0.0
	return float(p["value"])


static func icon_dir(id: String) -> String:
	var p := of(id)
	return "" if p.is_empty() else "res://assets/anim/%s_walk" % str(p["anim"])
