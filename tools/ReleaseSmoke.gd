extends SceneTree

# Run against the exported PCK, with a fresh disposable profile supplied by the launcher.
func _init() -> void:
	var profile := OS.get_environment("BLOODLORD_CAPTURE_PROFILE").replace("\\", "/")
	if not "/build/qa/" in profile or profile != OS.get_environment("APPDATA").replace("\\", "/") \
			or profile != OS.get_environment("LOCALAPPDATA").replace("\\", "/"):
		push_error("ReleaseSmoke requires a disposable profile in both app-data folders")
		quit(2)
		return
	create_timer(35.0).timeout.connect(func() -> void: quit(1))
	call_deferred("_run")


func _run() -> void:
	assert(not Foe.pixel_motion_pilot, "Rejected replacement art is enabled")
	var actors: Array = FoeTiers.TIERS.keys()
	actors.append_array(["boss_1", "boss_2", "boss_3", "boss_4", "boss_5"])
	for skin in SkinDefs.SKINS:
		actors.append(str(skin["id"]))
	assert(actors.size() == 57)
	for actor in actors:
		assert(not Foe.pixel_pilot_ready(actor), "Replacement actor is enabled: %s" % actor)
		assert(Foe.portrait_path(actor, "original") == "original", "Replacement portrait is enabled")
		for motion in ["walk", "attack"]:
			assert(Assets.frames("res://assets/anim/%s_%s" % [actor, motion]).size() > 1,
				"Packed original animation is missing: %s_%s" % [actor, motion])
	var boss_effects: Array = FoeTiers.SPECIAL_KIND.keys()
	boss_effects.append("rock")
	for key in boss_effects:
		var frames := Assets.frames("res://assets/anim/boss_vfx/" + str(key))
		assert(frames.size() == 12, "Packed LibreSprite boss VFX is incomplete: " + str(key))
	var title: Node = load("res://Title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	assert(title.is_node_ready(), "Packed title did not load")
	title.queue_free()
	await process_frame
	var game: Node = load("res://Main.tscn").instantiate()
	game.save_muted = true
	root.add_child(game)
	while not game.is_node_ready() or not game.is_processing():
		await process_frame
	for frame in 120:
		await process_frame
	assert(game._hero.texture != null and not Foe.is_pixel_pilot_texture(game._hero.texture), "Packed gameplay did not restore the original hero")
	assert(game._outfit_cells.size() == 9, "Packed outfit selection did not build")
	for i in SkinDefs.SKINS.size():
		var id := str(SkinDefs.SKINS[i]["id"])
		assert(game._outfit_cells[i]["icon"].texture.resource_path == "res://assets/anim/%s_idle/0.png" % id, "Outfit did not restore its original image")
	assert(game._hud_portrait.texture.resource_path == "res://assets/ui/portrait_hero.png", "HUD did not restore its original portrait")
	for foe in get_nodes_in_group("foes"):
		assert(foe._pose_texture() != null and not Foe.is_pixel_pilot_texture(foe._pose_texture()), "Enemy did not restore its original image")
	assert(game.skill_presets.size() == 3 and game.gear_presets.size() == 3,
		"Fresh game has no saved-build slots")
	game._select_tab("home")
	assert(not game._board_goal.text.is_empty() and not game._board_tactic.text.is_empty())
	game._open_presets()
	await process_frame
	assert(game._preset_body.get_child_count() == 8, "Packed recommendation or preset cards are missing")
	print("ReleaseSmoke OK: original 57 actors, 17 LibreSprite VFX sets, title/gameplay/outfits/HUD, growth board and recommendation/preset cards")
	game.queue_free()
	await process_frame
	quit()
