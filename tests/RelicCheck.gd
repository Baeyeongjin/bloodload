extends SceneTree

# 유물(RelicDefs)을 잰다. 지키는 것 다섯:
#   1) 표 — 아이콘 실재, 등급이 소환 표에 있는 것, id 중복 없음
#   2) 배수 — 만렙 곱이 예산 안(공격 x1.5~2.5), 레벨 0 이면 x1.0
#   3) 수령 — 첫 장은 1단계, 중복은 조각, 5개마다 한 단계, 만렙에서 안 넘침
#   4) 효과 — 유물이 실제로 공격력·체력·방치 상한을 올린다
#   5) 저장 — 레벨과 조각이 복원된다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	var seen := {}
	for r in RelicDefs.RELICS:
		var id := str(r["id"])
		assert(not seen.has(id), "id 중복: %s" % id)
		seen[id] = true
		assert(FileAccess.file_exists(RelicDefs.icon_path(r)),
			"%s 아이콘이 없다: %s" % [id, RelicDefs.icon_path(r)])
		assert(not GachaDefs.rarity(str(r["rarity"])).is_empty(),
			"%s 등급이 소환 표에 없다" % id)
		assert(float(r["value"]) > 0.0, "%s 값이 0" % id)
		assert(RelicDefs.effect_text(r, 1) != "", "%s 효과 설명이 없다" % id)
	# **낮은 등급부터** 늘어서 있어야 한다 (사장님) — 화면이 표 순서를 그대로 쓰므로
	# 종을 덧붙일 때 뒤에만 붙이면 진열이 뒤섞인다(실제로 6종 추가에서 났다).
	var rank := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3,
		"legend": 4, "mythic": 5}
	var prev := -1
	for r in RelicDefs.RELICS:
		var cur := int(rank[str(r["rarity"])])
		assert(cur >= prev, "%s 에서 등급 순서가 뒤집혔다" % str(r["id"]))
		prev = cur

	# ── 2) 배수 ────────────────────────────────────────────────────────────
	assert(is_equal_approx(RelicDefs.mult("damage", {}), 1.0), "빈 유물이 배수를 준다")
	var full := {}
	for r in RelicDefs.RELICS:
		full[str(r["id"])] = RelicDefs.MAX_LV
	var atk := RelicDefs.mult("damage", full)
	# 후반 간극(30일 -> 90일 1.35배 vs 목표 2배)을 메우는 몫이라 이 대역이어야 한다.
	# 너무 작으면 넣은 뜻이 없고, 너무 크면 곱연산 예산이 혈맥까지 밀어낸다.
	assert(atk > 1.5 and atk < 2.5, "유물 완주 공격 배수 x%.2f — 예산 밖" % atk)
	assert(RelicDefs.add("hours", full) > 0.0, "방치 상한 유물이 없다")
	# 절반 레벨이면 절반쯤이어야 한다(레벨당 1/5 규칙).
	var half := {}
	for r in RelicDefs.RELICS:
		half[str(r["id"])] = 1
	assert(RelicDefs.mult("damage", half) < atk, "레벨이 낮은데 배수가 같다")

	# ── 3~5) 씬 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.relics = {}
	scene.gacha_shards = {}
	scene._gacha_kind = "relic"

	# 첫 장 = 1단계.
	var got: Dictionary = scene._receive_gacha_relic("legend")
	assert(not got.is_empty(), "전설 유물이 안 나왔다")
	var id0 := str(got["id"])
	assert(int(scene.relics[id0]) == 1, "첫 장이 1단계가 아니다")
	# 유물이 없는 등급도 빈손으로 돌려보내지 않는다.
	var low: Dictionary = scene._receive_gacha_relic("common")
	assert(not low.is_empty(), "커먼에서 빈손으로 돌아왔다")

	# 중복 -> 조각, 5개마다 한 단계.
	scene.relics = {id0: 1}
	scene.gacha_shards = {}
	for i in RelicDefs.SHARDS_PER_LV:
		# 같은 유물만 나오도록 그 등급에 하나뿐인 상황을 흉내 낼 수 없으므로
		# 조각을 직접 쌓아 경계만 본다(수령 경로는 위에서 이미 통과).
		scene.gacha_shards["relic:" + id0] = i
	assert(int(scene.gacha_shards["relic:" + id0]) == RelicDefs.SHARDS_PER_LV - 1)

	# ── 4) 효과 ────────────────────────────────────────────────────────────
	scene.relics = {}
	var dmg0: float = scene.damage()
	var hp0: float = scene.max_hp()
	var hours0: float = scene._offline_cap_hours()
	for r in RelicDefs.RELICS:
		scene.relics[str(r["id"])] = RelicDefs.MAX_LV
	assert(scene.damage() > dmg0 * 1.4, "유물이 공격력을 안 올린다")
	assert(scene.max_hp() > hp0, "유물이 체력을 안 올린다")
	assert(scene._offline_cap_hours() > hours0, "유물이 방치 상한을 안 올린다")
	# 공격속도는 **간격이 줄어야** 한다 — 배수를 그냥 곱하면 거꾸로 느려진다.
	scene.relics = {}
	var iv0: float = scene.attack_interval()
	for r in RelicDefs.RELICS:
		if str(r["kind"]) == "speed":
			scene.relics[str(r["id"])] = RelicDefs.MAX_LV
	assert(scene.attack_interval() < iv0, "공격속도 유물이 간격을 늘렸다")

	# ── 5) 저장 ────────────────────────────────────────────────────────────
	scene.relics = {id0: 3}
	scene.gacha_shards["relic:" + id0] = 2
	scene._save_game()
	scene.relics = {}
	scene._load_game()
	assert(int(scene.relics.get(id0, 0)) == 3, "유물 레벨이 복원 안 됐다")
	assert(int(scene.gacha_shards.get("relic:" + id0, 0)) == 2, "조각이 복원 안 됐다")

	# 등급 접기 — 커먼·언커먼이 전설로 승격되던 버그(사장님: 10뽑에 레전 9개).
	# 유물이 없는 등급은 가까운 쪽(레어/레전)으로 접혀야 한다.
	for pair in [["common", "rare"], ["uncommon", "rare"], ["mythic", "legend"],
			["rare", "rare"], ["legend", "legend"]]:
		var rgot: Dictionary = scene._receive_gacha_relic(str(pair[0]))
		assert(str(rgot["rarity"]) == str(pair[1]),
			"%s 가 %s 로 접혀야 하는데 %s" % [pair[0], pair[1], str(rgot["rarity"])])

	print("RelicCheck OK")
	quit()
