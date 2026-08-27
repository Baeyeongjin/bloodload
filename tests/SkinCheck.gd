extends SceneTree

# 의상실 — 표 무결성(그림 존재)·구매·장착·보유 효과가 실제로 도는지.
func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	# **설명이 코드와 갈리면 안 된다.** 핑크빛 군주가 "혈액 +5%" 라고 적혀 있는데
	# 실제 키는 attack 이었다(2026-08-27, 800 보석짜리다). 돈 받는 물건의 설명은
	# 사람이 눈으로 대조할 게 아니라 여기서 걸려야 한다.
	#
	# 규칙: 보너스 키마다 화면에 나가는 이름이 정해져 있고, desc 에는 **그 이름이
	# 그 숫자와 함께** 들어 있어야 한다. 그리고 desc 에 적힌 축 수와 실제 키 수가
	# 같아야 한다 — 하나를 슬쩍 빼먹는 것도 거짓말이다.
	var axis_name := {"attack": "공격", "tough": "체력", "critdmg": "치명 피해"}
	var seen_effect := {}
	for sk in SkinDefs.SKINS:
		var p := "res://assets/anim/%s_idle/0.png" % str(sk["id"])
		assert(FileAccess.file_exists(p), "%s idle 그림이 없다" % sk["id"])
		var b: Dictionary = sk["bonus"]
		var d := str(sk["desc"])
		var axes := 0
		for k in b:
			assert(axis_name.has(str(k)),
				"%s 의 보너스 키 '%s' 를 읽는 곳이 없다 — 팔면 안 되는 효과다"
				% [sk["id"], k])
			var want := "%s +%d%%" % [axis_name[str(k)], int(round(float(b[k]) * 100.0))]
			assert(d.contains(want),
				"%s 설명에 '%s' 가 없다: \"%s\"" % [sk["id"], want, d])
			axes += 1
		# desc 에만 있고 코드엔 없는 축(핑크가 그랬다)을 잡는다.
		for k in axis_name:
			if not b.has(k):
				assert(not d.contains(str(axis_name[k]) + " +"),
					"%s 설명은 '%s' 를 약속하는데 보너스에 그 키가 없다"
					% [sk["id"], axis_name[k]])
		# **둘이 같은 효과면 비싼 쪽은 살 이유가 없다.**
		if axes > 0:
			var sig := ""
			for k in ["attack", "tough", "critdmg"]:
				sig += "%s=%.3f " % [k, float(b.get(k, 0.0))]
			assert(not seen_effect.has(sig),
				"%s 와 %s 의 효과가 똑같다 (%s)" % [sk["id"], seen_effect.get(sig, "?"), sig])
			seen_effect[sig] = str(sk["id"])
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
	assert(scene.skin == "valentino_1", "상점 구매가 장착까지 해 버렸다")
	assert(scene.gem < gem0, "보석이 안 빠졌다")
	# 갈아입기는 외형 판 — 돈을 안 받는다.
	var gem1: float = scene.gem
	scene._outfit_pick("demon_king")
	assert(scene.skin == "demon_king" and is_equal_approx(scene.gem, gem1),
		"외형 변경이 안 되거나 돈을 받았다")
	scene._outfit_pick("pink")
	assert(scene.skin == "demon_king", "미보유 스킨이 장착됐다")
	assert(SkinDefs.bonus("attack", scene.skins_owned) > 0.0, "보유 효과가 없다")
	var poor: float = 10.0
	scene.gem = poor
	scene._wear_click("grim")
	assert(not scene.skins_owned.has("grim") and is_equal_approx(scene.gem, poor),
		"보석이 없는데 팔렸다")
	print("SkinCheck OK")
	quit(0)
