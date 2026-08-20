extends SceneTree
# 소환 값 치르기 — 소환권을 있는 만큼 먼저 쓰고 모자란 몫만 보석으로.
# 예전엔 전부 아니면 전무라 권 9장을 놔둔 채 보석 300 이 나갔다(사장님).

func _init() -> void:
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._gacha_kind = "weapon"
	scene.free_pull_date = Time.get_date_string_from_system()   # 무료 판 소진

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
	print("PullCostCheck OK")
	quit()
