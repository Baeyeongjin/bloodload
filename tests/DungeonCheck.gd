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
	assert(DungeonDefs.open_floors(29) == 0, "30구간 전인데 열렸다")
	assert(DungeonDefs.open_floors(30) == 5, "30구간 개방이 5층이 아니다")
	assert(DungeonDefs.open_floors(40) == 10, "40구간 개방이 10층이 아니다")
	assert(DungeonDefs.open_floors(9999) == DungeonDefs.FLOOR_CAP,
		"개방 상한이 안 걸린다")
	# 주기: 5층 중간보스, 10층 보스, 겹치지 않는다.
	for f in [5, 15, 95]:
		assert(DungeonDefs.is_midboss_floor(f) and not DungeonDefs.is_boss_floor(f))
	for f in [10, 50, 100]:
		assert(DungeonDefs.is_boss_floor(f) and not DungeonDefs.is_midboss_floor(f))
	assert(DungeonDefs.kills_needed(3) == DungeonDefs.KILLS_PER_FLOOR)
	assert(DungeonDefs.kills_needed(10) == 1)
	# 제한 시간: 본편과 같은 문법 (보스·중간보스만).
	assert(DungeonDefs.time_limit(3) == 0.0, "일반 층에 제한 시간이 걸렸다")
	assert(DungeonDefs.time_limit(10) == StageDefs.TIME_BOSS)
	# 깊이 색: 채널이 1을 안 넘고(밝아지면 안 된다) 깊을수록 어둡다.
	var t1 := DungeonDefs.depth_tint(1)
	var t100 := DungeonDefs.depth_tint(100)
	assert(t100.r <= t1.r and t100.g < t1.g, "깊은 층이 더 밝다")
	assert(t100.g >= 0.5, "100층 색이 너무 어둡다 — 체력 바 대비가 죽는다")

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
	assert(scene._c_kills_needed() == DungeonDefs.KILLS_PER_FLOOR)
	assert("미궁" in scene._c_label())
	# 혈액은 본편 시세다 — 등가 구간 시세로 주면 미궁이 더 나은 사냥터가 된다.
	assert(is_equal_approx(scene._c_gold_per_kill(), StageDefs.gold_per_kill(home_stage)),
		"미궁 혈액이 본편 시세가 아니다")
	# 층 클리어 — 오르고 기록이 남는다. (여기도 암전 꼬리까지)
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	var waited := 0.0
	while scene._fade_t > 0.0 and waited < 5.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(scene.dungeon_best == 3, "층 기록이 안 남았다: %d" % scene.dungeon_best)
	assert(scene.dungeon_floor == 4, "다음 층으로 안 올랐다: %d" % scene.dungeon_floor)
	assert(scene.stage == home_stage, "등반이 본편 stage 를 건드렸다")
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
	print("")
	print("DungeonCheck OK")
	quit()
