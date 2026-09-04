extends SceneTree
# 재화 던전이 **판**인가. 예전엔 셋 다 3초에 끝났다(사장님: "왜 이리 쉽노").
#
# 시간을 손으로 적지 않고 **게임과 같은 공식으로** 계산한다 — 상수를 만지면
# 이 검사가 바로 답을 준다.

func _init() -> void:
	# **가드.** 이게 없으면 assert 가 깨져도 SceneTree 가 안 죽어서 실패가
	# "타임아웃"으로 둔갑한다 — TicketCheck 를 그렇게 몇 주 오진했다.
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 버티기(제단)가 처치로 안 끝나는가 — 예전 버그의 자리 ────────────────
	scene.raid_on = "pact"
	scene.kills = 0
	assert(RaidDefs.kills_needed("pact") == 0, "제단이 처치를 판정으로 쓴다")
	for k in [1, 3, 50]:
		scene.kills = k
		assert(not scene._c_kill_clear(),
			"제단에서 %d마리 잡았다고 판이 끝난다" % k)
	# 다른 던전은 처치가 판정이다.
	scene.raid_on = "blood"
	scene.kills = RaidDefs.SWARM_KILLS - 1
	assert(not scene._c_kill_clear(), "동굴이 한 마리 모자란데 끝났다")
	scene.kills = RaidDefs.SWARM_KILLS
	assert(scene._c_kill_clear(), "동굴이 다 잡았는데 안 끝난다")
	scene.raid_on = ""

	# ── 한 판이 몇 초인가 ──────────────────────────────────────────────────
	# **설계 기준점에서 잰다.** 씬의 영웅을 그대로 쓰면 안 된다 — 갓 만든
	# 영웅은 1레벨인데 던전 몹은 25구간이라 2334초가 나온다(실측). 실제로는
	# 25구간을 밟아야 던전이 열리므로 그때의 화력으로 재야 뜻이 있다.
	#
	# 마리당 = 처치 + 달려가기. **달려가는 시간은 체력과 무관하다** — 이걸
	# 빼먹어서 구간 처치수를 처음에 잘못 잡았다(KILLS_PER_STAGE 주석).
	var ttk := 0.75          # 일반 몹 처치시간 (BalanceTest 가 찍는 값)
	var speed := 200.0       # Main.TRAVEL_SPEED
	var raid_per := ttk * RaidDefs.SWARM_HP_MULT + RaidDefs.SWARM_GAP / speed
	var raid_time := raid_per * float(RaidDefs.SWARM_KILLS)
	assert(raid_time < RaidDefs.TIME_LIMIT,
		"물량 던전이 %.0f초 — 제한 %.0f초 안에 못 끝낸다"
		% [raid_time, RaidDefs.TIME_LIMIT])
	assert(raid_time > RaidDefs.TIME_LIMIT * 0.6,
		"물량 던전이 %.0f초 — 제한의 60%%도 안 쓰면 판이 아니다" % raid_time)
	# 본편 한 구간과 견줘 본다 — 하루 3판짜리가 본편 한 구간보다 가벼우면
	# "던전"이라는 이름값을 못 한다.
	var stage_time := (ttk + 160.0 / speed) * float(StageDefs.KILLS_PER_STAGE)
	assert(raid_time > stage_time * 0.6,
		"던전 %.0f초 vs 본편 한 구간 %.0f초 — 너무 가볍다" % [raid_time, stage_time])
	print("  물량 던전 %.0f초 / 제한 %.0f초 (%d마리) · 본편 한 구간 %.0f초"
		% [raid_time, RaidDefs.TIME_LIMIT, RaidDefs.SWARM_KILLS, stage_time])

	# 물량 판은 빽빽해야 한다 — 간격이 넓으면 100마리가 달리기 100번이 된다.
	assert(RaidDefs.wave_size("blood", 6) > 6, "물량 판인데 몹이 안 늘었다")
	assert(RaidDefs.foe_gap("blood", 160.0) < 160.0, "물량 판인데 줄이 안 좁다")
	# 단일 강적은 **한 마리**다 — 여섯이 서면 각자 보스 체력이라 판이 안 끝난다.
	assert(RaidDefs.wave_size("forge", 6) == 1, "성소에 수호자가 여럿 선다")

	# ── 이 판이 시간 안에 깰 수 있는가 (2026-09-02) ──────────────────────
	# **이게 없어서 물량 판이 수학적으로 불가능한 채로 나갔다.** 설계 때 쓴
	# 모델이 시체 대기와 임팩트 지연을 빼먹어 38% 낙관이었고(주석의
	# "0.49초 x 100 = 49초"), 실제로는 60초에 88.5마리라 요구 100마리를
	# **공격력을 무한대로 올려도** 못 넘겼다. 사장님이 체감으로 찾았다.
	#
	# 마리당 최소 주기 = 임팩트 지연 + max(시체 대기, 간격 / 전진속도).
	# 앞뒤 둘은 **병렬**이다 — 몹이 죽는 순간 전진이 시작되고 대기도 같이 흐른다.
	var M := load("res://Main.gd")
	var impact: float = M.ATTACK_SWING * 0.759   # 3연격 임팩트 프레임 평균(실측)
	for kind in RaidDefs.RAIDS:
		var k := str(kind)
		if RaidDefs.goal(k) != "swarm":
			continue
		var gap: float = RaidDefs.foe_gap(k, M.FOE_GAP)
		var pause: float = RaidDefs.engage_pause(k, M.ENGAGE_PAUSE)
		var per: float = impact + maxf(pause, gap / M.TRAVEL_SPEED)
		var cap: float = RaidDefs.time_limit(k) / per
		var need: float = float(RaidDefs.kills_needed(k))
		# **한 방 컷이어도** 이만큼이 상한이다. 여유가 없으면 그 판은
		# 성장으로 못 여는 판이다.
		assert(cap >= need * 1.10,
			"%s: 한 방 컷 상한 %.1f마리인데 요구가 %.0f마리다 (마리당 %.3f초) — 여유 10%% 미만"
			% [k, cap, need, per])
	# **간격이 실제로 레버인가.** 시체 대기가 간격보다 크면 간격을 아무리
	# 좁혀도 한 마리도 안 는다 — 예전에 그 상태였다.
	for kind2 in RaidDefs.RAIDS:
		var k2 := str(kind2)
		if RaidDefs.goal(k2) != "swarm":
			continue
		var gap2: float = RaidDefs.foe_gap(k2, M.FOE_GAP)
		assert(gap2 / M.TRAVEL_SPEED > RaidDefs.engage_pause(k2, M.ENGAGE_PAUSE),
			"%s: 시체 대기가 이동보다 길다 — 간격을 좁혀도 아무 일도 안 일어난다" % k2)
	# 본편은 안 건드린다 — 그 박자에 수입 곡선이 걸려 있다.
	assert(is_equal_approx(RaidDefs.engage_pause("forge", M.ENGAGE_PAUSE),
		M.ENGAGE_PAUSE), "단일 강적 판까지 대기를 줄였다")

	print("RaidPaceCheck OK  (판 시간 · 물량 상한 · 간격이 레버인가)")
	quit()
