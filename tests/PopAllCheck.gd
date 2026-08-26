extends SceneTree
# 창 등장 애니가 **전부**에 걸렸는가. 손 목록이 7개였고 판은 28개였다 —
# 이름 규칙 훑기가 실제로 다 잡는지, 두 번 걸리지는 않는지 본다.

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
	var missed: Array = []
	var n := 0
	for prop in scene.get_property_list():
		var pname := str(prop["name"])
		if not (pname.ends_with("_view") or pname.ends_with("_detail")
				or pname in ["_trial_panel", "_maze_panel", "_boss_panel"]):
			continue
		var node = scene.get(pname)
		if not (node is Control):
			continue
		n += 1
		if not node.has_meta("pop_in"):
			missed.append(pname)
	assert(missed.is_empty(), "애니가 안 걸린 판: %s" % str(missed))
	assert(n >= 20, "판을 %d개밖에 못 찾았다 — 훑기가 헛돌았다" % n)

	# 두 번 걸리면 트윈이 겹쳐 크기가 튄다. 시그널 연결이 하나여야 한다.
	for pname in ["_confirm_view", "_reward_view", "_codex_view"]:
		var node: Control = scene.get(pname)
		assert(node.visibility_changed.get_connections().size() == 1,
			"%s 에 애니가 %d 번 걸렸다" % [pname,
			node.visibility_changed.get_connections().size()])

	# 실제로 걸리는가 — setter 안에서 바로 울리므로 await 없이 잰다(PopupCheck 와 같은 이유).
	var v: Control = scene._gear_detail
	v.visible = true
	assert(v.scale.x < 1.0 or v.modulate.a < 1.0, "장비 상세가 툭 나타난다")

	# 어둠막은 줄어든 상태에서도 화면을 덮어야 한다 — 안 그러면 테두리가 번쩍인다.
	var dim: ColorRect = scene._confirm_view.get_child(0)
	assert(dim.size.x * 0.92 >= float(Grid.BG.x) and dim.size.y * 0.92 >= float(Grid.BG.y),
		"어둠막이 팝인 중에 화면을 다 못 덮는다: %s" % str(dim.size))
	print("PopAllCheck OK  (판 %d개)" % n)
	quit()
