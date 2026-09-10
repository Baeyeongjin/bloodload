extends SceneTree

# Main을 트리에 붙이지 않는다. 저장·로드는 메모리 ConfigFile만 사용한다.
class GameProbe:
	extends "res://Main.gd"
	var reward_entries: Array = []
	func _refresh_hud() -> void:
		pass
	func _refresh_shop() -> void:
		pass
	func _refresh_currency_visibility() -> void:
		pass
	func _show_reward(_title: String, entries: Array) -> void:
		reward_entries = entries.duplicate(true)


func _init() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("IdleGrowthCheck timed out")
		quit(1))
	var game := GameProbe.new()
	game.save_muted = true
	game._quest_roll_day()
	_check_max(game)
	_check_chest(game)
	game.free()
	print("IdleGrowthCheck OK (MAX zero guard, quantity/cap, frozen rewards, migration, repeat claim)")
	quit(0)


func _check_max(game: GameProbe) -> void:
	game.buy_step = -1
	game.gold = 0.0
	var level := game.stat_lv("damage")
	var trained := game._quest_count("train")
	var week_trained := int(game.quest_wprog.get("train", 0))
	assert(game._step_for("damage") == 0)
	assert(not game._growth_mode_todo("stat"), "MAX 0 still marks growth available")
	game._buy("damage")
	assert(game.gold == 0.0 and game.stat_lv("damage") == level)
	assert(game._quest_count("train") == trained, "MAX 0 completed daily training")
	assert(int(game.quest_wprog.get("train", 0)) == week_trained)

	# 실제 행을 만들어 표시 가격·수량과 버튼 상태도 확인한다. _ready는 실행하지 않는다.
	for st in StatDefs.STATS:
		var row := game._stat_row(str(st["key"]), str(st["name"]), str(st["icon"]))
		row.theme = Type.theme()
		game.add_child(row)
	game._refresh_growth()
	var button: Button = game._stat_rows["damage"]["btn"]
	assert(button.disabled and button.text.contains("혈액 부족"))
	assert(button.text.contains(game._n(game._buy_cost("damage", 1), true)))
	_check_button_text(button)

	game.gold = game._buy_cost("damage", 3) + 0.001
	game._refresh_growth()
	var steps := game._step_for("damage")
	var price := game._buy_cost("damage", steps)
	var before := game.gold
	assert(steps == 3 and not button.disabled and button.text.contains("+3레벨"))
	_check_button_text(button)
	assert(game._growth_mode_todo("stat"))
	game._buy("damage")
	assert(game.stat_lv("damage") == level + steps)
	assert(is_equal_approx(game.gold, before - price))
	assert(game._quest_count("train") == trained + 1)

	game.buy_step = 100
	game.lv["damage"] = game._stat_cap("damage") - 2
	game.gold = 1e12
	assert(game._step_for("damage") == 2)
	before = game.gold
	price = game._buy_cost("damage", 2)
	game._buy("damage")
	assert(game.stat_lv("damage") == game._stat_cap("damage"))
	assert(is_equal_approx(game.gold, before - price), "Cap charged the full x100")
	game.lv["damage"] += 10
	assert(game._step_for("damage") == 0, "Over-cap save returned negative steps")
	game.lv.clear()
	game.gold = 0.0


func _check_chest(game: GameProbe) -> void:
	game.stage = 1
	game.dungeon_best = 12
	var expected_exp := game._offline_exp(10.0)
	var expected_blood := game.blood_per_sec() * 600.0
	var expected_crystal := game._sweep_per_hour() / 12.0
	var wallet := game.crystal
	game._accrue_chest(10.0)
	assert(is_equal_approx(game.chest_exp, expected_exp))
	assert(is_equal_approx(game.chest_gold, expected_blood))
	assert(is_equal_approx(game.chest_crystal, expected_crystal))
	assert(is_equal_approx(game.crystal, wallet + expected_crystal))
	game._accrue_chest(10.0)
	assert(is_equal_approx(game.chest_exp, expected_exp * 2.0))
	assert(is_equal_approx(game.chest_minutes, 20.0))
	game.chest_stages = 4

	# 적립한 뒤 강화/진행해도 수령값이 변하지 않는다. 직렬화도 파일 없이 검증한다.
	var cfg := ConfigFile.new()
	game._save_chest(cfg)
	var restored := ConfigFile.new()
	assert(restored.parse(cfg.encode_to_text()) == OK)
	game.stage = 200
	game.dungeon_best = 50
	game.lv["damage"] = 1000
	assert(not is_equal_approx(game._offline_exp(20.0), expected_exp * 2.0))
	game._load_chest(restored)
	assert(is_equal_approx(game.chest_exp, expected_exp * 2.0))
	assert(is_equal_approx(game.chest_crystal, expected_crystal * 2.0))
	assert(game.chest_stages == 4)
	var expected := GameProbe.new()
	expected._gain_exp(expected_exp * 2.0)
	wallet = game.crystal
	game._claim_chest()
	assert(is_equal_approx(game.gold, expected_blood * 2.0))
	assert(game.hero_lv == expected.hero_lv and is_equal_approx(game.hero_exp, expected.hero_exp))
	assert(is_equal_approx(game.crystal, wallet), "Claim paid crystal twice")
	assert(str(game.reward_entries[2]["label"]) == game._n(expected_crystal * 2.0))
	assert(game.chest_exp == 0.0 and game.chest_crystal == 0.0 and game.chest_stages == 0)
	var claimed := game._quest_count("chest")
	var blood := game.gold
	game._claim_chest()
	assert(game._quest_count("chest") == claimed and game.gold == blood)
	expected.free()

	# 없는 키만 기존 공식으로 이관한다. 저장된 0과 구분하고 혈정을 재지급하지 않는다.
	var legacy := ConfigFile.new()
	legacy.set_value("chest", "gold", 25.0)
	legacy.set_value("chest", "minutes", 60.0)
	expected_exp = game._offline_exp(60.0)
	game._load_chest(legacy, false)
	assert(is_equal_approx(game.chest_gold, 25.0 * Balance.BLOOD_UNIT))
	assert(is_equal_approx(game.chest_exp, expected_exp))
	assert(is_equal_approx(game.chest_crystal, game._sweep_per_hour() * 0.5))
	assert(game.crystal == wallet)
	game._save_chest(legacy)
	game.lv["damage"] = 1
	game._load_chest(legacy)
	assert(is_equal_approx(game.chest_exp, expected_exp), "Migrated value was converted twice")
	legacy.set_value("chest", "exp", 0.0)
	legacy.set_value("chest", "crystal", 0.0)
	game._load_chest(legacy)
	assert(game.chest_exp == 0.0 and game.chest_crystal == 0.0)
	game._load_chest(ConfigFile.new())
	assert(game.chest_gold == 0.0 and game.chest_minutes == 0.0)
	game.best_stage = 500
	game.gem = 10000.0
	game._shop_buy("warp")
	assert(is_equal_approx(game.chest_exp, game._offline_exp(ShopDefs.WARP_HOURS * 60.0)))
	assert(is_equal_approx(game.chest_crystal, ShopDefs.WARP_HOURS * game._sweep_per_hour() * 0.5))

	game._load_chest(ConfigFile.new())
	var start := game.stage
	game._grant_offline(Time.get_unix_time_from_system() - 7200.0)
	assert(absf(game.chest_minutes - 120.0) < 0.1)
	assert(game.chest_stages == game.stage - start)
	assert(is_equal_approx(game.chest_exp, game._offline_exp(game.chest_minutes)))
	assert(is_equal_approx(game.chest_gold, game.blood_per_sec() * game.chest_minutes * 60.0))
	var frozen := game.chest_exp
	game._grant_offline(Time.get_unix_time_from_system() - 5.0)
	assert(game.chest_exp == frozen, "Short focus change awarded offline rewards")


func _check_button_text(button: Button) -> void:
	var font := Type.font()
	var style := button.get_theme_stylebox("normal")
	var available := button.size.x - style.get_minimum_size().x \
		- float(button.get_theme_constant("icon_max_width")) \
		- float(button.get_theme_constant("h_separation"))
	for line in button.text.split("\n"):
		assert(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Type.SIZE_SMALL).x \
			<= available, "Growth button text overflows: " + line)
	assert(button.get_combined_minimum_size().y <= 48.0, "Two-line growth button exceeds 48px")
