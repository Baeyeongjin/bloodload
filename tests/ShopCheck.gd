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
		# 광고 줄(ad)은 보석이 아니라 광고가 값이다 — cost 0 이 정상.
		assert(int(it["per_day"]) > 0 and (int(it["cost"]) > 0
			or ShopDefs.is_ad(id)), "%s 값이 0" % id)
	# 해금 계단은 던전 표를 읽어야 한다 — 여기 숫자를 박으면 계단을 옮길 때마다
	# 상점만 딴 소리를 한다(던전 표가 그 실수로 두 번 깨졌다).
	assert(ShopDefs.open_stage("crystal") == DungeonDefs.OPEN_STAGE)
	assert(ShopDefs.open_stage("sigil") == RaidDefs.open_stage("pact"))
	# 핏빛 주머니(혈액)는 2026-08-27 에 지웠다 — 시간 왜곡이 같은 물건을
	# 정직한 요율로 팔고 있어서 30보석짜리 뭉치가 방치 10~20초치였다.
	assert(ShopDefs.of("blood").is_empty(), "지운 핏빛 주머니가 살아 있다")

	# ── 2) 값 ──────────────────────────────────────────────────────────────
	# **수량은 진행을 따라가야 한다.** 상수로 박아 두면 살 수 있게 될 무렵에는
	# 이미 쓸모없어진다 — 인장이 40 고정이라 제단 한 판의 27% 까지 녹았었다.
	for id in ["crystal", "sigil"]:
		var prev := 0.0
		for n2 in range(1, 8):
			var a := ShopDefs.amount(id, 50 + n2 * 20, n2 * 15, n2)
			assert(a > 0.0 and a >= prev, "%s 가 진행해도 안 는다 (%.0f)" % [id, a])
			prev = a
		assert(prev > ShopDefs.amount(id, 50, 0, 0),
			"%s 가 끝에서도 시작과 같다 — 상수로 박혔다" % id)
	# 던전 한 판보다 후하면 던전을 안 돌게 된다.
	for n3 in [1, 4, 7]:
		assert(ShopDefs.amount("sigil", 50, 0, n3) < RaidDefs.reward("pact", n3),
			"상점 인장이 제단 %d단계 한 판보다 많다" % n3)
	# 미궁이 열렸는데 아직 안 돈 사람(기록 0)에게 **빈 물건**을 팔면 안 된다.
	# 0 이 아니라 "혈맥 노드 한 레벨의 1/4" 이 바닥이다(TraitDefs.COST[0] = 180).
	assert(ShopDefs.amount("crystal", 50, 0) >= TraitDefs.COST[0] * 0.25,
		"미궁 기록 0 일 때 혈정 수량이 노드 1/4 에 못 미친다")

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

	# 혈정으로 산다 — 핏빛 주머니가 지워진 뒤 지갑에 바로 꽂히는 물건은 이것과
	# 인장 둘이다(입장권·시간 왜곡은 판 수·상자라 아래에서 따로 본다).
	scene.dungeon_best = 20
	var cry0: float = scene.crystal
	var gem0: float = scene.gem
	scene._shop_buy("crystal")
	assert(is_equal_approx(scene.gem, gem0 - 45.0), "보석이 안 빠졌다: %f" % scene.gem)
	assert(scene.crystal > cry0, "혈정이 안 들어왔다")
	assert(scene._shop_left("crystal") == 1, "오늘 한도가 안 깎였다")

	# 입장권은 하루 상한 **위로** 얹는다 — 산 판은 덤이다.
	scene._raid_roll_day()
	var left0: int = scene._raid_left("blood")
	scene._shop_buy("ticket")
	assert(scene._raid_left("blood") == left0 + 1, "입장권이 판을 안 늘렸다")
	assert(scene._shop_left("ticket") == 0, "입장권 한도가 안 깎였다")

	# 시간 왜곡은 지갑이 아니라 **상자**에 담긴다 — 방치 적립과 같은 길.
	var chest0: float = scene.chest_gold
	var mins0: float = scene.chest_minutes
	scene._shop_buy("warp")
	assert(scene.chest_gold > chest0, "시간 왜곡이 상자에 안 담겼다")
	assert(is_equal_approx(scene.chest_minutes, mins0 + ShopDefs.WARP_HOURS * 60.0),
		"시간 왜곡 분이 안 맞다: %f" % scene.chest_minutes)
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
	assert(scene._shop_left("crystal") == 2, "새 날에 한도가 안 찼다")

	# **광고 줄은 SDK 가 붙기 전까지 못 눌러야 한다.** 안 그러면 값 0 으로
	# 눌리고 하루 한도만 깎인 뒤 "보석 50 획득" 창이 뜬다 — 지갑은 그대로다
	# (2026-08-27 실측: is_ad 호출부가 Main 에 0건이었고 _shop_buy 의 match 에
	# ad_* 갈래가 없었다).
	for id in ["ad_ticket", "ad_gem", "ad_chest"]:
		assert(ShopDefs.is_ad(id), "%s 가 광고 줄이 아니다" % id)
		scene.best_stage = 999
		scene.gem = 9999.0
		scene.shop_used = {}
		var g0: float = scene.gem
		var used0: int = int(scene.shop_used.get(id, 0))
		scene._shop_buy(id)
		assert(int(scene.shop_used.get(id, 0)) == used0,
			"%s 를 눌렀더니 오늘 한도가 깎였다 — SDK 도 없는데 팔렸다" % id)
		assert(is_equal_approx(scene.gem, g0), "%s 가 보석을 먹었다" % id)

	print("ShopCheck OK")
	quit()
