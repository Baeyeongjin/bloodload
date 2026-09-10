extends "res://tests/FunLoopCheck.gd"

# Reuses isolated-profile guards and the production gameplay/UI checks.
const NOTICE_OUTPUT := "res://build/qa/notice-polish"


func _capture_enabled() -> bool:
	return true


func _capture(label: String) -> bool:
	if label == "home-boss-record":
		assert(is_equal_approx(game.ground_y, game.VIEW_BOTTOM - float(Grid.BG_SRC.y) * 2.0
			+ float(StageDefs.GROUND_ROW) * 2.0 + 6.0))
		await _shot("ground-contact")
		return true
	game._preset_view.hide()
	for notice in [
		["던전 클리어", "붉은 사냥터 25단계\n혈액 +12.4k\n처치 120 · 추가 보상 +50%", "dungeon-clear"],
		["미궁 돌파", "핏빛 미궁 12층 격파", "maze-clear"],
		["돌파!", "첫 격파 — 보석 +30 · 무기권 +1\n군림 — 새로운 성장 한계가 열렸습니다\n유물 수집과 새로운 던전이 열렸습니다", "unlock"],
		["사냥 편성 적용", "보유 스킬 6개 장착 · 현재 쿨다운은 유지됩니다", "loadout"]]:
		game._show_clear(notice[0], notice[1])
		await _shot(notice[2])
		_check_notice()
	game._show_clear("이전 알림", "한 줄 알림")
	await create_timer(0.35).timeout
	game._show_clear("새 알림", "보상 획득\n새로운 성장 목표가 열렸습니다\n전투를 계속합니다")
	await create_timer(1.65).timeout
	assert(game._clear_view.visible and game._clear_title.text == "새 알림",
		"Previous notification hid the replacement")
	await create_timer(1.5).timeout
	assert(not game._clear_view.visible, "Notification did not finish")
	# Failure/abandonment must not falsely say that the trial was cleared.
	game.raid_on = "trial"
	game._fade_t = 0.0
	game._trial_exit("도전 중단")
	assert(game._clear_title.text == "도전 종료")
	await _shot("challenge-end")
	assert(not game.has_method("_reforge_selected"))
	assert(Type.font().resource_path == Type.PATH)
	print("NoticePreview OK: original art/font, wrapped text bounds, replacement lifetime, trial exit, lowered ground, reforge removed")
	return true


func _check_notice() -> void:
	assert(game._clear_view.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(game._clear_sub.get_line_count() * Type.font().get_height(Type.SIZE_MID)
		<= game._clear_sub.size.y + 1.0, "Notice text clips vertically")
	assert(game._clear_sub.position.y + game._clear_sub.size.y <= game._clear_card.size.y - 20.0)
	assert(game._clear_card.position.y >= 0.0 and game._clear_card.get_global_rect().end.y < 800.0)
	assert(game._clear_plate.texture.resource_path == "res://assets/ui/band_power.png")
	assert(game._clear_crest.texture.resource_path == "res://assets/ui/reward_crest.png")
	assert(game._clear_card.scale.is_equal_approx(Vector2.ONE))
	assert(game._clear_card.modulate.a > 0.99)


func _shot(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NOTICE_OUTPUT))
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(NOTICE_OUTPUT + "/" + label + ".png") == OK)
