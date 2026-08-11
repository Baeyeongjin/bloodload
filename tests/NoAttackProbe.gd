extends SceneTree

# **공격력을 한 번도 안 찍으면 어디까지 가나.** 사장님: "지금은 공격력을 하나도
# 안 찍어도 엄청 진행이 많이 됨".
#
# CurveCheck 은 "전투력/골드가 제일 큰 것"을 사서 최적으로 걷는다. 그건 곡선이
# 성립하는지를 보는 자이고, **투자를 안 해도 되는가**는 못 잰다.
# 여기서는 정책을 셋으로 갈라 같은 길을 걷고 벽이 어디 서는지 비교한다:
#
#   전부      : 지금 CurveCheck 과 같다 (전투력/골드 최대)
#   공격 제외 : `damage` 를 절대 안 산다
#   무투자    : 아무것도 안 산다 (1레벨 그대로)
#
# 셋이 비슷한 데까지 가면 **투자에 의미가 없다**는 뜻이고, 그게 지금 증상이다.
#
# 공식은 여기 다시 안 적는다 — `Main.gd` 를 맨 인스턴스로 띄워 그대로 부른다
# (CurveCheck 과 같은 방법).
const FARM_GIVE_UP := 120


func _init() -> void:
	print("")
	print("%-10s %-8s %-10s %-12s %s"
		% ["정책", "벽 구간", "총 시간", "그때 전투력", "공격력 레벨"])
	print("-".repeat(64))
	for policy in ["전부", "공격 제외", "무투자"]:
		var r := _walk(policy)
		print("%-10s %-8s %-10s %-12s %s"
			% [policy, str(r["wall"]), "%.0f분" % (float(r["time"]) / 60.0),
			_n(float(r["power"])), str(r["dmg_lv"])])
	print("")
	_breakdown()
	print("")
	print("NoAttackProbe OK")
	quit()


func _walk(policy: String) -> Dictionary:
	var game = load("res://Main.gd").new()
	var gold := 0.0
	var total := 0.0
	var last := StageDefs.total_stages()
	for st in range(1, last + 1):
		game.stage = st
		if policy != "무투자":
			gold = _shop(game, gold, st, policy == "공격 제외")
		var need := StageDefs.kills_needed(st)
		var farmed := 0.0
		var tries := 0
		while true:
			var t := _clear_time(game, st, need)
			if t > 0.0:
				total += t
				gold += _reward(game, st, need)
				break
			# 못 넘는다 — 앞 구간을 되풀이해 돈을 번다
			tries += 1
			if tries > FARM_GIVE_UP:
				return {"wall": st, "time": total + farmed,
					"power": Balance.combat_power(game.dps(), game.max_hp(),
						game.regen_per_sec()),
					"dmg_lv": game.stat_lv("damage")}
			var back := maxi(1, st - 1)
			var bt := _clear_time(game, back, StageDefs.kills_needed(back))
			if bt <= 0.0:
				return {"wall": st, "time": total + farmed,
					"power": Balance.combat_power(game.dps(), game.max_hp(),
						game.regen_per_sec()),
					"dmg_lv": game.stat_lv("damage")}
			farmed += bt
			gold += _reward(game, back, StageDefs.kills_needed(back))
			if policy != "무투자":
				gold = _shop(game, gold, st, policy == "공격 제외")
	return {"wall": "끝까지", "time": total,
		"power": Balance.combat_power(game.dps(), game.max_hp(), game.regen_per_sec()),
		"dmg_lv": game.stat_lv("damage")}


# 그 구간을 미는 데 걸리는 시간. 못 밀면 -1.
# **게임과 같은 함수로 묻는다**(CurveCheck 과 같은 방법) — 여기서 식을 베껴 적으면
# 밸런스를 고쳤을 때 이 계측기만 옛 값을 본다.
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


# **DPS 를 무엇이 만드는가.** 공격력을 안 찍어도 되는 이유는 둘 중 하나다:
# 바닥값이 크거나, 다른 스탯이 대신 올려 주거나.
func _breakdown() -> void:
	var game = load("res://Main.gd").new()
	print("스탯 1레벨(바닥) DPS %.1f" % game.dps())
	for key in ["damage", "speed", "crit", "critdmg"]:
		for want in [10, 30, 60]:
			game.lv[key] = want
			print("   %-8s %2d레벨 -> DPS %8.1f  (x%.2f)"
				% [key, want, game.dps(), game.dps() / maxf(0.001, _base_dps())])
		game.lv[key] = 1
	print("")
	print("몹 체력 곡선")
	for st in [1, 50, 100, 200, 300, 450, 600, 1000]:
		var p: Dictionary = game._offline_profile(st)
		print("   %4d구간  체력 %12s  처치당 혈액 %s"
			% [st, _n(float(p["hp"])), _n(StageDefs.gold_per_kill(st))])


func _base_dps() -> float:
	var g = load("res://Main.gd").new()
	return g.dps()


static func _n(v: float) -> String:
	if v >= 1.0e9:
		return "%.1fB" % (v / 1.0e9)
	if v >= 1.0e6:
		return "%.1fM" % (v / 1.0e6)
	if v >= 1000.0:
		return "%.1fK" % (v / 1000.0)
	return "%.0f" % v
