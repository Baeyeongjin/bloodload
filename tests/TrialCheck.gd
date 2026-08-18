extends SceneTree

# 시련 (TrialDefs + Main._trial_*) — 단계 보스 격파 = 영구 공격·체력 %.
#
# 지키는 것 셋:
#   1. **보너스가 실제로 붙는가** — 표만 오르고 dps/max_hp 가 그대로면 뜻이 없다.
#   2. **미궁 잠금이 실제로 막는가** — 층이 모자라면 입장 자체가 안 된다.
#   3. **승리가 정확히 한 계단인가** — _advance_stage 한 번에 +1, 그리고 퇴장.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표 ─────────────────────────────────────────────────────────────────
	assert(is_equal_approx(TrialDefs.mult(0), 1.0), "0격파가 1.0이 아니다")
	assert(TrialDefs.mult(10) > TrialDefs.mult(9), "배수가 안 오른다")
	assert(TrialDefs.floor_need(2) > TrialDefs.floor_need(1), "잠금이 안 오른다")
	assert(TrialDefs.eq_stage(2) > TrialDefs.eq_stage(1), "등가 구간이 안 오른다")
	# 마지막 단계의 잠금이 미궁 상한(100층) 안에 있어야 완주가 가능하다.
	assert(TrialDefs.floor_need(TrialDefs.max_stage()) <= 100,
		"완주 잠금이 미궁 상한을 넘는다")

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.trial_stage = 0
	var dps0: float = scene.dps()
	var hp0: float = scene.max_hp()
	scene.trial_stage = 10
	assert(absf(scene.dps() / dps0 - TrialDefs.mult(10)) < 0.02,
		"공격에 시련 배수가 안 붙는다: x%.3f" % (scene.dps() / dps0))
	assert(absf(scene.max_hp() / hp0 - TrialDefs.mult(10)) < 0.02,
		"체력에 시련 배수가 안 붙는다: x%.3f" % (scene.max_hp() / hp0))
	scene.trial_stage = 0

	# 미궁 잠금 — 층이 모자라면 입장이 안 된다.
	scene.raid_on = ""
	scene.dungeon_on = false
	scene.dungeon_best = TrialDefs.floor_need(1) - 1
	scene._trial_enter()
	assert(scene.raid_on == "", "잠긴 시련에 들어갔다")
	scene.dungeon_best = TrialDefs.floor_need(1)
	scene._trial_enter()
	assert(scene.raid_on == "trial", "열린 시련에 못 들어간다")
	while scene._fade_t > 0.0:      # 입장 암전 — 실전에서도 이 뒤에야 싸운다
		await process_frame

	# 승리 — 정확히 한 계단, 그리고 본편으로.
	scene._advance_stage()
	assert(scene.trial_stage == 1, "격파가 한 계단이 아니다: %d" % scene.trial_stage)
	assert(scene.raid_on == "", "격파 뒤에도 시련에 남아 있다")

	# 중단 — 잃는 것 없이 나온다.
	while scene._fade_t > 0.0:      # 격파 퇴장 암전
		await process_frame
	scene.dungeon_best = TrialDefs.floor_need(2)
	scene._trial_enter()
	assert(scene.raid_on == "trial", "2단계에 못 들어간다")
	while scene._fade_t > 0.0:
		await process_frame
	scene._trial_exit("검사 중단")
	assert(scene.raid_on == "" and scene.trial_stage == 1,
		"중단이 단계를 건드렸다")

	print("TrialCheck OK")
	quit(0)
