class_name GachaDefs
extends RefCounted

const COST := 30.0
const RARE_INDEX := 2
const EPIC_INDEX := 3       # 고급 소환권의 바닥 등급
const LEGEND_INDEX := 4
# unlock = 이 등급이 나오기 시작하는 소환 레벨.
# **처음부터 전설·신화가 나오면 레벨을 올릴 이유가 없다.** 방치형에서 뽑기 레벨의
# 본체는 확률이 조금 오르는 게 아니라 **새 등급 칸이 열리는 것**이다.
# 전설 2레벨(누적 100회) · 신화 5레벨(누적 1000회).
# 전설이 100회인 건 100연 천장과 같은 지점이다 — 천장이 처음 터지는 그 뽑기에서
# 마침 열린다. 신화는 만렙(4500회)의 한참 앞에 둬서 만렙 전에도 목표가 남게 했다.
const RARITIES := [
	{"key": "common", "name": "커먼", "power": 1.0, "weight": 50.0, "unlock": 0,
		"col": Color(0.72, 0.72, 0.76)},
	{"key": "uncommon", "name": "언커먼", "power": 1.35, "weight": 30.0, "unlock": 0,
		"col": Color(0.42, 0.82, 0.55)},
	{"key": "rare", "name": "레어", "power": 1.8, "weight": 14.0, "unlock": 0,
		"col": Color(0.45, 0.62, 1.0)},
	{"key": "epic", "name": "에픽", "power": 3.2, "weight": 5.0, "unlock": 0,
		"col": Color(0.72, 0.45, 0.95)},
	{"key": "legend", "name": "레전더리", "power": 5.5, "weight": 0.9, "unlock": 2,
		"col": Color(1.0, 0.62, 0.22)},
	{"key": "mythic", "name": "신화", "power": 9.0, "weight": 0.1, "unlock": 5,
		"col": Color(1.0, 0.28, 0.38)},
]


static func unlocked(index: int, lv: int) -> bool:
	return lv >= int(RARITIES[index].get("unlock", 0))


# 이 레벨에서 나올 수 있는 가장 높은 등급.
static func top_unlocked(lv: int) -> int:
	var top := 0
	for i in RARITIES.size():
		if unlocked(i, lv):
			top = i
	return top


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


# ── 소환 레벨 ──────────────────────────────────────────────────────────────
# 뽑을수록 오르고, 오를수록 상위 등급 확률이 붙는다. 종류마다 따로 쌓인다.
#
# **천장과 역할이 다르다.** 천장은 "운이 나빠도 언젠가는"이고 레벨은 "오래 한 만큼
# 계속". 천장만 있으면 100연을 채우는 순간 기대치가 0으로 되돌아가서, 길게 보면
# 1000번 뽑은 사람과 처음 뽑는 사람의 한 번이 똑같다. 그래서 둘 다 둔다.
# 보석은 결국 유료·희소 재화라 1000회 뽑기를 전제로 만렙을 잡으면 아무도 못 간다.
# **만렙 10 / 200회**로 압축하되, 만렙에서의 효과(레어 이상 2.5배)는 그대로 뒀다 —
# 사다리를 짧게 만든 것이지 보상을 깎은 게 아니다.
# 레벨업에 드는 소환 횟수는 **레벨마다 늘어난다** — L레벨에서 L+1레벨로 가는 데 100L회.
#   1→2 100회(누적 100) · 2→3 200회(300) · 5레벨(1000) · 10레벨(4500)
# 고정 간격이면 초반이 지루하고 후반이 싱겁다. 앞은 금방 오르고 뒤는 무거워야
# "다음 레벨"이 계속 목표로 남는다.
#
# **시작이 0레벨이 아니라 1레벨이다.** 0레벨은 "아직 아무것도 아님"으로 읽히는데
# 소환은 처음부터 돌아간다.
const LEVEL_BASE := 100       # L -> L+1 에 LEVEL_BASE x L 회
const LEVEL_MIN := 1
const LEVEL_MAX := 10         # 누적 4500회
# 만렙에서 레어 이상 가중치가 몇 배가 되는가. 레벨당 증가폭은 여기서 역산한다 —
# 레벨 수를 바꿔도 끝점이 안 흔들린다.
const LEVEL_TOP_MULT := 2.5


# lv 레벨에 도달하는 데 필요한 **누적** 소환 횟수. 1레벨은 0.
static func level_total(lv: int) -> int:
	var n := clampi(lv, LEVEL_MIN, LEVEL_MAX)
	return LEVEL_BASE * (n - 1) * n / 2


static func level(pulls: int) -> int:
	var lv := LEVEL_MIN
	while lv < LEVEL_MAX and maxi(0, pulls) >= level_total(lv + 1):
		lv += 1
	return lv


# 레벨이 붙는 배수. 1레벨은 정확히 1.0 이어야 공개 확률표가 그대로 성립한다.
static func level_mult(lv: int) -> float:
	var span := float(maxi(1, LEVEL_MAX - LEVEL_MIN))
	return 1.0 + (LEVEL_TOP_MULT - 1.0) \
		* float(clampi(lv, LEVEL_MIN, LEVEL_MAX) - LEVEL_MIN) / span


# 다음 레벨까지 남은 횟수. 만렙이면 0.
static func level_next_need(pulls: int) -> int:
	var lv := level(pulls)
	if lv >= LEVEL_MAX:
		return 0
	return level_total(lv + 1) - maxi(0, pulls)


# 레벨이 반영된 실제 가중치. **레어 이상만** 키운다 —
# 전부 같은 비율로 키우면 정규화 후에 아무것도 안 바뀐다.
# skill_pool: 스킬 소환인가. 스킬은 **커먼~레전더리 5단계**다(형태 4 x 등급 5 = 20종).
# 신화가 없으므로 그 위는 굴리지 않는다 — 가중치를 0으로 두면 아래 정규화가
# 나머지 5등급에 **비율 그대로** 나눠 준다. 특수 분기가 필요 없다.
#
# 최고 등급을 상수로 두는 이유: 나중에 스킬에 신화를 추가하면 이 한 줄만 바꾼다.
const SKILL_TOP_INDEX := LEGEND_INDEX


static func weights(lv: int, skill_pool := false) -> Array[float]:
	var out: Array[float] = []
	for i in RARITIES.size():
		if not unlocked(i, lv) or (skill_pool and i > SKILL_TOP_INDEX):
			out.append(0.0)      # 안 열린 등급·스킬에 없는 등급은 아예 안 굴린다
			continue
		var w := float(RARITIES[i]["weight"])
		if i >= RARE_INDEX:
			w *= level_mult(lv)
		out.append(w)
	return out


# 화면에 적는 백분율. 표시와 실제 굴림이 **같은 함수**를 지나야 거짓말이 안 된다.
static func rates(lv: int, skill_pool := false) -> Array[float]:
	var w := weights(lv, skill_pool)
	var total := 0.0
	for v in w:
		total += v
	var out: Array[float] = []
	for v in w:
		out.append(v / maxf(0.001, total) * 100.0)
	return out


# 반환 pity는 다음 뽑기 전에 쌓여 있는 횟수다. 99면 이번 한 번이 전설이다.
# floor_index: 이 등급 아래는 안 나온다. 고급 소환권(에픽 확정)이 쓰는 길이고,
# **확률표는 안 건드린다** — 바닥 위쪽 무게로만 다시 굴린다(10연 레어 확정과 같은
# 기전). 표를 손대면 천장·기댓값 계산이 전부 다시다.
static func pull(count: int, pity: int, lv := 0, skill_pool := false,
		floor_index := 0) -> Dictionary:
	var out: Array[String] = []
	var has_rare := false
	# 천장이 찼는데 전설이 아직 안 열렸으면 **터뜨리지 않고 계속 쌓는다.**
	# 열린 순간 바로 터져서, 잠긴 동안 뽑은 게 헛되지 않는다.
	var pity_ready := unlocked(LEGEND_INDEX, lv)
	for i in count:
		var min_index := maxi(floor_index,
			RARE_INDEX if count == 10 and i == 9 and not has_rare else 0)
		var index := LEGEND_INDEX if (pity >= 99 and pity_ready) \
			else _roll_index(min_index, lv, skill_pool)
		out.append(str(RARITIES[index]["key"]))
		has_rare = has_rare or index >= RARE_INDEX
		pity = 0 if index == LEGEND_INDEX else pity + 1
	return {"rarities": out, "pity": pity}


static func _roll_index(min_index: int, lv: int, skill_pool := false) -> int:
	var w := weights(lv, skill_pool)
	var total := 0.0
	for i in range(min_index, RARITIES.size()):
		total += w[i]
	var value := randf() * total
	for i in range(min_index, RARITIES.size()):
		value -= w[i]
		if value <= 0.0:
			return i
	# 부동소수 오차로 여기까지 오면 **열린 것 중** 가장 높은 등급이다.
	# 그냥 마지막 칸을 돌려주면 잠긴 신화가 나온다.
	return top_unlocked(lv)
