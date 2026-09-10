extends SceneTree

# Combat showcase demo using the real renderer; the HUD is hidden for inspection.
# Run through tools/action_showcase.py, which isolates both Windows app-data folders.
# Engine options: --action-output=build/qa/action-after, --capture-skin=dragon,
# --capture-boss=10, --capture-skills=strike_rare,wave_rare,field_uncommon,ward_legend.
# Every rendered frame is saved: 600 PNGs at 60 fps.
const SECONDS := 10
const FPS := 60
const SKILLS := ["strike_rare", "wave_epic", "field_rare", "ward_common"]

func _init() -> void:
	# Refuse to instantiate Main unless the launcher supplied a disposable profile.
	var profile := OS.get_environment("BLOODLORD_CAPTURE_PROFILE")
	if profile.is_empty() or OS.get_environment("APPDATA") != profile \
			or OS.get_environment("LOCALAPPDATA") != profile:
		push_error("Run through tools/action_showcase.py to isolate the player save.")
		quit(1)
		return
	create_timer(120.0).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(576, 896)
	var output := "res://build/qa/action-after"
	var boss_stage := 0
	var skin_name := "valentino_1"
	var orc_study := false
	var study_key := "orc"
	var skills: Array = SKILLS.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-orc":
			orc_study = true
		if arg.begins_with("--capture-foe="):
			study_key = arg.trim_prefix("--capture-foe=")
			orc_study = true
		if arg.begins_with("--action-output="):
			output = arg.trim_prefix("--action-output=")
			if not output.is_absolute_path():
				output = "res://" + output
		if arg.begins_with("--capture-boss="):
			boss_stage = int(arg.trim_prefix("--capture-boss="))
		if arg.begins_with("--capture-skin="):
			skin_name = arg.trim_prefix("--capture-skin=")
		if arg.begins_with("--capture-skills="):
			skills = Array(arg.trim_prefix("--capture-skills=").split(",", false))
	assert(not SkinDefs.of(skin_name).is_empty(), "Unknown capture skin")
	assert(FoeTiers.TIERS.has(study_key), "Unknown capture foe")
	assert(skills.size() > 0 and skills.size() <= 4, "The 10-second demo supports one to four skills")
	for key in skills:
		assert(SkillDefs.all_keys().has(str(key)), "Unknown capture skill")
		assert(not bool(SkillDefs.rule_of(str(key)).get("passive", false)), "Capture needs active skills")
	var folder := output + "-frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	while not scene.is_node_ready() or not scene.is_processing():
		await process_frame
	print("ACTION SHOWCASE LOADED: %s" % output)
	seed(20260908)
	scene._hud_root.hide()
	scene.skin = skin_name
	scene._combo_live.clear()
	scene.skill_auto_equip = false
	scene.skill_equipped.clear()
	scene.stage = boss_stage if boss_stage > 0 else 1
	Foe.force_special = boss_stage > 0
	scene._restart_stage("ACTION SHOWCASE")
	while scene._phase != "fight":
		await process_frame
	if orc_study:
		# Use the production battle code with durable targets. Start the same
		# real approach used between enemies; no animation-only stand-ins.
		var tier := FoeTiers.get_tier(study_key)
		tier["midboss"] = true
		for foe in get_nodes_in_group("foes"):
			foe.setup(tier, scene._c_enemy_power(), 0.0)
			foe.position.x += 200.0
			foe.stop_x = foe.position.x
			foe._body_half = -1.0
			foe._art_base = -1.0
			foe._attack_anim = -1.0
			foe._tell_t = -1.0
			foe._swing_n = 0
			scene._forget_foe(foe)
		scene._phase = "advance"
		scene._hero_hit_t = -1.0
		scene._combo = 0
		scene._attack_t = 0.0
	for key in skills:
		scene.skill_owned[key] = 1
	var next_skill := 0
	var dashed := false
	var motions := {}
	var casts := {}
	var orc_special := false
	var special_queued := false
	var death_target: Foe = null
	var death_seen := false
	var advance_after_death := false
	var observations := []
	for frame in SECONDS * FPS:
		scene.hero_hp = scene.max_hp()
		# Keep the demonstration targets alive through all four skill families.
		for foe in get_nodes_in_group("foes"):
			if not foe.dying and not (orc_study and frame >= 492 and foe == scene._engaged):
				foe.max_hp = 1000000.0
				foe.hp = foe.max_hp
		if orc_study and frame >= 330 and not special_queued and is_instance_valid(scene._engaged):
			scene._engaged._swing_n = 2
			scene._engaged._attack_cd = 0.0
			special_queued = true
		if orc_study and frame == 492 and is_instance_valid(scene._engaged):
			# The next genuine contact kills it, then the real advance path runs.
			death_target = scene._engaged
			scene._engaged.hp = 0.1
		# Actual death/advance path exposes the running motion and its world scroll.
		if not orc_study and boss_stage == 0 and not dashed and frame >= 132 and is_instance_valid(scene._engaged):
			scene._engaged.take_damage(scene._engaged.hp * 2.0)
			dashed = true
		if next_skill < skills.size() and frame >= 204 + next_skill * 96:
			var key: String = str(skills[next_skill])
			scene.skill_equipped.clear()
			scene.skill_equipped.append(key)
			scene._skill_cd[key] = 0.0
			next_skill += 1
		await process_frame
		await RenderingServer.frame_post_draw
		if is_instance_valid(death_target):
			death_seen = death_seen or death_target.dying
		advance_after_death = advance_after_death or (death_seen and scene._phase == "advance")
		motions[str(scene._motion)] = true
		if scene._skill_action != "":
			casts[str(scene._skill_action)] = true
		if is_instance_valid(scene._engaged):
			var foe: Foe = scene._engaged
			orc_special = orc_special or (foe.special_swing and foe._attack_anim >= foe._impact_at() \
				and foe._impact_sent)
			observations.append({"frame": frame, "hero": scene._motion,
				"pose": scene._hero_frame_index(), "hero_x": scene.hero_x,
				"foe_x": foe.position.x, "foe_tell": foe._tell_t,
				"foe_attack": foe._attack_anim, "foe_special": foe.special_swing,
				"foe_y": foe.position.y, "foe_airborne": foe._airborne,
				"foe_dash": foe._dash_pose, "foe_hits": foe._special_hits,
				"meteor": foe._meteor_t, "center": foe.special_center_x(),
				"phase": scene._phase, "vfx": get_nodes_in_group("combat_vfx").size()})
		assert(scene.hero_face == 1, "Hero turned away from the right-hand targets")
		var capture := root.get_texture().get_image()
		var combat := capture.get_region(Rect2i(0, 96, 576, 320))
		var result := combat.save_png("%s/%04d.png" % [folder, frame])
		assert(result == OK, "Could not save capture frame")
	print("ACTION SHOWCASE SAVED: %s (%d frames at %d fps)" % [folder, SECONDS * FPS, FPS])
	print("ACTION MOTIONS: %s; SKILLS: %s" % [motions.keys(), casts.keys()])
	if orc_study:
		print("ACTION STUDY: %s; SPECIAL: %s; DEATH: %s; ADVANCE AFTER DEATH: %s" \
			% [study_key, orc_special, death_seen, advance_after_death])
		assert(orc_special, "The selected foe special did not resolve")
		assert(death_seen and advance_after_death, "Missing the real death/advance transition")
		assert(motions.has("dash") and motions.has("attack") and motions.has("attack2") \
			and motions.has("attack3") and motions.has("heavy"), "Missing a choreography beat")
	if boss_stage > 0:
		assert(orc_special, "Boss special did not reach its contact pose")
	var log_file := FileAccess.open(output + "-timing.json", FileAccess.WRITE)
	log_file.store_string(JSON.stringify(observations))
	if casts.size() != skills.size():
		push_error("A showcase skill did not activate")
		quit(1)
	else:
		quit()
