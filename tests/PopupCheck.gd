extends SceneTree

# 창이 뜰 때의 반응(Ui.pop_in)과 **나가는 문**을 잰다.
#   1) 팝업마다 닫기 경로가 있는가 — 칭호 창에 닫기가 없어서 못 나왔다(사장님)
#   2) 켜는 순간 애니가 걸리고, 끝나면 원래 크기·불투명으로 수렴하는가
#      (수렴을 못 하면 창이 조금 작거나 반투명한 채로 남는다)
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 1) 팝업마다 "닫기" 버튼이 있다. 뒤로 갈 길 없는 창은 막다른 길이다.
	for name in ["_title_view", "_status_view", "_quest_view", "_rates_view",
			"_bulk_view"]:
		var v: Control = scene.get(name)
		assert(v != null, "%s 가 없다" % name)
		assert(_has_close(v), "%s 에 닫기 버튼이 없다 — 들어가면 못 나온다" % name)

	# 2) 켜면 애니가 걸리고 끝에는 제자리로 수렴한다.
	var view: Control = scene._title_view
	view.visible = true
	await process_frame
	assert(view.scale.x < 1.0 or view.modulate.a < 1.0,
		"창이 켜졌는데 애니가 안 걸렸다 — Ui.pop_in 등록이 빠졌다")
	# TRANS_BACK 은 1.0 을 살짝 넘겼다가 돌아온다 — "1.0 미만"으로 기다리면
	# 오버슈트 지점(1.008)에서 먼저 빠져나온다. 거리로 기다린다.
	# 트윈 길이(0.16초)의 몇 배를 기다린 뒤 **눈에 안 보일 만큼** 붙었는지 본다.
	# is_equal_approx 로 재면 부동소수 정확도를 재는 것이지 수렴을 재는 게 아니다.
	var waited := 0.0
	while waited < 1.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(absf(view.scale.x - 1.0) < 0.01 and view.modulate.a > 0.99,
		"애니가 제자리로 안 돌아왔다: scale %.3f alpha %.3f"
		% [view.scale.x, view.modulate.a])

	print("PopupCheck OK")
	quit()


# 자손 중에 "닫기" 라고 적힌 버튼이 있는가.
func _has_close(node: Node) -> bool:
	for c in node.get_children():
		if c is Button and str((c as Button).text) == "닫기":
			return true
		if _has_close(c):
			return true
	return false
