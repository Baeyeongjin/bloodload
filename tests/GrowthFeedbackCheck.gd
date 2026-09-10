extends SceneTree

# Receipts and visible UI states; no real saves or automatic gameplay.
class Arena extends "res://Main.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass


var arena: Arena
var checks := 0


func _init() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\", "/")
	var qa := ProjectSettings.globalize_path("res://build/qa/").replace("\\", "/")
	if profile.is_empty() or profile != OS.get_environment("LOCALAPPDATA").replace("\\", "/") \
			or not profile.begins_with(qa) or not profile.contains("growth-feedback"):
		push_error("GrowthFeedbackCheck requires a disposable build/qa/*growth-feedback* profile in both APPDATA variables")
		quit(1)
		return
	create_timer(25.0).timeout.connect(func() -> void:
		push_error("GrowthFeedbackCheck timed out")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	arena = Arena.new()
	arena.save_muted = true
	arena.skill_auto_equip = false
	root.add_child(arena)
	for slot in GearDefs.SLOTS:
		for rarity in GachaDefs.RARITIES:
			if _gear_receipts(slot, str(rarity["key"])) != true:
				quit(1)
				return
	for rarity in GachaDefs.RARITIES.slice(0, GachaDefs.SKILL_TOP_INDEX + 1):
		if _skill_receipts(str(rarity["key"])) != true:
			quit(1)
			return
	for state in ["poor", "capped", "missing_shard", "ready"]:
		if _gear_detail(state) != true:
			quit(1)
			return
	if _result_cards() != true:
		quit(1)
		return
	arena.queue_free()
	await process_frame
	print("GrowthFeedbackCheck OK: %d cases; per-pull receipts, actual inventory, upgrade gates and result/detail text bounds" % checks)
	quit(0)


func _gear_receipts(slot: String, rarity: String) -> bool:
	arena.gear_inventory.clear()
	arena.gacha_shards.clear()
	arena.stage = 1
	seed(79)
	var first := arena._receive_gacha_gear(rarity, slot)
	var key := str(first["icon"])
	assert(first["receipt"]["new"] and first["receipt"]["shard_gain"] == 0)
	assert(not arena.gear_inventory[key].has("receipt"), "Transient receipt leaked into inventory")
	var original_base: float = first["base"]
	arena.gear_inventory[key]["lv"] = 9
	arena.gear_inventory[key].erase("kind") # Older/constructed inventory entries need the same valid result icon route.
	arena.stage = 300
	var last: Dictionary
	for i in 3:
		seed(79)
		last = arena._receive_gacha_gear(rarity, slot)
		assert(not last["receipt"]["new"] and last["receipt"]["shard_gain"] == 1)
		assert(last["receipt"]["shards"] == i + 1, "Multiple pulls lost their individual shard progress")
		assert(last["lv"] == 9 and last["base"] == original_base, "Receipt describes the new roll instead of the actual stored item")
		assert(last["kind"] == "gear", "Legacy gear result lost its icon route")
	assert(first["receipt"]["shards"] == 0, "Later pulls changed an earlier receipt")
	var index := GachaDefs.rarity_index(rarity)
	assert(bool(last["receipt"]["fuse_ready"]) == (index < 4), "Combination readiness ignored the legendary cap or highest rarity")
	if rarity == "legend":
		arena.gear_inventory[key]["lv"] = GearDefs.max_lv(last)
		seed(79)
		last = arena._receive_gacha_gear(rarity, slot)
		assert(last["receipt"]["fuse_ready"], "Max-level legendary does not report its available combination")
	for item in [first, last]:
		for line in arena._gacha_gain_lines(item):
			assert(_fits(line, 96.0), "Receipt text exceeds the small result card: " + line)
	checks += 1
	return true


func _skill_receipts(rarity: String) -> bool:
	arena.skill_owned.clear()
	arena.gacha_shards.clear()
	seed(113)
	var first := arena._receive_gacha_skill(rarity)
	var key := str(first["key"])
	assert(first["receipt"]["new"] and first["receipt"]["shards"] == 0)
	arena.skill_owned[key] = 17
	var last: Dictionary
	for i in 3:
		seed(113)
		last = arena._receive_gacha_skill(rarity)
		assert(not last["receipt"]["new"] and last["receipt"]["shards"] == i + 1)
		assert(last["lv"] == 17, "Duplicate skill receipt discarded its actual level")
	assert(bool(last["receipt"]["fuse_ready"]) == (rarity != "legend"), "Skill result suggests a forbidden legendary-to-mythic combination")
	assert(first["receipt"]["shards"] == 0)
	for item in [first, last]:
		for line in arena._gacha_gain_lines(item):
			assert(_fits(line, 96.0), "Skill receipt exceeds its result card: " + line)
	checks += 1
	return true


func _gear_detail(state: String) -> bool:
	if is_instance_valid(arena._gear_detail):
		arena._gear_detail.free()
	arena._gear_detail = Control.new()
	arena.add_child(arena._gear_detail)
	var item := GearDefs.make("weapon", 12, GachaDefs.rarity("mythic"))
	var key := str(item["icon"])
	item["lv"] = 400 if state == "capped" else 100
	arena.gear_inventory = {key: item}
	arena._gear_selected_key = key
	arena.whet = 0.0 if state == "poor" else 100000.0
	arena.gacha_shards = {"gear:" + key: 0 if state == "missing_shard" else 1}
	arena._refresh_gear_detail()
	var button := arena._gear_detail.get_node("GearUpgradeButton") as Button
	var hint := arena._gear_detail.get_node("GearUpgradeHint") as Label
	assert(button.disabled == (state != "ready"), "Visible upgrade button permits a no-op: " + state)
	assert(hint.text.contains({"poor": "연마석", "capped": "최대 레벨", "missing_shard": "조각 1개 부족", "ready": "100 → 101"}[state]))
	assert(_fits(hint.text, 532.0), "Upgrade hint exceeds the detail panel")
	for child in arena._gear_detail.get_children():
		if child is Label and child.position.x == 234.0 and child.position.y in [86.0, 114.0]:
			assert(_fits(child.text, 306.0), "Effect preview exceeds the detail panel: " + child.text)
		if child is Label and child.position.y in [146.0, 172.0, 198.0]:
			assert(_fits(child.text, 148.0), "Upgrade cost exceeds its resource cell: " + child.text)
	checks += 1
	return true


func _result_cards() -> bool:
	arena._gacha_reveal = Control.new()
	arena.add_child(arena._gacha_reveal)
	arena._gacha_kind = "weapon"
	arena.gear_inventory.clear()
	arena.gacha_shards.clear()
	var items: Array[Dictionary] = []
	for _i in 10:
		seed(79)
		items.append(arena._receive_gacha_gear("common", "weapon"))
	arena._show_gacha_results(items)
	var scroll: ScrollContainer
	for child in arena._gacha_reveal.get_children():
		if child is ScrollContainer:
			scroll = child
	assert(scroll != null, "Multiple results have no scroll container")
	var cards := scroll.get_child(0).get_children()
	assert(cards.size() == 10)
	for i in cards.size():
		var card: Control = cards[i]
		var first := card.get_node("Gain0") as Label
		var second := card.get_node("Gain1") as Label
		assert(first.text == ("신규 획득" if i == 0 else "조각 +1"), "Actual result card lost the acquisition kind")
		assert(second.text == "조합 가능" if i >= 3 else second.text != "조합 가능", "Actual result card reports combination readiness too early")
		assert(second.position.y + second.size.y <= card.size.y, "Progress label overlaps the next row: y=%s height=%s card=%s" % [second.position.y, second.size.y, card.size.y])
	assert(cards[5].position.y - cards[0].position.y >= cards[0].size.y, "Result card rows overlap")
	checks += 1
	return true


func _fits(text: String, width: float) -> bool:
	return Type.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Type.SIZE_SMALL).x <= width
