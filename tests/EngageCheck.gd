extends SceneTree

# **씬을 실제로 60초 돌리는 계측이다 — 90초쯤 걸린다.** 다른 tests/*.gd 처럼
# 매번 돌리는 게 아니라 전투 배치(칸 좌표 · 몹 걷기 · 순차 교전)를 만졌을 때 돌린다.
# 좌표 자체의 하한은 CombatRulesTest 가 즉시 검사한다.
#   godot --headless --path . --script tests/EngageCheck.gd
#
# 1) 영웅이 실제로 걸어 나가는가 (사장님: "가운데에서 왔다갓다 하지 않아")
# 2) 교전 몹이 0번 칸을 쓰게 됐는데 대기 몹과 겹치지 않는가
# 3) 일반 구간에서 제한 시간이 안 도는가
# 4) 뜸(멀리서 허공 치기)이 나면 **원인을 같이 찍는다** — 스킬 중 굳은 자리인가,
#    교전 몹이 아직 앞칸에 있는가.
# 5) 실제 처치 속도. 모델(Balance.stage_seconds)과 맞는지 본다.

const SECONDS := 60.0

func _init() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.stage = 1
	scene.kills = 0
	scene._restart_stage("측정")
	# 첫 무리가 자리를 잡을 때까지 기다린다 — 그 전 구간은 처치 속도에 안 넣는다.
	while scene._phase != "fight":
		await process_frame

	var t := 0.0
	var hx_lo := INF
	var hx_hi := -INF
	var overlap := 0.0
	var gap_hi := -INF
	var gap_hi_skill := ""
	var gap_hi_lane := 0.0
	var gap_skill_frames := 0     # 뜸이 난 프레임 중 스킬 중이던 것
	var gap_frames := 0
	var timer_ran := false
	var moving := 0
	var frames := 0
	var kills0: int = scene.kills

	while t < SECONDS:
		await process_frame
		var d: float = scene.get_process_delta_time()
		t += d
		if scene._phase != "fight":
			continue
		frames += 1
		var hx: float = scene.hero_x
		hx_lo = minf(hx_lo, hx)
		hx_hi = maxf(hx_hi, hx)
		var settled: bool = absf(hx - scene._dash_to) <= 1.0
		if not settled:
			moving += 1
		if scene._boss_time > 0.0:
			timer_ran = true
		var live: Array = []
		for f in scene.get_tree().get_nodes_in_group("foes"):
			if is_instance_valid(f) and not f.dying and absf(f.position.x - f.stop_x) <= 1.0:
				live.append(f)
		for i in live.size():
			for j in range(i + 1, live.size()):
				var a = live[i]
				var b = live[j]
				overlap = minf(overlap, absf(a.position.x - b.position.x)
					- a.body_half() - b.body_half())
		var e = scene._engaged
		if is_instance_valid(e) and not e.dying and settled \
				and absf(e.position.x - e.stop_x) <= 1.0:
			var g: float = scene._foe_gap(e) - scene.BODY_HALF
			if g > scene.GAP_MAX:
				gap_frames += 1
				if scene._skill_action != "":
					gap_skill_frames += 1
			if g > gap_hi:
				gap_hi = g
				gap_hi_skill = scene._skill_action
				gap_hi_lane = e.stop_x

	var span := hx_hi - hx_lo
	var killed: int = scene.kills - kills0
	print("")
	print("전투 프레임          %d  (%.0f초)" % [frames, SECONDS])
	print("영웅 x 범위          %.1f ~ %.1f  (폭 %.1f px)" % [hx_lo, hx_hi, span])
	print("이동 중 프레임 비율  %.0f%%" % (100.0 * float(moving) / maxf(1.0, float(frames))))
	print("몹끼리 최소 클리어런스 %.1f px  (음수 = 겹침)" % overlap)
	print("교전 몹과 최대 빈틈  %.1f px (한계 %.1f) / 그때 스킬 '%s' / 몹칸 %.0f"
		% [gap_hi, scene.GAP_MAX, gap_hi_skill, gap_hi_lane])
	print("뜬 프레임            %d 중 스킬 중 %d (%.0f%%)"
		% [gap_frames, gap_skill_frames,
		100.0 * float(gap_skill_frames) / maxf(1.0, float(gap_frames))])
	print("일반 구간 시계 돌았나 %s" % str(timer_ran))
	print("처치                 %d 마리 / %.0f초  = %.2f 마리/초  -> 100마리에 %.0f초"
		% [killed, SECONDS, float(killed) / SECONDS,
		SECONDS * 100.0 / maxf(1.0, float(killed))])
	print("모델 예상            %.0f초 (칸 %d, 걷기 %.2f초)"
		% [Balance.stage_seconds(100, scene._offline_profile(1)["hp"], scene.dps(),
			scene._wave_size(1), scene._lane_walk_seconds(1)),
		scene._wave_size(1), scene._lane_walk_seconds(1)])
	print("")
	assert(span > 50.0, "영웅이 제자리다: 폭 %.1f px" % span)
	assert(not timer_ran, "일반 구간에서 제한 시간이 돌았다")
	assert(killed > 0, "처치가 안 늘었다 - 전투가 멈췄다")
	assert(overlap > -8.0, "몹끼리 겹친다: %.1f px" % overlap)
	assert(gap_hi <= scene.GAP_MAX + 1.0, "멀리서 허공을 친다: %.1f px" % gap_hi)
	print("EngageCheck OK")
	quit()
