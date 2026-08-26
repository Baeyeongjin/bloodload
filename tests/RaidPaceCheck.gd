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

	print("RaidPaceCheck OK")
	quit()
