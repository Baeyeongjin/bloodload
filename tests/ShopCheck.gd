extends SceneTree

# 상점(ShopDefs)을 잰다. 지키는 것 넷:
#   1) 표 — 아이콘 파일 실재, 해금 구간이 Defs 를 읽는가(숫자 박기 금지)
#   2) 값 — 수량이 양수·구간 따라 증가, 던전 한 판보다 후하지 않은가
#   3) 구매 — 보석이 빠지고 재화가 들어오고 오늘 한도가 깎인다
#   4) 잠금 — 보석 부족 · 한도 소진 · 미해금이면 안 팔린다 (지갑 불변)
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	for it in ShopDefs.ITEMS:
		var id := str(it["id"])
		assert(FileAccess.file_exists(str(it["icon"])),
			"%s 아이콘 파일이 없다: %s" % [id, str(it["icon"])])
		assert(int(it["per_day"]) > 0 and int(it["cost"]) > 0, "%s 값이 0" % id)
	# 해금 계단은 던전 표를 읽어야 한다 — 여기 숫자를 박으면 계단을 옮길 때마다
	# 상점만 딴 소리를 한다(던전 표가 그 실수로 두 번 깨졌다).
	assert(ShopDefs.open_stage("crystal") == DungeonDefs.OPEN_STAGE)
	assert(ShopDefs.open_stage("essence") == RaidDefs.open_stage("essence"))
	assert(ShopDefs.open_stage("sigil") == RaidDefs.open_stage("pact"))
	assert(ShopDefs.open_stage("blood") == 1, "혈액은 늘 열려 있어야 한다")

	# ── 2) 값 ──────────────────────────────────────────────────────────────
	for id in ["blood", "essence"]:
		var prev := 0.0
		for st in range(1, 400, 20):
			var a := ShopDefs.amount(id, st, 20)
			assert(a > 0.0 and a >= prev, "%s %d구간 수량이 줄었다" % [id, st])
			prev = a
	# 던전 한 판보다 후하면 던전을 안 돌게 된다.
	assert(ShopDefs.amount("blood", 50, 20) < RaidDefs.reward("blood", 1),
		"상점 혈액이 동굴 한 판보다 많다")
	assert(ShopDefs.amount("essence", 50, 20) < RaidDefs.reward("essence", 1),
		"상점 정수가 성소 한 판보다 많다")
	# 미궁이 열렸는데 아직 안 돈 사람(기록 0)에게도 빈 물건을 팔면 안 된다.
	assert(ShopDefs.amount("crystal", 50, 0) > 0.0, "혈정 수량이 0 인 판이 뜬다")

	# ── 3~4) 씬 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# 결백성 — 지난 저장본을 덮는다.
	scene.stage = 50
	scene.best_stage = 100          # 전 품목 해금
	scene.gem = 1000.0
	scene.shop_date = ""
	scene.shop_used = {}
	scene._shop_roll_day()

	var gold0: float = scene.gold
	var gem0: float = scene.gem
	scene._shop_buy("blood")
	assert(is_equal_approx(scene.gem, gem0 - 30.0), "보석이 안 빠졌다: %f" % scene.gem)
	assert(scene.gold > gold0, "혈액이 안 들어왔다")
	assert(scene._shop_left("blood") == 2, "오늘 한도가 안 깎였다")

	# 입장권은 하루 상한 **위로** 얹는다 — 산 판은 덤이다.
	scene._raid_roll_day()
	var left0: int = scene._raid_left("blood")
	scene._shop_buy("ticket")
	assert(scene._raid_left("blood") == left0 + 1, "입장권이 판을 안 늘렸다")
	assert(scene._shop_left("ticket") == 0, "입장권 한도가 안 깎였다")
	# 한도 소진 — 지갑이 안 움직여야 한다.
	var gem1: float = scene.gem
	scene._shop_buy("ticket")
	assert(is_equal_approx(scene.gem, gem1), "한도가 0인데 팔렸다")

	# 보석 부족.
	scene.gem = 1.0
	var crystal0: float = scene.crystal
	scene._shop_buy("crystal")
	assert(is_equal_approx(scene.crystal, crystal0), "보석이 없는데 팔렸다")

	# 미해금 — 구간이 낮으면 안 판다.
	scene.gem = 1000.0
	scene.best_stage = 1
	var sigil0: float = scene.sigil
	scene._shop_buy("sigil")
	assert(is_equal_approx(scene.sigil, sigil0), "안 열린 품목이 팔렸다")

	# 날이 바뀌면 한도가 돌아온다.
	scene.shop_date = "2000-01-01"
	scene._shop_roll_day()
	assert(scene._shop_left("blood") == 3, "새 날에 한도가 안 찼다")

	print("ShopCheck OK")
	quit()
