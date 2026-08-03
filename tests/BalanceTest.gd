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

	# 14) 대표 성장값별 처치시간. 장비·영웅 레벨을 빼 보수적으로 잡는다.
	var starter_ttk := _foe_hp(10, "boss") / _build_dps(1, 1, 1, 1)
	var first_upgrade_ttk := _foe_hp(10, "boss") / _build_dps(2, 1, 1, 1)
	assert(starter_ttk > 60.0 and first_upgrade_ttk < 60.0,
		"첫 보스가 성장 전에는 막고 첫 공격력 훈련 뒤에는 열리지 않는다")
	var checkpoints := [
		{"name": "첫날", "stage": 50, "build": [60, 40, 10, 10]},
		{"name": "1주", "stage": 500, "build": [200, 150, 35, 40]},
		{"name": "1개월", "stage": 1000, "build": [600, 450, 80, 120]},
	]
	for point in checkpoints:
		var build: Array = point["build"]
		var build_dps := _build_dps(build[0], build[1], build[2], build[3])
		var normal_ttk := _foe_hp(point["stage"], "normal") / build_dps
		var mid_ttk := _foe_hp(point["stage"], "midboss") / build_dps
		var boss_ttk := _foe_hp(point["stage"], "boss") / build_dps
		assert(boss_ttk < 60.0, "%s 대표 성장값으로 보스를 못 잡는다" % point["name"])
		print("TTK %-4s %s  일반 %.2fs / 중간 %.2fs / 보스 %.2fs  DPS %.1f"
			% [point["name"], StageDefs.label(point["stage"]), normal_ttk,
			mid_ttk, boss_ttk, build_dps])

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
	var role_mult := 12.0 if role == "boss" else (3.5 if role == "midboss" else 1.0)
	return 10.0 * hp_mult * StageDefs.enemy_power(at_stage) * role_mult
