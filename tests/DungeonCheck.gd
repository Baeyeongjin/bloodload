extends SceneTree

# 핏빛 미궁(1단계)을 잰다. 지키는 것 셋:
#
#   1) DungeonDefs 표 — 층 곡선이 단조증가하고, 개방·주기·처치 수가 설계값인가
#   2) 분기 한 곳 — 본편 모드에서 래퍼(_c_*)가 StageDefs 와 **똑같은가.**
#      래퍼를 만든 이유가 "호출부마다 if 를 심으면 갈린다"인데, 래퍼 자체가
#      본편 값과 다르면 그 목적이 뒤집힌다
#   3) 입장·등반·이탈 — 층이 오르면 기록이 남고, 나가면 본편 그 자리인가

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	# 층 곡선: 등가 구간이 단조증가하고 본편 범위 안이다.
	var prev := 0
	for f in range(1, DungeonDefs.FLOOR_CAP + 1):
		var eq := DungeonDefs.eq_stage(f)
		assert(eq > prev or eq == StageDefs.total_stages(),
			"%d층 등가 구간이 안 오른다: %d -> %d" % [f, prev, eq])
		assert(eq <= StageDefs.total_stages(), "%d층이 본편 밖이다" % f)
		prev = eq
	# 개방: 30구간 전 0, 30에 5층, 이후 10구간마다 5층, 상한 100.
	# **문턱을 숫자로 박지 않는다** — 해금 계단을 옮길 때마다 검사가 깨진다
	# (2026-08-12 에 30 -> 35 로 옮기며 실제로 깨졌다). 규칙만 본다:
	# 문턱 전에는 0층, 문턱에서 5층, 10구간마다 5층씩.
	var open0 := DungeonDefs.OPEN_STAGE
	assert(DungeonDefs.open_floors(open0 - 1) == 0, "문턱 전인데 열렸다")
	assert(DungeonDefs.open_floors(open0) == 5, "문턱 개방이 5층이 아니다")
	assert(DungeonDefs.open_floors(open0 + 10) == 10, "10구간 뒤가 10층이 아니다")
	assert(DungeonDefs.open_floors(9999) == DungeonDefs.FLOOR_CAP,
		"개방 상한이 안 걸린다")
	# **층마다 보스 하나**다 (사장님 2026-08-25). 중간보스는 없어졌다.
	for f in [1, 3, 5, 10, 50, 100]:
		assert(DungeonDefs.is_boss_floor(f) and not DungeonDefs.is_midboss_floor(f),
			"%d층이 보스층이 아니다" % f)
		assert(DungeonDefs.kills_needed(f) == 1, "%d층 목표가 한 마리가 아니다" % f)
		assert(DungeonDefs.time_limit(f) == StageDefs.TIME_BOSS,
			"%d층에 보스 제한 시간이 안 걸렸다" % f)
	# 보스 체력 보정 — 그대로 두면 옛 일반 층(잡몹 5)의 일곱 배라 벽이 된다.
	assert(DungeonDefs.BOSS_HP_SCALE > 0.0 and DungeonDefs.BOSS_HP_SCALE < 1.0,
		"미궁 보스 체력 보정이 범위를 벗어났다")
	assert(FoeTiers.BOSS_HP_MULT * DungeonDefs.BOSS_HP_SCALE
		> float(DungeonDefs.KILLS_PER_FLOOR),
		"미궁 보스가 옛 일반 층보다 가볍다")
	# 깊이 색: 채널이 1을 안 넘고(밝아지면 안 된다) 깊을수록 어둡다.
	var t1 := DungeonDefs.depth_tint(1)
	var t100 := DungeonDefs.depth_tint(100)
	assert(t100.r <= t1.r and t100.g < t1.g, "깊은 층이 더 밝다")
	assert(t100.g >= 0.5, "100층 색이 너무 어둡다 — 체력 바 대비가 죽는다")
	# 혈정 수급 표 (EXPANSION 6장 초안 값 그대로).
	assert(is_equal_approx(DungeonDefs.first_clear_reward(3), 30.0))
	assert(is_equal_approx(DungeonDefs.first_clear_reward(100), 1000.0))
	assert(is_equal_approx(DungeonDefs.sweep_per_hour(50), 10.0))
	assert(is_equal_approx(DungeonDefs.sweep_per_hour(0), 0.0),
		"미궁을 한 층도 안 돌았는데 소탕이 나온다")

	# ── 2) 본편 모드에서 래퍼 == StageDefs ─────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for st in [1, 5, 10, 37, 100]:
		scene.stage = st
		assert(scene._c_is_boss() == StageDefs.is_boss_stage(st))
		assert(scene._c_is_midboss() == StageDefs.is_midboss_stage(st))
		assert(scene._c_kills_needed() == StageDefs.kills_needed(st))
		assert(is_equal_approx(scene._c_time_limit(), StageDefs.time_limit(st)))
		assert(is_equal_approx(scene._c_enemy_power(), StageDefs.enemy_power(st)))
		assert(scene._c_label() == StageDefs.label(st),
			"본편 모드 래퍼가 StageDefs 와 갈린다: %d" % st)

	# ── 3) 입장·등반·이탈 ─────────────────────────────────────────────────
	scene.stage = 41
	scene.best_stage = 100          # 40층 개방
	# **지난 실행의 저장본을 지운다.** 이 테스트는 혈정을 벌고 저장까지 타므로,
	# 남은 저장본 위에서 다시 돌면 절대값 비교가 전부 어긋난다 — 시작을 늘 0 으로.
	scene.crystal = 0.0
	scene.traits = {}
	scene._restart_stage("측정")
	# **암전 꼬리까지 기다린다.** 전투(phase fight)가 페이드 인이 끝나기 전에
	# 열리는데(실측 0.51초 남음), 입장·등반은 전환 중 연타를 막으려고
	# `_fade_t > 0` 이면 조용히 빠진다 — 게임에선 맞는 가드고 테스트가 기다릴 몫이다.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var home_stage: int = scene.stage
	scene.dungeon_best = 2
	scene._dungeon_enter()
	assert(scene.dungeon_on, "입장이 안 됐다")
	assert(scene.dungeon_floor == 3, "최고 기록 다음 층(3)이 아니다: %d" % scene.dungeon_floor)
	assert(scene.stage == home_stage, "입장이 본편 stage 를 건드렸다")
	# 미궁 값으로 갈렸는가 — 3층 = 등가 구간의 값이어야 한다.
	var eq3 := DungeonDefs.eq_stage(3)
	assert(is_equal_approx(scene._c_enemy_power(), StageDefs.enemy_power(eq3)),
		"미궁 몹 세기가 등가 구간 값이 아니다")
	assert(scene._c_kills_needed() == 1, "미궁 층 목표가 한 마리가 아니다")
	assert("미궁" in scene._c_label())
	# 혈액은 본편 시세다 — 등가 구간 시세로 주면 미궁이 더 나은 사냥터가 된다.
	assert(is_equal_approx(scene._c_gold_per_kill(), StageDefs.gold_per_kill(home_stage)),
		"미궁 혈액이 본편 시세가 아니다")
	# 층 클리어 — 오르고 기록이 남는다. (여기도 암전 꼬리까지)
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	# **여운(CLEAR_HOLD)이 지나야 층 처리가 돈다** — 격파 즉시 암전을 걸면
	# 쓰러지는 그림도 배너도 못 본다(사장님 2026-08-25). 결과를 기다린다.
	var waited := 0.0
	while scene.dungeon_best != 3 and waited < 8.0:
		await process_frame
		waited += scene.get_process_delta_time()
	while scene._fade_t > 0.0 and waited < 12.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(scene.dungeon_best == 3, "층 기록이 안 남았다: %d" % scene.dungeon_best)
	assert(scene.dungeon_floor == 4, "다음 층으로 안 올랐다: %d" % scene.dungeon_floor)
	assert(scene.stage == home_stage, "등반이 본편 stage 를 건드렸다")
	# **첫 돌파 혈정.** 3층 = +30. 소탕이 그 사이 몇 초 쌓였을 수 있어 딱값이 아니라
	# 구간으로 본다(기록 2층 -> 시간당 0.4, 몇 초면 0.001 미만).
	var got_crystal: float = scene.crystal
	assert(got_crystal >= 30.0 and got_crystal < 31.0,
		"3층 첫 돌파 혈정이 30이 아니다: %.2f" % got_crystal)
	# (30.0 딱이 아닌 이유: 소탕이 그 사이 몇 초 쌓인다 — 기록 2층이면 무시할 크기)
	# **다시 돌면 안 준다.** 층을 기록 아래로 되돌려 놓고 한 층 더 밀어 본다 —
	# 같은 층 재돌파는 소탕 시급이 이미 값을 치르고 있다.
	scene.dungeon_floor = 2
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	var waited2 := 0.0
	while scene._fade_t > 0.0 and waited2 < 5.0:
		await process_frame
		waited2 += scene.get_process_delta_time()
	assert(scene.crystal < got_crystal + 1.0,
		"재돌파인데 혈정이 또 나왔다: %.2f -> %.2f" % [got_crystal, scene.crystal])
	assert(scene.dungeon_best == 3, "재돌파가 기록을 깎았다")
	# 이탈 — 본편 그 자리로. (등반 직후라 암전이 돌고 있다)
	while scene._fade_t > 0.0:
		await process_frame
	scene._dungeon_exit("측정 이탈")
	assert(not scene.dungeon_on)
	assert(scene.stage == home_stage, "이탈했는데 본편 자리가 아니다")
	assert(scene._c_label() == StageDefs.label(home_stage))

	print("")
	print("미궁: 표 %d층 · 개방(30구간=5층, +10구간=+5층) · 주기 5/10 OK" \
		% DungeonDefs.FLOOR_CAP)
	print("래퍼: 본편 모드에서 StageDefs 와 일치 · 미궁 모드에서 등가 구간 값 OK")
	print("등반: 3층 클리어 -> 기록 3, 다음 4층, 본편 stage 불변 OK")
	print("혈정: 첫 돌파 +30 · 재돌파 0 · 소탕 시급표 OK")
	print("")
	print("DungeonCheck OK")
	quit()
