extends SceneTree

# 모션과 실제 이동이 어긋나는 프레임을 센다. 사장님 보고 두 건의 원인을 가른다.
#   (1) "달리는데 앞으로 안 나가고 제자리에서 걷는다"
#       -> walk/dash 를 재생하면서 hero_x 가 안 변하는 프레임
#   (2) "스테이지 클리어하면 중앙에서 문워크처럼 뒤로 달린다"
#       -> 전진(advance) 구간에서 hero_face 가 진행 방향(+1)과 반대인 프레임
#          배경은 왼쪽으로 흐르므로(=영웅이 오른쪽으로 간다) face 는 +1 이어야 한다

const SECONDS := 50.0

func _init() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.stage = 1
	scene._restart_stage("측정")

	var t := 0.0
	var frames := 0
	var stuck := {}          # 모션 -> 안 움직인 프레임 수
	var by := {}             # 제자리 프레임의 국면별 분포
	var moving := {}         # 모션 -> 움직인 프레임 수
	var adv_frames := 0
	var adv_back := 0        # 전진 중 뒤를 본 프레임
	var prev_x: float = scene.hero_x
	# **세상이 흐르는 것도 이동이다.** 찾아가는 모델에서 영웅은 앵커에 머물고 배경·몹이
	# 왼쪽으로 흐른다(`_advance_world`) — hero_x 만 보면 정상 전진을 "제자리 걷기"로
	# 잡는다(실제로 dash 32%가 그렇게 걸렸다). 둘을 합쳐 "화면에서 움직이는가"로 본다.
	var prev_scroll: float = scene._scroll
	while t < SECONDS:
		await process_frame
		var d: float = scene.get_process_delta_time()
		t += d
		frames += 1
		var m: String = str(scene._motion)
		var dx: float = (scene.hero_x - prev_x) + (scene._scroll - prev_scroll)
		prev_x = scene.hero_x
		prev_scroll = scene._scroll
		if m in ["walk", "dash"]:
			if absf(dx) < 0.05:
				stuck[m] = int(stuck.get(m, 0)) + 1
				# 어느 국면에서 나는지 갈라 찍는다 - 원인이 전진 쪽인지 전투 쪽인지
				var why := "%s/%s" % [str(scene._phase),
					("dying" if (is_instance_valid(scene._engaged)
						and scene._engaged.dying) else "live")]
				by[why] = int(by.get(why, 0)) + 1
			else:
				moving[m] = int(moving.get(m, 0)) + 1
		if scene._phase != "fight":
			adv_frames += 1
			if int(scene.hero_face) < 0:
				adv_back += 1

	print("")
	print("전체 %d 프레임 (%.0f초)" % [frames, SECONDS])
	for m in ["walk", "dash"]:
		var s := int(stuck.get(m, 0))
		var mv := int(moving.get(m, 0))
		print("%-5s  움직임 %5d / 제자리 %5d  -> 제자리 비율 %.0f%%"
			% [m, mv, s, 100.0 * float(s) / maxf(1.0, float(s + mv))])
	print("제자리 프레임 국면별: %s" % str(by))
	print("전진 구간 %d 프레임 중 뒤를 본 프레임 %d (%.0f%%)"
		% [adv_frames, adv_back, 100.0 * float(adv_back) / maxf(1.0, float(adv_frames))])
	# 이동 모션은 **실제로 움직일 때만** 재생돼야 한다. 실측으로 walk 95% / dash 62% 가
	# 제자리였다 — 화면에서는 그게 "제자리에서 걷는다"다.
	for m in ["walk", "dash"]:
		var s := int(stuck.get(m, 0))
		var mv := int(moving.get(m, 0))
		assert(float(s) / maxf(1.0, float(s + mv)) < 0.15,
			"%s 가 제자리에서 재생된다: %d 프레임" % [m, s])
	assert(adv_back == 0, "전진하는데 뒤를 본다(문워크): %d 프레임" % adv_back)

	# 보스 구간은 **왼쪽 화면 밖에서** 걸어 들어와야 한다.
	# 암전이 걷힌 뒤에 재면 이미 한참 걸어 들어와 있다 — 등장 전체에서 **최솟값**을 본다.
	scene.stage = StageDefs.BOSS_EVERY          # 1막 10구간 = 보스
	scene._restart_stage("보스 측정")
	var t2 := 0.0
	var lo := INF
	var faced_back := 0
	var fought_early := false
	var entered := false
	while t2 < 12.0:
		await process_frame
		t2 += scene.get_process_delta_time()
		if scene._boss_entry:
			entered = true
			lo = minf(lo, scene.hero_x)
			if int(scene.hero_face) < 0:
				faced_back += 1
			if scene._phase == "fight":
				fought_early = true
		elif entered:
			break
	print("보스 등장  최소 hero_x %.1f  (앵커 %.0f)  ·  %.2f 초에 도착" % [lo, scene.HERO_X, t2])
	print("   들어오는 중 전투 %s  ·  뒤를 본 프레임 %d" % [str(fought_early), faced_back])
	assert(entered, "보스 구간인데 등장 연출이 안 켜졌다")
	assert(lo < 0.0, "보스 구간인데 화면 안에서 시작한다: %.1f" % lo)
	assert(faced_back == 0, "왼쪽에서 들어오는데 왼쪽을 본다: %d 프레임" % faced_back)
	assert(not fought_early, "영웅이 들어오는 중에 전투가 열렸다")
	assert(not scene._boss_entry, "12초가 지나도 앵커에 못 들어왔다")
	# **임팩트 프레임이 되감는 꼬리에 안 걸리는가.**
	# `Assets.reach_peak_frame` 은 "전체 최소 이후의 최대"인데, 뒤쪽에 더 깊은
	# 골짜기가 있으면 창이 꼬리에 갇혀 칼이 이미 되감긴 프레임을 고른다.
	# hawaii 가 실제로 그랬다(f8, 사거리 12 — 진짜 극단은 f4 의 24).
	# 사거리가 반토막 나고 임팩트가 시전 창 끝에 붙어, 그 사이 표적이 죽으면
	# 스킬이 통째로 사라진다(2026-08-27 실측).
	for m in ["attack3", "cast"]:
		var dir := "res://assets/anim/hawaii_%s" % m
		if Assets.frames(dir).is_empty():
			continue
		var pk: int = Assets.reach_peak_frame(dir, true)
		var r_pk: float = Assets.frame_reach(dir, pk, 1.0, true)
		# 고른 프레임의 사거리가 전체 극단의 70% 는 넘어야 한다.
		var top := 0.0
		for f in Assets.frames(dir).size():
			top = maxf(top, Assets.frame_reach(dir, f, 1.0, true))
		assert(r_pk >= top * 0.70,
			"hawaii_%s 임팩트가 f%d(사거리 %.0f)인데 극단은 %.0f 다 — 되감는 꼬리에 걸렸다"
			% [m, pk, r_pk, top])

	print("MotionCheck OK")
	quit()
