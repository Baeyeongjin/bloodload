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
	# 칭호 전용 창(_title_view)은 사라졌다 — 칭호가 **도감 소탭**으로 들어가면서
	# 판이 통째로 없어졌는데 이 검사만 옛 이름을 들고 있었다(2026-08-18 발견).
	# 계약 판도 같은 규칙을 지키는지 여기서 같이 본다.
	for name in ["_codex_view", "_oath_view", "_status_view", "_quest_view",
			"_rates_view", "_bulk_view"]:
		var v: Control = scene.get(name)
		assert(v != null, "%s 가 없다" % name)
		assert(_has_close(v), "%s 에 닫기 버튼이 없다 — 들어가면 못 나온다" % name)

	# 2) 켜면 애니가 걸리고 끝에는 제자리로 수렴한다.
	#
	# **await 하지 않고 바로 잰다.** visibility_changed 는 setter 안에서 그 자리
	# 에서 울리므로 Ui.pop_in 의 시작값(0.92 / a=0)이 즉시 박힌다. 한 프레임
	# 기다렸다 재면 그 프레임의 delta 가 애니 길이(0.16초)보다 크면 이미 끝나
	# 있어서 헛통과·헛실패가 난다 — 헤드리스 첫 프레임이 정확히 그렇다
	# (실측: 한 프레임 뒤 scale 1.004 · a 1.0, 즉 오버슈트까지 지나갔다).
	var view: Control = scene._codex_view
	view.visible = true
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
# 판마다 닫기 문법이 둘이다: 글자 있는 Ui.button, 그리고 **그림 버튼 + 라벨**
# (투명 판정 버튼이라 text 가 비어 있다 — 세트를 쓰는 판은 전부 이쪽이다).
# 둘 다 "나갈 길"이므로 둘 다 인정한다.
func _has_close(node: Node) -> bool:
	for c in node.get_children():
		if c is Button and str((c as Button).text) == "닫기":
			return true
		if c is Label and str((c as Label).text) == "닫기":
			return true
		if _has_close(c):
			return true
	return false
