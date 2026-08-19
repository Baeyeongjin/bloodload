extends SceneTree
# 다시 굴리기(연속 _oath_play) 재현 — freed 노드를 만지는 트윈이 있으면
# 여기서 에러가 쏟아진다(사장님 실플레이 보고).


func _init() -> void:
	await process_frame
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.oath_first = true
	scene.oath_cards = 5
	scene.gem = 999.0
	scene._oath_view.visible = true
	scene._oath_play(false)
	for i in 40:
		await process_frame
	scene._oath_play(false)     # 결과 위에서 다시 굴리기와 같은 경로
	for i in 120:
		await process_frame
	print("OathReplay OK")
	quit()
