extends SceneTree

# 혈맹(PactDefs) + 계약의 제단을 잰다.
#   1) 표 — 별·보너스가 단조증가하고 만렙에서 멈춘다, 비용이 오른다
#   2) 예산 — 만렙 보너스가 합연산 풀 상한(+600%) 안이다. 넘으면 혈맥 곱연산
#      예산표(EXPANSION 8장)가 무의미해진다
#   3) 배선 — 레벨업이 공격·체력에 실제로 실린다, 인장이 없으면 안 오른다
#   4) 제단 — 본편 40구간 잠금, 격파 보상이 인장으로 들어온다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	var cap := PactDefs.level_cap()
	assert(cap == PactDefs.STAR_EVERY * PactDefs.STAR_MAX)
	assert(PactDefs.stars(0) == 0 and PactDefs.stars(49) == 0)
	assert(PactDefs.stars(50) == 1 and PactDefs.stars(cap) == PactDefs.STAR_MAX)
	assert(PactDefs.stars(cap + 999) == PactDefs.STAR_MAX, "별이 만렙에서 안 멈춘다")
	var prev_b := -1.0
	var prev_c := -1.0
	for lv in range(0, cap + 1):
		var b := PactDefs.bonus(lv)
		assert(b >= prev_b, "%d레벨에서 보너스가 내려갔다" % lv)
		prev_b = b
		var c := PactDefs.cost(lv)
		assert(c > prev_c, "%d레벨에서 비용이 안 올랐다" % lv)
		prev_c = c
	assert(is_equal_approx(PactDefs.bonus(cap + 999), PactDefs.bonus(cap)),
		"보너스가 만렙에서 안 멈춘다")
	# 2) 예산 — 만렙이 합연산 풀 상한 안인가.
	assert(PactDefs.bonus(cap) <= 6.0,
		"혈맹 만렙 +%d%% — 합연산 풀 상한(+600%%)을 넘었다" % int(PactDefs.bonus(cap) * 100.0))

	# ── 3~4) 씬 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# 결백성 — 지난 실행의 저장본 값을 되돌린다.
	scene.stage = 45
	scene.best_stage = 100
	scene.pact_lv = 0
	scene.sigil = 0.0
	scene.raid_best = {"blood": 0, "essence": 0, "pact": 0}
	scene.raid_left = {}
	scene.raid_date = ""
	scene._restart_stage("측정")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame

	# 인장이 없으면 안 오른다.
	scene._pact_up(1)
	assert(scene.pact_lv == 0, "인장 없이 혈맹이 올랐다")
	# 오르면 공격·체력에 실린다.
	var dmg0: float = scene.damage()
	var hp0: float = scene.max_hp()
	scene.sigil = 1.0e6
	scene._pact_up(10)
	assert(scene.pact_lv == 10, "혈맹이 10레벨이 안 됐다: %d" % scene.pact_lv)
	assert(scene.sigil < 1.0e6, "인장을 안 썼다")
	assert(scene.damage() > dmg0, "혈맹이 공격력에 안 실린다")
	assert(scene.max_hp() > hp0, "혈맹이 체력에 안 실린다")
	# 상한 — 넘겨 사도 만렙에서 멈추고, 만렙이면 더 안 산다.
	scene.pact_lv = cap - 3
	var before: float = scene.sigil
	scene._pact_up(10)
	assert(scene.pact_lv == cap, "상한을 안 지킨다: %d" % scene.pact_lv)
	var spent: float = before - scene.sigil
	assert(spent > 0.0 and spent <= 3.0 * PactDefs.cost(cap),
		"상한 걸친 묶음이 닿을 만큼보다 많이 받았다: %f" % spent)
	before = scene.sigil
	scene._pact_up(1)
	assert(is_equal_approx(scene.sigil, before), "만렙인데 값을 받았다")

	# 제단 — 문턱 전에는 못 들어간다. **숫자를 박지 않는다**(해금 계단이 움직인다).
	scene.pact_lv = 0
	var gate := RaidDefs.open_stage("pact")
	scene.best_stage = gate - 1
	scene._raid_enter("pact")
	assert(scene.raid_on == "", "문턱 전인데 제단에 들어갔다")
	scene.best_stage = gate + 5
	scene._raid_enter("pact")
	assert(scene.raid_on == "pact", "제단 입장이 안 됐다")
	# 격파 — 인장이 들어온다.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var sig0: float = scene.sigil
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	var waited := 0.0
	while scene._fade_t > 0.0 and waited < 5.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(scene.raid_on == "", "격파했는데 본편으로 안 나왔다")
	assert(scene.sigil - sig0 >= RaidDefs.reward("pact", 1),
		"인장이 안 들어왔다: +%f" % (scene.sigil - sig0))
	assert(int(scene.raid_best["pact"]) == 1, "제단 도전 단계가 안 올랐다")

	print("PactCheck OK")
	quit()
