extends SceneTree

# 이름 변경 — 이 게임의 **유일한 글자 입력**이다. 사람이 친 것과 저장 파일에
# 적힌 것 둘 다 믿지 않는다.
#
# 재는 것:
#   1) 다듬기 — 제어문자·줄바꿈·앞뒤 공백을 걷고 여덟 글자에서 끊는다
#   2) 빈 이름은 거절하고 **판을 안 닫는다** (닫아 버리면 왜 안 바뀌었는지 모른다)
#   3) 기본값 — 이름을 안 지었으면 화면에 기본 이름이 뜬다
#   4) 저장·복원, 그리고 저장본이 더러워도 읽을 때 같은 자로 잰다
#   5) HUD 이름판이 실제로 그 이름을 그린다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var nl := char(10)      # 줄바꿈. 소스에 직접 쓰면 문자열이 끊긴다.

	# ── 1) 다듬기 ──────────────────────────────────────────────────────────
	assert(scene._clean_name("  피의군주  ") == "피의군주", "앞뒤 공백이 안 잘린다")
	assert(scene._clean_name("피의" + nl + "군주") == "피의군주",
		"줄바꿈이 안 걸러진다 — 판이 밀린다")
	assert(scene._clean_name("피의" + char(9) + "군주") == "피의군주", "탭이 안 걸러진다")
	assert(scene._clean_name("가나다라마바사아자차") == "가나다라마바사아",
		"여덟 글자에서 안 끊긴다: %s" % scene._clean_name("가나다라마바사아자차"))
	assert(scene._clean_name("").is_empty(), "빈 문자열이 안 빈다")
	assert(scene._clean_name("     ").is_empty(), "공백만 친 것이 이름이 됐다")
	assert(scene._clean_name(nl + nl).is_empty(), "줄바꿈만 친 것이 이름이 됐다")
	# 여덟 글자째가 공백이면 꼬리가 남으면 안 된다.
	assert(scene._clean_name("일이삼사오육칠 구") == "일이삼사오육칠",
		"자른 꼬리의 공백이 남는다: [%s]" % scene._clean_name("일이삼사오육칠 구"))
	# 영문·숫자·이모지도 여덟 글자다(글자 수지 바이트가 아니다).
	assert(scene._clean_name("abcdefghij") == "abcdefgh", "영문이 여덟에서 안 끊긴다")

	# ── 2) 빈 이름은 거절하고 판을 안 닫는다 ───────────────────────────────
	scene.hero_name = "핏빛왕"
	scene._name_view.visible = true
	scene._name_edit.text = "   "
	scene._name_apply()
	assert(scene._name_view.visible, "빈 이름인데 판이 닫혔다")
	assert(scene.hero_name == "핏빛왕", "빈 이름이 먹었다: %s" % scene.hero_name)
	assert(scene._name_note.text != "", "왜 안 되는지 안 알려 준다")

	# 제대로 적으면 먹고 닫힌다. 다듬은 결과가 칸에도 남는다.
	scene._name_edit.text = "  어둠의공작  "
	scene._name_apply()
	assert(scene.hero_name == "어둠의공작", "이름이 안 바뀌었다: %s" % scene.hero_name)
	assert(not scene._name_view.visible, "확정했는데 판이 안 닫혔다")
	assert(scene._name_edit.text == "어둠의공작", "다듬은 결과가 칸에 안 남는다")

	# ── 3) 기본값 ──────────────────────────────────────────────────────────
	scene.hero_name = ""
	assert(scene._hero_name() == scene.NAME_DEFAULT, "이름이 없는데 기본값이 안 나온다")
	assert(scene._hero_name() != "", "화면에 빈 이름이 나간다")

	# ── 4) 저장·복원 · 더러운 저장본 ───────────────────────────────────────
	scene.hero_name = "혈야의주인"
	scene._save_game()
	scene.hero_name = ""
	scene._load_game()
	assert(scene.hero_name == "혈야의주인", "이름이 저장·복원을 못 넘었다")
	# 저장 파일은 사람이 고칠 수 있다 — 읽을 때도 같은 자로 잰다.
	var cfg := ConfigFile.new()
	cfg.load("user://bloodlord.cfg")
	cfg.set_value("run", "name", "긴" + nl + "이름을아주길게적음")
	cfg.save("user://bloodlord.cfg")
	scene._load_game()
	assert(scene.hero_name.length() <= scene.NAME_MAX,
		"저장본의 긴 이름이 그대로 들어왔다: %s" % scene.hero_name)
	assert(not (nl in scene.hero_name), "저장본의 줄바꿈이 그대로 들어왔다")

	# ── 5) HUD 이름판 ──────────────────────────────────────────────────────
	scene.hero_name = "밤의군주"
	scene._refresh_hud()
	assert(scene._lbl_name != null, "이름판 라벨이 없다")
	assert(scene._lbl_name.text == "밤의군주",
		"이름판이 다른 걸 그린다: %s" % scene._lbl_name.text)
	scene.hero_name = ""
	scene._refresh_hud()
	assert(scene._lbl_name.text == scene.NAME_DEFAULT, "이름판이 비었다")

	print("NameCheck OK")
	quit(0)
