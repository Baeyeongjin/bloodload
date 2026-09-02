extends SceneTree
# 15분할 회귀 — 분할이 곡선을 안 깼는지, 마이그레이션이 정확한지, MAX 가
# 음수를 못 흘리는지. 셋 다 "크래시 없이 조용히 틀리는" 종류라 검사로 잡는다.


func _init() -> void:
	# **가드.** 이게 없으면 assert 가 깨져도 SceneTree 가 안 죽어서 실패가
	# "타임아웃"으로 둔갑한다 — TicketCheck 를 그렇게 몇 주 오진했다.
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	# 1) 항등 — 등가 레벨의 누적 비용이 옛 곡선과 같아야 한다.
	# **굽힘(COST_BEND)이 켜져 있으면 이 절은 성립하지 않는다** — 옛 식을 여기
	# 직접 적어 뒀기 때문이다. 굽힘은 아래 1b 가 따로 잰다. 이 가드가 없으면
	# 굽힘을 켠 순간 이 파일이 빨개지고, 그러면 "원래 빨간 검사"로 취급되기
	# 시작한다(CHECKS.md 가 경고하는 실패 모드).
	assert(is_equal_approx(Balance.COST_BEND, 1.0),
		"굽힘이 켜진 채로 항등 절을 돌리고 있다 — 기본값은 1.0 이어야 한다")
	for spec in [[10.0, 1.15], [12.0, 1.15], [20.0, 1.22], [50.0, 1.35],
			[40.0, 1.28], [15.0, 1.22]]:
		var base: float = spec[0]
		var e: float = spec[1]
		for old_lv in [10, 50, 100, 181, 400]:
			var old_sum := base * (pow(e, float(int(old_lv) - 1)) - 1.0) / (e - 1.0) \
				* Balance.COST_SCALE
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

	# 5) 값이 있는데 "0"으로 찍히면 안 된다. 15분할 뒤 첫 칸 값이 1 미만이라
	#    스탯 가격이 전부 "혈액 0"으로 보였다(사장님 실플레이).
	var M := load("res://Main.gd")
	for spec2 in [[10.0, 1.15], [12.0, 1.15], [20.0, 1.22], [40.0, 1.28]]:
		var c: float = Balance.upgrade_cost(1, float(spec2[0]), float(spec2[1]))
		assert(c > 0.0, "첫 칸이 공짜다")
		assert(M._n(c) != "0", "가격 %.3f 이 화면에 0 으로 찍힌다" % c)
	assert(M._n(0.0) == "0", "0 은 그대로 0 이어야 한다")
	assert(M._n(0.004) != "0.0", "아주 작은 값도 0 으로 찍히면 안 된다")
	assert(M._n(1.0) == "1" and M._n(999.0) == "999", "정수 표기가 바뀌었다")

	# 6b) 가격은 올려서 적는다 — 화면이 살 수 있다고 하면 정말로 살 수 있어야
	#     한다. 내림이면 "혈액 9"인데 9.36 이 필요해 버튼이 안 눌린다.
	for v in [9.36, 0.4, 1.0, 99.9, 999.6, 1234.5, 2000.0, 1.5e9]:
		var shown: String = M._n(float(v), true)
		assert(_parse_n(shown) >= float(v) - 1e-6,
			"가격 %.2f 가 %s 로 모자라게 적힌다" % [v, shown])
	assert(M._n(9.36, true) == "10" and M._n(2000.0, true) == "2k",
		"가격 표기가 필요 이상으로 올라간다")

	# 6) 눈금 — 첫 칸 가격이 정수로 읽혀야 한다(소수점을 없애려고 15배 했다).
	for spec3 in [[10.0, 1.15], [12.0, 1.15], [20.0, 1.22], [40.0, 1.28]]:
		assert(Balance.upgrade_cost(1, float(spec3[0]), float(spec3[1])) >= 1.0,
			"첫 칸이 아직 1 미만이다 base %.0f" % spec3[0])
	# 수입과 비용이 **같은 배수**여야 체감이 안 바뀐다 — 첫 구간 기준 시간비.
	# **KILL_WORTH 를 나눈다.** 한 마리를 3배 무겁게 만들면서 한 마리 값도 3배가
	# 됐는데(StageDefs.gd:274·284) 이 식이 안 따라와서, 기대 0.6241 대 실제
	# 0.2080 — 정확히 3배로 어긋난 채 계속 실패하고 있었다. 상수를 읽게 두면
	# 다음에 무게를 또 바꿔도 이 줄은 안 깨진다.
	var pay := StageDefs.gold_per_kill(1)
	var price := Balance.upgrade_cost(1, 10.0, 1.15)
	var want := 10.0 * (pow(1.15, 1.0 / 15.0) - 1.0) / 0.15 / StageDefs.KILL_WORTH
	assert(absf(price / pay - want) < 1e-6,
		"수입과 비용의 비가 눈금 때문에 바뀌었다: %.4f 대 %.4f" % [price / pay, want])

	# 6) 흡혈량은 표에서 사라졌다.
	assert(StatDefs.of("gold").is_empty(), "흡혈량이 아직 표에 있다")

	print("SplitCheck OK")
	quit()


# "1.3k" -> 1300.0
func _parse_n(t: String) -> float:
	var mul := 1.0
	for u in [["k", 1e3], ["m", 1e6], ["b", 1e9], ["t", 1e12]]:
		if t.ends_with(str(u[0])):
			mul = float(u[1])
			t = t.trim_suffix(str(u[0]))
	return t.to_float() * mul
