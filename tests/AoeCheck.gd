extends SceneTree

# 광역 스킬 세 가지를 잰다. 눈으로는 "아이콘 튀고 끝"까지밖에 못 가고, 원인이
# 판정 범위인지 이펙트 개수인지 틱 유무인지 안 갈린다.
#
#   1) 광역이 **화면 밖 몹**을 때리는가        (_aoe_targets)
#   2) 이펙트가 **맞는 놈마다** 뜨는가         (혈우만 그랬다)
#   3) 진이 **여러 번** 때리는가               (다단히트)

func _init() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.stage = 1
	scene._restart_stage("측정")
	while scene._phase != "fight":
		await process_frame
	# **전투 phase 안에서 재야 한다.** `_aoe_targets` 는 `_foe_arrived` 를 보고 그건
	# `_phase == "fight"` 를 요구한다 — 전진 구간에서 재면 늘 0 이 나온다(처음에 그렇게
	# 짜서 "화면 안에 몹이 있는데 대상 0" 이 나왔다).
	var wait := 0.0
	while wait < 20.0:
		await process_frame
		wait += scene.get_process_delta_time()
		if scene._phase == "fight" and not (scene._aoe_targets() as Array).is_empty():
			break
	assert(scene._phase == "fight", "20초 안에 전투가 안 열렸다")

	var all: Array = scene.get_tree().get_nodes_in_group("foes")
	var on := 0
	var off := 0
	for f in all:
		if is_instance_valid(f):
			if f.position.x - f.body_half() > float(Grid.BG.x):
				off += 1
			else:
				on += 1
	var targets: Array = scene._aoe_targets()
	print("")
	print("살아 있는 몹 %d  (화면 안 %d / 화면 밖 %d)" % [all.size(), on, off])
	print("광역 판정 대상 %d 마리" % targets.size())
	for f in targets:
		print("   x %6.1f  %s" % [f.position.x, str(f.display_name)])
	assert(targets.size() <= on,
		"화면 밖 몹을 때린다: 판정 %d > 화면 안 %d" % [targets.size(), on])
	assert(targets.size() > 0, "화면 안에 몹이 있는데 광역 대상이 0이다")

	# ── 2) 이펙트가 맞는 놈마다 뜨는가 ────────────────────────────────────
	# 파(wave)를 강제로 쏘고, 그 프레임에 생긴 AnimatedSprite2D 수를 센다.
	scene._skill_action = ""
	scene._skill_cd.clear()
	var fx_before := _count_fx(scene)
	scene._skill_target = targets[0]
	scene._resolve_skill("wave_common")
	await process_frame
	var fx_after := _count_fx(scene)
	var made := fx_after - fx_before
	print("")
	print("파(wave) 1회 -> 이펙트 %d 개 생성 (대상 %d 마리)" % [made, targets.size()])
	assert(made >= targets.size(),
		"맞는 놈보다 이펙트가 적다: %d 개 / %d 마리" % [made, targets.size()])

	# ── 3) 진이 여러 번 때리는가 ──────────────────────────────────────────
	# **표적을 여기서 다시 뽑는다.** 위의 파(wave)가 1막 몹을 한 방에 죽이므로
	# targets[0] 은 이미 `dying` 이다 — hp 를 키워도 `_die()` 가 지난 뒤라 안 살아난다.
	# 처음에 그걸 몰라 "피해 0 번"이 나왔고, 원인은 계측 쪽이었다.
	# 장판이 깔릴 자리(_aoe_targets()[0])와 같은 놈이어야 문양 안에 든다.
	scene._phase = "fight"
	var wait2 := 0.0
	var alive: Array = scene._aoe_targets()
	while alive.is_empty() and wait2 < 20.0:
		await process_frame
		wait2 += scene.get_process_delta_time()
		if scene._phase == "fight":
			alive = scene._aoe_targets()
	assert(not alive.is_empty(), "살아 있는 광역 대상을 못 찾았다")
	var probe: Foe = alive[0]
	probe.max_hp = 1.0e9
	probe.hp = 1.0e9
	var hp0: float = probe.hp
	var drops := 0
	var prev := hp0
	scene._skill_action = ""
	scene._skill_cd.clear()
	scene._skill_target = probe
	# **_resolve_skill 첫 줄이 `_phase != "fight"` 면 통째로 빠져나간다.** 앞의 파가
	# 몹을 다 죽여 전진 구간으로 넘어가 있으면 장판이 아예 안 깔린다 - 처음에 그렇게
	# 재서 "피해 0 번"이 나왔다. 장판 자체는 phase 를 안 보지만 시전은 본다.
	scene._phase = "fight"
	var sk := SkillDefs.SHAPES["field"]
	var want := int(round(float(sk["duration"]) * float(sk["tick_rate"])))
	var gen0: int = scene._field_gen
	scene._resolve_skill("field_common")
	await process_frame
	print("   깔린 뒤: _field_x %.1f  반폭 %.1f  gen %d->%d  world_fx %d  대상 %d"
		% [scene._field_x, scene._field_half, gen0, scene._field_gen,
		(scene.get_tree().get_nodes_in_group("world_fx") as Array).size(),
		(scene._field_targets() as Array).size()])
	print("   probe x %.1f  잉크반폭 %.1f  거리 %.1f  dying %s"
		% [probe.position.x, probe.body_half(),
		absf(probe.position.x - scene._field_x), str(probe.dying)])
	var t := 0.0
	while t < float(sk["duration"]) + 1.0:
		await process_frame
		t += scene.get_process_delta_time()
		# **평타와 다른 스킬을 막는다.** 안 그러면 0.6초마다 기본공격이, 그리고 쿨다운이
		# 풀린 다른 스킬이 같은 놈을 때려서 틱과 섞인다 - 처음에 6틱 설계인데 13번,
		# 스킬만 남겼을 때 8번으로 나왔다.
		scene._attack_t = 99.0
		for k in scene.skill_equipped:
			scene._skill_cd[str(k)] = 99.0
		if not is_instance_valid(probe):
			break
		if probe.hp < prev - 0.0001:
			drops += 1
			prev = probe.hp
	print("")
	print("진(field) 1회 -> 피해가 %d 번 들어갔다 (설계 %d 틱: %.1f초 x 초당 %.0f)"
		% [drops, want, float(sk["duration"]), float(sk["tick_rate"])])
	print("   총 피해 %.1f  (%.1f -> %.1f)" % [hp0 - prev, hp0, prev])
	assert(drops >= 2, "진이 다단히트가 아니다: %d 번" % drops)
	assert(drops >= want - 1, "틱이 모자라다: %d / %d" % [drops, want])
	assert(drops <= want + 1, "틱이 설계보다 많다: %d / %d (평타가 섞였나)" % [drops, want])
	# **문양 폭이 몹 간격보다 좁으면 광역이 아니다.** 반폭 32 + 몹 22 = +-54px 인데
	# 몹은 FOE_GAP(160) 간격으로 서므로 한 번에 한 마리만 든다 - 다단히트는 되지만
	# "광역"은 아니다. 이건 아트 폭(64px)의 한계이고, 넓히려면 문양을 다시 뽑아야 한다.
	print("")
	print("문양 판정 폭 +-%.0f px  ·  몹 간격 %.0f px  ->  한 번에 최대 %d 마리"
		% [scene._field_half + probe.body_half(), scene.FOE_GAP,
		1 + int(2.0 * (scene._field_half + probe.body_half()) / scene.FOE_GAP)])
	print("")
	print("AoeCheck OK")
	quit()


func _count_fx(scene: Node) -> int:
	var n := 0
	for c in scene.get_children():
		if c is AnimatedSprite2D:
			n += 1
	return n
