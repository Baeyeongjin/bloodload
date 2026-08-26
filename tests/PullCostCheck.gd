extends SceneTree
# 소환 값 치르기 — 소환권을 있는 만큼 먼저 쓰고 모자란 몫만 보석으로.
# 예전엔 전부 아니면 전무라 권 9장을 놔둔 채 보석 300 이 나갔다(사장님).

func _init() -> void:
	# **가드.** 이게 없으면 assert 가 깨져도 SceneTree 가 안 죽어서 실패가
	# "타임아웃"으로 둔갑한다 — TicketCheck 를 그렇게 몇 주 오진했다.
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._gacha_kind = "weapon"
	scene.free_pull_date = Time.get_date_string_from_system()   # 무료 판 소진
	# 천장 상자를 멀리 밀어 둔다 — 열 번 도는 중에 차면 _mile_add 가 소환권을
	# 2장 돌려줘서 값 계산이 흔들린다(상자는 그것대로 맞는 동작이다).
	scene.mile_lv = 20
	scene.mile_fill = 0

	var cases := [
		# [가진 권, 뽑는 수, 쓸 권, 쓸 보석]
		[9, 10, 9, 30],      # 사장님이 지적한 자리
		[0, 10, 0, 300],
		[10, 10, 10, 0],
		[25, 10, 10, 0],     # 남아돌아도 열 장만
		[1, 1, 1, 0],
		[0, 1, 0, 30],
	]
	for c in cases:
		scene.tickets["weapon"] = int(c[0])
		scene.gem = 10000.0
		var g0: float = scene.gem
		scene._pull_gacha(int(c[1]))
		var used_tk: int = int(c[0]) - int(scene.tickets.get("weapon", 0))
		var used_gem: int = int(round(g0 - scene.gem))
		assert(used_tk == int(c[2]) and used_gem == int(c[3]),
			"권 %d로 %d연: 권 %d·보석 %d 를 썼다 (기대 권 %d·보석 %d)"
			% [c[0], c[1], used_tk, used_gem, c[2], c[3]])

	# 보석이 모자라면 아무것도 안 나간다 — 반쪽 결제가 제일 나쁘다.
	scene.tickets["weapon"] = 9
	scene.gem = 10.0                      # 30 이 필요한데 10 뿐
	scene._refresh_gacha()
	assert(scene._gacha_buttons["ten"].disabled, "못 사는데 버튼이 열려 있다")
	scene._pull_gacha(10)
	assert(int(scene.tickets.get("weapon", 0)) == 9 and scene.gem == 10.0,
		"값이 모자란데 재화가 나갔다")

	# 버튼 글자가 섞인 값을 말하는가.
	scene.gem = 10000.0
	scene.tickets["weapon"] = 9
	scene._refresh_gacha()
	var t: String = scene._gacha_btn_lbl["ten"].text
	assert("9" in t and "30" in t, "섞인 값이 버튼에 안 적힌다: %s" % t)

	# **버튼 폭 안에 드는가.** 섞인 값은 글자가 길어서 SIZE_MID 로는 258 을 넘어
	# 왼쪽으로 삐져나갔다(사장님 캡처). 눈으로만 보면 다음에 또 넘친다.
	const BTN_W := 258.0
	for tk in [9, 6, 1]:
		scene.tickets["weapon"] = tk
		scene.gem = 10000.0
		scene._refresh_gacha()
		var lbl: Label = scene._gacha_btn_lbl["ten"]
		var fs: int = lbl.get_theme_font_size("font_size")
		var wpx: float = lbl.get_theme_font("font").get_string_size(
			lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# 아이콘(34) 자리도 남겨야 한다 — 글자가 꽉 차면 아이콘이 버튼 밖에 붙는다.
		assert(wpx + 34.0 <= BTN_W,
			"권 %d일 때 버튼 글자가 %.0fpx — 폭 %.0f 를 넘는다: %s"
			% [tk, wpx + 34.0, BTN_W, lbl.text])
	# ── 펫 소환도 같은 규칙인가 ────────────────────────────────────────────
	# 펫은 _pet_pay 가 **한 장씩** 치르므로 섞이는 것 자체는 원래 됐다.
	# 문제는 화면이었다: 권이 하나라도 있으면 "10연"이라고만 떠서 보석이 얼마
	# 나가는지 몰랐고, 잠금이 1회 기준이라 권 1장 + 보석 0 에도 열려 한 번만
	# 뽑히고 아홉 번이 조용히 실패했다.
	scene.best_stage = maxi(scene.best_stage, PetDefs.PET_OPEN)
	for pk in ["pet", "petgear"]:
		scene.mile_lv = 20
		scene.mile_fill = 0
		scene.tickets[pk] = 9
		scene.gem = 10000.0
		var pg0: float = scene.gem
		if pk == "pet":
			scene._pet_roll_many(10)
		else:
			scene._petgear_roll_many(10)
		assert(int(scene.tickets.get(pk, 0)) == 0,
			"%s: 권 9장이 안 나갔다 (%d 남음)" % [pk, int(scene.tickets.get(pk, 0))])
		assert(int(round(pg0 - scene.gem)) == 30,
			"%s: 보석 %d 가 나갔다 (기대 30 — 권 9장을 놔두고 있다)"
			% [pk, int(round(pg0 - scene.gem))])

		# 값이 모자라면 10연이 안 열려야 한다 — 열리면 한 번만 뽑히고 만다.
		scene.tickets[pk] = 1
		scene.gem = 0.0
		scene._refresh_pet_roll()
		assert(scene._pet_roll_ui[pk]["ten"]["btn"].disabled,
			"%s: 권 1장 보석 0 인데 10연이 열려 있다" % pk)

		# 섞인 값이 버튼에 적히는가.
		scene.tickets[pk] = 9
		scene.gem = 10000.0
		scene._refresh_pet_roll()
		var pt: String = scene._pet_roll_ui[pk]["ten"]["lbl"].text
		assert("9" in pt and "30" in pt, "%s: 섞인 값이 안 적힌다: %s" % [pk, pt])
	print("PullCostCheck OK  (무기·펫·펫장비)")
	quit()
