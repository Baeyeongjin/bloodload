extends SceneTree

# 배수 구매(x1/x10/x100) 수치 검증. 눈으로는 절대 못 잡는 종류의 버그다 —
# 화면에는 그럴듯한 숫자가 찍히는데 실제로는 돈이 새거나 과금된다.
#   godot --headless --script tests/BalanceTest.gd

func _init() -> void:
	# 1) 레벨이 오를수록 비싸져야 한다. 안 그러면 무한 성장이 공짜가 된다.
	for lv in range(1, 200):
		assert(Balance.upgrade_cost(lv + 1) > Balance.upgrade_cost(lv),
			"비용이 안 오른다: Lv%d" % lv)

	# 2) 핵심 — 한 번에 n 단계 사는 값 == n 번 따로 사는 값.
	#    어긋나면 배수 버튼이 할인권이 되거나 바가지가 된다.
	for lv in [1, 7, 50, 200]:
		for n in [1, 10, 100]:
			var one_by_one := 0.0
			for k in n:
				one_by_one += Balance.upgrade_cost(lv + k)
			var bulk := Balance.buy_cost(lv, n)
			assert(absf(bulk - one_by_one) < maxf(1.0, one_by_one * 1e-6),
				"Lv%d x%d: 묶음 %f != 낱개 %f" % [lv, n, bulk, one_by_one])

	# 3) 지수 곡선이므로 묶음은 "현재 비용 x n" 보다 반드시 비싸다.
	#    이게 깨지면 누군가 buy_cost 를 단순 곱셈으로 되돌린 것이다.
	for lv in [1, 30, 100]:
		assert(Balance.buy_cost(lv, 10) > Balance.upgrade_cost(lv) * 10.0,
			"Lv%d: 묶음이 단순 곱보다 싸다" % lv)

	# 4) x1 은 한 단계 비용 그 자체.
	for lv in [1, 5, 99]:
		assert(is_equal_approx(Balance.buy_cost(lv, 1), Balance.upgrade_cost(lv)))

	# 5) 실제 구매를 흉내 낸다: 지갑이 정확히 맞아떨어지고 음수가 안 된다.
	var gold := 1.0e9
	var lv2 := 1
	while true:
		var cost := Balance.buy_cost(lv2, 10)
		if gold < cost:
			break
		gold -= cost
		lv2 += 10
		assert(gold >= 0.0, "지갑이 음수가 됐다")
	assert(lv2 > 1, "10억으로 한 번도 못 샀다 — 곡선이 너무 가파르다")
	# 6) 영웅 레벨: 경험치가 한 번에 여러 레벨을 넘겨도 새지 않아야 한다.
	#    (while 이 아니라 if 로 짜면 남은 경험치가 버려진다)
	var lv := 1
	var xp := 0.0
	var gained := 0.0
	for k in 500:
		var amount := Balance.exp_per_kill(20)
		xp += amount
		gained += amount
		while xp >= Balance.exp_need(lv):
			xp -= Balance.exp_need(lv)
			lv += 1
	var spent := 0.0
	for l in range(1, lv):
		spent += Balance.exp_need(l)
	assert(absf((spent + xp) - gained) < 1.0,
		"경험치가 샜다: 번 것 %.1f, 쓴 것+남은 것 %.1f" % [gained, spent + xp])
	assert(lv > 1, "500마리 잡고도 레벨이 안 올랐다")

	# 7) 레벨 보너스는 1레벨에서 정확히 1.0 이어야 한다(아무 보정 없음).
	assert(is_equal_approx(Balance.hero_mult(1), 1.0))
	assert(Balance.hero_mult(2) > 1.0)

	print("HeroLv: 20단계에서 500마리 -> Lv%d" % lv)
	# 8) 스탯 해금 — 잠긴 스탯은 스테이지를 넘겨도 impl 이 false 면 안 열린다.
	#    안 그러면 효과 없는 스탯을 사서 피만 버린다.
	for s in StatDefs.STATS:
		var key := str(s["key"])
		var un := int(s["unlock"])
		assert(not StatDefs.is_open(key, un - 1) or un <= 1,
			"해금 전인데 열려 있다: " + key)
		if bool(s.get("impl", true)):
			assert(StatDefs.is_open(key, un), "해금 단계인데 안 열린다: " + key)
		else:
			assert(not StatDefs.is_open(key, 9999),
				"구현 안 된 스탯이 열렸다: " + key)
		# 아이콘이 빠지면 빈 칸으로 남는다.
		assert(FileAccess.file_exists("res://assets/ui/%s.png" % str(s["icon"])),
			"아이콘 없음: " + str(s["icon"]))

	# 9) 상한 — 상한이 있는 스탯은 만렙에서 멈춘다(곱연산은 유한해야 한다).
	assert(StatDefs.at_cap("crit", 100))
	assert(not StatDefs.at_cap("crit", 99))
	assert(not StatDefs.at_cap("damage", 999999), "무한 스탯에 상한이 걸렸다")

	# 10) 치명타는 확률과 피해가 **둘 다** 올라야 값이 난다.
	assert(is_equal_approx(Balance.crit_mult(1, 1), 1.0), "1레벨에서 배수가 1이 아니다")
	var only_chance := Balance.crit_mult(50, 1)
	var only_dmg := Balance.crit_mult(1, 50)
	var both := Balance.crit_mult(50, 50)
	assert(both > only_chance and both > only_dmg, "치명타 두 축이 안 곱해진다")
	assert(is_equal_approx(only_dmg, 1.0), "확률 0인데 피해만으로 배수가 올랐다")
	# 확률은 100%에서 멈춘다 — 그 위로는 슈퍼 치명타로 승계한다(docs/STATS.md 3장).
	assert(is_equal_approx(Balance.crit_mult(101, 1), Balance.crit_mult(500, 1)))

	# 11) 스탯마다 비용 곡선이 다르다. 같으면 표를 안 읽고 있는 것이다.
	var c_dmg := Balance.upgrade_cost(50, 10.0, 1.15)
	var c_crit := Balance.upgrade_cost(50, 50.0, 1.35)
	assert(c_crit > c_dmg * 10.0, "상한 스탯이 무한 스탯보다 안 가파르다")

	# 12) 생존 수치 — 체력·방어구·회복이 실제 버티는 시간에 연결돼야 한다.
	var hp0 := Balance.hero_max_hp(1, 0.0)
	assert(is_equal_approx(hp0, 100.0), "기본 체력이 100이 아니다")
	assert(Balance.hero_max_hp(2, 0.0) > hp0, "체력 스탯이 최대 체력을 안 올린다")
	assert(Balance.hero_max_hp(1, 2.0) > hp0, "방어구가 최대 체력을 안 올린다")
	assert(is_equal_approx(Balance.hero_regen_per_sec(hp0, 1), 0.0))
	assert(Balance.hero_regen_per_sec(hp0, 2) > 0.0, "회복 스탯 효과가 없다")

	# 13) 몹 공격과 오프라인 판정은 난수 없이 같은 입력에 같은 결과를 내야 한다.
	var slow := Balance.foe_attack_interval(3.0)
	assert(slow > Balance.foe_attack_interval(1.0), "단단한 몹이 더 빠르게 친다")
	var survives := Balance.can_clear_stage(100.0, 0.0, 100.0,
		20, 10.0, 2, 4.0, 1.5)
	var fails := Balance.can_clear_stage(100.0, 0.0, 2.0,
		20, 10.0, 5, 40.0, 1.5)
	assert(survives and not fails, "오프라인 생존 판정이 공격/생존 차이를 못 가른다")
	# 제한 시간이 생긴 뒤로는 **버티기만으로는 못 넘는다.** 같은 입력이라도 시간이
	# 모자라면 오프라인도 멈춰야 실시간과 결과가 갈리지 않는다.
	# 위 survives 는 20마리 x 10 / dps 100 = 2초 + 접근 20 x 0.55 = 13초가 걸린다.
	var push20 := Balance.stage_seconds(20, 10.0, 100.0)
	assert(is_equal_approx(push20, 2.0 + 20.0 * Balance.APPROACH_SECONDS),
		"접근 시간이 구간 소요에 안 들어간다: %.1f초" % push20)
	assert(Balance.can_clear_stage(100.0, 0.0, 100.0, 20, 10.0, 2, 4.0, 1.5, push20 + 1.0),
		"시간이 남는데 제한에 걸린다")
	assert(not Balance.can_clear_stage(100.0, 0.0, 100.0, 20, 10.0, 2, 4.0, 1.5, push20 - 1.0),
		"제한 시간을 넘겼는데 통과한다")
	# 처리량 상한 — 몹이 화면 밖에서 걸어오므로 **DPS가 무한이어도** 동시 몹 수보다
	# 빨리 잡을 수 없다. 이걸 빼면 오프라인이 실시간으로는 못 넘는 구간을 넘어간다.
	# DPS 가 무한이어도 **접근 시간은 남는다** — 몹에게 달려가는 건 못 줄인다.
	assert(is_equal_approx(Balance.stage_seconds(60, 10.0, 1.0e9),
		60.0 * Balance.APPROACH_SECONDS), "DPS가 무한인데 접근 시간까지 사라진다")
	var flow2 := Balance.stage_seconds(60, 10.0, 1.0e9, 2, 2.33)
	var flow4 := Balance.stage_seconds(60, 10.0, 1.0e9, 4, 2.33)
	assert(flow2 > 60.0, "동시 2마리로 60마리를 60초에 잡을 수 있다고 나온다: %.1f초" % flow2)
	assert(flow4 < 60.0, "동시 4마리인데도 60초를 넘는다: %.1f초" % flow4)
	assert(flow2 > flow4, "칸이 늘었는데 더 오래 걸린다")
	# DPS가 모자라면 그쪽이 병목이다 — 둘 중 느린 쪽을 쓴다.
	assert(is_equal_approx(Balance.stage_seconds(60, 10.0, 1.0, 4, 2.33),
		Balance.push_seconds(60, 10.0, 1.0) + 60.0 * Balance.APPROACH_SECONDS),
		"DPS 병목일 때 처리량이 이긴다")
	# 구간 종류마다 시간이 다르고, 보스가 가장 길어야 한다.
	assert(StageDefs.time_limit(10) >= StageDefs.time_limit(1), "보스 제한이 더 짧다")
	for st in [1, 5, 10, 37, 100]:
		assert(StageDefs.time_limit(st) > 0.0, "제한 시간이 0 이하다: %d" % st)

	# 14) 대표 성장값별 처치시간. 장비·영웅 레벨을 빼 보수적으로 잡는다.
	# 첫 보스는 **가르치는 벽**이다. 맨몸으로는 제한 시간에 쫓기고, 조금 훈련하면 열린다.
	# 예전 검사는 "1레벨 올리면 열린다"였는데 그건 공격력이 레벨당 +100% 였을 때 얘기다 —
	# 합연산(+2%)에서는 한 레벨로 벽이 열리면 그게 오히려 이상하다.
	var starter_ttk := _foe_hp(10, "boss") / _build_dps(1, 1, 1, 1)
	var trained_ttk := _foe_hp(10, "boss") / _build_dps(40, 20, 5, 5)
	assert(starter_ttk > StageDefs.TIME_BOSS * 0.6,
		"첫 보스가 맨몸에도 너무 쉽다: %.0f초" % starter_ttk)
	assert(trained_ttk < StageDefs.TIME_BOSS * 0.6,
		"첫 보스가 훈련하고도 안 열린다: %.0f초" % trained_ttk)
	# 공격력은 **레벨당 +2% 합연산**이다. STATS 4장 검산표(DPS 배수)를 그대로 못 박는다 —
	# 이 검사가 곱연산으로 되돌리는 실수를 잡는다(곱연산이면 x70 / x479 / x8212 가 나온다).
	var base_dps := _build_dps(1, 1, 1, 1)
	var design := [
		{"name": "첫날", "stage": 50, "build": [60, 40, 10, 10], "dps_mult": 3.0},
		{"name": "1주", "stage": 500, "build": [200, 150, 35, 40], "dps_mult": 15.0},
		{"name": "1개월", "stage": 1000, "build": [600, 450, 80, 120], "dps_mult": 180.0},
		{"name": "3개월", "stage": 1000, "build": [1500, 1000, 100, 400], "dps_mult": 4000.0},
	]
	for point in design:
		var build: Array = point["build"]
		var build_dps := _build_dps(build[0], build[1], build[2], build[3])
		var mult := build_dps / base_dps
		var want := float(point["dps_mult"])
		# 설계표와 25% 안에서 맞아야 한다. 곱연산이면 20배 넘게 벌어져 바로 걸린다.
		assert(mult > want * 0.75 and mult < want * 1.25,
			"%s DPS 배수가 설계표와 다르다: x%.0f (설계 x%.0f)" % [point["name"], mult, want])
		var stage: int = point["stage"]
		var normal_ttk := _foe_hp(stage, "normal") / build_dps
		var mid_ttk := _foe_hp(stage, "midboss") / build_dps
		var boss_ttk := _foe_hp(stage, "boss") / build_dps
		# 구간은 **제한 시간 안에** 끝나야 한다. 예전엔 보스만 60초를 봤는데,
		# 60마리 구간이 제한을 넘는지가 실제로 막히는 자리다.
		var kills := StageDefs.kills_needed(stage - 1)   # 보스 구간 바로 앞 = 일반 구간
		var clear := Balance.stage_seconds(kills, _foe_hp(stage - 1, "normal"), build_dps,
			4, StageDefs.WAVE_WALK_SECONDS)
		assert(clear < StageDefs.TIME_NORMAL,
			"%s 일반 구간이 제한 시간을 넘는다: %.0f초" % [point["name"], clear])
		assert(mid_ttk < StageDefs.TIME_MIDBOSS,
			"%s 중간보스를 제한 시간 안에 못 잡는다: %.0f초" % [point["name"], mid_ttk])
		assert(boss_ttk < StageDefs.TIME_BOSS,
			"%s 보스를 제한 시간 안에 못 잡는다: %.0f초" % [point["name"], boss_ttk])
		print("TTK %-5s %-7s 일반 %.2fs (60마리 %.0f초) / 중간 %.1fs / 보스 %.1fs  DPS x%.0f"
			% [point["name"], StageDefs.label(stage), normal_ttk, clear,
			mid_ttk, boss_ttk, mult])

	# 15) 축약 표기. 자릿수를 한 칸 잘못 세면 조 단위가 천 단위로 보여서
	#     "얼마나 부자인지"가 통째로 거짓말이 된다.
	var main := load("res://Main.gd")
	assert(main._n(999.0) == "999", "네 자리 미만은 그대로 찍어야 한다")
	assert(main._n(1000.0) == "1k")
	assert(main._n(1400.0) == "1.4k")
	assert(main._n(1_100_000.0) == "1.1m")
	assert(main._n(2_700_000_000.0) == "2.7b")
	# 표 밖으로 나가도 마지막 단위에서 멈춘다 — 없는 단위를 지어내면 인덱스가 터진다.
	assert(main._n(5.0e15) == "5000t")

	# 16) 전투력 알림 — 오른 만큼이 있을 때만 뜬다.
	assert(main.power_toast(500.0, 0.0) == "", "안 올랐는데 알림이 뜬다")
	assert(main.power_toast(500.0, -100.0) == "", "내렸는데 알림이 뜬다")
	assert(main.power_toast(1400.0, 400.0) == "전투력 1.4k  ▲400")
	# 표시 중에 또 오르면 **합산**해서 보여 준다 — 연속 상승이 한 번으로 보이면 안 된다.
	assert(main.power_toast(1800.0, 800.0) == "전투력 1.8k  ▲800")

	print("Crit: 확률만 x%.2f / 피해만 x%.2f / 둘다 x%.2f"
		% [only_chance, only_dmg, both])
	print("BalanceTest OK  (10억으로 Lv%d 까지, 잔액 %.0f)" % [lv2, gold])
	quit()


func _build_dps(damage_lv: int, speed_lv: int, crit_lv: int, critdmg_lv: int) -> float:
	var hit := Balance.hero_damage(damage_lv, 0.0, 1) \
		* Balance.crit_mult(crit_lv, critdmg_lv)
	return Balance.auto_dps(hit, Balance.attack_interval(speed_lv), 0.70, 20.0, 6.0, 0.30)


func _foe_hp(at_stage: int, role: String) -> float:
	var act: Dictionary = StageDefs.act_data(at_stage)
	var hp_mult := 0.0
	if role == "boss":
		hp_mult = float(FoeTiers.get_tier(str(act["boss"]))["hp_mult"])
	else:
		for key in act["roster"]:
			hp_mult += float(FoeTiers.get_tier(str(key))["hp_mult"])
		hp_mult /= float((act["roster"] as Array).size())
	return FoeTiers.foe_hp(hp_mult, StageDefs.enemy_power(at_stage),
		role == "boss", role == "midboss")
