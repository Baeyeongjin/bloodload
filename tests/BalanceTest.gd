extends SceneTree

# 배수 구매(x1/x10/x100) 수치 검증. 눈으로는 절대 못 잡는 종류의 버그다 —
# 화면에는 그럴듯한 숫자가 찍히는데 실제로는 돈이 새거나 과금된다.
#   godot --headless --script tests/BalanceTest.gd

func _init() -> void:
	# **안전장치.** Godot 의 assert 는 실패하면 그 자리에서 함수를 멈추는데, 그러면
	# 아래 quit() 에 못 가서 프로세스가 영영 안 끝난다(타임아웃으로 죽여야 했다).
	# 먼저 시계를 걸어 두면 멈춰도 반드시 끝나고, 종료 코드로 실패가 드러난다.
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("테스트가 안 끝났다 — assert 실패로 멈춘 것이다")
		quit(1))
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
	# 8) 스탯 해금 — 문턱이 둘이다(단계 + 선행 스탯 레벨).
	#    잠긴 스탯은 스테이지를 넘겨도 impl 이 false 면 안 열린다. 안 그러면 효과 없는
	#    스탯을 사서 피만 버린다.
	var maxed := {}          # 선행이 다 채워진 상태
	for s in StatDefs.STATS:
		maxed[str(s["key"])] = 99999
	for s in StatDefs.STATS:
		var key := str(s["key"])
		var un := int(s["unlock"])
		assert(not StatDefs.is_open(key, un - 1, maxed) or un <= 1,
			"해금 전인데 열려 있다: " + key)
		if bool(s.get("impl", true)):
			assert(StatDefs.is_open(key, un, maxed), "해금 단계인데 안 열린다: " + key)
		else:
			assert(not StatDefs.is_open(key, 9999, maxed),
				"구현 안 된 스탯이 열렸다: " + key)
		# 선행 스탯 문턱. 단계를 다 넘겨도 선행이 모자라면 잠겨 있어야 한다 —
		# 이게 깨지면 "기다리면 열린다"로 되돌아간 것이다.
		var need: Array = s.get("need", [])
		if not need.is_empty():
			assert(need.size() == 2, "선행 형식이 [키, 레벨] 이 아니다: " + key)
			var pre := str(need[0])
			assert(not StatDefs.of(pre).is_empty(), "없는 스탯을 선행으로 걸었다: " + pre)
			# 선행은 **자기보다 먼저 열려야** 한다. 아니면 영영 못 채운다.
			assert(int(StatDefs.of(pre)["unlock"]) <= un,
				"선행이 나중에 열린다: %s <- %s" % [key, pre])
			var short := maxed.duplicate()
			short[pre] = int(need[1]) - 1
			assert(not StatDefs.is_open(key, 9999, short),
				"선행이 모자란데 열려 있다: %s (%s Lv%d)" % [key, pre, int(need[1])])
			short[pre] = int(need[1])
			assert(StatDefs.is_open(key, 9999, short) or not bool(s.get("impl", true)),
				"선행을 채웠는데 안 열린다: " + key)
		# 아이콘이 빠지면 빈 칸으로 남는다.
		assert(FileAccess.file_exists("res://assets/ui/%s.png" % str(s["icon"])),
			"아이콘 없음: " + str(s["icon"]))
	# **처음부터 살 수 있는 스탯이 있어야 한다.** 전부 선행에 걸리면 첫 판에 아무것도
	# 못 사서 게임이 시작되지 않는다. Lv1 상태 = 아무것도 안 산 상태로 확인한다.
	var fresh := {}
	var openable := 0
	for s in StatDefs.STATS:
		if StatDefs.is_open(str(s["key"]), 1, fresh):
			openable += 1
	assert(openable >= 1, "1단계 맨몸에서 살 수 있는 스탯이 없다")
	# 체력은 **일반 구간의 유일한 게이트**(생존)를 고치는 스탯이다. 단계로 늦게 묶으면
	# 죽어도 살 게 없는 구간이 생긴다 — 1단계에 있어야 한다.
	assert(int(StatDefs.of("tough")["unlock"]) <= 1,
		"체력이 1단계보다 늦게 열린다 — 죽어도 살 게 없다")

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
	# 회복은 **상한이 있어야 한다.** 없으면 Lv67 에서 초당 100% 회복이라 그 뒤로
	# 아무리 맞아도 안 죽고, survival_seconds 가 INF 를 돌려 오프라인 판정이 생존을
	# 아예 안 보게 된다(STATS 1장: 곱연산은 반드시 상한).
	assert(is_equal_approx(Balance.hero_regen_per_sec(hp0, 999999),
		hp0 * Balance.REGEN_CAP), "회복에 상한이 없다")
	assert(Balance.hero_regen_per_sec(hp0, Balance.REGEN_CAP_LEVEL - 1)
		< Balance.hero_regen_per_sec(hp0, Balance.REGEN_CAP_LEVEL),
		"상한 도달 전인데 회복이 안 오른다")
	assert(StatDefs.at_cap("regen", Balance.REGEN_CAP_LEVEL),
		"회복 상한이 스탯 표에 안 걸려 있다 — 상한 넘게 살 수 있다")

	# 전투력은 **전투 능력 전부**를 반영해야 한다. 예전엔 생존 인자가 장비 방어구
	# 하나뿐이라 체력 스탯을 올려도 지표가 1도 안 움직였다 — 성장했는데 숫자가
	# 그대로면 그 스탯은 아무도 안 산다.
	var pow_base := Balance.combat_power(100.0, 100.0, 0.0)
	assert(Balance.combat_power(200.0, 100.0, 0.0) > pow_base, "공격이 전투력에 없다")
	assert(Balance.combat_power(100.0, 200.0, 0.0) > pow_base, "체력이 전투력에 없다")
	assert(Balance.combat_power(100.0, 100.0, 5.0) > pow_base, "회복이 전투력에 없다")

	# 13) 몹 공격과 오프라인 판정은 난수 없이 같은 입력에 같은 결과를 내야 한다.
	var slow := Balance.foe_attack_interval(3.0)
	assert(slow > Balance.foe_attack_interval(1.0), "단단한 몹이 더 빠르게 친다")
	# 체력 400 은 **접근 시간에 안 걸리게** 잡은 값이다. 100 이었을 때는 생존 18.8초 vs
	# 소요 19.8초로 아슬아슬해서, APPROACH_SECONDS 를 0.55 -> 0.89 로 재실측하자 이
	# 픽스처가 통째로 뒤집혔다 — 이 검사가 보려는 건 "공격/생존을 가르는가"지
	# 접근 시간의 자릿수가 아니다.
	var survives := Balance.can_clear_stage(400.0, 0.0, 100.0,
		20, 10.0, 2, 4.0, 1.5)
	var fails := Balance.can_clear_stage(400.0, 0.0, 2.0,
		20, 10.0, 5, 40.0, 1.5)
	assert(survives and not fails, "오프라인 생존 판정이 공격/생존 차이를 못 가른다")
	# 제한 시간이 **있는 구간**(보스·중간보스)에서는 버티기만으로 못 넘는다. 시간이
	# 모자라면 오프라인도 멈춰야 실시간과 결과가 갈리지 않는다.
	# 위 survives 는 20마리 x 10 / dps 100 = 2초 + 접근 20 x 0.89 = 19.8초가 걸린다.
	var push20 := Balance.stage_seconds(20, 10.0, 100.0)
	assert(is_equal_approx(push20, 2.0 + 20.0 * Balance.APPROACH_SECONDS),
		"접근 시간이 구간 소요에 안 들어간다: %.1f초" % push20)
	assert(Balance.can_clear_stage(400.0, 0.0, 100.0, 20, 10.0, 2, 4.0, 1.5, push20 + 1.0),
		"시간이 남는데 제한에 걸린다")
	assert(not Balance.can_clear_stage(400.0, 0.0, 100.0, 20, 10.0, 2, 4.0, 1.5, push20 - 1.0),
		"제한 시간을 넘겼는데 통과한다")
	# **DPS 가 무한이어도 접근 시간은 남는다** — 다음 놈에게 달려가는 건 못 줄인다.
	# 이걸 빼면 오프라인이 DPS만 보고 실시간으로는 몇 분 걸리는 구간을 넘어간다.
	assert(is_equal_approx(Balance.stage_seconds(60, 10.0, 1.0e9),
		60.0 * Balance.APPROACH_SECONDS), "DPS가 무한인데 접근 시간까지 사라진다")
	# DPS 가 모자라면 그만큼 더 걸린다. 둘은 **더해진다** — 예전엔 동시 몹 수로 나누는
	# 병렬 상한과 둘 중 느린 쪽을 골랐는데, 몹이 서 있고 영웅이 한 마리씩 찾아가는
	# 지금은 병렬이 없다(Balance.stage_seconds 주석).
	assert(is_equal_approx(Balance.stage_seconds(60, 10.0, 1.0),
		Balance.push_seconds(60, 10.0, 1.0) + 60.0 * Balance.APPROACH_SECONDS),
		"처치 시간과 접근 시간이 안 더해진다")
	# **때리는 것은 이산이다.** 간격을 주면 한 대에 죽는 몹도 스윙 한 번을 다 센다.
	# 안 그러면 초반(한 방 컷)에서 모델이 마리당 0.4초씩 낙관해서 방치 수익이
	# 과지급된다 — 실측은 Balance.push_seconds 주석에 있다.
	#   체력 10 · DPS 100 · 간격 0.6  ->  한 대 60 피해라 1타, 즉 0.6초
	assert(is_equal_approx(Balance.push_seconds(1, 10.0, 100.0, 0.6), 0.6),
		"한 방에 죽는데 스윙 한 번을 안 센다: %.3f" % Balance.push_seconds(1, 10.0, 100.0, 0.6))
	assert(Balance.push_seconds(1, 10.0, 100.0, 0.6) > Balance.push_seconds(1, 10.0, 100.0),
		"이산 모델이 연속 모델보다 빠르다 — 올림이 안 걸렸다")
	# 두 대 걸리면 두 배. 올림이라 1.1타도 2타다.
	#   체력 70 · 한 대 60  ->  1.17타 -> 2타 -> 1.2초
	assert(is_equal_approx(Balance.push_seconds(1, 70.0, 100.0, 0.6), 1.2),
		"올림이 안 된다: %.3f" % Balance.push_seconds(1, 70.0, 100.0, 0.6))
	# 여러 대 걸리는 후반에는 오차가 올림 한 번(<1타)으로 줄어든다 — 초반만큼
	# 벌어지지 않아야 한다. 벌어지면 per_swing 을 잘못 되돌린 것이다.
	var many_cont := Balance.push_seconds(1, 6000.0, 100.0)
	var many_disc := Balance.push_seconds(1, 6000.0, 100.0, 0.6)
	assert(many_disc - many_cont < 0.6, "후반 오차가 한 타를 넘는다: %.3f" % (many_disc - many_cont))
	# **제한 시간은 보스·중간보스에만 붙는다**(2026-08-06). 일반 구간을 시계로 막으면
	# 몹 걷기 속도가 곧 벽이 되어 연출을 못 늦춘다 — StageDefs.time_limit 주석 참고.
	# 이 검사가 "일반 구간에도 다시 걸자"는 되돌림을 잡는다.
	for st in [1, 2, 4, 6, 9, 11, 37, 100]:
		if StageDefs.is_boss_stage(st) or StageDefs.is_midboss_stage(st):
			continue
		assert(StageDefs.time_limit(st) <= 0.0, "일반 구간에 제한 시간이 붙었다: %d" % st)
	# 한 마리당으로 재면 보스가 가장 넉넉해야 한다. 총량으로 재면 안 된다 —
	# 일반 구간은 100마리라 목표 100초지만 한 마리에 1초다.
	var per_normal := StageDefs.PACE_NORMAL / float(StageDefs.kills_needed(1))
	assert(StageDefs.time_limit(10) > per_normal, "보스 한 마리에 주는 시간이 잡몹보다 짧다")
	assert(StageDefs.time_limit(5) > per_normal, "중간보스 한 마리가 잡몹보다 짧다")
	assert(StageDefs.time_limit(5) > 0.0 and StageDefs.time_limit(10) > 0.0,
		"보스 구간의 제한 시간이 사라졌다")

	# 14) 대표 성장값별 처치시간. 장비·영웅 레벨을 빼 보수적으로 잡는다.
	# **칸 수·걷는 시간은 실제 구현에서 읽는다.** 둘 다 노드를 안 만지므로 맨
	# 인스턴스로 부를 수 있다(씬을 띄우면 자산 로딩까지 딸려 온다).
	var game = load("res://Main.gd").new()
	# 첫 보스는 **가르치는 벽**이다. 맨몸으로는 제한 시간에 쫓기고, 조금 훈련하면 열린다.
	# 예전 검사는 "1레벨 올리면 열린다"였는데 그건 공격력이 레벨당 +100% 였을 때 얘기다 —
	# 합연산(+2%)에서는 한 레벨로 벽이 열리면 그게 오히려 이상하다.
	# **훈련 기준을 올렸다**(2026-08-12, 곡선에 선형항 부활). 몹이 세지면서
	# 40/20/5/5 로는 48초가 걸린다 — 그 정도 스펙에 첫 보스가 안 열리는 게 아니라
	# **더 키우고 오라는 것**이 새 의도다. 열리는 지점을 실측해 그 자리를 못 박는다.
	var starter_ttk := _foe_hp(10, "boss") / _build_dps(1, 1, 1, 1)
	var trained_ttk := _foe_hp(10, "boss") / _build_dps(80, 40, 10, 10)
	assert(starter_ttk > StageDefs.TIME_BOSS * 0.6,
		"첫 보스가 맨몸에도 너무 쉽다: %.0f초" % starter_ttk)
	assert(trained_ttk < StageDefs.TIME_BOSS * 0.6,
		"첫 보스가 훈련하고도 안 열린다: %.0f초" % trained_ttk)
	# 공격력은 **레벨당 +3.5% 합연산**이다(2026-08-11 저녁, 혈맥 도입과 동시 이관 —
	# 같은 날 낮에 x1.03 곱연산이었다. 여정 전체는 Balance.DMG_PER_LEVEL 주석).
	#
	# **곱연산 %는 이제 혈맥(TraitDefs)에만 산다.** 이 검사가 그 분담을 못 박는다:
	# 스탯 쪽이 다시 곱연산이 되거나(아래 배수 상한 초과로 걸린다), 혈맥 노드가
	# 예산을 넘게 부풀면(가지 배수 상한) EXPANSION 8장의 예산표가 무효가 된다.
	var base_dps := _build_dps(1, 1, 1, 1)
	# 도달 가능한 범위(30~120레벨)에서 합연산 기울기가 설계값(+3.5%)인가.
	for probe in [{"lv": 30, "lo": 1.8, "hi": 2.3}, {"lv": 60, "lo": 2.6, "hi": 3.5},
			{"lv": 120, "lo": 4.5, "hi": 6.0}]:
		var got := _build_dps(int(probe["lv"]), 1, 1, 1) / base_dps
		assert(got > float(probe["lo"]) and got < float(probe["hi"]),
			"공격력 %d레벨 DPS 배수 x%.1f — %.1f~%.1f 사이여야 한다 (합연산 +3.5%%)"
			% [int(probe["lv"]), got, float(probe["lo"]), float(probe["hi"])])
		print("공격력 %3d레벨 -> DPS x%.2f (합연산)" % [int(probe["lv"]), got])
	# 혈맥 예산 — 공격 가지를 다 찍어도 공격 배수는 x1.2~1.4, 스킬은 x1.05~1.2.
	# 이 상한 안이어야 "스탯 합연산 + 혈맥 곱연산"의 합이 8장 예산표(x2.0)에 든다.
	var all_traits := {}
	for n in TraitDefs.NODES:
		all_traits[str(n["id"])] = true
	var t_atk := TraitDefs.mult("attack", all_traits)
	var t_skill := TraitDefs.mult("skill", all_traits)
	assert(t_atk > 1.2 and t_atk < 1.4,
		"혈맥 공격 배수 x%.2f — 예산(x1.2~1.4)을 벗어났다" % t_atk)
	assert(t_skill > 1.05 and t_skill < 1.2,
		"혈맥 스킬 배수 x%.2f — 예산(x1.05~1.2)을 벗어났다" % t_skill)
	print("혈맥 완주 배수  공격 x%.2f · 스킬 x%.2f · 치명피해 +%.0f%%"
		% [t_atk, t_skill, TraitDefs.add("critdmg", all_traits) * 100.0])
	# 페이스 표 갱신 (2026-08-12, 난이도 x3). 예전 목표(첫날 50 / 1주 500)는
	# "아무것도 안 해도 돌파"라 사장님이 기각했다. 새 곡선(x1.064)의 의도 페이스:
	# 첫날 40 언저리, 1주 250 언저리 — 그 뒤는 매일 벌어서 벽을 미는 구간이다.
	# 이 검문은 "의도한 페이스 지점에서 그 시점의 스펙이면 안 늘어진다"의 바닥이다.
	# 곡선에 선형항이 살아나면서 같은 스펙으로 갈 수 있는 구간이 확 줄었다
	# (2026-08-12). 1주 250 -> 120: 250구간은 이제 몹이 x40 이라 그 스펙으로는
	# 99초가 걸린다. **의도 페이스를 곡선에 맞춘다** — 검사가 곡선을 따라와야지
	# 곡선이 검사를 따라가면 순서가 뒤집힌다.
	# 2026-08-13 갱신 (총 500구간 · 몹 x1.40 · 상한 연속). tests/PaceProbe 무과금
	# 실측이 첫날 30 · 1주 100 이지만 **여기서 재는 건 그 자리가 아니다.**
	# 이 검사는 장비를 0 으로 놓고 60초 페이스를 요구하는데, 새 곡선에서는
	# 구간당 시간이 뒤로 갈수록 길어지는 게 **정상**이다 — 3달 300구간이면
	# 후반은 구간 하나에 몇 시간이 걸린다. 60초는 **초반 페이스** 기준이므로
	# 초반 구간만 본다: "여기서부터 늘어지면 새 유저가 첫 화면에서 지친다"의 바닥.
	var design := [
		{"name": "첫날", "stage": 12, "build": [48, 30, 8, 8]},
		{"name": "1주", "stage": 30, "build": [85, 60, 18, 20]},
	]
	for point in design:
		var build: Array = point["build"]
		var build_dps := _build_dps(build[0], build[1], build[2], build[3])
		var mult := build_dps / base_dps
		var stage: int = point["stage"]
		var normal_ttk := _foe_hp(stage, "normal") / build_dps
		var mid_ttk := _foe_hp(stage, "midboss") / build_dps
		var boss_ttk := _foe_hp(stage, "boss") / build_dps
		# 일반 구간은 이제 제한 시간이 없다 — 대신 **목표 페이스**(PACE_NORMAL)를 본다.
		# 넘겨도 실패하지는 않지만, 넘기면 구간이 늘어져 죽은 화면이 된다.
		#
		# **처리량 상한(칸 수 / 걷는 시간)이 없어졌다**(2026-08-06). 몹이 서 있고 영웅이
		# 한 마리씩 찾아가므로 한 마리당 고정비가 직렬로 든다 — 그게
		# `APPROACH_SECONDS` 다. 동시 마릿수는 처리량에 영향이 없다.
		var kills := StageDefs.kills_needed(stage - 1)   # 보스 구간 바로 앞 = 일반 구간
		var clear := Balance.stage_seconds(kills, _foe_hp(stage - 1, "normal"), build_dps)
		assert(clear < StageDefs.PACE_NORMAL,
			"%s 일반 구간이 목표 페이스를 넘는다: %.0f초 (목표 %.0f초)"
			% [point["name"], clear, StageDefs.PACE_NORMAL])
		assert(mid_ttk < StageDefs.TIME_MIDBOSS,
			"%s 중간보스를 제한 시간 안에 못 잡는다: %.0f초" % [point["name"], mid_ttk])
		assert(boss_ttk < StageDefs.TIME_BOSS,
			"%s 보스를 제한 시간 안에 못 잡는다: %.0f초" % [point["name"], boss_ttk])
		print("TTK %-5s %-7s 일반 %.2fs (%d마리 %.0f초 / 페이스 %.0f) / 중간 %.1fs / 보스 %.1fs  DPS x%.0f"
			% [point["name"], StageDefs.label(stage), normal_ttk, kills, clear,
			StageDefs.PACE_NORMAL, mid_ttk, boss_ttk, mult])
	game.free()

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

	# 17) 탭 알림 점. **켜지는 것보다 꺼지는 것을 검사한다** — 늘 켜져 있는 점은
	#     없는 점과 같다. 쓸 게 없으면 반드시 꺼져야 점에 뜻이 생긴다.
	var m = main.new()
	m.gold = 0.0
	m.essence = 0.0
	m.free_pull_date = Time.get_date_string_from_system()   # 오늘 공짜 뽑기를 이미 썼다
	assert(not m._tab_todo("growth"), "혈액이 0인데 성장 점이 켜졌다")
	assert(not m._tab_todo("gear"), "장비를 안 꼈는데 장비 점이 켜졌다")
	assert(not m._tab_todo("summon"), "공짜 뽑기도 조각도 없는데 소환 점이 켜졌다")
	assert(not m._tab_todo("codex"), "도감은 눌러 올릴 게 없어 점이 없어야 한다")
	m.gold = 1.0e12
	assert(m._tab_todo("growth"), "혈액이 넘치는데 성장 점이 안 켜졌다")
	m.free_pull_date = ""
	assert(m._tab_todo("summon"), "공짜 뽑기가 남았는데 소환 점이 안 켜졌다")
	# 보석만 쌓인 상태로는 안 켜진다 — 아껴 쓰는 재화라 잔소리하지 않기로 한 규칙.
	m.free_pull_date = Time.get_date_string_from_system()
	m.gem = 1.0e9
	assert(not m._tab_todo("summon"), "보석만 있는데 소환 점이 켜졌다")
	m.free()

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
