class_name GoalDefs
extends RefCounted

# 성장 가이드 — 방치형의 "다음에 뭘 하지"를 대신 정해 주고 보상으로 밀어 준다.
#
# **업적 화면을 따로 만들지 않는다.** 방치형에서 업적과 가이드는 같은 데이터의
# 다른 뷰다(하나는 "지금 목표", 하나는 "지금까지 깬 것). 표를 두 벌 만들면
# 조건·보상이 두 군데에 흩어져서 하나만 고치면 어긋난다. 여기서는 트랙 하나에
# 단계가 무한히 이어지고, 화면은 **각 트랙의 지금 단계**만 보여 준다.
#
# **표를 손으로 안 적는다.** 방치형은 목표가 수백 개 필요한데 그걸 다 적으면
# 줄만 늘고 곡선은 눈으로 못 본다. 트랙마다 `base × mult^단계` 사다리 하나면
# 끝이 없고, 곡선을 고칠 때 숫자 두 개만 만지면 된다.
#
# 보석이 여기서 나온다. 예전엔 보스를 처음 깰 때뿐이라 소환을 돌릴 수가 없었다.

# kind 는 Main._goal_value() 가 "지금 값"을 돌려주는 열쇠다. 새 트랙을 넣으려면
# 거기에 한 줄을 같이 추가해야 한다 — GoalTest 가 빠진 걸 잡는다.
const TRACKS := [
	{"kind": "stage", "name": "단계 도달", "unit": "단계",
		"base": 3.0, "mult": 1.55, "gem": 25.0, "icon": "stat_damage"},
	{"kind": "kills", "name": "누적 처치", "unit": "마리",
		"base": 120.0, "mult": 2.1, "gem": 18.0, "icon": "stat_drain"},
	{"kind": "hero_lv", "name": "영웅 레벨", "unit": "레벨",
		"base": 5.0, "mult": 1.7, "gem": 20.0, "icon": "stat_tough"},
	{"kind": "damage_lv", "name": "공격력 훈련", "unit": "레벨",
		"base": 10.0, "mult": 1.8, "gem": 15.0, "icon": "stat_damage"},
	{"kind": "pulls", "name": "소환 횟수", "unit": "회",
		"base": 10.0, "mult": 2.0, "gem": 22.0, "icon": "stat_crit"},
	{"kind": "knowledge", "name": "도감 지식", "unit": "레벨",
		"base": 4.0, "mult": 1.6, "gem": 30.0, "icon": "stat_regen"},
]


static func track(kind: String) -> Dictionary:
	for t in TRACKS:
		if str(t["kind"]) == kind:
			return t
	return {}


# step 번째(0부터) 목표에 필요한 값. 사다리라 끝이 없다.
# 반올림해서 "1,234마리" 같은 어중간한 수가 안 나오게 두 자리로 자른다 —
# 목표는 눈으로 읽고 기억할 수 있어야 한다.
static func need(kind: String, step: int) -> int:
	var t := track(kind)
	if t.is_empty():
		return 0
	var raw: float = float(t["base"]) * pow(float(t["mult"]), float(maxi(0, step)))
	if raw < 100.0:
		return int(round(raw))
	var digits: float = floor(log(raw) / log(10.0)) - 1.0
	var unit: float = pow(10.0, digits)
	return int(round(raw / unit) * unit)


# 보상 보석. 단계가 오를수록 늘지만 필요값(x2 안팎)보다 훨씬 완만하다 —
# 같은 비율로 올리면 후반 목표 하나가 소환 수백 회가 되어 초반이 무의미해진다.
static func gem_reward(kind: String, step: int) -> float:
	var t := track(kind)
	if t.is_empty():
		return 0.0
	return round(float(t["gem"]) * pow(1.35, float(maxi(0, step))))


static func label(kind: String, step: int) -> String:
	var t := track(kind)
	if t.is_empty():
		return ""
	return "%s %s%s" % [str(t["name"]), _n(need(kind, step)), str(t["unit"])]


# 큰 수 축약. Main._n 과 같은 규칙이지만 여기 표는 Main 없이도 검사할 수 있어야
# 해서 따로 둔다(테스트가 씬을 안 띄운다).
static func _n(v: int) -> String:
	if v < 1000:
		return str(v)
	var f := float(v)
	var units := ["k", "m", "b", "t"]
	var i := -1
	while f >= 1000.0 and i < units.size() - 1:
		f /= 1000.0
		i += 1
	return ("%.1f" % f).trim_suffix(".0") + units[i]


# 지금까지 깬 목표 수. 업적 화면 대신 이 숫자 하나로 "얼마나 했나"를 보여 준다.
static func cleared_total(steps: Dictionary) -> int:
	var sum := 0
	for t in TRACKS:
		sum += int(steps.get(str(t["kind"]), 0))
	return sum
