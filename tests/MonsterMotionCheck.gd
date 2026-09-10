extends SceneTree

# 실제 자산 전체에서 접촉 프레임과 피해 시각을 함께 확인한다. 저장은 열지 않는다.
func _init() -> void:
	# Original logical clips; the displayed full roster is checked by PixelPilotCheck.
	Foe.pixel_motion_pilot = false
	create_timer(30.0).timeout.connect(func() -> void: quit(1))
	var checked := 0
	var tiers: Array = []
	for key in FoeTiers.TIERS:
		for role in 3:
			var tier := FoeTiers.get_tier(key)
			tier["midboss"] = role == 1
			tier["check_boss"] = role == 2
			tiers.append(tier)
	for act in StageDefs.ACTS:
		var tier := FoeTiers.get_tier(str(act["boss"]))
		tier["anim_key"] = str(act["boss_anim"])
		tier["check_boss"] = true
		tiers.append(tier)
	for tier in tiers:
		var foe := Foe.new()
		foe.setup(tier, 1.0, 0.0, bool(tier["check_boss"]))
		assert(not foe._attack_dir.ends_with("_v2") and not foe._special_dir.ends_with("_v2"),
			"Rejected procedural monster poses were re-enabled")
		foe.combat_active = true
		foe.engaged = true
		for special in [false, true]:
			foe.special_swing = special
			var frames: Array = foe._special_frames if special and not foe._special_frames.is_empty() else foe._attack_frames
			if frames.is_empty():
				continue
			var impact: float = foe._impact_at()
			var contact := clampi(int(impact * frames.size() / foe.attack_dur() + 0.00001), 0, frames.size() - 1)
			if not special:
				if foe._attack_dir == "res://assets/anim/orc_attack" and frames.size() == 9:
					# Visually reviewed whole source pose: f3 winds up behind the head;
					# f6 is the forward club strike, for every existing monster size/role.
					assert(contact == 6, "Orc damage precedes its forward club strike")
				else:
					assert(is_equal_approx(impact, foe.attack_dur() * Foe.IMPACT_RATIO),
						"Orc marker changed another monster's normal timing: %s" % foe.key)
			assert(foe._attack_frame_at(impact, frames.size()) == contact, "Contact frame drift: %s" % foe.key)
			var previous := -1
			var samples_in_pose := 0
			var first_frame: int = foe._attack_frame_at(0.0, frames.size())
			var source_hold := int(ceil(foe.attack_dur() * 60.0 / frames.size())) + 1
			var seen := {}
			if special:
				# 첫 프레임은 예고에서 이미 재생된다. 이동/공격이 이를 되감지 않는다.
				foe._tell_t = float(foe._sp[0])
				assert(foe._pose_texture() == frames[0], "Tell skipped its first pose: %s" % foe.key)
				seen[0] = true
				foe._tell_t = -1.0
			# 촘촘한 보간 샘플 대신 실제 60Hz에서 모든 원본 동작이 보이는지 검사한다.
			for i in int(ceil(foe.attack_dur() * 60.0)) + 1:
				var at := minf(float(i) / 60.0, foe.attack_dur())
				var frame: int = foe._attack_frame_at(at, frames.size())
				assert(frame >= previous and frame < frames.size(), "Frame rewind: %s" % foe.key)
				assert(previous < 0 or frame - previous <= 1, "60Hz skipped a pose: %s" % foe.key)
				samples_in_pose = samples_in_pose + 1 if frame == previous else 1
				var allowed_hold := source_hold * (2 if special and frame == first_frame else 1)
				assert(samples_in_pose <= allowed_hold, "Pose stalled beyond source timing: %s" % foe.key)
				seen[frame] = true
				previous = frame
			assert(seen.size() == frames.size(), "60Hz did not show every source pose: %s" % foe.key)
			# 공격 모션 이징이 몸 전체를 임팩트 앞뒤로 순간 이동시키면 안 된다.
			foe._attack_anim = impact - 0.0001
			var before_contact: Vector2 = foe._motion_offset()
			foe._attack_anim = impact + 0.0001
			assert(foe._motion_offset().distance_to(before_contact) <= 1.0,
				"Body jumped at contact: %s" % foe.key)
			foe._attack_anim = 0.0
			if special:
				foe._tell_t = 0.001
				var prepared: Texture2D = foe._pose_texture()
				var prepared_offset: Vector2 = foe._motion_offset()
				foe._tell_t = -1.0
				assert(foe._pose_texture() == prepared, "Windup restarted after tell: %s" % foe.key)
				assert(foe._motion_offset() == prepared_offset, "Body jumped after tell: %s" % foe.key)
				for moving in ["_dash_pose", "_airborne"]:
					foe.set(moving, true)
					assert(foe._pose_texture() == prepared, "Moving windup changed pose: %s" % foe.key)
					foe.set(moving, false)
			foe._impact_sent = false
			foe._echo_hit_t = -1.0
			foe._tick_attack(impact - 0.001)
			assert(not foe._impact_sent, "Early damage: %s" % foe.key)
			foe._tick_attack(0.0011)
			assert(foe._impact_sent, "Late damage: %s" % foe.key)
			assert(foe._pose_texture() == frames[contact], "Damage and pose disagree: %s" % foe.key)
			checked += 1
		foe.free()

	var reaction := Foe.new()
	reaction.setup(FoeTiers.get_tier("skeleton"), 100.0, 0.0)
	reaction.combat_active = true
	reaction.engaged = true
	reaction._attack_anim = reaction._impact_at()
	var held: Texture2D = reaction._pose_texture()
	var offset: Vector2 = reaction._motion_offset()
	var origin: Vector2 = reaction.position
	reaction.set_visual_frozen(true)
	reaction._process(0.12)
	assert(reaction._pose_texture() == held and reaction._motion_offset() == offset, "Hitstop pose moved")
	assert(reaction._attack_anim > reaction._impact_at(), "Visual freeze stopped damage clock")
	reaction.set_visual_frozen(false)
	assert(reaction._pose_texture() != held, "Unfreeze did not catch up to combat")
	assert(reaction.position == origin, "Visual lunge moved combat coordinates")
	# 마지막으로 그린 공격 포즈에서 죽어야 기본 스틸로 순간 전환되지 않는다.
	reaction._shown_texture = held
	reaction._shown_offset = offset
	reaction._die()
	assert(reaction._pose_texture() == held and reaction._motion_offset() == offset, "Death pose snapped")
	reaction.free()
	print("MonsterMotionCheck OK (%d clips at 60Hz, contact/tell/move continuity, frozen/death poses)" % checked)
	quit()
