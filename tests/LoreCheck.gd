extends SceneTree

# 도감의 나머지 셋 — 장비 · 스킬 · 연대기(LoreDefs).
#
# 여기서 지키려는 것은 **셈이 맞는가**다. 도감은 "빈 칸이 보여야 모으고 싶다"가
# 전부인데, 종수를 잘못 세면 다 모아도 칸이 안 차거나 안 모았는데 찬다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표 ─────────────────────────────────────────────────────────────────
	assert(LoreDefs.gear_total() > 0, "장비 종수가 0")
	assert(LoreDefs.skill_total() == SkillDefs.all_keys().size(),
		"스킬 종수가 표와 다르다")
	# 이정표의 마지막이 전체 종수여야 **다 모으면 다 받는다**.
	var g_last: int = int(LoreDefs.GEAR_MARKS[LoreDefs.GEAR_MARKS.size() - 1]["need"])
	assert(g_last == LoreDefs.gear_total(),
		"장비 마지막 이정표(%d)가 전체 종수(%d)와 다르다"
		% [g_last, LoreDefs.gear_total()])
	var s_last: int = int(LoreDefs.SKILL_MARKS[LoreDefs.SKILL_MARKS.size() - 1]["need"])
	assert(s_last == LoreDefs.skill_total(),
		"스킬 마지막 이정표(%d)가 전체 종수(%d)와 다르다"
		% [s_last, LoreDefs.skill_total()])
	# 이정표는 올라가기만 한다 — 뒤섞이면 to_next 가 거꾸로 센다.
	for marks in [LoreDefs.GEAR_MARKS, LoreDefs.SKILL_MARKS]:
		var prev := 0
		for m in marks:
			assert(int(m["need"]) > prev, "이정표가 안 오른다")
			prev = int(m["need"])
	assert(LoreDefs.to_next(LoreDefs.GEAR_MARKS, 0)
		== int(LoreDefs.GEAR_MARKS[0]["need"]), "첫 이정표까지가 틀렸다")
	assert(LoreDefs.to_next(LoreDefs.GEAR_MARKS, g_last) == 0,
		"다 모았는데 남은 게 있다")
	# 보상은 **작아야 한다** — 성장 축 여덟이 이미 곡선을 채우고 있다.
	var sum := 0.0
	for m in LoreDefs.GEAR_MARKS + LoreDefs.SKILL_MARKS:
		sum += float(m["rate"])
	assert(sum < 0.40, "도감 보상 합이 너무 크다: %.2f" % sum)
	# 연대기는 막마다 한 줄.
	assert(LoreDefs.CHRONICLE.size() == StageDefs.ACTS.size(),
		"연대기 줄 수(%d)가 막 수(%d)와 다르다"
		% [LoreDefs.CHRONICLE.size(), StageDefs.ACTS.size()])
	assert(LoreDefs.act_text(0) != "", "1막 기록이 비었다")
	assert(LoreDefs.act_text(99) == "", "없는 막에 기록이 있다")

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# **결백성** — 앞선 검사가 남긴 저장본이면 이미 모아 둔 게 있다.
	scene.gear_seen = {}
	scene.skill_owned = {}

	# 화면이 세는 열쇠 수와 표의 종수가 같아야 격자가 안 어긋난다.
	assert(scene._lore_keys("gear").size() == LoreDefs.gear_total(),
		"장비 격자 칸 수가 표와 다르다: %d" % scene._lore_keys("gear").size())
	assert(scene._lore_keys("skill").size() == LoreDefs.skill_total(),
		"스킬 격자 칸 수가 표와 다르다")
	assert(scene._lore_got("gear") == 0, "안 모았는데 센다")

	# **뽑으면 도감에 남는다.** 장착·분해와 무관해야 한다 — gear_inventory 로
	# 세면 분해할 때 도감이 거꾸로 줄어든다(그래서 gear_seen 을 따로 둔다).
	scene._gacha_kind = "weapon"
	scene._receive_gacha_gear("common")
	assert(scene._lore_got("gear") == 1, "뽑았는데 도감에 안 남았다")
	var key := str(scene.gear_seen.keys()[0])
	scene.gear_inventory = {}          # 분해한 셈 치고 비운다
	scene.equipped = {}
	assert(scene._lore_got("gear") == 1, "분해했더니 도감이 줄었다")
	assert(scene.gear_seen.has(key), "도감 열쇠가 사라졌다")

	# 저장.
	scene._save_game()
	scene.gear_seen = {}
	scene._load_game()
	assert(scene.gear_seen.has(key), "장비 도감이 복원 안 됐다")

	# 소탭 전환이 넷 다 도는가 — 하나라도 죽어 있으면 그 도감은 못 본다.
	for m in ["foe", "gear", "skill", "title", "act"]:
		scene._codex_set_mode(m)
		assert(scene._codex_roots[m].visible, "%s 소탭이 안 열린다" % m)
		for other in ["foe", "gear", "skill", "title", "act"]:
			if other != m:
				assert(not scene._codex_roots[other].visible,
					"%s 를 열었는데 %s 도 보인다" % [m, other])

	# **칭호가 도감 안으로 들어왔다** — 별도 판(_title_view)은 없앴다.
	# 그 판을 다시 만들면 여는 곳이 둘이 되어 하나는 늘 낡은 값을 보인다.
	assert(not ("_title_view" in scene), "칭호 판이 되살아났다")
	scene._codex_set_mode("title")
	assert(scene._title_head != null, "칭호 소탭에 머리글이 없다")
	assert(scene._title_names.size() == TitleDefs.TITLES.size(),
		"칭호 줄 수가 표와 다르다: %d" % scene._title_names.size())

	print("LoreCheck OK")
	quit()
