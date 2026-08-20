extends SceneTree
# 15분할 회귀 — 분할이 곡선을 안 깼는지, 마이그레이션이 정확한지, MAX 가
# 음수를 못 흘리는지. 셋 다 "크래시 없이 조용히 틀리는" 종류라 검사로 잡는다.


func _init() -> void:
	# 1) 항등 — 등가 레벨의 누적 비용이 옛 곡선과 같아야 한다.
	for spec in [[10.0, 1.15], [12.0, 1.15], [20.0, 1.22], [50.0, 1.35],
			[40.0, 1.28], [15.0, 1.22]]:
		var base: float = spec[0]
		var e: float = spec[1]
		for old_lv in [10, 50, 100, 181, 400]:
			var old_sum := base * (pow(e, float(int(old_lv) - 1)) - 1.0) / (e - 1.0)
			var new_lv: int = 1 + Balance.SPLIT * (int(old_lv) - 1)
			var new_sum := Balance.buy_cost(1, new_lv - 1, base, e)
			var err: float = absf(new_sum - old_sum) / maxf(1.0, old_sum)
			assert(err < 1e-6, "누적이 안 맞는다 base %.1f exp %.2f 옛Lv%d: %.6f"
				% [base, e, old_lv, err])

	# 2) 묶음 == 낱개 합 (닫힌식이 등비합과 같은가)
	var loop := 0.0
	for k in 40:
		loop += Balance.upgrade_cost(500 + k, 10.0, 1.15)
	assert(absf(Balance.buy_cost(500, 40, 10.0, 1.15) - loop) / loop < 1e-9,
		"닫힌식이 낱개 합과 다르다")

	# 3) MAX — 음수를 절대 안 돌려주고, 판 값이 지갑 안에 든다.
	assert(Balance.max_steps(100, 0.0, 10.0, 1.15) == 0, "빈 지갑에 MAX 가 샀다")
	assert(Balance.max_steps(100, -5.0, 10.0, 1.15) == 0, "음수 지갑에서 샀다")
	for purse in [1.0, 1e3, 1e6, 1e12]:
		var n := Balance.max_steps(100, float(purse), 10.0, 1.15)
		assert(n >= 0, "MAX 가 음수를 돌려줬다: %d" % n)
		if n > 0:
			assert(Balance.buy_cost(100, n, 10.0, 1.15) <= float(purse),
				"MAX 가 지갑을 넘겼다: %d단계" % n)
		assert(Balance.buy_cost(100, n + 1, 10.0, 1.15) > float(purse),
			"MAX 가 한 단계 덜 샀다: %d단계" % n)

	# 4) 효과 항등 — 새 레벨의 유효값이 옛 레벨과 같아야 한다.
	for old_lv in [1, 30, 181, 500]:
		var new_lv: int = 1 + Balance.SPLIT * (int(old_lv) - 1)
		var eff := 1.0 + float(new_lv - 1) / float(Balance.SPLIT)
		assert(absf(eff - float(old_lv)) < 1e-9, "유효 레벨이 어긋난다")
		assert(absf(Balance.hero_damage(eff, 0.0, 1)
			- Balance.hero_damage(float(old_lv), 0.0, 1)) < 1e-9, "피해가 어긋난다")

	# 5) 흡혈량은 표에서 사라졌다.
	assert(StatDefs.of("gold").is_empty(), "흡혈량이 아직 표에 있다")

	print("SplitCheck OK")
	quit()
