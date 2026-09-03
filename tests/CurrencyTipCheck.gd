extends SceneTree

# 재화 안내 (사장님 2026-09-02: "재화 툴팁도 ㄱㄱ").
#
# 재화가 여덟인데 **어느 것도 눌러 볼 수 없었다** — "재화가 0이라 버튼이 회색"
# 상태에서 어디로 가야 하는지 알 길이 없었다. 이 검사가 지키는 것 셋:
#   1) 표가 **실제 재화 전부**를 덮는가 (하나 빠지면 그 재화만 조용히 미아가 된다)
#   2) 표가 가리키는 탭·소탭이 **실제로 있는가** (오타 하나면 눌러도 아무 일 없다)
#   3) 아이콘 파일이 있는가 · 잠긴 탭으로는 안 보내는가
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var info: Dictionary = scene.CURRENCY_INFO

	# ── 1) 지갑에 있는 재화가 표에 다 있는가 ──────────────────────────────
	# 지갑 변수를 직접 센다 — 표만 보면 "표에 있는 것만 맞는지" 되물을 뿐이다.
	for key in ["gold", "gem", "crystal", "sigil", "feed", "whet", "ticket",
			"mark"]:
		assert(info.has(key), "%s 이(가) 재화 표에 없다 — 눌러도 아무 일이 없다" % key)
	assert(info.size() == 8, "재화 표가 8종이 아니다: %d" % info.size())

	# ── 2) 표가 가리키는 곳이 실제로 있는가 ───────────────────────────────
	var tab_keys := {}
	for row in scene.TABS:
		tab_keys[str(row[0])] = true
	var growth_keys := {}
	for row in scene.GROWTH_MODES:
		growth_keys[str(row[0])] = true
	for key in info:
		var c: Dictionary = info[key]
		for f in ["name", "icon", "get", "spend", "tab", "mode"]:
			assert(c.has(f) and str(c[f]) != "" or f in ["tab", "mode"],
				"%s 의 %s 이(가) 비었다" % [key, f])
		assert(str(c["get"]) != "" and str(c["spend"]) != "",
			"%s 에 얻는 곳·쓰는 곳이 다 적혀 있지 않다" % key)
		assert(FileAccess.file_exists(str(c["icon"])),
			"%s 아이콘이 없는 파일이다: %s" % [key, str(c["icon"])])
		var tab := str(c["tab"])
		if tab == "" or tab == "quest":
			continue     # quest 는 탭이 아니라 옆줄 판이다
		assert(tab_keys.has(tab), "%s 이(가) 없는 탭을 가리킨다: %s" % [key, tab])
		var mode := str(c["mode"])
		if mode == "":
			continue
		if tab == "growth":
			assert(growth_keys.has(mode),
				"%s 이(가) 없는 성장 소탭을 가리킨다: %s" % [key, mode])
		elif tab == "raid":
			assert(mode in ["maze", "raid", "boss", "trial", "rush"],
				"%s 이(가) 없는 던전 소탭을 가리킨다: %s" % [key, mode])

	# ── 3) 눌러도 안 죽는가 · 잠긴 탭으로 안 보내는가 ─────────────────────
	scene.best_stage = 1
	scene.gear_inventory = {}
	scene._relayout_tabs()
	# 1구간에서는 던전이 잠겨 있다 — 그 재화들은 이동 버튼이 없어야 한다.
	assert(not scene._tab_open("raid"), "1구간에 던전이 열렸다 — 전제가 깨졌다")
	for key in ["crystal", "sigil", "feed", "whet"]:
		scene._show_currency(str(key))
		assert(scene._confirm_view.visible, "%s 안내창이 안 떴다" % key)
		assert(not scene._confirm_ok.visible,
			"%s: 잠긴 곳으로 가는 버튼이 살아 있다" % key)
		assert("잠겨" in scene._confirm_body.text,
			"%s: 잠겼다는 말이 없다: %s" % [key, scene._confirm_body.text])
		scene._confirm_view.visible = false

	# 열리면 이동 버튼이 산다.
	scene.best_stage = 500
	scene._relayout_tabs()
	scene._show_currency("crystal")
	assert(scene._confirm_ok.visible and scene._confirm_ok.text == "가기",
		"열렸는데 이동 버튼이 없다: %s" % scene._confirm_ok.text)
	assert(scene._confirm_title.text == "혈정",
		"제목이 재화 이름이 아니다: %s" % scene._confirm_title.text)
	# 실제로 그리로 간다.
	scene._goto_currency("raid", "maze")
	assert(scene._tab == "raid", "이동이 안 됐다: %s" % scene._tab)
	scene._confirm_view.visible = false

	# ── 4) 확인창을 빌려 쓴 뒤 원래 쓰임이 안 망가졌는가 ──────────────────
	# _ask 의 기본값이 살아 있어야 기존 호출 서른 곳이 그대로 돈다.
	scene._ask("보통 확인창", Callable())
	assert(scene._confirm_title.text == "알림" and scene._confirm_ok.visible
		and scene._confirm_ok.text == "확인",
		"기본 확인창이 재화 안내에 오염됐다: %s / %s"
		% [scene._confirm_title.text, scene._confirm_ok.text])
	scene._confirm_view.visible = false

	print("CurrencyTipCheck OK  (8종 · 가리키는 곳 실재 · 잠김 처리 · 확인창 원복)")
	quit(0)
