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
	# ── 탐욕 (재화) ────────────────────────────────────────────────────────
	# **순서를 뒤집었다** (2026-08-26). 값은 하나도 안 바꿨다 — 어느 효과가 몇
	# 티어에 앉느냐만 바꿨으므로 총액(222,930)도 완주 배수도 그대로다.
	# 고친 것 둘:
	#   1. 혈정 감식(소탕 +12%)이 **마지막 노드**였다. 줄기가 한 줄이라 마지막은
	#      18번째 — 혈정을 더 벌게 해 주는 유일한 노드가 **혈정을 다 쓴 뒤에**
	#      켜졌다. 이제 첫 노드다: 나머지 열일곱 노드의 값을 이 노드가 번다.
	#   2. 긴 잠 I·II(방치 +4시간)는 **300구간을 넘으면 죽는다.**
	#      _offline_cap_hours = min(16, 8 + 혈맥4 + 군림IV 4 + …) 인데 군림 IV 가
	#      300구간에 열리므로 8+4+4 가 정확히 상한 16 이다(유물·혈세는 그 위로).
	#      죽을 노드를 비싼 티어(1,050·1,890)에 두면 값만 받고 아무것도 안 준다 —
	#      살아 있는 동안 값이 싼 2·3티어(324·585)로 내렸다.
	#   3. 잔혹(치명 피해)은 상한이 없다(Balance.crit_mult 는 안 끊는다). 끝까지
	#      값하는 유일한 갈래라 비싼 뒤 티어를 준다.
	{"id": "wealth_1", "branch": "wealth", "tier": 1, "kind": "sweep",
		"value": 0.12, "name": "혈정 감식"},
	{"id": "wealth_2", "branch": "wealth", "tier": 2, "kind": "hours",
		"value": 2.0, "name": "긴 잠 I"},
	{"id": "wealth_3", "branch": "wealth", "tier": 3, "kind": "hours",
		"value": 2.0, "name": "긴 잠 II"},
	{"id": "wealth_4", "branch": "wealth", "tier": 4, "kind": "critdmg",
		"value": 0.10, "name": "잔혹 I"},
	{"id": "wealth_5", "branch": "wealth", "tier": 5, "kind": "critdmg",
		"value": 0.10, "name": "잔혹 II"},
	{"id": "wealth_6", "branch": "wealth", "tier": 6, "kind": "critdmg",
		"value": 0.10, "name": "잔혹 III"},
]

const BRANCHES := ["attack", "life", "wealth"]
const BRANCH_NAMES := {"attack": "살육", "life": "불사", "wealth": "탐욕"}

# **노드마다 10레벨** (2026-08-12 사장님: "미궁 클리어로 재화를 얻고, 재화로
# 노드를 해금하고, 제일 밑 노드를 10레벨 찍으면 위 노드가 열린다").
#
# 바뀐 것: 잠금이 **앞 노드 만렙 하나**다. 미궁 층(10/30/60)과 영웅 레벨 문턱은
# 뺐다 — 미궁은 이제 **혈정을 주는 곳**이지 잠그는 곳이 아니고(첫 돌파 + 소탕),
# 문턱이 셋이면 왜 안 열리는지 매번 다시 읽어야 한다.
#
# 표의 `value` 는 **만렙(10레벨) 기준 총량**이다 — 레벨당은 그 1/10. 이렇게
# 잡아야 EXPANSION 8장 예산표(혈맥 완주 공격 x1.26)가 그대로 산다.
const MAX_LV := 10

# 노드 비용(혈정)은 **레벨 하나당** 값이다. 티어마다 x1.8.
#
# 총액을 **3배로 올렸다**: 1/10 로 나눠 담기만 하면 총량이 그대로라 "같은 걸
# 열 번에 나눠 사는 것"일 뿐이다. 게다가 미궁 층 문턱을 뺀 지금 **혈정이
# 유일한 문턱**이라 값이 곧 속도다. 18노드 전부 만렙 = 222,930 으로 미궁
# 100층 첫 돌파 누적(50,500)의 약 4.4배 — 첫 돌파로 1/4, 나머지는 소탕이
# 도는 몇 주다.
const COST := [180.0, 324.0, 585.0, 1050.0, 1890.0, 3402.0]


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


# **한 줄기 순서** (사장님: "한 줄기에서 나가도록"). 티어를 돌며 세 가지를
# 번갈아 오른다: 살육1 -> 불사1 -> 탐욕1 -> 살육2 -> ... 화면의 덩굴이 곧
# 이 순서고, 잠금도 이 순서의 **바로 앞 노드 만렙** 하나다.
static func order() -> Array:
	var out: Array = []
	for t in range(1, 7):
		for b in BRANCHES:
			out.append("%s_%d" % [b, t])
	return out


# 줄기에서 바로 앞 노드. 첫 노드면 "".
static func prev_id(id: String) -> String:
	var seq := order()
	var i := seq.find(id)
	return "" if i <= 0 else str(seq[i - 1])


# 지금 레벨 (없으면 0). 옛 저장본은 `true` 로 적혀 있으므로 만렙으로 읽는다.
# ── 제련 (2026-09-02 사장님 픽) — 혈정 후반 싱크 ───────────────────────────
# **만렙 노드를 되태워, 시간을 들여 유물 조각 하나로 굽는다.** 노드는 0 으로
# 돌아가고, 다시 사려면 혈정이 또 든다 — 그게 무한 싱크의 정체다.
#
# 왜 이게 필요한가: 혈맥 완주 총액은 222,930 으로 **유한**한데 혈정 수입은
# 무한이다(미궁 소탕 + 펫 둥지 + 상점). HANDOFF 의 "완주 133~368일"은 펫 둥지를
# 뺀 소탕 전용 모델이라 실제와 열 배 다르다 — 펫을 넣으면 후반 하루 12,135,
# 완주 18.4일이다. 다 찍고 나면 혈정이 죽은 재화가 된다.
#
# 왜 이 모양이어야 하는가:
#   - **곱연산 예산을 안 건드린다.** 혈맥의 % 를 **덜어서** 유물의 % 로 옮기는
#     것이라 두 축의 합이 안 늘고, 굽는 동안은 오히려 마이너스다
#     (EXPANSION 2장 · RelicDefs 머리글의 "곱연산은 혈맥 + 유물 둘").
#   - **숫자가 아니라 규칙이 바뀐다.** "혈맥은 다 찍으면 끝인 유한 축"이라는
#     성질 자체가 없어지고 재구성 가능한 축이 된다.
#   - **새 시계를 안 만든다.** 굽는 시간은 펫 원정(PetDefs.TRIP_HOURS)이 이미
#     쓰는 동사를 그대로 빌린다.
#
# **줄기의 맨 위부터만 태운다.** 중간 티어를 태우면 그 위가 전부 잠긴 채로 남아
# ("앞 노드 만렙"이 문턱이라) 무엇이 왜 안 열리는지 알 수 없게 된다.
static func bake_hours(tier: int) -> float:
	if tier >= 6:
		return 16.0
	if tier >= 5:
		return 12.0
	if tier >= 3:
		return 8.0
	return 4.0


# 굽는 등급 — 티어가 정한다. **전설은 t6 에서만** 나와야 유물의 "뽑기로
# 띄엄띄엄 크는 축"이라는 성격이 안 죽는다(RelicDefs 머리글).
static func bake_rarity(tier: int) -> String:
	if tier >= 6:
		return "legend"
	if tier >= 4:
		return "epic"
	return "rare"


# 태울 수 있는가 — 만렙이면서, 같은 줄기의 **위쪽이 전부 비어 있어야** 한다.
static func can_bake(id: String, owned: Dictionary) -> bool:
	var n := node(id)
	if n.is_empty() or level_of(id, owned) < MAX_LV:
		return false
	for m in NODES:
		if str(m["branch"]) == str(n["branch"]) \
				and int(m["tier"]) > int(n["tier"]) \
				and level_of(str(m["id"]), owned) > 0:
			return false
	return true


static func level_of(id: String, owned: Dictionary) -> int:
	var v = owned.get(id, 0)
	if typeof(v) == TYPE_BOOL:
		return MAX_LV if v else 0
	return clampi(int(v), 0, MAX_LV)


# 곱배수 갈래. guard 는 (1-v)를 곱해 "받는 피해 경감"이 된다.
static func mult(kind: String, owned: Dictionary) -> float:
	var out := 1.0
	for n in NODES:
		if str(n["kind"]) != kind:
			continue
		var lv := level_of(str(n["id"]), owned)
		if lv <= 0:
			continue
		# 레벨당 value/10 — 표의 값은 만렙 기준 총량이다.
		var v := float(n["value"]) * float(lv) / float(MAX_LV)
		out *= (1.0 - v) if kind == "guard" else (1.0 + v)
	return out


# 합산 갈래 (critdmg: 치명 피해 배수에 더함 · hours: 오프라인 상한 시간).
static func add(kind: String, owned: Dictionary) -> float:
	var out := 0.0
	for n in NODES:
		if str(n["kind"]) != kind:
			continue
		out += float(n["value"]) * float(level_of(str(n["id"]), owned)) \
			/ float(MAX_LV)
	return out


# 이 노드를 지금 살 수 있는가 — 이유를 문자열로 돌려준다("" = 가능).
# UI 가 버튼에 그대로 적는다: 왜 안 되는지가 안 보이면 잠긴 축은 없는 축이다.
# hero_lv·dungeon_best 는 안 쓴다(문턱이 앞 노드 하나로 줄었다) — 호출부가
# 여럿이라 시그니처는 남긴다. 다음에 문턱이 늘면 여기서 다시 본다.
static func lock_reason(id: String, owned: Dictionary, _hero_lv: int,
		_dungeon_best: int) -> String:
	var n := node(id)
	if n.is_empty():
		return "없는 노드"
	if level_of(id, owned) >= MAX_LV:
		return "만렙"
	# **문턱은 하나뿐이다: 줄기의 바로 앞 노드 만렙.** 아래를 다 채워야 위가 열린다.
	var prev := prev_id(id)
	if prev != "" and level_of(prev, owned) < MAX_LV:
		return "앞 %d렙" % MAX_LV
	return ""
