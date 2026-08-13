extends SceneTree

# 소환권(TicketDefs)을 잰다. 지키는 것 넷:
#   1) 표 — 아이콘 실재, 고급권 바닥이 에픽
#   2) 굴림 — 고급권으로 굴리면 **에픽 아래가 안 나온다**(확률표는 그대로)
#   3) 지불 순서 — 무료 > 소환권 > 보석. 소환권을 두고 보석이 나가면 안 된다
#   4) 발행 — 임무·도감 보상이 지갑에 실제로 들어온다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	for key in [TicketDefs.BASIC, TicketDefs.HIGH]:
		assert(FileAccess.file_exists(TicketDefs.icon_of(key)),
			"%s 아이콘이 없다" % key)
		assert(TicketDefs.name_of(key) != key, "%s 이름이 없다" % key)
	assert(TicketDefs.HIGH_FLOOR == GachaDefs.EPIC_INDEX)

	# ── 2) 굴림 ────────────────────────────────────────────────────────────
	# 만렙 레벨로 200번 — 바닥 아래 등급이 한 번이라도 나오면 실패다.
	for i in 200:
		var r := GachaDefs.pull(1, 0, 5, false, TicketDefs.HIGH_FLOOR)
		var idx := GachaDefs.rarity_index(str(r["rarities"][0]))
		assert(idx >= GachaDefs.EPIC_INDEX,
			"고급권에서 %s 가 나왔다" % str(r["rarities"][0]))
	# 바닥 없는 굴림은 커먼도 나와야 한다 — 바닥을 전역에 걸어 버리지 않았는가.
	var saw_low := false
	for i in 200:
		var r := GachaDefs.pull(1, 0, 0)
		if GachaDefs.rarity_index(str(r["rarities"][0])) < GachaDefs.EPIC_INDEX:
			saw_low = true
	assert(saw_low, "일반 소환에도 바닥이 걸렸다")

	# ── 3~4) 씬 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.free_pull_date = Time.get_date_string_from_system()   # 무료는 이미 씀
	scene.gem = 1000.0
	scene.ticket = 3
	scene.ticket_hi = 1

	# 소환권이 있으면 보석이 안 나간다.
	var gem0: float = scene.gem
	scene._pull_gacha(1)
	assert(scene.ticket == 2, "소환권이 안 깎였다: %d" % scene.ticket)
	assert(is_equal_approx(scene.gem, gem0), "소환권을 두고 보석이 나갔다")
	# 10연은 소환권이 모자라므로 보석으로 간다(부분 지불 없음).
	scene._pull_gacha(10)
	assert(scene.ticket == 2, "모자란 소환권이 부분 지불됐다")
	assert(scene.gem < gem0, "10연에 보석이 안 나갔다")
	# 고급권 — 한 장 쓰고, 없으면 안 굴러간다.
	var pulls0: int = int(scene.gacha_pulls[scene._gacha_kind])
	scene._pull_gacha(1, true)
	assert(scene.ticket_hi == 0, "고급권이 안 깎였다")
	assert(int(scene.gacha_pulls[scene._gacha_kind]) == pulls0 + 1,
		"고급 소환이 누적에 안 들어갔다")
	var gem1: float = scene.gem
	scene._pull_gacha(1, true)
	assert(scene.ticket_hi == 0 and is_equal_approx(scene.gem, gem1),
		"고급권이 0인데 굴러갔다")

	# ── 4) 발행 ────────────────────────────────────────────────────────────
	# 임무 표가 소환권을 주도록 바뀌었는가 + 받으면 실제로 들어오는가.
	var kinds := {}
	for q in QuestDefs.QUESTS:
		kinds[str(q["reward"])] = true
	assert(kinds.has("ticket"), "일일 임무에 소환권이 없다")
	var t0: int = scene.ticket
	scene._grant_reward("ticket", 4.0)
	scene._grant_reward("ticket_hi", 2.0)
	assert(scene.ticket == t0 + 4 and scene.ticket_hi == 2, "지급이 안 들어왔다")
	# 도감 부가 보상 — 줄마다 한 종류만, 표에 없는 종류를 쓰지 않는가.
	var hi_seen := false
	for r in FoeTiers.CODEX_REWARDS:
		var extra := FoeTiers.codex_extra(r)
		if extra.is_empty():
			continue
		assert(str(extra["kind"]) in FoeTiers.EXTRA_KEYS)
		hi_seen = hi_seen or str(extra["kind"]) == "ticket_hi"
	assert(hi_seen, "도감에 고급권이 하나도 없다")

	# 저장·복원 — 소환권은 정수라 float 로 새면 티가 안 난다.
	scene._save_game()
	scene._load_game()
	assert(scene.ticket == t0 + 4 and scene.ticket_hi == 2,
		"저장/복원에서 소환권이 어긋났다: %d / %d" % [scene.ticket, scene.ticket_hi])

	print("TicketCheck OK")
	quit()
