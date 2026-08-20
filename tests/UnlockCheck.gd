extends SceneTree

# 성장 창의 잠금 표시가 **실제 씬에서** 무엇을 보여 주는지 찍는다. 순수 함수 검사는
# BalanceTest 가 하지만, `lv` 를 안 넘긴 호출부가 남아 있으면 여기서만 드러난다.

func _init() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	for step in [[1, {}], [1, {"damage": 5}], [1, {"damage": 5, "tough": 5}],
			[6, {"damage": 5, "tough": 5, "speed": 10, "crit": 5}],
			[6, {"damage": 5, "tough": 20, "speed": 10, "crit": 5}]]:
		var major: int = int(step[0])
		scene.stage = (major - 1) * StageDefs.STEPS_PER_STAGE + 1
		scene.lv = (step[1] as Dictionary).duplicate()
		scene._refresh_growth()
		await process_frame
		var open: Array = []
		var shut: Array = []
		for s in StatDefs.STATS:
			var key := str(s["key"])
			var row: Dictionary = scene._stat_rows[key]
			if bool(row["btn"].visible):
				open.append(str(s["name"]))
			else:
				shut.append("%s(%s)" % [str(s["name"]), str(row["lock"].text)])
		print("%d단계 %-42s" % [major, str(step[1])])
		print("   열림 %s" % ", ".join(open))
		print("   잠김 %s" % ", ".join(shut))

	# 맨 처음 상태에서 공격력·흡혈량이 열려 있어야 게임이 시작된다.
	scene.stage = 1
	scene.lv = {}
	scene._refresh_growth()
	await process_frame
	assert(bool(scene._stat_rows["damage"]["btn"].visible), "공격력이 처음부터 안 열린다")
	assert(not bool(scene._stat_rows["tough"]["btn"].visible), "체력이 선행 없이 열렸다")
	assert(str(scene._stat_rows["tough"]["lock"].text).contains("공격력"),
		"체력 잠금이 선행을 안 알려 준다: %s" % str(scene._stat_rows["tough"]["lock"].text))
	# 선행을 채우면 같은 단계에서 바로 열려야 한다(스테이지를 안 넘겨도).
	scene.lv = {"damage": 60}   # 15분할 문턱(딱 떨어지는 수로 끊었다)
	scene._refresh_growth()
	await process_frame
	assert(bool(scene._stat_rows["tough"]["btn"].visible),
		"공격력 Lv5 인데 체력이 안 열린다: %s" % str(scene._stat_rows["tough"]["lock"].text))
	# 단계가 모자라면 **단계**를 보여 줘야 한다 — 선행을 채워도 안 열리니까.
	scene.lv = {"damage": 5, "tough": 5, "speed": 10, "crit": 5}
	scene._refresh_growth()
	await process_frame
	assert(str(scene._stat_rows["crit"]["lock"].text).contains("단계"),
		"단계가 모자란데 선행을 시킨다: %s" % str(scene._stat_rows["crit"]["lock"].text))
	print("UnlockCheck OK")
	quit()
