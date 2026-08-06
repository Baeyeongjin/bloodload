extends SceneTree

# 구간이 넘어갈 때 영웅이 **어디서 시작하는지** 잰다(사장님: "스테이지 시작하면 중앙에서").
# 1차 측정에서 암전 시작·걷힘 모두 288.0(정중앙)이었다 — _tick_dash 의
# `_phase != "fight"` 분기가 암전 중에 이미 되돌린다.
#
# 그러면 사장님이 본 건 그 **다음**이다: 전투가 시작되는 순간과, 첫 몹이 영웅을
# 중앙에서 끌어내는 데 걸리는 시간. 그걸 잰다.

func _init() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.stage = 1
	scene._restart_stage("측정")

	for round_i in 2:
		# 전투 시작을 기다린다
		while scene._phase != "fight":
			await process_frame
		var at_fight: float = scene.hero_x
		# 중앙을 10px 넘게 벗어나는 첫 순간
		var t := 0.0
		var left := -1.0
		var far := 0.0
		while t < 6.0 and scene._phase == "fight":
			await process_frame
			t += scene.get_process_delta_time()
			var d: float = absf(scene.hero_x - scene.HERO_X)
			far = maxf(far, d)
			if left < 0.0 and d > 10.0:
				left = t
		print("전투 시작    hero_x %.1f  (중앙 %.0f 에서 %+.1f)"
			% [at_fight, scene.HERO_X, at_fight - scene.HERO_X])
		print("   중앙 이탈  %.2f 초 뒤 (10px 초과)   6초간 최대 이탈 %.0f px"
			% [left, far])
		# 다음 구간까지 흘려보낸다
		var stage0: int = scene.stage
		var wait := 0.0
		while scene.stage == stage0 and wait < 90.0:
			await process_frame
			wait += scene.get_process_delta_time()
		while scene._fade_t > 0.0:
			await process_frame
	print("StartPosCheck OK")
	quit()
