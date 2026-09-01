extends SceneTree

# 스킬 해금 사슬 — 형태별 등급 천장(숙련 사다리).
# 설계는 docs/SKILL_UNLOCK_PLAN.md 3장 "다", 사장님 픽 2026-08-27.
#
# 재는 것:
#   1) 천장 표 — 레벨 합이 오르면 천장도 오른다, 커먼은 처음부터
#   2) 형태 고르기 — 천장 위 등급은 그 형태로 안 나온다
#   3) **등급 분포가 안 바뀐다** — 이 설계의 약속이라 제일 중요하다.
#      사장님 질문("뽑기 확률을 엄청 낮춰야겟는데")에 대한 답이 이 절이다.
#   4) 그 등급을 받을 형태가 없으면 조각으로 돌아온다 (뽑기를 무르지 않는다)
#   5) 진행 표시 — 다음 천장까지 남은 값
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 천장 표 ────────────────────────────────────────────────────────
	# 커먼은 0 이다 — 넷 다 처음부터 열려 있어야 첫 소환이 빈손이 안 된다.
	assert(SkillDefs.shape_cap("strike", {}) == "common",
		"아무것도 안 가졌는데 커먼도 안 열렸다")
	# 레벨 합이 오르면 천장도 오른다. 표(SHAPE_CAP_STEPS)의 눈금을 그대로 짚는다.
	var owned := {"strike_common": 10}
	assert(SkillDefs.shape_cap("strike", owned) == "uncommon",
		"합 10 인데 언커먼이 안 열렸다: %s" % SkillDefs.shape_cap("strike", owned))
	assert(SkillDefs.shape_cap("wave", owned) == "common",
		"격에 부었는데 파의 천장이 올랐다 — 형태별이 아니다")
	owned = {"strike_common": 50, "strike_uncommon": 50, "strike_rare": 30}
	assert(SkillDefs.shape_cap("strike", owned) == "legend",
		"합 130 인데 레전더리가 안 열렸다: %s" % SkillDefs.shape_cap("strike", owned))
	# 합은 **그 형태 것만** 센다.
	assert(SkillDefs.shape_mastery("strike", {"strike_common": 7, "wave_epic": 40}) == 7,
		"다른 형태 레벨이 숙련도에 섞였다")

	# ── 2) 열린 형태만 나온다 ─────────────────────────────────────────────
	var only_strike := {"strike_common": 130}
	var legend_shapes := SkillDefs.shapes_for("legend", only_strike)
	assert(legend_shapes.size() == 1 and legend_shapes[0] == "strike",
		"전설을 받는 형태가 격 하나여야 하는데: %s" % str(legend_shapes))
	# 커먼은 늘 넷 다.
	assert(SkillDefs.shapes_for("common", {}).size() == SkillDefs.SHAPE_ORDER.size(),
		"커먼이 네 형태에서 다 안 열린다")

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 3) **등급 분포가 안 바뀐다** ──────────────────────────────────────
	# 이 설계의 약속이다. 천장은 "어느 형태로 나올지"만 좁히고 등급표는 손대지
	# 않는다 — 전설을 굴리면 전설이 나온다. 해금이 거의 안 된 상태(커먼만)와
	# 다 된 상태에서 같은 등급을 넣어 보고, **들어간 등급 그대로 나오는지**를
	# 센다. (뽑기 자체를 굴리면 난수 두 겹이라 분산이 커져 못 잰다 — 등급은
	# GachaDefs 가 이미 정해서 넘겨주므로 여기서는 그 등급이 보존되는지만 본다.)
	for state in [{"tag": "커먼만", "owned": {"strike_common": 0}},
			{"tag": "전부 해금", "owned": {"strike_common": 50, "strike_uncommon": 50,
				"strike_rare": 30, "wave_common": 50, "wave_uncommon": 50,
				"wave_rare": 30, "field_common": 50, "field_uncommon": 50,
				"field_rare": 30, "ward_common": 50, "ward_uncommon": 50,
				"ward_rare": 30}}]:
		for want in ["common", "uncommon", "rare", "epic", "legend"]:
			scene.skill_owned = (state["owned"] as Dictionary).duplicate()
			scene.gacha_shards = {}
			var kept := 0
			for i in 200:
				var got: Dictionary = scene._receive_gacha_skill(want)
				if str(got.get("rarity", "")) == want:
					kept += 1
			# 커먼만 열린 상태에서 상위 등급은 조각으로 가므로 등급이 보존되지
			# 않는다 — 그 경우는 4절이 따로 잰다. 여기서는 열린 등급만 본다.
			var open_now: Array[String] = SkillDefs.shapes_for(want,
				state["owned"] as Dictionary)
			if open_now.is_empty():
				assert(kept == 0, "%s/%s: 안 열렸는데 그 등급이 나왔다" % [state["tag"], want])
			else:
				assert(kept == 200,
					"%s/%s: 200 번 중 %d 번만 그 등급이다 — 천장이 등급을 갈아치웠다"
					% [state["tag"], want, kept])

	# 그리고 **형태는 실제로 갈린다** — 격만 130 이면 전설은 격으로만 나와야 한다.
	scene.skill_owned = {"strike_common": 130}
	scene.gacha_shards = {}
	var shapes_seen := {}
	for i in 120:
		var got2: Dictionary = scene._receive_gacha_skill("legend")
		shapes_seen[str(SkillDefs.split(str(got2["key"]))[0])] = true
	assert(shapes_seen.size() == 1 and shapes_seen.has("strike"),
		"전설이 격 말고 다른 형태로도 나왔다: %s" % str(shapes_seen.keys()))

	# ── 4) 받을 형태가 없으면 조각 ────────────────────────────────────────
	# 커먼만 열린 상태에서 전설을 굴리면 **뽑기를 무르지 않고** 조각으로 준다.
	scene.skill_owned = {"strike_common": 0}
	scene.gacha_shards = {}
	var res: Dictionary = scene._receive_gacha_skill("legend")
	assert(res.has("shards") and int(res["shards"]) > 0,
		"천장 위 등급인데 조각이 안 왔다: %s" % str(res))
	assert(int(scene.gacha_shards.get("skill:strike_common", 0)) > 0,
		"조각이 가진 스킬에 안 얹혔다")
	assert(not scene.skill_owned.has("strike_legend"),
		"천장 위인데 스킬이 그냥 들어왔다 — 사슬이 새고 있다")

	# ── 5) 진행 표시 ──────────────────────────────────────────────────────
	var pg: Array = SkillDefs.cap_progress("strike", {"strike_common": 7})
	assert(str(pg[0]) == "common" and str(pg[1]) == "uncommon" and int(pg[2]) == 3,
		"다음 천장까지 남은 값이 틀리다: %s" % str(pg))
	var done: Array = SkillDefs.cap_progress("strike", {"strike_common": 500})
	assert(str(done[0]) == "legend" and str(done[1]) == "",
		"천장을 다 올렸는데 다음이 남아 있다: %s" % str(done))

	print("SkillUnlockCheck OK  (천장 사다리 · 등급 분포 불변 · 조각 대체)")
	quit(0)
