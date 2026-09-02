class_name GoalDefs
extends RefCounted

# 성장 가이드 — 방치형의 "다음에 뭘 하지"를 대신 정해 주고 보상으로 밀어 준다.
#
# **가이드는 한 줄로 이어진다.** 가이드 1, 2, 3 … 이 끝없이 이어지고 화면에는
# 늘 하나만 있다. 깨면 눌러서 받고, 그때 다음 것이 나온다.
# 예전엔 트랙 6개가 동시에 굴러가서 "받을 게 몇 개 쌓였다"를 보여 줄 목록 창이
# 따로 필요했는데, 그 창이 곧 지워 달라는 것이었다(사장님 지적). 한 줄이면
# 창이 필요 없고 "지금 뭘 해야 하나"도 하나로 좁혀진다.
#
# **업적 화면을 따로 만들지 않는다.** 방치형에서 업적과 가이드는 같은 데이터의
# 다른 뷰다(하나는 "지금 목표", 하나는 "지금까지 깬 것). 표를 두 벌 만들면
# 조건·보상이 두 군데에 흩어져서 하나만 고치면 어긋난다.
#
# **표를 손으로 안 적는다.** 방치형은 목표가 수백 개 필요한데 그걸 다 적으면
# 줄만 늘고 곡선은 눈으로 못 본다. 트랙마다 `base × mult^단계` 사다리 하나면
# 끝이 없고, 곡선을 고칠 때 숫자 두 개만 만지면 된다.
#
# 보석이 여기서 나온다. 예전엔 보스를 처음 깰 때뿐이라 소환을 돌릴 수가 없었다.

# kind 는 Main._goal_value() 가 "지금 값"을 돌려주는 열쇠다. 새 트랙을 넣으려면
# 거기에 한 줄을 같이 추가해야 한다 — GoalTest 가 빠진 걸 잡는다.
# ── 사다리 재조정 (2026-08-20, 사장님 "촘촘하게") ──────────────────────────
#
# 1) **간격을 좁혔다.** 배수가 1.6~2.1 이면 열 번째 목표가 첫 목표의 100~600배라
#    중반부터 가이드 하나가 며칠짜리가 된다 — 화면에 늘 하나만 뜨는 구조라
#    그동안은 "다음에 뭘 하지"를 아무도 안 알려 준다. 1.38~1.75 로 낮췄다.
#
# 2) **두 트랙은 기준값이 틀려 있었다.** 15분할(Balance.SPLIT)로 스탯 레벨이
#    15배가 되면서 `damage_lv` 목표를 순식간에 넘겼고, 배급을 3배로 올리면서
#    `pulls` 도 같은 꼴이 됐다. 눈금이 바뀌면 그 눈금을 읽는 목표도 같이
#    옮겨야 한다 — base 를 10 -> 150(=10x15) · 10 -> 30 으로 맞춘다.
const TRACKS := [
	# **첫 보상은 그 자리에서 쓸 수 있어야 한다.** 25 였는데 이 게임에서 보석으로
	# 살 수 있는 가장 싼 것이 소환 1회 30 이라, 90초 걸려 첫 목표를 깨면 보석
	# 알약이 새로 나타나면서 숫자가 25 — 아무것도 못 사는 첫 보상이었다.
	{"kind": "stage", "name": "단계 도달", "unit": "단계",
		"base": 3.0, "mult": 1.38, "gem": 30.0, "icon": "stat_damage"},
	{"kind": "kills", "name": "처치", "unit": "마리",
		"base": 120.0, "mult": 1.75, "gem": 18.0, "icon": "stat_drain"},
	{"kind": "hero_lv", "name": "영웅", "unit": "레벨",
		"base": 5.0, "mult": 1.48, "gem": 20.0, "icon": "stat_tough"},
	{"kind": "damage_lv", "name": "공격력", "unit": "레벨",
		"base": 150.0, "mult": 1.55, "gem": 15.0, "icon": "stat_damage"},
	# **사다리의 첫 칸에는 배급 눈금을 쓰면 안 된다.** base 30 은 정상 상태의
	# 하루 소환 수인데, 가이드 다섯째 칸이 그것이라 앞의 넷을 몇 분에 깬 사람이
	# 여기서 보석 900 어치를 모으느라 몇 시간 멈춰 섰다 — 그동안 "다음에 뭘
	# 하지"를 알려주는 유일한 위젯이 얼어 있다. 무료 뽑기 하루 1회 + 보스 첫
	# 격파 소환권이면 첫날 안에 닿는 값으로 내린다(mult 는 그대로라 두 바퀴째
	# 부터는 지금 곡선으로 돌아온다).
	{"kind": "pulls", "name": "소환", "unit": "회",
		"base": 5.0, "mult": 1.75, "gem": 22.0, "icon": "stat_crit"},
	{"kind": "knowledge", "name": "지식", "unit": "레벨",
		"base": 4.0, "mult": 1.42, "gem": 30.0, "icon": "stat_regen"},
]


# index 번째(0부터) 가이드가 어느 트랙의 몇 단계인지. 트랙을 **돌아가며** 한 단계씩
# 내준다 — 한 트랙을 다 밀고 다음으로 가면 "처치만 60번" 같은 구간이 생긴다.
static func quest(index: int) -> Dictionary:
	var i := maxi(0, index)
	return {"kind": str(TRACKS[i % TRACKS.size()]["kind"]), "step": i / TRACKS.size()}


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
	return round(float(t["gem"]) * pow(1.28, float(maxi(0, step))))


# 단계만 표기가 다르다. **"3단계"는 화면 어디에도 없는 숫자다** — 상단에는 "1-3"으로
# 나오고, 성장 창의 "3단계 해금"은 또 다른 뜻(큰 단계)이라 같은 낱말이 두 가지를
# 가리켰다(사장님: "단계 도달이 도대체 뭔데?"). 상단 표기를 그대로 쓴다.
static func label(kind: String, step: int) -> String:
	var t := track(kind)
	if t.is_empty():
		return ""
	if kind == "stage":
		return "%s 도달" % StageDefs.label(need(kind, step))
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
