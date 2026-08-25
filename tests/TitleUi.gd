extends SceneTree

# 칭호 화면이 **실제로 그려지는가**. 표 검사(TitleCheck)와 달리 화면을 띄운다 —
# 2026-08-25 에 칭호 스탯을 gold -> critdmg 로 옮기면서 아이콘 표에 그 키가
# 없어 칭호 탭이 통째로 터졌다(사장님: "칭호누르면 버그 남"). 대괄호 접근은
# 키가 없으면 그 자리에서 죽으므로, 표 하나만 빠져도 화면이 안 뜬다.
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

	# 표에 있는 **모든** 스탯이 이름과 아이콘을 갖췄는가 — 하나라도 빠지면
	# 그 칭호가 목록에 뜨는 순간 화면이 죽는다.
	for t in TitleDefs.TITLES:
		var st := str(t["stat"])
		assert(TitleDefs.stat_name(st) != st,
			"%s: 스탯 이름이 없다(%s)" % [str(t["id"]), st])
		var icon: String = str(scene.TITLE_STAT_ICON.get(st, ""))
		assert(icon != "", "%s: 아이콘 표에 %s 가 없다" % [str(t["id"]), st])
		assert(FileAccess.file_exists("res://assets/ui/%s.png" % icon),
			"%s: 아이콘 파일이 없다(%s)" % [str(t["id"]), icon])

	# 실제로 열어 본다 — 딴 것 없는 상태와 하나 딴 상태 둘 다.
	scene._select_tab("codex")
	scene._codex_set_mode("title")
	await process_frame
	scene._refresh_titles()
	await process_frame
	scene.titles_got[str(TitleDefs.TITLES[0]["id"])] = true
	scene._refresh_titles()
	await process_frame
	assert(scene._title_names.size() > 0, "칭호 줄이 하나도 안 그려졌다")
	print("TitleUi OK")
	quit(0)
