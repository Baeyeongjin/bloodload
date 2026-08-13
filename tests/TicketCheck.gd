extends SceneTree

# 소환권(TicketDefs)을 잰다. **종류별 4종**이다(사장님 2026-08-13) — 천장이
# 종류마다 따로 쌓이므로 권도 나뉜다. 지키는 것 넷:
#   1) 표 — 아이콘 실재, 이름·보상 키 왕복
#   2) 지불 순서 — 무료 > 그 종류의 권 > 보석. 다른 종류의 권은 안 나간다
#   3) 발행 — 임무·도감이 종류를 흩어서 준다(한 종류만 주면 나머지 천장이 안 찬다)
#   4) 저장 — 종류별 장수가 복원된다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	assert(TicketDefs.KINDS.size() == 4, "종류가 넷이 아니다")
	for k in TicketDefs.KINDS:
		assert(FileAccess.file_exists(TicketDefs.icon_of(k)),
			"%s 아이콘이 없다: %s" % [k, TicketDefs.icon_of(k)])
		assert(TicketDefs.name_of(k) != k and TicketDefs.short_of(k) != k,
			"%s 이름이 없다" % k)
		# 보상 키 왕복 — 표에 "ticket_weapon" 으로 적고 여기서 종류를 되찾는다.
		assert(TicketDefs.kind_of(TicketDefs.reward_of(k)) == k, "%s 왕복 실패" % k)
	assert(TicketDefs.kind_of("gem") == "", "재화를 소환권으로 읽는다")
	assert(TicketDefs.kind_of("ticket_none") == "", "없는 종류를 받아들인다")
	# 소환 화면의 종류와 같아야 한다 — 다르면 그 탭에서 쓸 권이 없다.
	for k in GearDefs.SLOTS:
		assert(k in TicketDefs.KINDS, "장비 종류 %s 의 권이 없다" % k)
	assert("skill" in TicketDefs.KINDS, "스킬권이 없다")

	# ── 2~4) 씬 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.free_pull_date = Time.get_date_string_from_system()   # 무료는 이미 씀
	scene.gem = 1000.0
	scene.tickets = {"weapon": 3, "skill": 0}
	scene._gacha_kind = "weapon"

	# 그 종류의 권이 있으면 보석이 안 나간다.
	var gem0: float = scene.gem
	scene._pull_gacha(1)
	assert(int(scene.tickets["weapon"]) == 2, "무기권이 안 깎였다")
	assert(is_equal_approx(scene.gem, gem0), "권을 두고 보석이 나갔다")

	# **다른 종류의 권은 안 쓴다** — 스킬 탭에서 무기권이 나가면 안 된다.
	scene._gacha_kind = "skill"
	var w0: int = int(scene.tickets["weapon"])
	scene._pull_gacha(1)
	assert(int(scene.tickets["weapon"]) == w0, "다른 종류의 권이 나갔다")
	assert(scene.gem < gem0, "스킬권이 없는데 보석이 안 나갔다")

	# 10연은 권이 모자라면 보석으로 간다(부분 지불 없음).
	scene._gacha_kind = "weapon"
	var gem1: float = scene.gem
	scene._pull_gacha(10)
	assert(int(scene.tickets["weapon"]) == w0, "모자란 권이 부분 지불됐다")
	assert(scene.gem < gem1, "10연에 보석이 안 나갔다")

	# ── 3) 발행 ────────────────────────────────────────────────────────────
	# 임무가 **종류를 흩어서** 주는가 — 한 종류만 주면 나머지 천장이 안 찬다.
	var seen := {}
	for q in QuestDefs.QUESTS + QuestDefs.WEEKLY:
		var k := TicketDefs.kind_of(str(q["reward"]))
		if k != "":
			seen[k] = true
	assert(seen.size() >= 3, "임무가 소환권 종류를 안 흩는다: %d" % seen.size())
	# 도감도 마찬가지.
	var cseen := {}
	for r in FoeTiers.CODEX_REWARDS:
		var extra := FoeTiers.codex_extra(r)
		if extra.is_empty():
			continue
		var k2 := TicketDefs.kind_of(str(extra["kind"]))
		if k2 != "":
			cseen[k2] = true
	assert(cseen.size() == 4, "도감이 네 종류를 다 안 준다: %d" % cseen.size())

	# 지급이 실제로 들어오는가.
	scene.tickets = {}
	scene._grant_reward("ticket_trinket", 4.0)
	assert(int(scene.tickets.get("trinket", 0)) == 4, "지급이 안 들어왔다")

	# ── 4) 저장 ────────────────────────────────────────────────────────────
	scene.tickets = {"weapon": 2, "skill": 7}
	scene._save_game()
	scene.tickets = {}
	scene._load_game()
	assert(int(scene.tickets.get("weapon", 0)) == 2
		and int(scene.tickets.get("skill", 0)) == 7,
		"저장/복원에서 소환권이 어긋났다")

	print("TicketCheck OK")
	quit()
