extends SceneTree
# 승급해도 **하위 종 한 벌은 남는다** — 보유(수집) 효과가 조합으로 증발하면
# 안 된다(사장님 2026-08-18). 화면에서 확인할 길이 없으니 여기서 못 박는다.


func _init() -> void:
	await process_frame
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	# 1) 장비 — 커먼 무기 하나에 조각 5개를 주고 승급시킨다.
	scene.gear_inventory.clear()
	var item: Dictionary = GearDefs.make("weapon", 1,
		GachaDefs.rarity("common"))
	var key := str(item["icon"])
	scene.gear_inventory[key] = item
	scene.gacha_owned["gear:" + key] = true
	scene.gacha_shards["gear:" + key] = 5
	var before: float = scene._collection_bonus(str(item["stat"]))
	var new_key: String = scene._synthesize(key)
	assert(new_key != "" and new_key != key, "승급이 안 됐다: " + new_key)
	assert(scene.gear_inventory.has(key),
		"승급했더니 하위 종이 사라졌다 — 보유 효과가 증발한다")
	assert(scene.gear_inventory.has(new_key), "상위 종이 안 들어왔다")
	var after: float = scene._collection_bonus(str(item["stat"]))
	assert(after > before,
		"보유 효과가 늘지 않았다: %.4f -> %.4f" % [before, after])

	# 2) 스킬 — 원본이 남고 장착도 유지된다.
	var skey := SkillDefs.key_of("bite", "common")
	scene.skill_owned[skey] = 1
	scene.gacha_shards["skill:" + skey] = SkillDefs.SYNTH_SHARDS
	var snext: String = scene._synthesize_skill(skey)
	assert(snext != "", "스킬 승급이 안 됐다")
	assert(scene.skill_owned.has(skey), "스킬 원본이 사라졌다")
	assert(scene.skill_owned.has(snext), "상위 스킬이 안 들어왔다")

	print("HoldKeepCheck OK")
	quit()
