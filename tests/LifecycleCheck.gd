extends SceneTree

# 모바일 수명주기 — 뒤로가기 · 앱 전환 · 나갈 때 저장.
#
# **폰은 껐다 켜는 게 아니라 전환이 기본이다.** 이 셋이 없으면 방치형인데
# "몇 시간 뒤 들어왔더니 아무것도 안 쌓였다"가 되고, 뒤로가기 한 번에 앱이
# 그냥 꺼진다. 저장소에 `_notification` 이 한 곳도 없던 자리다(2026-08-27).
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 0) 트리가 알아서 끄면 안 된다 ────────────────────────────────────
	# **에뮬레이터에서만 나온 것이다.** Godot 은 뒤로가기에서 이 설정이 켜져
	# 있으면 우리 `_notification` 이 무엇을 하든 **트리를 알아서 종료한다**.
	# 기본값이 켜짐이라, 아래 검사가 전부 통과하는데도 실기에서는 앱이 그냥
	# 꺼졌다(2026-08-27, 안드로이드 에뮬레이터에서 확인). 헤드리스로는
	# `_notification` 을 직접 부르므로 이 자동 종료를 안 지난다.
	assert(not bool(ProjectSettings.get_setting(
		"application/config/quit_on_go_back", true)),
		"quit_on_go_back 이 켜져 있다 — 뒤로가기가 우리 처리를 무시하고 앱을 끈다")

	# ── 1) 뒤로가기는 **한 겹씩** 걷는다 ──────────────────────────────────
	# 팝업이 떠 있으면 그것부터. 바로 탭을 닫으면 화면이 하나 밀린 것처럼 읽힌다.
	scene._select_tab("gear")
	scene._info_view.visible = true
	scene._notification(scene.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(not scene._info_view.visible, "뒤로가기가 팝업을 안 닫았다")
	assert(scene._tab == "gear", "팝업만 닫아야 하는데 탭까지 닫았다")

	# 팝업이 없으면 탭을 닫는다.
	scene._notification(scene.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(scene._tab == "home", "뒤로가기가 탭을 안 닫았다: %s" % scene._tab)

	# 사냥터에서는 **바로 안 끈다** — 확인을 띄운다. 방치형에서 실수 한 번에
	# 그날 판이 날아간 것처럼 읽히면 안 된다.
	scene._notification(scene.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(scene._confirm_view.visible,
		"사냥터에서 뒤로가기가 확인 없이 지나갔다 — 앱이 그냥 꺼진다")
	scene._confirm_view.visible = false

	# ── 2) 앱 전환 — 나갈 때 저장하고, 돌아올 때 방치분을 친다 ───────────
	scene.chest_gold = 0.0
	scene.chest_minutes = 0.0
	scene._notification(scene.NOTIFICATION_APPLICATION_PAUSED)
	assert(scene._away_at > 0.0, "나간 시각을 안 적었다")
	# **두 번 나가도 시각은 처음 것이다.** 덮어쓰면 백그라운드에서 알림이
	# 여러 번 올 때마다 방치 시간이 0 으로 리셋된다.
	var first: float = scene._away_at
	scene._notification(scene.NOTIFICATION_APPLICATION_PAUSED)
	assert(is_equal_approx(scene._away_at, first), "나간 시각을 덮어썼다")

	# 두 시간 전에 나간 것으로 꾸며 복귀시킨다.
	scene._away_at = Time.get_unix_time_from_system() - 7200.0
	scene._notification(scene.NOTIFICATION_APPLICATION_RESUMED)
	assert(is_equal_approx(scene._away_at, 0.0), "복귀했는데 나간 시각이 남아 있다")
	assert(scene.chest_gold > 0.0,
		"두 시간 자리를 비웠는데 상자가 비었다 — 전환 복귀에 방치가 안 붙는다")
	assert(scene.chest_minutes > 0.0, "방치 분이 안 쌓였다")

	# ── 3) 짧은 전환은 무시한다 ──────────────────────────────────────────
	# 데스크톱 알트탭이 방치 보상이 되면 안 된다. _grant_offline 이 60초
	# 미만을 스스로 거르므로 여기서 따로 막지 않는다는 것을 못 박는다.
	var g0: float = scene.chest_gold
	scene._notification(scene.NOTIFICATION_APPLICATION_PAUSED)
	scene._away_at = Time.get_unix_time_from_system() - 5.0
	scene._notification(scene.NOTIFICATION_APPLICATION_RESUMED)
	assert(is_equal_approx(scene.chest_gold, g0),
		"5초 전환에 방치 보상이 붙었다 — 알트탭이 수입이 된다")

	print("LifecycleCheck OK  (뒤로가기 3겹 · 전환 복귀 2시간 · 짧은 전환 무시)")
	quit(0)
