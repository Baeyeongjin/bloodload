extends SceneTree

# 성장 창의 잠금 표시가 **실제 씬에서** 무엇을 보여 주는지 찍는다. 순수 함수 검사는
# BalanceTest 가 하지만, `lv` 를 안 넘긴 호출부가 남아 있으면 여기서만 드러난다.

func _init() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	for step in [[1, {}], [1, {"damage": 5}], [1, {"damage": 5, "tough": 5}],
			[6, {"damage": 5, "tough": 5, "speed": 10, "crit": 5}],
			[6, {"damage": 5, "tough": 20, "speed": 10, "crit": 5}]]:
		var major: int = int(step[0])
		scene.stage = (major - 1) * StageDefs.STEPS_PER_STAGE + 1
		scene.lv = (step[1] as Dictionary).duplicate()
		scene._refresh_growth()
		await process_frame
		var open: Array = []
		var shut: Array = []
		for s in StatDefs.STATS:
			var key := str(s["key"])
			var row: Dictionary = scene._stat_rows[key]
			if bool(row["btn"].visible):
				open.append(str(s["name"]))
			else:
				shut.append("%s(%s)" % [str(s["name"]), str(row["lock"].text)])
		print("%d단계 %-42s" % [major, str(step[1])])
		print("   열림 %s" % ", ".join(open))
		print("   잠김 %s" % ", ".join(shut))

	# 맨 처음 상태에서 공격력·흡혈량이 열려 있어야 게임이 시작된다.
	scene.stage = 1
	scene.lv = {}
	scene._refresh_growth()
	await process_frame
	assert(bool(scene._stat_rows["damage"]["btn"].visible), "공격력이 처음부터 안 열린다")
	assert(not bool(scene._stat_rows["tough"]["btn"].visible), "체력이 선행 없이 열렸다")
	assert(str(scene._stat_rows["tough"]["lock"].text).contains("공격력"),
		"체력 잠금이 선행을 안 알려 준다: %s" % str(scene._stat_rows["tough"]["lock"].text))
	# 선행을 채우면 같은 단계에서 바로 열려야 한다(스테이지를 안 넘겨도).
	scene.lv = {"damage": 60}   # 15분할 문턱(딱 떨어지는 수로 끊었다)
	scene._refresh_growth()
	await process_frame
	assert(bool(scene._stat_rows["tough"]["btn"].visible),
		"공격력 Lv5 인데 체력이 안 열린다: %s" % str(scene._stat_rows["tough"]["lock"].text))
	# 단계가 모자라면 **단계**를 보여 줘야 한다 — 선행을 채워도 안 열리니까.
	scene.lv = {"damage": 5, "tough": 5, "speed": 10, "crit": 5}
	scene._refresh_growth()
	await process_frame
	assert(str(scene._stat_rows["crit"]["lock"].text).contains("단계"),
		"단계가 모자란데 선행을 시킨다: %s" % str(scene._stat_rows["crit"]["lock"].text))
	# ── 탭·소탭 진도 잠금 (2026-09-02) ────────────────────────────────────
	# 첫 실행에 일곱 탭이 다 서 있었고 그중 넷은 열면 회색 문구뿐인 방이었다.
	scene.best_stage = 1
	scene.gear_inventory = {}
	scene.skill_owned = {}
	scene._relayout_tabs()
	scene._relayout_growth()
	# 성장은 **절대 잠기면 안 된다** — 부팅 기본 탭이자 잠긴 탭의 되돌아갈 곳이다.
	assert(scene._tab_open("growth") and scene._tab_open("home"),
		"성장·사냥이 잠겼다 — 되돌아갈 곳이 없어진다")
	assert(scene._tab_open("summon"), "소환이 잠겼다 — 첫 뽑기는 무료다")
	assert(not scene._tab_open("gear"), "아무것도 안 뽑았는데 장비 탭이 열렸다")
	assert(not scene._tab_open("pet") and not scene._tab_open("raid"),
		"1구간에 펫·던전이 열렸다")
	# 성장 소탭 — 첫 화면에 스탯만.
	assert(scene._growth_mode_open("stat"), "스탯이 잠겼다")
	for m in ["skill", "trait", "pact", "relic", "prestige"]:
		assert(not scene._growth_mode_open(str(m)),
			"1구간에 %s 소탭이 열렸다" % m)

	# 진행하면 **열린다**. 문턱은 각 시스템이 이미 가진 상수를 그대로 읽는지 본다.
	scene.best_stage = PetDefs.PET_OPEN
	assert(scene._tab_open("pet"), "%d구간인데 펫이 안 열렸다" % PetDefs.PET_OPEN)
	scene.best_stage = PrestigeDefs.OPEN_STAGE
	assert(scene._tab_open("raid") and scene._growth_mode_open("trait")
		and scene._growth_mode_open("pact") and scene._growth_mode_open("relic")
		and scene._growth_mode_open("prestige"),
		"끝까지 갔는데 안 열린 것이 있다")
	# 장비는 구간이 아니라 **가진 게 있나**로 연다(드랍이 없어 구간으로 열면
	# 여전히 빈 판을 본다).
	assert(not scene._tab_open("gear"), "200구간이면 안 뽑아도 장비가 열린다")
	scene.gear_inventory = {"x": {"lv": 1}}
	assert(scene._tab_open("gear"), "장비를 가졌는데 안 열린다")

	# **잠긴 탭으로는 못 간다.** 부르는 자리가 서른 곳이 넘어서 문 하나에서 막는다.
	scene.best_stage = 1
	scene.gear_inventory = {}
	scene._relayout_tabs()
	scene._select_tab("pet")
	assert(scene._tab == "growth",
		"잠긴 탭으로 갔다: %s" % scene._tab)
	scene._set_growth_mode("prestige")
	assert(scene._growth_mode == "stat",
		"잠긴 소탭이 골라졌다: %s" % scene._growth_mode)

	# 열린 것끼리 **폭을 나눠 갖는다** — 빈칸이 남으면 눌러도 안 되는 자리가 된다.
	var xs: Array = []
	for row in scene.TABS:
		var c: Dictionary = scene._tab_cells[str(row[0])]
		if (c["marker"] as Control).visible:
			xs.append((c["marker"] as Control).position.x)
	assert(xs.size() >= 3, "첫 화면에 탭이 %d개뿐이다" % xs.size())
	xs.sort()
	assert(is_equal_approx(xs[0], 0.0), "첫 탭이 왼쪽 끝에 안 붙었다: %f" % xs[0])
	for i in range(1, xs.size()):
		assert(xs[i] > xs[i - 1], "탭이 겹쳐 있다")

	print("UnlockCheck OK  (스탯 선행 · 탭/소탭 진도 잠금)")
	quit()
