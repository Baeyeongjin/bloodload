class_name TraitDefs
extends RefCounted
# =====================================================================
#  혈맥 — 특성 트리 (EXPANSION 3장, 3단계)
#
#  2층 성장 축: **유한·곱연산·혈정.** 곱연산 %는 게임 전체에서 여기에만 산다 —
#  공격력 스탯은 이 축이 생기면서 합연산으로 돌아갔고(Balance 주석), 군림(4단계)은
#  기능만 연다. 이 분담이 깨지면 EXPANSION 8장의 예산표가 무효다.
#
#  잠금 두 겹(참고작의 엇갈린 잠금):
#    가지 = 미궁 층(10/30/60)  ·  티어 = 영웅 레벨(10~140)
#  그래서 혈맥을 올리려면 미궁을 오르고, 미궁을 오르려면 본편을 밀게 된다.
# =====================================================================

# 노드는 가지당 6개, 티어 순서대로만 찍는다(t 는 t-1 보유가 선행).
# kind 가 효과의 갈래다 — Main 이 `TraitDefs.mult / add` 로 읽는다:
#   attack/hp/regen/gold/sweep/skill  곱배수 Π(1+v)
#   guard                             경감   Π(1-v)
#   critdmg                           치명 피해 배수에 합산 (+v)
#   hours                             오프라인 상한에 합산 (+v 시간)
const NODES := [
	# ── 살육 (공격, 미궁 10층) — 완주 시 공격 계열 ≈ x2.0 ────────────────────
	{"id": "attack_1", "branch": "attack", "tier": 1, "kind": "attack",
		"value": 0.08, "name": "핏빛 격노 I"},
	{"id": "attack_2", "branch": "attack", "tier": 2, "kind": "attack",
		"value": 0.08, "name": "핏빛 격노 II"},
	{"id": "attack_3", "branch": "attack", "tier": 3, "kind": "attack",
		"value": 0.08, "name": "핏빛 격노 III"},
	{"id": "attack_4", "branch": "attack", "tier": 4, "kind": "critdmg",
		"value": 0.15, "name": "사혈 I"},
	{"id": "attack_5", "branch": "attack", "tier": 5, "kind": "critdmg",
		"value": 0.15, "name": "사혈 II"},
	{"id": "attack_6", "branch": "attack", "tier": 6, "kind": "skill",
		"value": 0.12, "name": "피의 각성"},
	# ── 불사 (생존, 미궁 30층) ──────────────────────────────────────────────
	{"id": "life_1", "branch": "life", "tier": 1, "kind": "hp",
		"value": 0.10, "name": "굳은 피 I"},
	{"id": "life_2", "branch": "life", "tier": 2, "kind": "hp",
		"value": 0.10, "name": "굳은 피 II"},
	{"id": "life_3", "branch": "life", "tier": 3, "kind": "hp",
		"value": 0.10, "name": "굳은 피 III"},
	{"id": "life_4", "branch": "life", "tier": 4, "kind": "regen",
		"value": 0.10, "name": "재생 I"},
	{"id": "life_5", "branch": "life", "tier": 5, "kind": "regen",
		"value": 0.10, "name": "재생 II"},
	{"id": "life_6", "branch": "life", "tier": 6, "kind": "guard",
		"value": 0.06, "name": "불사의 살갗"},
	# ── 탐욕 (재화, 미궁 60층) ──────────────────────────────────────────────
	{"id": "wealth_1", "branch": "wealth", "tier": 1, "kind": "gold",
		"value": 0.10, "name": "갈증 I"},
	{"id": "wealth_2", "branch": "wealth", "tier": 2, "kind": "gold",
		"value": 0.10, "name": "갈증 II"},
	{"id": "wealth_3", "branch": "wealth", "tier": 3, "kind": "gold",
		"value": 0.10, "name": "갈증 III"},
	{"id": "wealth_4", "branch": "wealth", "tier": 4, "kind": "hours",
		"value": 2.0, "name": "긴 잠 I"},
	{"id": "wealth_5", "branch": "wealth", "tier": 5, "kind": "hours",
		"value": 2.0, "name": "긴 잠 II"},
	{"id": "wealth_6", "branch": "wealth", "tier": 6, "kind": "sweep",
		"value": 0.12, "name": "혈정 감식"},
]

const BRANCHES := ["attack", "life", "wealth"]
const BRANCH_NAMES := {"attack": "살육", "life": "불사", "wealth": "탐욕"}
# 가지를 여는 미궁 층 (EXPANSION 7장의 교차 잠금).
const BRANCH_FLOOR := {"attack": 10, "life": 30, "wealth": 60}
# 티어를 여는 영웅 레벨.
const HERO_GATE := [10, 25, 45, 70, 100, 140]

# 노드 비용(혈정). 티어마다 x1.8 — 전체 18노드 합 ≈ 74,190 으로,
# 미궁 100층 첫 돌파 누적(50,500)의 약 1.5배다(EXPANSION 6장: 첫 돌파로 절반,
# 나머지는 소탕 며칠).
const COST := [600.0, 1080.0, 1950.0, 3500.0, 6300.0, 11340.0]


static func node(id: String) -> Dictionary:
	for n in NODES:
		if str(n["id"]) == id:
			return n
	return {}


static func nodes_of(branch: String) -> Array:
	var out: Array = []
	for n in NODES:
		if str(n["branch"]) == branch:
			out.append(n)
	return out


static func cost(tier: int) -> float:
	return COST[clampi(tier - 1, 0, COST.size() - 1)]


static func hero_gate(tier: int) -> int:
	return HERO_GATE[clampi(tier - 1, 0, HERO_GATE.size() - 1)]


static func branch_floor(branch: String) -> int:
	return int(BRANCH_FLOOR.get(branch, 9999))


# 곱배수 갈래. guard 는 (1-v)를 곱해 "받는 피해 경감"이 된다.
static func mult(kind: String, owned: Dictionary) -> float:
	var out := 1.0
	for n in NODES:
		if str(n["kind"]) != kind or not owned.has(str(n["id"])):
			continue
		out *= (1.0 - float(n["value"])) if kind == "guard" \
			else (1.0 + float(n["value"]))
	return out


# 합산 갈래 (critdmg: 치명 피해 배수에 더함 · hours: 오프라인 상한 시간).
static func add(kind: String, owned: Dictionary) -> float:
	var out := 0.0
	for n in NODES:
		if str(n["kind"]) == kind and owned.has(str(n["id"])):
			out += float(n["value"])
	return out


# 이 노드를 지금 살 수 있는가 — 이유를 문자열로 돌려준다("" = 가능).
# UI 가 버튼에 그대로 적는다: 왜 안 되는지가 안 보이면 잠긴 축은 없는 축이다.
static func lock_reason(id: String, owned: Dictionary, hero_lv: int,
		dungeon_best: int) -> String:
	var n := node(id)
	if n.is_empty():
		return "없는 노드"
	if owned.has(id):
		return "보유"
	var need_floor := branch_floor(str(n["branch"]))
	if dungeon_best < need_floor:
		return "미궁 %d층" % need_floor
	var tier := int(n["tier"])
	if tier > 1 and not owned.has("%s_%d" % [str(n["branch"]), tier - 1]):
		return "앞 노드"
	if hero_lv < hero_gate(tier):
		return "Lv%d" % hero_gate(tier)
	return ""
