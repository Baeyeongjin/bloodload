extends SceneTree

# 이펙트가 **어디에 그려지는가**를 잰다. 사장님: "이펙트들에 위치랑 이런것들이 좀 아쉽네".
# 눈으로는 "뭔가 아쉽다"까지밖에 못 가고, 원인이 셋 중 어느 것인지 안 갈린다:
#   (1) 몸에서 떨어져 허공에 뜬다      -> 이펙트 상자와 표적 잉크 상자가 안 겹친다
#   (2) 절반이 땅 밑에 묻힌다          -> 이펙트 아래끝이 지면선보다 아래
#   (3) 표적을 통째로 가린다           -> 이펙트가 표적보다 훨씬 크고 완전히 덮는다
#
# 이펙트 원본은 64px 을 draw_scale 배로 그리고 **중심 정렬**이다(AnimatedSprite2D).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.stage = 1
	scene._restart_stage("측정")
	while scene._phase != "fight":
		await process_frame

	# 표적 하나를 전열에 세운다
	var t: Foe = null
	for f in scene.get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f) and not f.dying:
			t = f
			break
	if t == null:
		push_error("표적이 없다")
		quit(1)
	var gy: float = float(scene.ground_y)
	var half: float = t.body_half()
	var top: float = gy - half * 2.0        # 표적 머리 대략
	print("")
	print("지면 %.0f · 표적 x %.0f · 잉크 절반 %.0f · 머리 %.0f"
		% [gy, t.position.x, half, top])
	print("영웅 x %.0f · 앵커 %.0f" % [scene.hero_x, scene.HERO_X])
	print("")
	print("%-22s %-7s %-6s %-6s %s" % ["스킬", "fx_y", "배율", "높이", "그려지는 세로 범위 / 판정"])
	print("-".repeat(92))
	for shape in SkillDefs.SHAPE_ORDER:
		for rarity in ["common", "legend"]:
			var key: String = SkillDefs.key_of(shape, rarity)
			var p: Dictionary = SkillDefs.fx_profile(key)
			var frames: Array = Assets.frames("res://assets/anim/%s" % str(p["fx"]))
			if frames.is_empty():
				print("%-22s (프레임 없음: %s)" % [key, str(p["fx"])])
				continue
			var tex: Texture2D = frames[0]
			# 실제 스폰 자리 (Main._resolve_skill 과 같은 식)
			# **실제 코드와 같은 함수로 잰다.** 여기서 식을 베껴 적으면 한쪽만 고쳤을 때
			# 검사가 통과하면서 화면은 어긋난다 — 그게 이 검사를 쓰는 이유다.
			var style := str(p["style"])
			# 바닥 문양(hold)은 **세로만** 길 폭에 맞춰 눌린다. 여기서 x 배율로 높이를
			# 재면 검사는 통과하고 화면은 어긋난다 — 그리기와 같은 함수를 쓴다.
			var sy: float = scene._ground_scale_y(str(p["fx"]), float(p["scale"])) \
				if style == "hold" else float(p["scale"])
			var h: float = float(tex.get_height()) * sy
			var w: float = float(tex.get_width()) * float(p["scale"])
			var body_mid := (gy - float(Grid.SPRITE)) if shape == "ward" 				else (t.position.y - half)
			var cy: float = scene._fx_anchor_y(style, str(p["fx"]), float(p["scale"]),
				body_mid, float(p["y"]))
			var where := "영웅" if shape == "ward" else "표적"
			var y0 := cy - h * 0.5
			var y1 := cy + h * 0.5
			var verdict := ""
			if y1 > gy + 6.0:
				verdict += "땅에 묻힘(%.0f) " % (y1 - gy)
			if y0 > gy - 4.0:
				verdict += "지면 아래에서 시작 "
			if shape != "ward" and y1 < top:
				verdict += "머리 위 허공 "
			if style == "hold":
				# 바닥 문양은 **맞는 놈마다 하나씩** 깔리므로(Main._start_field) 그림
				# 폭으로 판정하지 않는다 — 몇 마리에 닿는지는 tests/AoeCheck 가 잰다.
				# 여기서 볼 것은 **길을 넘는지** 하나다.
				var over: float = (gy - y0) - scene.ROAD_H
				if over > 0.0:
					verdict += "길 %.0fpx 초과 " % over
				verdict += "길 안 %.0f/%.0f " % [gy - y0, scene.ROAD_H]
				assert(over <= 0.0,
					"%s: 바닥 문양이 길(%.0fpx)을 %.0fpx 넘어 나무 구역까지 올라간다"
					% [key, scene.ROAD_H, over])
			elif w > half * 2.0 * 2.5:
				verdict += "표적보다 %.1f배 " % (w / maxf(1.0, half * 2.0))
			print("%-22s %-7.0f %-6.1f %-6.0f %s %.0f~%.0f  %s"
				% [key, float(p["y"]), float(p["scale"]), h, where, y0, y1,
				verdict if verdict != "" else "OK"])

	# ── 바닥에 서는 것은 **어떤 배율에서도** 밑단이 지면선이어야 한다 ──────────
	# 2026-08-10 사장님이 "뜨지 않게"를 네 번 말했다. 그때마다 원인이 달랐고
	# (띄우기 상수 -> 묻기 값 -> BACK 이징 -> 잔상) 전부 "가운데 원점 + 절반 보정"에서
	# 나왔다. 원점을 잉크 아래끝으로 옮겨 보정을 없앴으니, **보정이 되살아나면
	# 여기서 걸린다.** 배율을 흔들어 보는 것이 요점이다 — 밑단이 배율에 안 흔들려야
	# 원점이 제자리에 있다는 뜻이다.
	print("")
	print("바닥에 서는 이펙트 — 배율을 바꿔도 밑단이 지면선인가")
	for key in ["field_uncommon", "field_legend", "strike_legend", "wave_rare"]:
		var p: Dictionary = SkillDefs.fx_profile(key)
		var style := str(p["style"])
		if style != "rise" and style != "fall":
			continue
		# 자산별로 더 묻는 값(FX_SINK)이 있으면 그만큼 내려온 자리가 정답이다 —
		# 흩뿌린 방울이 덩어리 아래까지 그려진 그림에만 붙는다(갈라진 대지).
		var want: float = gy + float(scene.FX_SINK.get(str(p["fx"]), 0.0))
		for mul in [0.5, 1.0, 2.5]:
			var s: float = float(p["scale"]) * mul
			var cy: float = scene._fx_anchor_y(style, str(p["fx"]), s, 0.0, float(p["y"]))
			assert(is_equal_approx(cy, want),
				"%s 배율 %.1f 에서 기준이 흔들렸다: %.1f (기대 %.1f)"
				% [key, s, cy, want])
		print("  %-18s %s  배율 0.5/1.0/2.5 전부 %.0f (지면 %.0f%s)"
			% [key, style, want, gy,
			"" if is_equal_approx(want, gy) else " +묻기 %.0f" % (want - gy)])
	print("")
	quit()
