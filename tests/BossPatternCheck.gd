extends SceneTree

# Exercise the real combat routes, without loading Main's UI or any save file.
# Launch with APPDATA and LOCALAPPDATA set to the same new build/qa/*boss-pattern* folder.
class Arena extends "res://Main.gd":
	var clock := 0.0
	var contacts: Array[Dictionary] = []
	var casts: Array[Node2D] = []
	var waves: Array[Dictionary] = []

	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _c_enemy_power() -> float:
		return 1.0
	func _trait_mult(_kind: String) -> float:
		return 1.0
	func _oath_val(_key: String) -> float:
		return 0.0
	func _hero_action_live() -> bool:
		return true
	func _pop_hero_damage(_damage: float) -> void:
		pass
	func _set_hero_flash(_value: float) -> void:
		pass
	func _shake_combat(_amount: float) -> void:
		pass
	func _dash_ghost(_foe: Foe) -> void:
		pass
	func _shatter(_foe: Foe) -> void:
		pass
	func on_foe_killed(_foe: Foe) -> void:
		pass
	func _slam_wave(at_x: float, radius: float, key: String, _dir := 1.0) -> void:
		waves.append({"x": at_x, "radius": radius, "key": key})
	func _boss_impact_fx(at_x: float, radius: float, key: String, _face: int, _contact := 0.0) -> void:
		waves.append({"x": at_x, "radius": radius, "key": key})
	func on_foe_attack(foe: Foe) -> void:
		var before := hero_hp
		super.on_foe_attack(foe)
		contacts.append({"time": clock, "damage": before - hero_hp,
			"x": foe.position.x, "y": foe.position.y, "anim": foe._attack_anim,
			"pose": foe._pose_texture(), "center": foe.special_center_x(),
			"radius": foe.reach()})
	func on_foe_meteor(foe: Foe) -> Node2D:
		var effect: Node2D = super.on_foe_meteor(foe)
		casts.append(effect)
		return effect


const STEP := 1.0 / 120.0
var arena: Arena
var cases := 0


func _init() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\", "/")
	var qa := ProjectSettings.globalize_path("res://build/qa/").replace("\\", "/")
	if profile.is_empty() or profile != OS.get_environment("LOCALAPPDATA").replace("\\", "/") \
			or not profile.begins_with(qa) or not profile.contains("boss-pattern"):
		push_error("BossPatternCheck requires one disposable build/qa/*boss-pattern* profile in both APPDATA variables")
		quit(1)
		return
	create_timer(35.0).timeout.connect(func() -> void:
		push_error("BossPatternCheck timed out after an assertion or unfinished pattern")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	Foe.pixel_motion_pilot = false
	Foe.force_special = false
	arena = Arena.new()
	arena.save_muted = true
	root.add_child(arena)
	arena.ground_y = 320.0
	arena._phase = "fight"
	for key in FoeTiers.SPECIAL_KIND:
		if _check_locked_range(str(key)) != true:
			quit(1)
			return
	if _check_locked_range("orc") != true: # Default midboss warning.
		quit(1)
		return
	for key in FoeTiers.SPECIAL_KIND:
		var move := str(FoeTiers.special_kind(str(key))[4])
		if move in ["dash", "jump"]:
			if _check_movement(str(key), move) != true:
				quit(1)
				return
	if await _check_live_movement() != true:
		quit(1)
		return
	if _check_frost_combo() != true:
		quit(1)
		return
	for key in ["gargoyle", "plague_hag", "bloodmoon_avatar"]:
		for dodge in [false, true]:
			if _check_meteor(key, dodge) != true:
				quit(1)
				return
	for death in [false, true]:
		for state in ["tell", "dash", "jump", "meteor", "second-hit"]:
			if await _check_cancel(state, death) != true:
				quit(1)
				return
	arena.queue_free()
	await process_frame
	print("BossPatternCheck OK: %d cases, fixed warning ranges, moving contacts, two real frost strikes, meteor landing/cancellation" % cases)
	quit(0)


func _foe(key: String) -> Foe:
	arena.contacts.clear()
	arena.casts.clear()
	arena.waves.clear()
	arena.clock = 0.0
	arena.hero_x = 200.0
	arena.hero_hp = 1000000.0
	arena._hero_dead = false
	var tier := FoeTiers.get_tier(key)
	for act in StageDefs.ACTS:
		if str(act["boss"]) == key:
			tier["anim_key"] = str(act["boss_anim"])
			break
	var foe := Foe.new()
	foe.setup(tier, 1000.0, 0.0, true)
	arena.add_child(foe)
	foe.set_process(false)
	foe.position = Vector2(arena.hero_x + foe.body_half() + 26.0, arena.ground_y)
	foe.stop_x = foe.position.x
	foe.hero_x = arena.hero_x
	foe.engaged = true
	foe.set_combat_active(true)
	foe._attack_cd = 0.0
	foe._swing_n = Foe.SPECIAL_EVERY - 1
	_step(foe)
	assert(foe.telling() and foe.special_swing, "Special warning did not begin: " + key)
	assert(foe.pattern_active(), "Warning is not considered an active pattern")
	return foe


func _step(foe: Foe, delta := STEP) -> void:
	arena.clock += delta
	foe.hero_x = arena.hero_x
	if not foe.dying:
		foe._tick_attack(delta)
	if foe._move_tw != null and foe._move_tw.is_valid():
		foe._move_tw.pause()
		# The synchronous clock has no SceneTree frame to retire completed tweens.
		if not foe._move_tw.custom_step(delta):
			foe._move_tw.kill()


func _finish_tell(foe: Foe) -> void:
	for _i in 300:
		if not foe.telling():
			return
		_step(foe)
	assert(false, "Warning never completed: " + foe.key)


func _dispose(foe: Foe) -> void:
	foe.set_combat_active(false)
	foe.free()


func _contact_pose(foe: Foe) -> Texture2D:
	var frames: Array = foe._special_frames if not foe._special_frames.is_empty() else foe._attack_frames
	return frames[foe._attack_frame_at(foe._impact_at(), frames.size())]


func _check_locked_range(key: String) -> bool:
	var foe := _foe(key)
	var center := foe.special_center_x()
	var radius := foe.reach()
	var move := str(foe._sp[4])
	var expected := arena.hero_x if move == "meteor" else foe.position.x
	assert(is_equal_approx(center, expected), "Warning starts over the wrong target: " + key)
	arena.hero_x -= radius + 300.0
	foe.position.x += 420.0
	_step(foe, 0.05)
	assert(is_equal_approx(foe.special_center_x(), center), "Warning chased a moving target: " + key)
	assert(is_equal_approx(foe.reach(), radius), "Warning radius changed during the tell: " + key)
	# Evaluate the real Main damage boundary at contact, independently of movement timing.
	foe._tell_t = -1.0
	foe._attack_anim = foe._impact_at()
	arena.hero_x = center + radius + 1.0
	foe.position.x = arena.hero_x # Old body-centered hit checks wrongly hit this position.
	arena.on_foe_attack(foe)
	assert(float(arena.contacts.back()["damage"]) == 0.0, "Damage outside the warned range: " + key)
	arena.hero_x = center + radius - 1.0
	foe.position.x = arena.hero_x + radius * 3.0
	arena.on_foe_attack(foe)
	assert(float(arena.contacts.back()["damage"]) > 0.0, "Warned interior misses after the caster moves: " + key)
	assert(not arena.waves.is_empty(), "Special impact produced no effect route: " + key)
	for wave in arena.waves:
		assert(is_equal_approx(float(wave["x"]), center), "Effect and damage centers disagree: " + key)
		assert(is_equal_approx(float(wave["radius"]), radius), "Effect and damage radii disagree: " + key)
	_dispose(foe)
	cases += 1
	return true


func _check_movement(key: String, move: String) -> bool:
	var foe := _foe(key)
	var center := foe.special_center_x()
	var origin := foe.position
	_finish_tell(foe)
	foe._attack_cd = 0.0 # An expired cooldown cannot start another swing during movement/return.
	var swings := foe._swing_n
	var samples := {}
	var repeated_impact_checked := false
	for _i in 600:
		if not foe.pattern_active():
			break
		_step(foe)
		assert(foe._swing_n == swings, "Moving pattern started an overlapping swing: " + key)
		if (foe._dash_pose or foe._airborne) and arena.contacts.is_empty():
			samples[foe._pose_texture()] = true
		if not arena.contacts.is_empty() and not repeated_impact_checked:
			foe._emit_attack_impact()
			foe._emit_attack_impact()
			assert(arena.contacts.size() == 1, "Contact helper emitted duplicate damage: " + key)
			repeated_impact_checked = true
	assert(not foe.pattern_active(), "Moving pattern did not release its lock: %s (anim %.3f, dash %s, air %s, tween %.3f, hits %d)" % [key, foe._attack_anim, foe._dash_pose, foe._airborne, foe._move_tw.get_total_elapsed_time(), arena.contacts.size()])
	assert(samples.size() >= 2, "Movement held one frozen preparation pose: " + key)
	assert(arena.contacts.size() == 1, "Moving pattern did not hit exactly once: " + key)
	var hit: Dictionary = arena.contacts[0]
	assert(absf(float(hit["x"]) - center) < 0.1, "Damage did not occur on arrival: " + key)
	assert(absf(float(hit["y"]) - arena.ground_y) < 0.1, "Damage happened before landing: " + key)
	assert(hit["pose"] == _contact_pose(foe), "Arrival damage does not show the contact pose: " + key)
	assert(absf(float(hit["anim"]) - foe._impact_at()) <= STEP * 1.6, "Arrival restarted the attack instead of striking: " + key)
	assert(float(hit["damage"]) > 0.0, "A stationary hero avoided the committed arrival attack: " + key)
	assert(absf(foe.position.x - (origin.x if move == "dash" else center)) < 0.1, "Movement ended at the wrong rest position: " + key)
	_dispose(foe)
	cases += 1
	return true


func _check_live_movement() -> bool:
	var foe := _foe("wraith_knight")
	var origin := foe.position
	foe._attack_cd = 20.0
	foe.set_process(true)
	# Use the actual SceneTree clock once, without pausing or cleaning up its tween.
	await create_timer(2.0).timeout
	foe.set_process(false)
	assert(arena.contacts.size() == 1, "Live movement did not produce exactly one contact")
	assert(not foe.pattern_active(), "Live movement retained its completed tween lock")
	assert(foe._move_tw == null or not foe._move_tw.is_valid(), "SceneTree did not retire the completed movement tween")
	assert(foe.position.is_equal_approx(origin), "Live dash did not return to its resting position")
	assert(arena.contacts[0]["pose"] == _contact_pose(foe), "Live contact missed its source contact pose")
	_dispose(foe)
	cases += 1
	return true


func _check_frost_combo() -> bool:
	var foe := _foe("frost_golem")
	_finish_tell(foe)
	foe._attack_cd = 0.0
	var swings := foe._swing_n
	var resets := 0
	var previous := foe._attack_anim
	for _i in 600:
		if not foe.pattern_active():
			break
		_step(foe)
		if foe._attack_anim >= 0.0 and foe._attack_anim + STEP < previous:
			resets += 1
		previous = foe._attack_anim
		assert(foe._swing_n == swings, "Frost combo overlaps a cooldown swing")
	assert(not foe.pattern_active() and resets == 1, "Frost second hit has no distinct restarted motion")
	assert(arena.contacts.size() == 2 and foe._special_hits == 2, "Frost must contact exactly twice")
	for hit in arena.contacts:
		assert(hit["pose"] == _contact_pose(foe), "Frost timer dealt damage between real contact poses")
		assert(absf(float(hit["anim"]) - foe._impact_at()) <= STEP * 1.6, "Frost damage missed its motion contact")
	var gap: float = arena.contacts[1]["time"] - arena.contacts[0]["time"]
	var expected := foe.attack_dur() - foe._impact_at() + foe._impact_at() / 1.5
	assert(absf(gap - expected) < STEP * 4.0, "Frost second hit still uses an unrelated damage timer")
	_dispose(foe)
	cases += 1
	return true


func _check_meteor(key: String, dodge: bool) -> bool:
	var foe := _foe(key)
	var center := foe.special_center_x()
	var radius := foe.reach()
	for _i in 400:
		if foe._meteor_t >= 0.0:
			break
		_step(foe)
	assert(foe._meteor_t > 0.0 and is_instance_valid(foe._meteor_fx), "Meteor cast created no falling effect")
	assert(arena.contacts.is_empty() and foe._special_hits == 0, "Meteor casting dealt damage before landing")
	assert(arena.casts.size() == 1 and foe.pattern_active(), "Meteor fall lost its pattern lock")
	var ball: Node2D = foe._meteor_fx
	foe._emit_attack_impact()
	assert(arena.casts.size() == 1, "Meteor cast was emitted twice")
	arena.hero_x = center + radius + 1.0 if dodge else center
	foe.position.x += radius * 3.0
	var before := arena.hero_hp
	for _i in 150:
		if not arena.contacts.is_empty():
			break
		_step(foe)
	assert(arena.contacts.size() == 1 and foe._special_hits == 1, "Meteor landing did not strike once")
	assert((arena.hero_hp == before) == dodge, "Meteor damage ignored its fixed landing range")
	assert(is_equal_approx(float(arena.contacts[0]["center"]), center), "Meteor followed the caster after launch")
	assert(not is_instance_valid(ball) or ball.is_queued_for_deletion(), "Landed meteor remains in the scene")
	_dispose(foe)
	cases += 1
	return true


func _check_cancel(state: String, death: bool) -> bool:
	var key: String = {"tell":"eye_mass", "dash":"wraith_knight", "jump":"sanctum_guardian",
		"meteor":"gargoyle", "second-hit":"frost_golem"}[state]
	var foe := _foe(key)
	if state in ["dash", "jump"]:
		_finish_tell(foe)
		for _i in 6:
			_step(foe)
	elif state == "meteor":
		for _i in 400:
			if foe._meteor_t > 0.0:
				break
			_step(foe)
		assert(is_instance_valid(foe._meteor_fx), "Cancellation fixture did not reach meteor flight")
	elif state == "second-hit":
		for _i in 400:
			if arena.contacts.size() == 1:
				break
			_step(foe)
		assert(arena.contacts.size() == 1, "Cancellation fixture did not reach frost recovery")
	var tween: Tween = foe._move_tw
	var ball: Node2D = foe._meteor_fx
	var hits := arena.contacts.size()
	var hp := arena.hero_hp
	var cooldown := foe._attack_cd
	if death:
		foe._die()
	else:
		foe.set_combat_active(false)
	var stopped := foe.position
	assert(not foe.pattern_active(), "Cancelled pattern is still active: " + state)
	assert(foe._tell_t < 0.0 and foe._attack_anim < 0.0 and foe._meteor_t < 0.0,
		"Cancelled warning/attack/fall clock remains armed: " + state)
	assert(not foe._airborne and not foe._dash_pose, "Cancelled movement pose remains armed: " + state)
	assert(tween == null or not tween.is_valid(), "Cancelled movement tween is still alive: " + state)
	assert(not is_instance_valid(ball) or ball.is_queued_for_deletion(), "Cancelled meteor is still alive")
	assert(is_equal_approx(foe._attack_cd, cooldown), "Cancellation reset the preserved cooldown")
	assert(is_equal_approx(foe.special_center_x(), foe.position.x), "Cancelled target lock was not cleared")
	for _i in 240:
		_step(foe)
	assert(arena.contacts.size() == hits and arena.hero_hp == hp, "Damage arrived after cancellation: " + state)
	assert(foe.position.is_equal_approx(stopped), "Cancelled movement continued moving: " + state)
	await process_frame
	assert(not is_instance_valid(ball), "Cancelled falling effect survived a frame")
	_dispose(foe)
	cases += 1
	return true
