extends SceneTree

# 실제 AnimatedSprite2D 와 트윈을 진행한다. UI·저장·전투는 시작하지 않는다.
class FxHarness extends "res://Main.gd":
	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass


class DamageProbe extends "res://Foe.gd":
	var hits: Array[float] = []

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func take_damage(amount: float) -> void:
		hits.append(amount)
		hp -= amount


func _init() -> void:
	create_timer(22.0).timeout.connect(func() -> void:
		push_error("VFX motion check timed out")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	var scene := FxHarness.new()
	root.add_child(scene)
	scene.ground_y = 320.0
	Engine.max_fps = 120
	# 디스크 첫 로딩 시간을 80ms 모션 창에 포함하지 않는다.
	for name in ["fx_exec_crown", "fx_sk_epic_ward", "fx_sk_common_ward",
			"fx_sk_common_wave", "fx_cleave"]:
		Assets.frames("res://assets/anim/%s" % name)
	await process_frame
	await process_frame
	var at := Vector2(250.0, 280.0)
	var crown := scene._anim_fx("fx_exec_crown", at, 0.34, 1.0, "pulse")
	var orbit := scene._anim_fx("fx_sk_epic_ward", at, 12.0, 1.0, "orbit")
	var ward := scene._anim_fx("fx_sk_common_ward", at, 12.0, 1.0,
		"pulse", 0, 1.0, 1, 0.0, false, 1, 1, 0.0, 2.4)
	var ghost_births: Array[Dictionary] = []
	scene.child_entered_tree.connect(func(child: Node) -> void:
		if child is Sprite2D and str(child.name).begins_with("VfxAfterimage"):
			var record := func() -> void:
				if is_instance_valid(child):
					ghost_births.append({"x": child.position.x,
						"world": child.is_in_group(scene.WORLD_FX_GROUP)})
			record.call_deferred())
	var sweep := scene._anim_fx("fx_sk_common_wave", at, 16.0, 1.0,
		"sweep", 2, 1.0, 1, 0.0, true, -1)
	# 구간 교체처럼 잔상 예약 직후 본체가 사라져도 예약 콜백이 안전해야 한다.
	var cancelled := scene._anim_fx("fx_cleave", at, 18.0, 1.0, "burst", 2)
	cancelled.queue_free()
	assert(crown != null and orbit != null and ward != null and sweep != null)
	assert(ward.sprite_frames.get_animation_loop("play"), "지속 가호가 반복되지 않는다")
	scene._hero = Sprite2D.new()
	scene.add_child(scene._hero)
	scene._hero.position.y = scene.ground_y - 32.0
	scene._phase = "fight"
	scene._ward_aura = ward
	scene._ward_aura_y = -46.0
	scene._dash_to = scene.hero_x + 20.0
	scene._tick_dash(0.016)
	assert(ward.position == Vector2(scene.hero_x, scene.ground_y - 46.0),
		"가호가 이동 중 스킬 고유 높이를 잃었다")

	# 64px 가 아닌 실제 텍스처를 넣어 착지 경로 전체의 잉크 밑단을 검사한다.
	var img := Image.create(40, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(4, 4, 28, 16), Color.WHITE)
	var texture := ImageTexture.create_from_image(img)
	Assets._fcache["res://assets/anim/vfx_anchor_fixture"] = [texture]
	scene._slam_fx_one(320.0, ["vfx_anchor_fixture", 0.0, 0.0, 2.0, 1.0, null, 0.0])
	var landing: AnimatedSprite2D = scene.get_child(scene.get_child_count() - 1)

	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	await process_frame
	assert(sweep.position.x > at.x, "그림 반전이 진행 방향까지 뒤집었다")
	assert(sweep.scale.x < 0.0, "그림만 뒤집는 옵션이 없어졌다")
	assert(not ghost_births.is_empty(), "실제 프레임 잔상이 생성되지 않았다")
	for ghost in ghost_births:
		assert(float(ghost["x"]) < sweep.position.x, "잔상이 칼보다 앞에 있다")
		assert(bool(ghost["world"]), "잔상이 세상과 같이 움직이지 않는다")
	_check_foot(landing, img, scene.ground_y)
	await create_timer(0.30).timeout
	_check_foot(landing, img, scene.ground_y)
	assert(absf(orbit.scale.x - 1.0) < 0.035,
		"가호가 회전 완료를 기다리느라 커진 채 복귀하지 않는다")

	await create_timer(1.02).timeout
	assert(is_instance_valid(crown) and crown.modulate.a > 0.75,
		"0.34fps 왕관이 실제 수명 전에 투명해졌다")
	assert(is_instance_valid(ward) and ward.modulate.a > 0.75,
		"지속 가호가 첫 애니메이션 끝에서 사라졌다")
	await create_timer(1.0).timeout
	assert(not is_instance_valid(ward), "끝난 가호가 남아 있다")
	await create_timer(0.85).timeout
	assert(not is_instance_valid(crown), "수명이 지난 왕관이 정리되지 않았다")
	if await _check_combat_vfx(scene) != true:
		quit(1)
		return
	scene.queue_free()
	await process_frame
	print("VfxMotionCheck OK: true lifetime, looping ward, orbit settle, directional trails, anchored ink, cap36 (replacement art retired)")
	quit()


func _check_combat_vfx(scene: FxHarness) -> bool:
	# The experiment remains independently inspectable; live combat need not use it.
	for i in 50:
		scene._combat_vfx("heavy", Vector2(i, scene.ground_y))
	assert(get_nodes_in_group("combat_vfx").size() == 36,
		"전투 VFX 예산이 36개를 넘었다")
	for effect in get_nodes_in_group("combat_vfx"):
		assert(effect.is_in_group(scene.WORLD_FX_GROUP), "전투 VFX가 세상과 같이 움직이지 않는다")
	await create_timer(0.65).timeout
	assert(get_nodes_in_group("combat_vfx").is_empty(), "TTL 이후 전투 VFX가 남았다")
	return true


func _check_foot(sprite: AnimatedSprite2D, img: Image, ground: float) -> void:
	var bottom := Vector2(0.0, float(img.get_used_rect().end.y)
		- float(img.get_height()) * 0.5) + sprite.offset
	assert(absf(sprite.to_global(bottom).y - ground) < 0.01,
		"착지 그림의 잉크가 크기 변화 중 지면에서 떴다")


func _check_pilot_skills(scene: FxHarness) -> bool:
	var original_pilot := Foe.pixel_motion_pilot
	Foe.pixel_motion_pilot = true
	scene.skin = "valentino_1"
	assert(Foe.pixel_pilot_ready(scene.skin), "Pilot skill check needs imported Valentino frames")
	scene._phase = "fight"
	var probe := DamageProbe.new()
	probe.position = Vector2(scene.hero_x + 40.0, scene.ground_y)
	probe.stop_x = probe.position.x
	probe.hp = 1.0e9
	probe.max_hp = probe.hp
	scene.add_child(probe)
	probe.add_to_group("foes")
	scene._skill_target = probe
	# Resolve the same real hit through both display paths; damage and interval agree.
	Foe.pixel_motion_pilot = false
	scene._resolve_skill("strike_common")
	assert(probe.hits.size() == 1, "Original strike did not reach the fixture")
	var interval := scene.attack_interval()
	Foe.pixel_motion_pilot = true
	scene._resolve_skill("strike_common")
	assert(probe.hits.size() == 2 and is_equal_approx(probe.hits[0], probe.hits[1]),
		"Pilot strike changed damage")
	assert(is_equal_approx(scene.attack_interval(), interval), "VFX changed attack interval")
	assert(_kind_count("heavy") == 1, "Pilot strike did not use the new heavy ribbon")
	# Native and old ward nodes must share the same following/cleanup path.
	scene._resolve_skill("ward_common")
	var ward: Node2D = scene._ward_aura
	assert(ward != null and str(ward.get("_kind")) == "ward")
	assert(is_equal_approx(float(ward.get("_life")), scene._summon_t),
		"Pilot ward lifetime differs from its actual buff")
	assert(not ward.is_in_group(scene.WORLD_FX_GROUP), "Following ward also scrolls with the world")
	var extra := DamageProbe.new()
	extra.position = Vector2(probe.position.x + 120.0, scene.ground_y)
	extra.stop_x = extra.position.x
	extra.hp = 1.0e9
	extra.max_hp = extra.hp
	scene.add_child(extra)
	extra.add_to_group("foes")
	var already_hits := probe.hits.size()
	scene._mastery_cleave(probe)
	scene._summon_cleave = "fx_cleave_wave"
	scene._cleave_swing(probe)
	assert(probe.hits.size() == already_hits and extra.hits.size() == 2,
		"Pilot cleave changed its excluded or extra targets")
	assert(is_equal_approx(extra.hits[0], extra.hits[1]) and _kind_count("sweep") == 2,
		"Mastery/buff cleave differ in damage or fail to show the new sweep")
	extra.remove_from_group("foes")
	extra.queue_free()
	scene._dash_to = scene.hero_x - 12.0
	scene._tick_dash(0.016)
	assert(ward.position == Vector2(scene.hero_x, scene.ground_y - 32.0),
		"Native ward lost the hero body anchor")
	probe.hits.clear()
	scene._resolve_skill("field_common")
	var field: Node2D
	for effect in get_nodes_in_group("combat_vfx"):
		if str(effect.get("_kind")) == "field":
			field = effect
	assert(field != null and absf(field.position.x - scene._field_x) <= 0.5
		and field.position.y == scene.ground_y,
		"Pilot ground seal is not on the actual field center/floor")
	assert(not field.is_in_group(scene.WORLD_FX_GROUP) and scene._field_fixed,
		"Fixed field and displayed seal scroll differently")
	assert(is_equal_approx(float(field.get("_reach")), scene._field_reach),
		"Ground seal does not show the actual field radius")
	assert(field.z_index < 1 and ward.z_index < 1, "Held skill ink hides the actors")
	await create_timer(3.15).timeout
	assert(probe.hits.size() == SkillDefs.ticks_of("field_common"),
		"Pilot field changed the number of damage ticks")
	for amount in probe.hits:
		assert(is_equal_approx(amount, probe.hits[0]), "VFX changed field tick damage")
	assert(not is_instance_valid(field), "Expired field ink remains")
	assert(is_instance_valid(ward), "Ward vanished with the shorter field duration")
	# Exercise every skill-specific drawing path under real frame redraws.
	for key in ["wave_common", "wave_uncommon", "wave_rare", "wave_epic", "wave_legend",
			"field_uncommon", "field_rare", "field_legend"]:
		scene._resolve_skill(key)
	assert(_kind_count("sweep") == 1 and _kind_count("wave") == 1,
		"Piercing sweep and repeated wave share the wrong display branch")
	assert(_kind_count("eye") == 1 and _kind_count("crown") == 1,
		"Overhead field roles were replaced with floor effects")
	await create_timer(3.2).timeout
	assert(not is_instance_valid(ward), "Pilot ward did not expire with its buff")
	assert(get_nodes_in_group("combat_vfx").is_empty(), "Pilot skill VFX leaked past their lifetimes")
	probe.queue_free()
	Foe.pixel_motion_pilot = original_pilot
	return true


func _kind_count(kind: String) -> int:
	var count := 0
	for effect in get_nodes_in_group("combat_vfx"):
		if str(effect.get("_kind")) == kind:
			count += 1
	return count
