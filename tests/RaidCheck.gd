extends SceneTree

# 재화 던전(RaidDefs)을 잰다. 지키는 것 넷:
#   1) 표 — 등가 구간이 단조증가·상한, 보상이 양수·단조증가
#   2) 래퍼 3분기 — raid_on 이면 던전 값, 나오면 본편 값 그대로
#   3) 입장권 — 하루 한 장: 입장에서 소모, 겹입장 금지, 같은 날 재입장 금지
#   4) 격파 — 뭉치 지급 + 도전 단계 상승 + 본편 복귀 (stage 불변)
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	var prev_eq := 0
	for n in range(1, 200):
		var eq := RaidDefs.eq_stage(n, "blood")
		assert(eq >= prev_eq, "%d단계 등가 구간이 내려간다" % n)
		assert(eq <= StageDefs.total_stages(), "%d단계가 본편 밖이다" % n)
		prev_eq = eq
	for kind in ["blood", "essence"]:
		var prev_r := 0.0
		for n in range(1, 50):
			var r := RaidDefs.reward(kind, n)
			assert(r > 0.0 and r >= prev_r,
				"%s %d단계 보상이 줄었다: %f -> %f" % [kind, n, prev_r, r])
			prev_r = r
		assert(FileAccess.file_exists(str(RaidDefs.RAIDS[kind]["icon"])),
			"%s 아이콘 파일이 없다" % kind)

	# ── 2~4) 씬 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# **결백성** — 지난 실행의 저장본 값을 전부 0으로 되돌린다.
	scene.stage = 25
	scene.best_stage = 25
	scene.raid_best = {"blood": 0, "essence": 0, "pact": 0}
	scene.raid_left = {}
	scene.raid_date = ""
	scene._restart_stage("측정")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var home_stage: int = scene.stage

	scene._raid_enter("blood")
	assert(scene.raid_on == "blood", "입장이 안 됐다")
	assert(scene._raid_left("blood") == RaidDefs.TRIES_PER_DAY,
		"입장에서 표가 깎였다 — 표는 격파에만 깎인다")
	assert(scene.stage == home_stage, "입장이 본편 stage 를 건드렸다")
	# 겹입장 금지 — 표도 안 쓴다.
	scene._raid_enter("essence")
	assert(scene.raid_on == "blood", "던전 안에서 다른 던전에 들어갔다")
	# 래퍼가 던전 값으로 갈렸는가.
	assert(scene._c_kills_needed() == RaidDefs.KILLS)
	assert(is_equal_approx(scene._c_time_limit(), RaidDefs.TIME_LIMIT))
	assert(is_equal_approx(scene._c_enemy_power(),
		StageDefs.enemy_power(RaidDefs.eq_stage(1, "blood"))), "몹 세기가 등가 구간 값이 아니다")
	assert("혈액의 동굴" in scene._c_label())
	assert(not scene._c_is_boss(), "재화 던전에 보스 판정이 떴다")
	assert(is_equal_approx(scene._c_gold_per_kill(),
		StageDefs.gold_per_kill(home_stage)), "던전 킬 혈액이 본편 시세가 아니다")

	# 격파 — 암전 꼬리까지 기다렸다가 처치 수를 채운다.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var gold_before: float = scene.gold
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	var waited := 0.0
	while scene._fade_t > 0.0 and waited < 5.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(scene.raid_on == "", "격파했는데 본편으로 안 나왔다")
	assert(int(scene.raid_best["blood"]) == 1, "도전 단계가 안 올랐다")
	assert(scene.stage == home_stage, "격파가 본편 stage 를 건드렸다")
	assert(scene.gold - gold_before >= RaidDefs.reward("blood", 1),
		"격파 뭉치가 안 들어왔다: +%f" % (scene.gold - gold_before))
	# 래퍼가 본편으로 돌아왔는가.
	assert(scene._c_kills_needed() == StageDefs.kills_needed(home_stage))
	# 같은 날 재입장 금지.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	# 격파했으니 표가 하나 깎였다 — 아직 남았으니 또 들어갈 수 있다.
	assert(scene._raid_left("blood") == RaidDefs.TRIES_PER_DAY - 1,
		"격파했는데 표가 안 깎였다: %d" % scene._raid_left("blood"))
	scene._raid_enter("blood")
	assert(scene.raid_on == "blood", "표가 남았는데 못 들어갔다")
	# 입장이 건 페이드가 도는 중에는 이탈이 조용히 빠진다(반쪽 상태 방지 가드).
	while scene._fade_t > 0.0:
		await process_frame
	scene._raid_exit("측정")
	assert(scene.raid_on == "", "이탈이 안 됐다")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	# 실패로 나온 판은 표를 안 먹는다.
	assert(scene._raid_left("blood") == RaidDefs.TRIES_PER_DAY - 1,
		"실패한 판이 표를 먹었다")
	# 표를 다 쓰면 못 들어간다.
	scene.raid_left["blood"] = 0
	scene._raid_enter("blood")
	assert(scene.raid_on == "", "표가 0인데 들어갔다")

	print("RaidCheck OK")
	quit()
