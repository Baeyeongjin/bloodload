extends SceneTree

# 핏방울(일일 수집물) — 스폰·줍기·하루 상한이 실제로 도는지.
func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.drop_date = ""
	scene._drop_roll_day()
	assert(scene.drop_got == 0, "날짜 굴림이 안 됐다")
	scene._drop_spawn()
	assert(scene._drop != null, "방울이 안 떨어졌다")
	var gem0: float = scene.gem
	var gold0: float = scene.gold
	scene._drop_take()
	assert(scene._drop == null, "주웠는데 방울이 남아 있다")
	assert(is_equal_approx(scene.gem, gem0 + scene.DROP_GEM), "보석이 안 들어왔다")
	assert(scene.gold >= gold0, "혈액이 줄었다")
	assert(scene.drop_got == 1, "센 수가 안 올랐다")
	# 하루 상한 — 다 주웠으면 틱이 새 방울을 안 만든다.
	scene.drop_got = scene.DROP_PER_DAY
	scene._drop_t = 0.0
	scene._drop_tick(1.0)
	assert(scene._drop == null, "상한인데 방울이 나왔다")
	print("DropCheck OK")
	quit(0)
