extends SceneTree

# 1000구간(5막 x 100단계 x 10)을 **끝까지 걸어 본다.** 어디서 못 넘고 어디가
# 늘어지는지 숫자로 낸다.
#
# 이걸 만드는 이유: 지금까지 밸런스 검사는 공식의 성질(올림·상한·역전)과 **첫 보스
# 하나**만 봤다(BalanceTest). 200구간에 벽이 서는지 500구간이 늘어지는지는 아무도
# 잰 적이 없고, 그러면 "어디가 심심한가"를 사장님이 직접 다 겪어서 찾아야 한다.
#
# **공식을 여기 다시 적지 않는다.** `Main.gd` 를 맨 인스턴스로 띄워 `dps()` ·
# `max_hp()` · `upgrade_cost()` · `_offline_profile()` 을 그대로 부른다 — 베껴 적으면
# 밸런스를 고쳤을 때 이 검사만 옛 값을 보고 통과한다. 노드를 안 만지는 함수들이라
# 씬 없이 부를 수 있다(BalanceTest 가 쓰는 방법과 같다).
#
# 모델은 **바닥값**이다: 장비·도감·스킬 없이 스탯만 올린다. 실제 플레이는 이보다
# 빠르므로, 여기서 통과하면 실제로도 통과한다. 반대로 여기서 벽이면 장비로 메워야
# 한다는 뜻이고 그건 그것대로 알아야 하는 정보다.
#
# **느리다(약 4분).** 빠른 검사 묶음에 넣지 말고 곡선을 건드렸을 때만 돌린다 —
# `Balance` · `StageDefs` 의 곡선 상수, `StatDefs` 의 비용, 처치 보상을 만졌을 때.

# 앞 구간을 이만큼 되풀이해도 못 넘으면 **벽**으로 본다. 300 랩이면 1-1 기준으로도
# 몇 시간이라 게임으로서 이미 끝난 것이고, 상한을 크게 잡으면 계측기가 후반에서
# 수백만 번 돌아 안 끝난다(4000 으로 뒀다가 400초를 넘겼다).
const FARM_GIVE_UP := 300
const STOP_AFTER_WALLS := 3     # 벽이 이만큼 나오면 더 볼 것도 없다 — 거기서 멈춘다


func _init() -> void:
	var game = load("res://Main.gd").new()
	var gold := 0.0
	var exp_pool := 0.0
	var total := 0.0            # 구간을 미는 데 든 시간
	var farm := 0.0             # 못 넘어서 앞 구간을 되풀이한 시간
	var walls: Array = []       # [구간, 파밍 초]
	var hard := 0
	var last := StageDefs.total_stages()
	var marks := {}             # 막 경계에서 찍는 스냅샷

	for st in range(1, last + 1):
		game.stage = st
		gold = _shop(game, gold, st)
		var need := StageDefs.kills_needed(st)
		var farmed := 0.0
		var tries := 0
		# 못 넘으면 **앞 구간을 되풀이해** 피를 모으고 다시 산다. 방치형에서
		# 벽이란 "못 간다"가 아니라 "여기서 얼마나 갈리느냐"다.
		while not _clears(game, st, need) and tries < FARM_GIVE_UP:
			var prev := maxi(1, st - 1)
			var lap := _play(game, prev)
			farmed += lap["secs"]
			gold += lap["gold"]
			exp_pool = _level(game, exp_pool + lap["exp"])
			gold = _shop(game, gold, st)
			tries += 1
		if tries >= FARM_GIVE_UP:
			hard += 1
			walls.append([st, -1.0])
			print("  벽: %d 구간 — 앞 구간 %d 랩을 돌아도 못 넘는다 (%s)"
				% [st, FARM_GIVE_UP, StageDefs.label(st)])
			if hard >= STOP_AFTER_WALLS:
				last = st
				break
		elif farmed > 0.0:
			farm += farmed
			if walls.size() < 40:
				walls.append([st, farmed])
		var run := _play(game, st)
		total += run["secs"]
		gold += run["gold"]
		exp_pool = _level(game, exp_pool + run["exp"])
		if st % 100 == 0 or st == 1:
			marks[st] = {"h": (total + farm) / 3600.0, "lv": game.hero_lv,
				"dmg": game.stat_lv("damage"), "sec": run["secs"]}
			print("  ... %d 구간 통과  누적 %.1f 시간" % [st, (total + farm) / 3600.0])

	print("")
	print("=== 1000구간 진행 곡선 (장비·도감·스킬 없는 바닥값) ===")
	print("")
	print("%-8s %10s %8s %8s %10s" % ["구간", "누적(시간)", "영웅Lv", "공격력Lv", "구간(초)"])
	for st in marks:
		var m: Dictionary = marks[st]
		print("%-8d %10.1f %8d %8d %10.1f"
			% [st, m["h"], m["lv"], m["dmg"], m["sec"]])
	print("")
	print("미는 시간 %.1f 시간  ·  파밍 %.1f 시간  ·  합계 %.1f 시간"
		% [total / 3600.0, farm / 3600.0, (total + farm) / 3600.0])
	print("벽이 선 구간 %d 개 (그중 못 넘음 %d)" % [walls.size(), hard])
	for w in walls:
		if float(w[1]) < 0.0:
			print("   %4d  못 넘음" % int(w[0]))
		else:
			print("   %4d  파밍 %.0f 분" % [int(w[0]), float(w[1]) / 60.0])
	print("")
	print("걸어 본 구간 1 ~ %d / %d" % [last, StageDefs.total_stages()])
	print("")
	# **경고로 끝낸다.** 이건 규칙 위반을 잡는 검사가 아니라 곡선을 재는 자다.
	# 바닥값(장비·도감·스킬 0)이라 벽이 나온다고 곧 게임이 깨진 건 아니다 —
	# "여기부터는 장비가 있어야 한다"는 선을 알려 주는 것이다.
	if hard > 0:
		print("!! 바닥값으로는 %d 구간에서 막힌다. 그 뒤는 장비·도감이 메워야 한다." % last)
	print("CurveCheck OK")
	quit()


# 그 구간을 넘을 수 있나. **게임과 같은 함수로 묻는다.**
func _clears(game, st: int, need: int) -> bool:
	var p: Dictionary = game._offline_profile(st)
	return Balance.can_clear_stage(game.max_hp(), game.regen_per_sec(), game.dps(),
		need, float(p["hp"]), int(p["count"]), float(p["damage"]),
		float(p["interval"]), StageDefs.time_limit(st), game.attack_interval())


# 그 구간을 한 번 미는 데 드는 시간과 거기서 나오는 피·경험치.
func _play(game, st: int) -> Dictionary:
	var p: Dictionary = game._offline_profile(st)
	var need := StageDefs.kills_needed(st)
	var secs := Balance.stage_seconds(need, float(p["hp"]), game.dps(),
		game.attack_interval())
	return {
		"secs": secs,
		"gold": float(need) * StageDefs.gold_per_kill(st) * game.gold_mult(),
		"exp": float(need) * Balance.exp_per_kill(st),
	}


# 경험치를 붓고 오를 만큼 올린다. 남은 경험치를 돌려준다.
func _level(game, pool: float) -> float:
	while pool >= Balance.exp_need(game.hero_lv):
		pool -= Balance.exp_need(game.hero_lv)
		game.hero_lv += 1
	return pool


# 살 수 있는 만큼 산다. **전투력이 가장 많이 오르는 것을 산다** — 제일 싼 것을
# 사면 공격력만 999 가 되어 맞아 죽고, 그건 사람이 하는 선택이 아니다.
func _shop(game, gold: float, st: int) -> float:
	while true:
		var best := ""
		var best_score := 0.0
		var best_cost := 0.0
		for s in StatDefs.STATS:
			var key := str(s["key"])
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


# 그 스탯을 한 단계 올렸을 때 전투력이 얼마나 오르나. **올려 보고 되돌린다** —
# 스탯마다 어디에 곱해지는지 다시 적으면 그게 곧 갈리는 두 번째 공식이 된다.
func _gain(game, key: String, lv: int) -> float:
	var before := Balance.combat_power(game.dps(), game.max_hp(), game.regen_per_sec())
	game.lv[key] = lv + 1
	var after := Balance.combat_power(game.dps(), game.max_hp(), game.regen_per_sec())
	game.lv[key] = lv
	return maxf(0.0, after - before)
