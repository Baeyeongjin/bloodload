extends SceneTree

# 진행 초기화를 잰다. 지키는 것 둘:
#   1) _wipe_save 가 저장 파일을 실제로 지운다
#   2) 지운 뒤에는 **어떤 저장 호출도 파일을 되살리지 못한다** (_wiped 깃발)
#      — 초기화와 재시작 사이 틈에 갱신 경로 하나가 저장하면 반쪽 초기화가 된다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify). 실저장본에서 돌리면
# 이 테스트가 사장님 저장본을 지운다.

func _init() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	# reload_current_scene 이 조용히 실패하지 않게 현재 씬으로 등록해 둔다.
	current_scene = scene

	# 저장 파일을 만들어 둔다.
	scene.gold = 1234.0
	scene.best_stage = 77
	scene._save_game()
	assert(FileAccess.file_exists(scene.SAVE_PATH), "저장 파일이 안 만들어졌다")

	# 초기화 — 파일이 사라진다.
	scene._wipe_save()
	assert(not FileAccess.file_exists(scene.SAVE_PATH), "초기화했는데 파일이 남았다")

	# 지운 뒤의 저장은 전부 무효여야 한다.
	scene._save_game()
	assert(not FileAccess.file_exists(scene.SAVE_PATH),
		"초기화 뒤 저장이 파일을 되살렸다 — _wiped 깃발이 안 먹는다")

	print("ResetCheck OK")
	quit()
