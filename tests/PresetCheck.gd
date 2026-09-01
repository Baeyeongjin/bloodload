extends SceneTree

# 프리셋 — 스킬과 장비를 **따로** 3벌씩 (사장님 확정 2026-08-27).
#
# 재는 것:
#   1) 저장·적용 — 스킬
#   2) **프리셋을 고르면 자동 장착이 꺼진다** (안 끄면 다음 레벨업에 덮인다)
#   3) 저장·적용 — 장비. **inventory_key 로 담는다**(dict 통째로 담으면
#      레벨을 올린 뒤 되돌릴 때 옛 수치로 굳는다)
#   4) 없어진 것이 남아 있어도 안 깨진다 — 판 장비, 안 가진 스킬
#   5) 옛 저장본(키 없음)·길이가 어긋난 저장본을 칸 수에 맞춘다
#   6) 스킬과 장비가 **서로 안 섞인다**
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 5) 칸 수 맞추기 (먼저 본다 — 아래가 전부 인덱스로 접근한다) ─────────
	assert(scene.skill_presets.size() == scene.PRESETS,
		"스킬 프리셋 칸이 %d 개다" % scene.skill_presets.size())
	assert(scene.gear_presets.size() == scene.PRESETS,
		"장비 프리셋 칸이 %d 개다" % scene.gear_presets.size())
	# 짧은 저장본·긴 저장본·엉뚱한 타입을 다 받아 낸다.
	assert(scene._preset_load([], []).size() == scene.PRESETS, "빈 저장본에서 안 채웠다")
	assert(scene._preset_load([["a"], ["b"], ["c"], ["d"], ["e"]], []).size()
		== scene.PRESETS, "긴 저장본을 안 잘랐다")
	var mixed: Array = scene._preset_load([{"a": 1}], [])
	assert(mixed[0] is Array, "타입이 다른 칸을 안 걸렀다")

	# ── 1) 스킬 저장·적용 ──────────────────────────────────────────────────
	scene.skill_owned = {"strike_common": 5, "wave_common": 5, "field_common": 5,
		"ward_common": 5}
	scene.skill_auto_equip = false
	var set_a: Array[String] = ["strike_common", "wave_common"]
	scene.skill_equipped = set_a.duplicate()
	scene._preset_save("skill", 0)
	assert(not scene._preset_empty("skill", 0), "저장했는데 비었다고 나온다")

	var set_b: Array[String] = ["field_common", "ward_common"]
	scene.skill_equipped = set_b.duplicate()
	scene._preset_save("skill", 1)

	assert(scene._preset_apply("skill", 0), "0번 프리셋 적용이 실패했다")
	assert(scene.skill_equipped == set_a,
		"0번을 꺼냈는데 다른 게 껴 있다: %s" % str(scene.skill_equipped))
	assert(scene._preset_apply("skill", 1), "1번 프리셋 적용이 실패했다")
	assert(scene.skill_equipped == set_b, "1번이 안 껴졌다")

	# ── 2) 고르면 자동 장착이 꺼진다 ───────────────────────────────────────
	# 안 끄면 다음 레벨업·뽑기에서 _auto_equip_skills 가 덮어써 고른 것이 사라진다.
	scene.skill_auto_equip = true
	scene._preset_apply("skill", 0)
	assert(not scene.skill_auto_equip,
		"프리셋을 골랐는데 자동 장착이 켜진 채다 — 다음 레벨업에 덮인다")

	# ── 4-1) 안 가진 스킬이 프리셋에 남아 있어도 된다 ──────────────────────
	scene.skill_presets[2] = ["strike_common", "wave_legend", "없는놈"]
	assert(scene._preset_apply("skill", 2), "성한 것 하나는 있는데 통째로 실패했다")
	assert(scene.skill_equipped.size() == 1
		and str(scene.skill_equipped[0]) == "strike_common",
		"안 가진 스킬이 그대로 껴졌다: %s" % str(scene.skill_equipped))
	# 하나도 안 남으면 아무 일도 안 일어난다(빈손으로 만들지 않는다).
	var before: Array = scene.skill_equipped.duplicate()
	scene.skill_presets[2] = ["없는놈1", "없는놈2"]
	assert(not scene._preset_apply("skill", 2), "전부 없는데 적용됐다고 한다")
	assert(scene.skill_equipped == before, "적용에 실패했는데 장착이 바뀌었다")

	# ── 3) 장비 저장·적용 ──────────────────────────────────────────────────
	# 보관함에 둘을 심고 하나를 낀다.
	var slot0: String = str(GearDefs.SLOTS[0])
	# **진짜 장비를 굴려 쓴다.** 손으로 dict 를 지어내면 화면 코드가 기대하는
	# 필드(name·icon…)가 빠져 엉뚱한 데서 터진다 — 실제로 그렇게 터졌다.
	scene.gear_inventory = {
		"k1": GearDefs.roll(slot0, 1),
		"k2": GearDefs.roll(slot0, 1),
	}
	scene.equipped = {}
	scene._equip_inventory_item("k1")
	scene._preset_save("gear", 0)
	scene._equip_inventory_item("k2")
	assert(str(scene.equipped[slot0]["inventory_key"]) == "k2", "k2 가 안 껴졌다")
	assert(scene._preset_apply("gear", 0), "장비 프리셋 적용이 실패했다")
	assert(str(scene.equipped[slot0]["inventory_key"]) == "k1",
		"장비 프리셋이 k1 을 안 되돌렸다")

	# **inventory_key 로 담는다** — 담은 뒤 레벨을 올려도 프리셋이 최신을 낀다.
	(scene.gear_inventory["k1"] as Dictionary)["lv"] = 7
	scene._equip_inventory_item("k2")
	scene._preset_apply("gear", 0)
	assert(int(scene.equipped[slot0]["lv"]) == 7,
		"프리셋이 옛 수치로 굳었다: lv %d" % int(scene.equipped[slot0]["lv"]))

	# ── 4-2) 판 장비가 프리셋에 남아 있어도 안 깨진다 ──────────────────────
	scene.gear_inventory.erase("k1")
	scene._equip_inventory_item("k2")
	assert(not scene._preset_apply("gear", 0),
		"보관함에 없는데 적용됐다고 한다")
	assert(str(scene.equipped[slot0]["inventory_key"]) == "k2",
		"적용에 실패했는데 장착이 풀렸다")

	# ── 6) 스킬과 장비가 안 섞인다 ────────────────────────────────────────
	# 사장님: "스킬 장비 프리셋 각각 따로". 같은 번호를 써도 서로 안 건드린다.
	var one: Array[String] = ["strike_common"]
	scene.skill_equipped = one
	scene._preset_save("skill", 0)
	var gear_before: Dictionary = (scene.gear_presets[0] as Dictionary).duplicate()
	assert(scene.gear_presets[0] == gear_before, "스킬을 저장했는데 장비가 바뀌었다")
	assert(not (scene.skill_presets[0] as Array).is_empty(), "스킬 저장이 안 됐다")

	print("PresetCheck OK  (스킬·장비 각각 3벌 · 자동 꺼짐 · 없어진 것 견딤)")
	quit(0)
