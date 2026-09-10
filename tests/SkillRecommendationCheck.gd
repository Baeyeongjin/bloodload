extends SceneTree

func _init() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	assert(SkillDefs.recommend({}, 6, "hunt").is_empty())
	assert(SkillDefs.recommend({"strike_common": 0}, 0, "boss").is_empty())
	assert(SkillDefs.recommend({"strike_common": 0}, -1, "hunt").is_empty())
	assert(SkillDefs.recommend({"strike_common": 0}, 6, "invalid").is_empty())
	# Same inventory: total hits across three foes vs one boss changes the choice.
	var pair := {"strike_rare": 0, "wave_rare": 0}
	assert(SkillDefs.recommend(pair, 1, "boss") == ["strike_rare"])
	assert(SkillDefs.recommend(pair, 1, "hunt") == ["wave_rare"])
	# Actual behavior overrides the name: uncommon strike pierces only two targets.
	pair = {"strike_common": 1, "strike_uncommon": 0}
	assert(SkillDefs.recommend(pair, 1, "boss") == ["strike_common"])
	assert(SkillDefs.recommend(pair, 1, "hunt") == ["strike_uncommon"])
	pair = {"strike_rare": 0, "wave_uncommon": 0}
	assert(SkillDefs.recommend(pair, 1, "boss") == ["strike_rare"], "Bounce cannot hit a lone boss three times")
	assert(SkillDefs.recommend(pair, 1, "hunt") == ["wave_uncommon"])
	# Upgrade levels and cooldown steps matter; hits/ticks must not duplicate total power.
	assert(SkillDefs.recommend({"strike_common": 20, "strike_rare": 0}, 1, "boss") == ["strike_common"])
	assert(SkillDefs.recommend({"wave_legend": 0, "field_rare": 50}, 1, "boss") == ["wave_legend"])
	assert(SkillDefs.recommend({"strike_rare": 50, "wave_rare": 0}, 1, "hunt") == ["strike_rare"])
	# Completing a pair can beat the larger isolated gain of wave_rare.
	var combo := SkillDefs.recommend({"strike_common": 0, "strike_rare": 0, "wave_rare": 0}, 2, "boss")
	assert(combo.has("strike_common") and combo.has("strike_rare") and not combo.has("wave_rare"))
	# Buffs earn their slot; a redundant active ward cannot stack over the existing one.
	assert(SkillDefs.recommend({"strike_legend": 0, "strike_rare": 0, "ward_epic": 0}, 2, "boss").has("ward_epic"))
	var wards := SkillDefs.recommend({"strike_legend": 50, "ward_legend": 50,
		"ward_common": 50, "ward_rare": 0}, 3, "boss")
	assert(wards.has("ward_rare") and not wards.has("ward_common"))
	# field_epic has positive nominal power but really casts a buff. Preserve one attack.
	assert(SkillDefs.recommend({"strike_common": 0, "field_epic": 50, "ward_legend": 50}, 1, "hunt") == ["strike_common"])
	assert(SkillDefs.recommend({"ward_common": 0}, 7, "boss") == ["ward_common"])
	# Stable score ties and dictionary insertion order must not shuffle saved suggestions.
	assert(SkillDefs.recommend({"field_common": 0, "strike_common": 0}, 1, "boss") == ["strike_common"])
	var owned := {}
	for key in SkillDefs.all_keys():
		owned[key] = 15
	var snapshot := owned.duplicate(true)
	var reverse := {}
	var reversed_keys: Array = owned.keys()
	reversed_keys.reverse()
	for key in reversed_keys:
		reverse[key] = owned[key]
	var hunt := SkillDefs.recommend(owned, 6, "hunt")
	var boss := SkillDefs.recommend(owned, 6, "boss")
	assert(hunt != boss, "Six-slot hunting and boss builds need different priorities")
	for mode in ["hunt", "boss"]:
		for cap in [1, 6, 7, 999]:
			var result := SkillDefs.recommend(owned, cap, mode)
			assert(result.size() == mini(cap, 7))
			assert(result == SkillDefs.recommend(reverse, cap, mode))
			var seen := {}
			var damage := false
			for key in result:
				assert(owned.has(key) and not seen.has(key))
				seen[key] = true
				damage = damage or SkillDefs.behavior_of(key) != "ward"
			assert(damage)
	assert(owned == snapshot, "Recommendation changed the inventory")
	# Unknown keys/types are ignored; valid levels are clamped without changing input.
	var invalid := {"strike_common": -4, "wave_rare": 9999, "not_a_skill": 50,
		"strike_common_extra": 50, "strike_rare": "50", "ward_common": false,
		"field_common": [], "wave_common": null, 12: 50}
	var invalid_before := invalid.duplicate(true)
	assert(SkillDefs.recommend(invalid, 6, "hunt") == SkillDefs.recommend({"strike_common": 0, "wave_rare": 50}, 6, "hunt"))
	assert(invalid == invalid_before)
	assert(SkillDefs.recommend({"strike_common": NAN, "wave_common": INF}, 6, "boss").is_empty())
	assert(SkillDefs.recommend({"strike_mythic": 50}, 7, "boss") == ["strike_mythic"])
	print("SkillRecommendationCheck OK: modes, actual rules, combos, wards, levels, caps, stability and pure inventory")
	print("hunt6=", hunt)
	print("boss6=", boss)
	quit(0)
