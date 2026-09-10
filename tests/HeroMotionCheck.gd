extends SceneTree

# Run with an isolated APPDATA, like the other game checks.
func _init() -> void:
	# Original logical clips; the displayed full roster is checked by PixelPilotCheck.
	Foe.pixel_motion_pilot = false
	create_timer(30.0).timeout.connect(func() -> void: quit(1))
	var game: Node = load("res://Main.gd").new()
	game._hero = Sprite2D.new()
	var checked := 0
	for entry in SkinDefs.SKINS:
		game.skin = str(entry["id"])
		for motion in game.COMBO_MOTIONS + game.SKILL_MOTIONS:
			assert(not game._hero_motion_dir(motion).ends_with("_v2"),
				"Rejected procedural hero poses were re-enabled")
			game._play(motion, game.SKILL_DUR if motion in game.SKILL_MOTIONS else 0.0)
			assert(not game._hero_frames.is_empty(), "%s/%s has no motion" % [game.skin, motion])
			assert(game._hero.texture == game._hero_frames[0], "New action kept the previous pose")
			if motion in game.SKILL_MOTIONS:
				assert(is_equal_approx(game._motion_duration, game.SKILL_DUR), "Skill pose outlives cast")
			var last := -1
			var seen := {}
			var samples_in_pose := 0
			var source_hold := int(ceil(game._motion_duration * 60.0 / game._hero_frames.size())) + 1
			# Sample the actual 60 Hz display cadence: dense arbitrary samples can
			# pass while short in-betweens disappear in the real renderer.
			for step in int(ceil(game._motion_duration * 60.0)) + 1:
				game._hero_anim = minf(float(step) / 60.0, game._motion_duration)
				var index: int = game._hero_frame_index()
				assert(index >= last and index < game._hero_frames.size(), "Action rewinds or overruns")
				assert(last < 0 or index - last <= 1, "60 Hz skipped an authored in-between: %s/%s" % [game.skin, motion])
				samples_in_pose = samples_in_pose + 1 if index == last else 1
				assert(samples_in_pose <= source_hold, "Pose stalled beyond source timing: %s/%s" % [game.skin, motion])
				seen[index] = true
				last = index
			assert(seen.size() == game._hero_frames.size(), "60 Hz did not display every pose: %s/%s" % [game.skin, motion])
			game._hero_anim = game._impact_time(motion, game._motion_duration)
			assert(game._hero_frame_index() == game._impact_frame(motion), "Damage misses contact pose")
			game._play(motion, game.SKILL_DUR)
			var held: Texture2D = game._hero.texture
			game._tick_motion(game._motion_duration * 0.5, true)
			assert(game._hero.texture == held, "Hitstop failed to hold the displayed pose")
			assert(game._hero_anim > 0.0, "Hitstop stopped the combat animation clock")
			game._tick_motion(0.0, false)
			assert(game._hero.texture == game._hero_frames[game._hero_frame_index()], "Pose did not catch up")
			checked += 1
		game._play("dash")
		if game.skin == "valentino_1":
			assert(game._hero_frames.size() == 9, "Run must use the original whole-body poses")
			# Sample inside each pose at 60 Hz, then one complete stride later.
			for step in 24:
				game._hero_anim = game.VALENTINO_RUN_START + (float(step) + 0.5) / 60.0
				var pose: int = game._hero_frame_index()
				assert(pose == 3 + step / 4, "Run cadence skips or stalls a stride pose")
				game._hero_anim += game.VALENTINO_RUN_CYCLE
				assert(game._hero_frame_index() == pose, "Run period changes after startup")
		if game.skin == "shadow":
			assert(game._hero_frames.size() == 10, "Retouched run bridge is missing from the game: %s" % game.skin)
		var dash_seen := {}
		# The standing takeoff is allowed once. Several later cycles must keep
		# using stride poses instead of restarting that standing pose.
		for step in int(ceil(game._motion_duration * 4.0 * 60.0)) + 1:
			game._hero_anim = float(step) / 60.0
			var index: int = game._hero_frame_index()
			assert(index >= 0 and index < game._hero_frames.size(), "Dash frame overruns")
			if game._hero_anim < game._motion_duration:
				dash_seen[index] = true
			elif game._hero_loop_from > 0:
				assert(index >= game._hero_loop_from, "Dash replayed its standing takeoff: %s" % game.skin)
		assert(dash_seen.size() == game._hero_frames.size(), "Dash did not show its complete first stride")
		game._hero_dead = true
		game._play("death", game.REVIVE_TIME)
		var first: Texture2D = game._hero.texture
		game._tick_motion(0.40)
		assert(game._hero.texture != first, "Death animation is stuck at its first frame")
		game._tick_motion(game.REVIVE_TIME)
		assert(game._hero.texture == game._hero_frames.back(), "Death did not hold the fallen pose")
		assert(game._motion == "death", "Dead hero returned to idle")
		game._hero_dead = false
	game._hero.free()
	game.free()
	print("HeroMotionCheck OK: %d actions at 60 Hz, %d dash loops and death animations" % [checked, SkinDefs.SKINS.size()])
	quit()
