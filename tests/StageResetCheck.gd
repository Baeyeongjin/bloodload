extends SceneTree

# 새 판은 늘 만피로 시작하는가 (사장님 2026-08-12). 갈래가 넷이라 넷 다 짚는다:
#   1) 본편 다음 구간
#   2) 미궁 다음 층
#   3) 재화 던전 격파 후 복귀
#   4) 재시작(쓰러짐·이탈)
# 그리고 **보스 체력이 새 판에서 원상 복구**되는가 — 몹은 판마다 새로 스폰되지만
# 그 규칙이 깨지면 반쯤 깎인 보스가 남는다.
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
	scene.stage = 44          # 45 = 보스 직전
	scene.best_stage = 100
	scene.dungeon_best = 3
	scene.raid_left = {}
	scene.raid_date = ""
	scene._restart_stage("측정")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame

	# ── 1) 본편 다음 구간 ─────────────────────────────────────────────────
	scene.hero_hp = scene.max_hp() * 0.2
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	var waited := 0.0
	while scene._fade_t > 0.0 and waited < 5.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(is_equal_approx(scene.hero_hp, scene.max_hp()),
		"본편 다음 구간에서 체력이 안 찼다: %f / %f" % [scene.hero_hp, scene.max_hp()])
	# 보스 구간(45)이다 — 스폰된 보스가 만피인가.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var boss: Node = null
	for f in scene.get_tree().get_nodes_in_group("foes"):
		boss = f
		break
	assert(boss != null, "보스 구간인데 몹이 없다")
	assert(is_equal_approx(boss.hp, boss.max_hp), "보스가 깎인 채로 나왔다")
	# 보스를 반쯤 깎고 재시작 — 새 보스는 만피여야 한다.
	var was_max: float = boss.max_hp
	boss.hp = was_max * 0.3
	scene._restart_stage("측정 재시작")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var boss2: Node = null
	for f in scene.get_tree().get_nodes_in_group("foes"):
		boss2 = f
		break
	assert(boss2 != null and is_equal_approx(boss2.hp, boss2.max_hp),
		"재시작한 보스가 깎인 채다")
	assert(is_equal_approx(scene.hero_hp, scene.max_hp()), "재시작에서 체력이 안 찼다")

	# ── 2) 미궁 다음 층 ───────────────────────────────────────────────────
	scene._dungeon_enter()
	assert(scene.dungeon_on, "미궁 입장이 안 됐다")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene.hero_hp = scene.max_hp() * 0.2
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	waited = 0.0
	while scene._fade_t > 0.0 and waited < 5.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(is_equal_approx(scene.hero_hp, scene.max_hp()), "미궁 다음 층에서 체력이 안 찼다")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene._dungeon_exit("측정")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame

	# ── 3) 재화 던전 격파 복귀 ────────────────────────────────────────────
	scene._raid_enter("blood")
	assert(scene.raid_on == "blood", "던전 입장이 안 됐다")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene.hero_hp = scene.max_hp() * 0.2
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	waited = 0.0
	while scene._fade_t > 0.0 and waited < 5.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(is_equal_approx(scene.hero_hp, scene.max_hp()), "던전 복귀에서 체력이 안 찼다")

	# ── 보스 몸집 — 30% 작아졌는가 ────────────────────────────────────────
	assert(is_equal_approx(Foe.BOSS_BODY, 0.7), "보스 몸집 배수가 0.7 이 아니다")

	print("StageResetCheck OK")
	quit()
