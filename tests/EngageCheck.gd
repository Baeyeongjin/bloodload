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
	# **누적으로 센다.** scene.kills 는 구간이 넘어갈 때 0 으로 리셋된다 —
	# KILLS_PER_STAGE 가 40 이 된 뒤로 60초 안에 몇 번 넘어가서, 차이로 재면
	# 처치 8마리(실제 48)로 나온다. 실제로 그 함정에 빠졌다.
	var total := 0
	var prev: int = scene.kills
	var stages := 0
	var scroll0: float = scene._scroll
	var pops_hi := 0        # 동시에 떠 있던 피해 숫자 최대치
	var labels_hi := 0      # 실제 노드 수. _dmg_pops 와 어긋나면 새고 있는 것이다

	while t < SECONDS:
		await process_frame
		var d: float = scene.get_process_delta_time()
		t += d
		if scene._phase != "fight":
			continue
		frames += 1
		var k: int = scene.kills
		if k >= prev:
			total += k - prev
		else:
			total += k + 1      # 구간을 넘긴 그 한 방까지
			stages += 1
		prev = k
		pops_hi = maxi(pops_hi, int(scene._dmg_pops))
		var pop_now := 0
		for c in scene.get_children():
			if c is Label and int(c.z_index) == 6:
				pop_now += 1
		labels_hi = maxi(labels_hi, pop_now)
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
	var scrolled: float = scene._scroll - scroll0
	var killed := total
	var need := StageDefs.KILLS_PER_STAGE
	print("")
	print("전투 프레임          %d  (%.0f초)" % [frames, SECONDS])
	print("영웅 x 범위          %.1f ~ %.1f  (폭 %.1f px, 앵커 %.0f)"
		% [hx_lo, hx_hi, span, scene.HERO_X])
	print("세상 전진            %.0f px = %.0f px/초" % [scrolled, scrolled / SECONDS])
	print("이동 중 프레임 비율  %.0f%%" % (100.0 * float(moving) / maxf(1.0, float(frames))))
	print("몹끼리 최소 클리어런스 %.1f px  (음수 = 겹침)" % overlap)
	print("교전 몹과 최대 빈틈  %.1f px (한계 %.1f) / 그때 스킬 '%s' / 몹칸 %.0f"
		% [gap_hi, scene.GAP_MAX, gap_hi_skill, gap_hi_lane])
	print("뜬 프레임            %d 중 스킬 중 %d (%.0f%%)"
		% [gap_frames, gap_skill_frames,
		100.0 * float(gap_skill_frames) / maxf(1.0, float(gap_frames))])
	print("일반 구간 시계 돌았나 %s" % str(timer_ran))
	print("피해 숫자 동시 최대   %d 개 (노드 %d, 상한 %d)"
		% [pops_hi, labels_hi, scene.DMG_POP_MAX])
	print("처치                 %d 마리 / %.0f초  = %.2f 마리/초  (구간 %d 회 통과)"
		% [killed, SECONDS, float(killed) / SECONDS, stages])
	print("구간 %d마리          실측 %.0f초  /  모델 %.0f초  /  목표 %.0f초"
		% [need, SECONDS * float(need) / maxf(1.0, float(killed)),
		Balance.stage_seconds(need, scene._offline_profile(1)["hp"], scene.dps(),
			scene.attack_interval()),
		StageDefs.PACE_NORMAL])
	# **APPROACH_SECONDS 역산.** Balance.gd 의 그 상수는 "실측 초/마리에서 모델
	# 처치시간을 뺀 나머지"로 정해졌다(전진 + 사망 대기 + 첫 스윙까지의 지연).
	# 같은 자리의 `ponytail:` 주석이 FOE_GAP · TRAVEL_SPEED · DIE_DUR 를 바꾸면
	# 여기로 다시 재라고 가리킨다 — 그래서 그 수를 여기서 바로 찍는다.
	# 짐작으로 못 맞추는 값이라(0.55 -> 0.89 -> 0.76 -> 0.83 -> 0.57 -> 0.47) 눈으로 본다.
	var per_kill := SECONDS / maxf(1.0, float(killed))
	var model_kill: float = Balance.push_seconds(need,
		scene._offline_profile(1)["hp"], scene.dps(), scene.attack_interval()) 		/ float(maxi(1, need))
	print("접근 고정비 역산      실측 %.2f초/마리 - 모델 처치 %.2f초 = %.2f초  (지금 상수 %.2f)"
		% [per_kill, model_kill, per_kill - model_kill, Balance.APPROACH_SECONDS])
	print("  (참고: dps %.0f · 주기 %.2f초 · 몹 hp %.0f)"
		% [scene.dps(), scene.attack_interval(), scene._offline_profile(1)["hp"]])
	print("")
	# **움직이는 것은 세상이다.** 찾아가는 모델에서 영웅은 앵커를 지키고 배경·몹이
	# 왼쪽으로 흐른다 — "영웅이 50px 넘게 움직여야 한다"는 웨이브 모델의 규칙이라
	# 여기서는 정상 동작을 실패로 잡는다. 대신 **전진이 실제로 일어났는가**를 본다.
	assert(scrolled > 200.0, "세상이 전진하지 않았다: %.0f px" % scrolled)
	# **영웅은 앵커를 크게 벗어나지 않는다.** 벗어나면 화면 고정 전제가 깨진다 —
	# 표적을 멀리까지 쫓게 두자 42~536(화면 전체)까지 나갔다(실측). 큰 몹이 자리를
	# 밀어내는 폭(23px)에 넉백 여유를 더한 만큼만 허용한다.
	var slack: float = scene.FRONT_X - scene.HERO_X + 40.0
	assert(hx_hi <= scene.HERO_X + slack and hx_lo >= scene.HERO_X - slack,
		"영웅이 앵커에서 너무 멀다: %.1f ~ %.1f (앵커 %.0f +-%.0f)"
		% [hx_lo, hx_hi, scene.HERO_X, slack])
	assert(not timer_ran, "일반 구간에서 제한 시간이 돌았다")
	assert(killed > 0, "처치가 안 늘었다 - 전투가 멈췄다")
	assert(overlap > -8.0, "몹끼리 겹친다: %.1f px" % overlap)
	assert(gap_hi <= scene.GAP_MAX + 1.0, "멀리서 허공을 친다: %.1f px" % gap_hi)
	# 피해 숫자가 상한을 넘거나 노드가 카운터보다 많으면 새고 있는 것이다 —
	# 트윈 콜백이 안 돌면 라벨이 화면에 그대로 쌓여 전투를 가린다.
	assert(pops_hi <= scene.DMG_POP_MAX,
		"피해 숫자가 상한을 넘었다: %d" % pops_hi)
	assert(labels_hi <= scene.DMG_POP_MAX,
		"피해 숫자 노드가 안 지워진다: %d 개" % labels_hi)
	assert(pops_hi > 0, "피해 숫자가 아예 안 떴다")
	print("EngageCheck OK")
	quit()
