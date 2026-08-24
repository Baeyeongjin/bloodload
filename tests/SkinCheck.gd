extends SceneTree

# 의상실 — 표 무결성(그림 존재)·구매·장착·보유 효과가 실제로 도는지.
func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	for sk in SkinDefs.SKINS:
		var p := "res://assets/anim/%s_idle/0.png" % str(sk["id"])
		assert(FileAccess.file_exists(p), "%s idle 그림이 없다" % sk["id"])
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.gem = 5000.0
	scene.skins_owned = {}
	scene.skin = "valentino_1"
	var gem0: float = scene.gem
	scene._wear_click("demon_king")
	assert(scene.skins_owned.has("demon_king"), "구매가 안 됐다")
	assert(scene.skin == "demon_king", "장착이 안 됐다")
	assert(scene.gem < gem0, "보석이 안 빠졌다")
	var gem1: float = scene.gem
	scene._wear_click("valentino_1")
	assert(scene.skin == "valentino_1" and is_equal_approx(scene.gem, gem1),
		"갈아입기에 돈을 받았다")
	assert(SkinDefs.bonus("attack", scene.skins_owned) > 0.0, "보유 효과가 없다")
	var poor: float = 10.0
	scene.gem = poor
	scene._wear_click("grim")
	assert(not scene.skins_owned.has("grim") and is_equal_approx(scene.gem, poor),
		"보석이 없는데 팔렸다")
	print("SkinCheck OK")
	quit(0)
