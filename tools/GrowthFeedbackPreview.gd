extends SceneTree

const OUTPUT := "res://build/qa/growth-feedback-preview"
var game: Node


func _init() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\", "/")
	var qa := ProjectSettings.globalize_path("res://build/qa/").replace("\\", "/")
	if not profile.begins_with(qa) or not profile.contains("growth-feedback-preview") \
			or profile != OS.get_environment("LOCALAPPDATA").replace("\\", "/"):
		push_error("GrowthFeedbackPreview requires a fresh build/qa/*growth-feedback-preview* profile in BOTH APPDATA variables")
		quit(1)
		return
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("GrowthFeedbackPreview timed out")
		quit(1))
	root.size = Vector2i(576, 896)
	root.content_scale_size = Vector2i(576, 896)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_run.call_deferred()


func _run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.save_muted = true
	root.add_child(game)
	while not game.is_node_ready() or not game.is_processing():
		await process_frame
	await create_timer(0.4).timeout
	game.set_process(false)
	for popup in game._popups():
		if popup != null:
			popup.hide()
	game._clear_view.hide()
	game._power_band.hide()
	game._boss_cut_clear()
	game._clear_foes()
	game.stage = 100
	game.best_stage = 100
	game.gem = 420.0
	game.tickets = {"weapon": 8, "skill": 7}
	game.whet = 100000.0
	game.skill_auto_equip = false
	game.gear_inventory.clear()
	game.skill_owned.clear()
	game.gacha_shards.clear()
	game._refresh_hud()
	game._power_band.hide()
	game._select_tab("summon")
	game._set_gacha_kind("weapon")
	var rarities := ["common", "common", "common", "common", "uncommon",
		"rare", "epic", "legend", "mythic", "rare"]
	var items: Array[Dictionary] = []
	for rarity in rarities:
		seed(79)
		items.append(game._receive_gacha_gear(rarity, "weapon"))
	game._show_gacha_results(items)
	if await _capture("gear-ten-pull") != true:
		quit(1)
		return
	game._gacha_reveal.hide()
	game._set_gacha_kind("skill")
	items.clear()
	for rarity in ["common", "common", "common", "common", "rare", "uncommon", "epic", "legend", "rare", "epic"]:
		seed(113)
		items.append(game._receive_gacha_skill(rarity))
	game._show_gacha_results(items)
	if await _capture("skill-ten-pull") != true:
		quit(1)
		return
	game._gacha_reveal.hide()
	game._select_tab("gear")
	game._set_gear_mode("inventory")
	var item := GearDefs.make("weapon", 12, GachaDefs.rarity("rare"))
	item["lv"] = 18
	item["copies"] = 4
	var key := str(item["icon"])
	game.gear_inventory[key] = item
	game.gacha_shards["gear:" + key] = 3
	game._refresh_gear_inventory()
	game._open_gear_detail(key)
	if await _capture("gear-next-level") != true:
		quit(1)
		return
	item = GearDefs.make("weapon", 12, GachaDefs.rarity("mythic"))
	item["lv"] = 100
	item["copies"] = 1
	key = str(item["icon"])
	game.gear_inventory[key] = item
	game.gacha_shards["gear:" + key] = 0
	game._open_gear_detail(key)
	if await _capture("gear-mythic-shard-shortage") != true:
		quit(1)
		return
	print("GrowthFeedbackPreview OK: four production UI captures at 576x896; save_muted=true")
	game.queue_free()
	await process_frame
	quit(0)


func _capture(label: String) -> bool:
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	if game._gear_detail.is_visible_in_tree():
		for child in game._gear_detail.get_children():
			if child is Label and (child.position.y in [86.0, 114.0, 146.0, 172.0, 198.0, 318.0]):
				var width: float = child.get_theme_font("font").get_string_size(child.text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
				assert(width <= child.size.x, "Rendered detail text is clipped: %s (%.1f > %.1f)" % [child.text, width, child.size.x])
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(576, 896))
	assert(image.save_png(OUTPUT + "/" + label + ".png") == OK)
	return true
