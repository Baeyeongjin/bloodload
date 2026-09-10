extends "res://tests/FunLoopCheck.gd"

# Inherits fresh-profile guards, save_muted and the real gameplay/UI checks.
const UI_OUTPUT := "res://build/qa/ui-polish"


func _capture_enabled() -> bool:
	return true


func _capture(label: String) -> bool:
	await _shot(label)
	if label != "recommended-loadouts":
		return true
	game._preset_view.hide()
	game.stage = 201
	game.best_stage = 201
	game.gold = 1234567.0
	game._receive_gacha_gear("legend", "weapon")
	game._receive_gacha_gear("epic", "armor")
	game._refresh_hud()
	game._power_band.hide()
	for tab in ["growth", "gear", "summon", "raid", "pet", "shop"]:
		game._select_tab(tab)
		assert(game._tab == tab, "Navigation blocked: " + tab)
		await _shot(tab)
	game._select_tab("growth")
	game._set_growth_mode("stat")
	game._set_step(1)
	var key := str(StatDefs.STATS[0]["key"])
	var before := int(game.stat_lv(key))
	game._buy(key)
	assert(int(game.stat_lv(key)) == before + 1, "Upgrade button no longer trains")
	var button: Button = game._stat_rows[key]["btn"]
	assert(button.has_meta("pulse_tw"), "Successful upgrade has no feedback")
	Ui.pulse(button, Color(1.2, 1.2, 1.1))
	Ui.pulse(button, Color(1.2, 1.2, 1.1))
	await create_timer(0.5).timeout
	assert(button.self_modulate.is_equal_approx(Color.WHITE), "Rapid effects did not settle")
	game._show_reward("보상 획득", [{"icon": "res://assets/ui/res_blood.png", "label": "혈액 +1.2k"},
		{"icon": "res://assets/ui/res_gem.png", "label": "보석 +30"}])
	await _shot("reward")
	game._reward_view.hide()
	# Reopening must cancel the previous entrance and settle at original geometry.
	game._open_presets()
	game._preset_view.hide()
	game._preset_view.show()
	await create_timer(0.4).timeout
	assert(game._preset_view.scale.is_equal_approx(Vector2.ONE))
	assert(game._preset_view.modulate.a > 0.99)
	game._preset_view.hide()
	game._quest_view.show()
	game._front(game._quest_view)
	game._refresh_quests()
	await _shot("quests")
	print("UiPolishPreview OK: 6 tabs, upgrade, replaceable feedback, reward, popup reopening, quests")
	return true


func _shot(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UI_OUTPUT))
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	assert(picture.get_size() == Vector2i(576, 896))
	assert(picture.save_png(UI_OUTPUT + "/" + label + ".png") == OK)
