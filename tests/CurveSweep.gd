extends SceneTree

# **곡선 후보를 여러 개 넣어 보고 벽이 어디 서는지 표로 뽑는다.**
#
# 사장님: "관련 곡선 표로 뽑아서 보여줘".
#
# 고르는 값은 둘이다(`StageDefs`):
#   POWER_STEP  큰 단계(10구간)마다 적이 세지는 배수. 지금 1.038 (1000구간 누적 x41)
#   GOLD_SLOPE  큰 단계마다 처치 보상에 더해지는 몫. 지금 0.55 (1000구간 x56)
#
# **둘을 같이 움직여야 한다.** 적만 세게 하면 벽만 서고 넘을 돈이 안 생기고,
# 돈만 늘리면 지금과 똑같이 헐거워진다.
#
# 네 가지 길로 각각 걸어 본다(`NoAttackProbe` 와 같은 정책):
#   전부 / 공격 제외 / 스킬+공격제외 / 무투자
#
# **읽는 법**: "전부"는 멀리 가고 나머지는 일찍 막혀야 좋은 곡선이다.
# 넷이 비슷하면 투자에 의미가 없다는 뜻이고, 그게 지금 증상이었다.
#
# 공식은 다시 안 적는다 — `Main.gd` 를 맨 인스턴스로 띄워 그대로 부른다.

const FARM_GIVE_UP := 120
const LOADOUT := ["strike_common", "wave_common", "field_common", "ward_common",
	"strike_uncommon", "wave_uncommon"]

# [적 배수, 보상 기울기]. 첫 줄이 지금 값이다.
# 수입을 **적과 같은 기울기이거나 조금 아래**로 붙인다. 지수끼리 붙어야 뒤로 갈수록
# 못 사는 일이 안 생긴다. 첫 줄이 지금 값이다.
const CANDIDATES := [
	[1.038, 0.55],
	[1.038, 1.10],
	[1.050, 1.10],
	[1.050, 2.00],
	[1.060, 3.00],
]


func _init() -> void:
	var keep_power: float = StageDefs.POWER_STEP
	var keep_gold: float = StageDefs.GOLD_SLOPE
	print("")
	print("%-16s %-8s %-10s %-14s %-10s %s"
		% ["곡선", "전부", "공격제외", "스킬+공격제외", "무투자", "1000구간 적/보상"])
	print("-".repeat(84))
	for c in CANDIDATES:
		StageDefs.POWER_STEP = float(c[0])
		StageDefs.GOLD_SLOPE = float(c[1])
		var cells: Array = []
		for policy in ["전부", "공격 제외", "스킬+공격제외", "무투자"]:
			var r := _walk(policy)
			cells.append("%s" % str(r["wall"]))
		var tag := "적 x%.3f 돈 %.2f" % [float(c[0]), float(c[1])]
		if is_equal_approx(float(c[0]), keep_power) and is_equal_approx(float(c[1]), keep_gold):
			tag += "*"
		print("%-16s %-8s %-10s %-14s %-10s x%.0f / x%.0f"
			% [tag, cells[0], cells[1], cells[2], cells[3],
			StageDefs.enemy_power(1000), StageDefs.gold_per_kill(1000)])
	StageDefs.POWER_STEP = keep_power
	StageDefs.GOLD_SLOPE = keep_gold
	print("")
	print("* = 지금 값")
	print("")
	_hp_table()
	print("")
	_damage_table()
	print("")
	print("CurveSweep OK")
	quit()


# 후보별 몹 체력이 어떻게 벌어지는지. 표로 나란히 놓아야 기울기가 보인다.
func _hp_table() -> void:
	var keep_power: float = StageDefs.POWER_STEP
	var game = load("res://Main.gd").new()
	var head := "%-8s" % "구간"
	for c in CANDIDATES:
		head += "%-12s" % ("x%.3f" % float(c[0]))
	print("몹 체력 (일반 몹 기준)")
	print(head)
	for st in [1, 50, 100, 250, 500, 750, 1000]:
		var line := "%-8d" % st
		for c in CANDIDATES:
			StageDefs.POWER_STEP = float(c[0])
			var p: Dictionary = game._offline_profile(st)
			line += "%-12s" % _n(float(p["hp"]))
		print(line)
	StageDefs.POWER_STEP = keep_power


# **공격력 스탯이 왜 안 팔리는가.** 비용은 지수(x1.15/레벨)인데 피해는 합연산
# (레벨당 +2%)이다 — 100레벨이면 값은 백만 배인데 피해는 세 배다.
# 아래 표는 **곡선을 안 바꾸고 계산만** 해 본 것이다. 바꿀지는 사장님 판단이다
# (지금 합연산은 STATS 1장의 "합연산은 무한, 곱연산은 유한"에 따른 의도된 선택이다).
func _damage_table() -> void:
	print("공격력 레벨당 — 비용은 지수, 피해는 합연산")
	print("%-8s %-14s %-14s %-14s %s"
		% ["레벨", "누적 비용배수", "피해(지금·합)", "피해(x1.03)", "피해(x1.05)"])
	for lv in [1, 10, 30, 60, 100, 150]:
		var n := float(lv - 1)
		print("%-8d %-14s %-14s %-14s %s"
			% [lv, _n(pow(Balance.UP_EXP, n)),
			"x%.2f" % (1.0 + Balance.DMG_PER_LEVEL * n),
			"x%.2f" % pow(1.03, n), "x%.2f" % pow(1.05, n)])


func _walk(policy: String) -> Dictionary:
	var game = load("res://Main.gd").new()
	if policy == "스킬+공격제외":
		for k in LOADOUT:
			game.skill_owned[k] = 1
			game.skill_equipped.append(k)
	var gold := 0.0
	var last := StageDefs.total_stages()
	for st in range(1, last + 1):
		game.stage = st
		if policy != "무투자":
			gold = _shop(game, gold, st, policy != "전부")
		var need := StageDefs.kills_needed(st)
		var tries := 0
		while true:
			if _clear_time(game, st, need) > 0.0:
				gold += _reward(game, st, need)
				break
			tries += 1
			if tries > FARM_GIVE_UP:
				return {"wall": st}
			var back := maxi(1, st - 1)
			if _clear_time(game, back, StageDefs.kills_needed(back)) <= 0.0:
				return {"wall": st}
			gold += _reward(game, back, StageDefs.kills_needed(back))
			if policy != "무투자":
				gold = _shop(game, gold, st, policy != "전부")
	return {"wall": "끝"}


func _clear_time(game, st: int, need: int) -> float:
	var p: Dictionary = game._offline_profile(st)
	if not Balance.can_clear_stage(game.max_hp(), game.regen_per_sec(), game.dps(),
			need, float(p["hp"]), int(p["count"]), float(p["damage"]),
			float(p["interval"]), StageDefs.time_limit(st), game.attack_interval()):
		return -1.0
	return Balance.stage_seconds(need, float(p["hp"]), game.dps(), game.attack_interval())


func _reward(game, st: int, need: int) -> float:
	return StageDefs.gold_per_kill(st) * float(need) * game.gold_mult()


func _shop(game, gold: float, st: int, skip_damage: bool) -> float:
	while true:
		var best := ""
		var best_score := 0.0
		var best_cost := 0.0
		for s in StatDefs.STATS:
			var key := str(s["key"])
			if skip_damage and key == "damage":
				continue
			if not StatDefs.is_open(key, st, game.lv):
				continue
			var lv: int = game.stat_lv(key)
			if StatDefs.at_cap(key, lv):
				continue
			var cost: float = game.upgrade_cost(key, lv)
			if cost > gold:
				continue
			var score := _gain(game, key, lv) / maxf(1.0, cost)
			if score > best_score:
				best_score = score
				best = key
				best_cost = cost
		if best == "":
			return gold
		gold -= best_cost
		game.lv[best] = game.stat_lv(best) + 1
	return gold


func _gain(game, key: String, lv: int) -> float:
	var before := Balance.combat_power(game.dps(), game.max_hp(), game.regen_per_sec())
	game.lv[key] = lv + 1
	var after := Balance.combat_power(game.dps(), game.max_hp(), game.regen_per_sec())
	game.lv[key] = lv
	return maxf(0.0, after - before)


static func _n(v: float) -> String:
	if v >= 1.0e9:
		return "%.1fB" % (v / 1.0e9)
	if v >= 1.0e6:
		return "%.1fM" % (v / 1.0e6)
	if v >= 1000.0:
		return "%.1fK" % (v / 1000.0)
	return "%.0f" % v
