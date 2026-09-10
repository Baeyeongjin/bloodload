extends SceneTree

# Capture production Main UI using only an isolated disposable save profile.
const OUTPUT := "res://build/qa/portrait-review"
var observations: Array = []

func _init() -> void:
	var profile := OS.get_environment("BLOODLORD_CAPTURE_PROFILE")
	if profile.is_empty() or OS.get_environment("APPDATA") != profile \
			or OS.get_environment("LOCALAPPDATA") != profile \
			or not profile.replace("\\", "/").begins_with(ProjectSettings.globalize_path("res://build/qa/")):
		push_error("PortraitReview requires the same disposable build/qa profile in both APPDATA variables")
		quit(1)
		return
	create_timer(90.0).timeout.connect(func() -> void: quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(576, 896)
	var game: Node = load("res://Main.tscn").instantiate()
	game.save_muted = true
	root.add_child(game)
	while not game.is_node_ready() or not game.is_processing():
		await process_frame
	game.set_process(false)
	game.best_stage = 1000
	game._select_tab("home")
	for skin in SkinDefs.SKINS:
		game.skins_owned[str(skin["id"])] = true
	game._refresh_outfit()
	game._outfit_view.show()
	for i in SkinDefs.SKINS.size():
		_check_icon(game._outfit_cells[i]["icon"], str(SkinDefs.SKINS[i]["id"]), true, "outfit")
	await _capture("outfit-all")
	game._outfit_view.hide()
	game.skins_owned.clear()
	game._select_tab("shop")
	game._shop_set_mode("wear")
	for i in SkinDefs.SKINS.size():
		_check_icon(game._wear_rows[i]["icon"], str(SkinDefs.SKINS[i]["id"]), true, "shop")
	for i in [0, 4, 8]:
		var scroll: ScrollContainer = game._wear_view.get_parent()
		scroll.ensure_control_visible(game._wear_rows[i]["root"])
		await _capture("shop-%d" % i)
	game._select_tab("home")
	game.codex_found = 0
	game.codex_knowledge = 0
	for key in FoeTiers.all_keys():
		game.codex[str(key)] = 12
		game.codex_found += 1
		game.codex_knowledge += FoeTiers.codex_level(12)
	game._codex_view.show()
	game._codex_set_mode("foe")
	for _frame in 3:
		await process_frame
	for key in ["orc", "frost_golem", "slime"]:
		game._select_codex(key)
		_check_icon(game._codex_detail["big"], key, false, "codex-detail")
		_check_icon(game._codex_cells[key]["icon"], key, false, "codex-list")
		var scroll: ScrollContainer = game._codex_cells[key]["icon"].get_parent().get_parent().get_parent()
		scroll.ensure_control_visible(game._codex_cells[key]["icon"].get_parent())
		await _capture("codex-" + key)
	game._codex_view.hide()
	var hud_sheet := Image.create_empty(540, 288, false, Image.FORMAT_RGBA8)
	for i in SkinDefs.SKINS.size():
		var id := str(SkinDefs.SKINS[i]["id"])
		game.skins_owned[id] = true
		game._outfit_pick(id)
		game._refresh_hud() # The regular process loop does this after a skin change.
		_check_icon(game._hud_portrait, id, false, "hud-equipped", "avatar")
		for _frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		hud_sheet.blit_rect(root.get_texture().get_image(), Rect2i(0, 0, 180, 96),
			Vector2i(i % 3 * 180, i / 3 * 96))
	assert(hud_sheet.save_png(OUTPUT + "/hud-nine-skins.png") == OK)
	game._select_tab("raid")
	game._raid_set_mode("trial")
	game._refresh_trial()
	_check_icon(game._trial_ui["art"], "ruin_warden", false, "trial")
	await _capture("trial")
	game._raid_set_mode("rush")
	for i in StageDefs.ACTS.size():
		game.rush_best = i
		game._refresh_rush()
		_check_icon(game._rush_ui["art"], str(StageDefs.ACTS[i]["boss_anim"]), false, "rush")
		if i in [0, 9]:
			await _capture("rush-%d" % i)
	game._raid_set_mode("boss")
	for i in EventDefs.BOSSES.size():
		game._dev_boss = i
		game._refresh_boss()
		_check_icon(game._boss_art, str(EventDefs.BOSSES[i]["anim"]), false, "weekly-boss")
		if i in [0, 3]:
			await _capture("weekly-boss-%d" % i)
	var log := FileAccess.open(OUTPUT + "/geometry.json", FileAccess.WRITE)
	log.store_string(JSON.stringify(observations, "\t"))
	print("PortraitReview OK: 13 production UI captures, 48 portrait bindings checked")
	quit(0)


func _check_icon(icon: TextureRect, actor: String, flipped: bool, location: String, image := "portrait") -> void:
	assert(icon.texture != null)
	assert(icon.texture.resource_path == "res://assets/anim/pixel_pilot/%s/%s.png" % [actor, image])
	assert(icon.flip_h == flipped)
	assert(icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert(icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	observations.append({"location": location, "actor": actor,
		"texture": icon.texture.resource_path, "source_size": str(icon.texture.get_size()),
		"box": str(icon.size), "position": str(icon.global_position), "flipped": icon.flip_h})


func _capture(label: String) -> void:
	for _frame in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png") == OK)
