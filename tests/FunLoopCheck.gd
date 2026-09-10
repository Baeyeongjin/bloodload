extends SceneTree

# Production UI scene; never loads a real player profile or persists seeded state.
const OUTPUT := "res://build/qa/fun-loop"
var game: Node
var checks := 0
var geometry: Array = []


func _capture_enabled() -> bool:
	return false


func _init() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\", "/")
	var qa := ProjectSettings.globalize_path("res://build/qa/").replace("\\", "/")
	if not profile.begins_with(qa) or not profile.contains("fun-loop") \
			or profile != OS.get_environment("LOCALAPPDATA").replace("\\", "/"):
		push_error("FunLoopCheck requires one fresh build/qa/*fun-loop* profile in BOTH APPDATA variables")
		quit(1)
		return
	create_timer(45.0).timeout.connect(func() -> void:
		push_error("FunLoopCheck timed out")
		quit(1))
	root.size = Vector2i(576, 896)
	root.content_scale_size = Vector2i(576, 896)
	_run.call_deferred()


func _run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.save_muted = true
	root.add_child(game)
	while not game.is_node_ready() or not game.is_processing():
		await process_frame
	await create_timer(0.4).timeout # Let the existing loading cover fade away.
	game.set_process(false) # UI pop-in tweens must still run for real rendering.
	for popup in game._popups():
		if popup != null:
			popup.hide()
	game._clear_view.hide()
	game._boss_cut_clear()
	game._clear_foes()
	await process_frame
	_seed_skills()
	for check in [_check_recommendations, _check_goals, _check_attempts, _check_prizes]:
		if not check.call():
			quit(1)
			return
	await _prepare_preview()
	if not _check_text(game._board_goal, "next-boss") or not _check_text(game._board_tactic, "boss-record"):
		quit(1)
		return
	if _capture_enabled():
		if not await _capture("home-boss-record"):
			quit(1)
			return
	game._open_presets()
	for i in 3:
		await process_frame
	for card in game._preset_body.get_children().slice(0, 2):
		for child in card.get_children():
			if child is Label:
				if not _check_text(child, "recommendation"):
					quit(1)
					return
	if _capture_enabled():
		if not await _capture("recommended-loadouts"):
			quit(1)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT + "/ui-check.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "text_bounds": geometry,
		"capture_size": [576, 896], "save_muted": game.save_muted}, "\t"))
	print("FunLoopCheck OK: %d checks; actual Main UI, recommendation invariants, goal routes, boss records, next prizes, text bounds" % checks)
	game.queue_free()
	await process_frame
	quit(0)


func _seed_skills() -> void:
	game.skill_owned = {"strike_common": 8, "strike_rare": 3, "strike_epic": 2,
		"wave_common": 9, "wave_rare": 3, "wave_epic": 2, "field_common": 7,
		"field_rare": 4, "field_epic": 2, "ward_common": 9, "ward_rare": 4, "ward_epic": 2}
	game.skill_presets = [["strike_common"], ["wave_common", "ward_common"], []]
	game.gear_presets = [{"weapon": "qa_saved_weapon"}, {}, {}]
	game.preset_names = {"skill:0": "내 보스 편성", "gear:0": "원래 장비"}
	game._skill_cd = {"strike_common": 3.25, "wave_rare": 8.75, "ward_epic": 11.0}
	game._summon_t = 2.5
	game._summon_bonus = 0.35
	game.gold = 123456.0
	game.gem = 789.0
	game.crystal = 123.0
	game.sigil = 87.0
	game.whet = 56.0
	game.feed = 43.0
	game.tickets = {"weapon": 4, "skill": 7}
	game.chest_gold = 456.0
	game.chest_exp = 78.0


func _economy() -> Dictionary:
	var out := {}
	for key in ["gold", "gem", "crystal", "sigil", "whet", "feed", "tickets", "lv",
		"skill_owned", "skill_presets", "gear_presets", "preset_names", "gacha_pulls",
		"gacha_pity", "equipped", "gear_inventory", "chest_gold", "chest_exp"]:
		out[key] = game.get(key)
	return out.duplicate(true)


func _check_recommendations() -> bool:
	var economy := _economy()
	var cooldowns: Dictionary = game._skill_cd.duplicate(true)
	for mode in ["hunt", "boss"]:
		game.skill_auto_equip = true
		assert(game._apply_recommended_skills(mode))
		assert(not game.skill_auto_equip and not game.skill_equipped.is_empty())
		assert(game.skill_equipped.size() <= game._equip_cap())
		var unique := {}
		for key in game.skill_equipped:
			assert(game.skill_owned.has(key) and not unique.has(key))
			unique[key] = true
		assert(_economy() == economy, "Recommendation changed money, ownership or saved presets")
		assert(game._skill_cd == cooldowns and game._summon_t == 2.5 and game._summon_bonus == 0.35,
			"Recommendation reset cooldowns or active ward")
		checks += 7
	var worn: Array = game.skill_equipped.duplicate()
	assert(not game._apply_recommended_skills("invalid") and game.skill_equipped == worn)
	var owned: Dictionary = game.skill_owned
	game.skill_owned = {}
	assert(not game._apply_recommended_skills("boss") and game.skill_equipped == worn)
	game.skill_owned = owned
	game._clear_view.hide()
	checks += 2
	return true


func _check_goals() -> bool:
	var economy := _economy()
	for index in [3, 4, 5, 0, 1, 2]:
		game.goal_index = 60 + index # Deliberately unmet; test the real button handler.
		assert(not game._goal_ready())
		game._goal_widget.pressed.emit()
		match index:
			3: assert(game._tab == "growth" and game._growth_mode == "stat")
			4: assert(game._tab == "summon")
			5: assert(game._codex_view.visible and game._codex_mode == "foe")
			_: assert(game._tab == "home")
		assert(_economy() == economy and game.goal_index == 60 + index,
			"Guide navigation spent currency or claimed a reward")
		game._codex_view.hide()
		checks += 3
	game.goal_index = 0
	game.best_stage = 100
	game.codex = {"slime": 200} # The next guide is also ready: one click must claim just one.
	var gems: float = game.gem
	game._goal_widget.pressed.emit()
	assert(game.goal_index == 1 and game.gem == gems + GoalDefs.gem_reward("stage", 0))
	assert(game._goal_ready() and game._reward_view.visible)
	game._reward_view.hide()
	checks += 2
	return true


func _make_boss() -> Foe:
	game._clear_foes()
	var foe := Foe.new()
	foe.setup(FoeTiers.get_tier("wraith_knight"), 1.0, 0.0, true)
	foe.position = Vector2(340, game.ground_y)
	game.add_child(foe)
	foe.set_process(false)
	foe.max_hp = 100.0
	foe.hp = 28.0
	return foe


func _check_attempts() -> bool:
	game.stage = 10
	game.dungeon_on = false
	game.raid_on = ""
	game._boss_attempt.clear()
	var foe := _make_boss()
	var economy := _economy()
	game._record_boss_attempt("시간 초과")
	assert(game._boss_attempt["count"] == 1 and is_equal_approx(game._boss_attempt["best"], 28.0))
	foe.hp = 11.0
	game._record_boss_attempt("시간 초과")
	assert(game._boss_attempt["count"] == 2 and is_equal_approx(game._boss_attempt["previous"], 28.0))
	assert(is_equal_approx(game._boss_attempt["last"], 11.0) and is_equal_approx(game._boss_attempt["best"], 11.0))
	assert(game._boss_attempt_text().contains("지난 28%"), "Whole-percent floating point boundary inflated the displayed record")
	foe.hp = 19.0
	game._record_boss_attempt("쓰러짐")
	assert(is_equal_approx(game._boss_attempt["previous"], 11.0) and is_equal_approx(game._boss_attempt["best"], 11.0))
	assert(game._boss_attempt_text().contains("체력 강화"))
	var record: Dictionary = game._boss_attempt.duplicate(true)
	for kind in ["ordinary", "raid", "maze", "dying"]:
		game.stage = 1 if kind == "ordinary" else 10
		game.raid_on = "boss" if kind == "raid" else ""
		game.dungeon_on = kind == "maze"
		foe.dying = kind == "dying"
		game._record_boss_attempt("시간 초과")
		assert(game._boss_attempt == record, "Recorded a non-main-boss attempt")
	game.dungeon_on = false
	game.raid_on = ""
	foe.dying = false
	game.stage = 20
	foe.hp = 44.0
	game._record_boss_attempt("시간 초과")
	assert(game._boss_attempt["stage"] == 20 and game._boss_attempt["count"] == 1)
	game.stage = 21
	game._begin_stage_pose()
	assert(game._boss_attempt.is_empty())
	assert(_economy() == economy, "Recording attempt changed progression rewards")
	checks += 12
	return true


func _check_prizes() -> bool:
	var economy := _economy()
	for pair in [[1, 1, "1-10"], [10, 10, "1-10"], [1, 11, "2-10"], [21, 11, "3-10"]]:
		game.stage = pair[0]
		game.best_stage = pair[1]
		assert(game._next_boss_reward_text().contains(pair[2]))
	for at in [491, 499, 500]:
		game.stage = at
		game.best_stage = at
		assert(game._next_boss_reward_text().contains("최종"))
	assert(_economy() == economy)
	checks += 8
	return true


func _prepare_preview() -> void:
	game.stage = 10
	game.best_stage = 10
	game._boss_time = 45.0
	game._boss_attempt.clear()
	var foe := _make_boss()
	game._record_boss_attempt("시간 초과")
	foe.hp = 11.0
	game._record_boss_attempt("시간 초과")
	game._hero_dead = false
	game.hero_hp = game.max_hp()
	game.hero_x = 218.0
	game._hero.position.x = game.hero_x
	game._play("idle")
	game._apply_stage_bg()
	game.goal_index = 63
	game._select_tab("home")
	game._refresh_goal_widget()
	game._refresh_hud()
	game._refresh_board()
	for popup in game._popups():
		popup.hide()
	game._clear_view.hide()
	for i in 20:
		await process_frame
	game._power_band.hide() # The paused battle cannot expire its temporary equip toast.


func _check_text(label: Label, context: String) -> bool:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var maximum := 0.0
	for line in label.text.split("\n"):
		maximum = maxf(maximum, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	assert(maximum <= label.size.x + 0.5, "Text overflows: " + label.text)
	assert(label.get_line_count() * font.get_height(size) <= label.size.y + 1.0,
		"Text height overflows: " + label.text)
	geometry.append({"context": context, "text": label.text, "ink_width": maximum,
		"box": str(label.size), "position": str(label.global_position)})
	checks += 1
	return true


func _capture(name: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(576, 896))
	assert(image.save_png(OUTPUT + "/" + name + ".png") == OK)
	return true
