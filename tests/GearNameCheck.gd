extends SceneTree

func _init() -> void:
	create_timer(15.0).timeout.connect(func() -> void: quit(1))
	var ids := {}
	var names := {}
	for slot in GearDefs.SLOTS:
		for rarity in GachaDefs.RARITIES:
			var items := GearDefs.items_of(slot, str(rarity["key"]))
			assert(items.size() == 4)
			for spec in items:
				assert(not ids.has(spec[0]) and not names.has(spec[1]))
				ids[spec[0]] = true
				names[spec[1]] = true
				var item := {"slot": slot, "rarity": rarity["key"], "icon": spec[0],
					"name": "이전 이름", "lv": 7, "base": 123.0, "stat": GearDefs.SLOT_STAT[slot]}
				var weapon_trait := GearDefs.trait_of(item)
				GearDefs.normalize_catalog_item(item)
				assert(item["name"] == spec[1] and item["icon"] == spec[0])
				assert(item["lv"] == 7 and item["base"] == 123.0)
				assert(GearDefs.trait_of(item) == weapon_trait)
				assert(ResourceLoader.exists(GearDefs.icon_path(item)))
	assert(ids.size() == 72)
	assert(GearDefs.items_of("weapon", "legend")[1] == ["gw_glaive_gold", "태양 석궁"])
	assert(Type.font().resource_path == Type.PATH and Type.SIZE_SMALL == 11)
	print("GearNameCheck OK: 72 unique names/icons, old-name normalization, stats/traits preserved, original font")
	quit()
