extends SceneTree

# 성장 패스(PassDefs + Main._claim_pass). 이 상품의 설계 원칙 셋이 코드에서
# 실제로 지켜지는지 잰다(MONETIZATION_PLAN 5-1):
#   1. **이미 하는 행동에 얹는다** — 점수는 임무를 받을 때만 오른다
#   2. **무료 줄이 있다** — 안 사도 같은 트랙을 오르되 받는 것이 적다
#   3. **유료 줄은 사야 열린다** — 안 샀는데 열리면 파는 물건이 아니다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표 ─────────────────────────────────────────────────────────────────
	assert(PassDefs.STEPS == 30, "단계 수가 바뀌었다")
	assert(PassDefs.step_of(0) == 0, "0점이 1단계다")
	assert(PassDefs.step_of(PassDefs.STEP_POINT) == 1, "한 단계 점수가 안 맞다")
	assert(PassDefs.step_of(PassDefs.STEP_POINT * 999) == PassDefs.STEPS,
		"단계가 상한을 넘는다")
	assert(PassDefs.to_next(0) == PassDefs.STEP_POINT, "남은 점수가 안 맞다")
	# 유료 줄이 무료 줄보다 후해야 파는 물건이 된다.
	var free_gem := 0.0
	for i in range(1, PassDefs.STEPS + 1):
		var r := PassDefs.free_reward(i)
		if str(r["kind"]) == "gem":
			free_gem += float(r["amount"])
	assert(PassDefs.paid_total_gem() > free_gem * 2.0,
		"유료 줄이 무료 줄보다 충분히 후하지 않다")
	# 소환권은 **네 종류를 다** 돌아야 한다 — 한 종류만 주면 나머지 천장이 안 찬다.
	var kinds := {}
	for i in range(1, PassDefs.STEPS + 1):
		var t := TicketDefs.kind_of(str(PassDefs.free_reward(i)["kind"]))
		if t != "":
			kinds[t] = true
	assert(kinds.size() == TicketDefs.KINDS.size(),
		"패스가 소환권 종류를 안 흩는다: %d" % kinds.size())

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.pass_points = 0
	scene.pass_free_got = {}
	scene.pass_paid_got = {}
	scene.iap_subs = {}

	# 1) 점수는 **임무를 받을 때** 오른다.
	var before: int = scene.pass_points
	scene._pass_add(PassDefs.POINT_QUEST)
	assert(scene.pass_points == before + PassDefs.POINT_QUEST, "점수가 안 올랐다")

	# 2) 무료 줄은 안 사도 받는다.
	scene.pass_points = PassDefs.STEP_POINT * 3
	var gem0: float = scene.gem
	scene._claim_pass(1, false)
	assert(scene.gem > gem0, "무료 줄이 안 들어왔다")
	assert(scene.pass_free_got.has(1), "수령 표식이 없다")
	var gem1: float = scene.gem
	scene._claim_pass(1, false)
	assert(is_equal_approx(scene.gem, gem1), "같은 칸을 두 번 줬다")

	# 3) 유료 줄은 **사야** 열린다.
	scene._claim_pass(2, true)
	assert(not scene.pass_paid_got.has(2), "안 샀는데 유료 줄이 열렸다")
	scene._iap_buy("season_pass")
	scene._claim_pass(2, true)
	assert(scene.pass_paid_got.has(2), "샀는데 유료 줄이 안 열렸다")

	# 아직 못 간 단계는 못 받는다.
	scene._claim_pass(PassDefs.STEPS, false)
	assert(not scene.pass_free_got.has(PassDefs.STEPS), "미달 단계를 줬다")

	# 4) 일괄 수령 — 받을 수 있는 것을 한 번에. 남는 게 없어야 한다.
	scene._claim_pass_all()
	var step: int = PassDefs.step_of(scene.pass_points)
	for i in range(1, step + 1):
		assert(scene.pass_free_got.has(i), "%d단계 무료가 남았다" % i)
		assert(scene.pass_paid_got.has(i), "%d단계 유료가 남았다" % i)

	# 5) 저장 — 진행과 수령 이력이 복원된다.
	scene._save_game()
	var pts: int = scene.pass_points
	scene.pass_points = 0
	scene.pass_free_got = {}
	scene.pass_paid_got = {}
	scene._load_game()
	assert(scene.pass_points == pts and scene.pass_free_got.has(1),
		"패스 진행이 복원 안 됐다")

	print("PassCheck OK")
	quit()
