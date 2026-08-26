extends SceneTree
# 격노·강골이 (1) 정말 전투 계산에 붙고 (2) 게이트대로 잠기고 (3) 초기화가
# 전액을 돌려주는가. 셋 다 조용히 틀릴 수 있는 자리다.


func _init() -> void:
	# **가드.** 이게 없으면 assert 가 깨져도 SceneTree 가 안 죽어서 실패가
	# "타임아웃"으로 둔갑한다 — TicketCheck 를 그렇게 몇 주 오진했다.
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	await process_frame
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 1) 효과 — 괄호 A 에 붙어 피해·체력을 올린다.
	scene.lv = {}
	var d0: float = scene.damage()
	var h0: float = scene.max_hp()
	scene.lv["rage"] = 1 + Balance.SPLIT * 100     # 유효 101 = +100%
	assert(scene.damage() > d0 * 1.5, "격노가 공격에 안 붙는다: x%.3f"
		% (scene.damage() / d0))
	scene.lv["grit"] = 1 + Balance.SPLIT * 100
	assert(scene.max_hp() > h0 * 1.5, "강골이 체력에 안 붙는다: x%.3f"
		% (scene.max_hp() / h0))

	# 2) 게이트 — 단계와 선행 레벨 둘 다 봐야 열린다.
	var full := {}
	for st in StatDefs.STATS:
		full[str(st["key"])] = 99999
	assert(not StatDefs.is_open("rage", 19, full), "격노가 19단계에 열렸다")
	assert(StatDefs.is_open("rage", 20, full), "격노가 20단계에 안 열린다")
	var short := full.duplicate()
	short["damage"] = 1499
	assert(not StatDefs.is_open("rage", 99, short), "선행 1499에 격노가 열렸다")
	assert(not StatDefs.is_open("grit", 23, full), "강골이 23단계에 열렸다")
	assert(StatDefs.is_open("grit", 24, full), "강골이 24단계에 안 열린다")

	# 3) 초기화 — 쓴 만큼 정확히 돌려주고 전부 Lv1 이 된다.
	scene.lv = {"damage": 301, "tough": 151, "rage": 61}
	var want: float = scene._stat_refund_total()
	assert(want > 0.0, "환급액이 0이다")
	scene.gold = 0.0
	scene.gold += scene._stat_refund_total()
	scene.lv.clear()
	assert(is_equal_approx(scene.gold, want), "환급이 어긋난다")
	assert(scene._stat_refund_total() == 0.0, "초기화 뒤에도 환급이 남는다")
	assert(scene.stat_lv("damage") == 1, "초기화 뒤 레벨이 1이 아니다")

	print("RageGritCheck OK  (환급 %.0f 혈액)" % want)
	quit()
