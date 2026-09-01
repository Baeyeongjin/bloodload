extends SceneTree

# 보스 첫 격파 보상 — 표와 지급, 그리고 **배너가 실제로 뜨는지**.
#
# 왜 배너까지 재나: 보석 보상은 예전부터 있었는데 **조용히 줘서** 받은 줄도
# 몰랐고, 군림 해금 배너는 _offline_banner 삭제(2026-08-27) 때 표시가 통째로
# 유실됐는데 **아무 검사도 그걸 몰랐다.** "알림이 있다"는 것도 검사 대상이다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 성질 ────────────────────────────────────────────────────────
	assert(StageDefs.boss_first_reward(7).is_empty(), "일반 구간인데 보상이 있다")
	assert(StageDefs.boss_first_reward(5).is_empty(), "중간보스 구간인데 보상이 있다")
	var r10: Dictionary = StageDefs.boss_first_reward(10)
	assert(not r10.is_empty() and int(r10["n"]) == 1, "첫 보스 보상이 1장이 아니다")
	# 종류는 대단계마다 돈다 — 넷이 고르게 채워져야 종류별 천장이 다 찬다.
	var kinds := {}
	for m in range(1, 5):
		kinds[str(StageDefs.boss_first_reward(m * 10)["kind"])] = true
	assert(kinds.size() == TicketDefs.KINDS.size(),
		"네 대단계에 종류가 %d 개뿐이다 — 순환이 안 된다" % kinds.size())
	# 장수는 순환이 돌 때마다 +1. (1~10단계 1장 … 41~50단계 5장)
	assert(int(StageDefs.boss_first_reward(110)["n"]) == 2,
		"11단계 보스가 2장이 아니다: %d" % int(StageDefs.boss_first_reward(110)["n"]))
	assert(int(StageDefs.boss_first_reward(500)["n"]) == 5,
		"50단계 보스가 5장이 아니다")
	# 평생 합 — 재화 설계 숫자다. 표를 바꾸면 여기도 의도적으로 바꿔야 한다.
	var total := 0
	for s in range(10, 501, 10):
		total += int(StageDefs.boss_first_reward(s)["n"])
	assert(total == 150, "평생 소환권 합이 150 이 아니다: %d" % total)

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 2) 실제 지급 — 보스 구간을 처음 돌파하면 보석·소환권이 는다 ────────
	# **페이드가 끝나길 기다린다.** _advance_stage 는 페이드 중이면 조용히
	# 튕긴다(_fade_t > 0 가드) — 안 기다리면 이 검사가 시차로 헛돈다.
	# 실제로 헛돌았다: 원복 판에서 5절이 앞 절의 페이드에 먹혔다.
	while scene._fade_t > 0.0:
		await process_frame
	scene.stage = 10
	scene.best_stage = 10
	scene.kills = 999
	scene.gem = 0.0
	scene.tickets = {}
	scene._advance_stage()
	# _advance_stage 는 _fade 콜백 안에서 지급한다 — 페이드가 돌 시간을 준다.
	# 300 프레임 — 페이드 중간점(콜백 시점)이 헤드리스에서 40프레임을 넘는 것을
	# 실측했다(어서트가 콜백보다 먼저 터졌다). 조건이 차면 바로 빠져나간다.
	for i in 300:
		await process_frame
		if scene.best_stage > 10:
			break
	assert(scene.best_stage == 11, "돌파가 안 됐다: %d" % scene.best_stage)
	assert(scene.gem > 0.0, "첫 격파 보석이 안 왔다")
	var kind10 := str(StageDefs.boss_first_reward(10)["kind"])
	assert(int(scene.tickets.get(kind10, 0)) == 1,
		"첫 격파 소환권이 안 왔다: %s" % str(scene.tickets))
	# ── 3) 배너 — 조용히 주면 없는 기능이다 ──────────────────────────────
	assert(scene._clear_view.visible, "첫 격파 배너가 안 떴다")
	assert("첫 격파" in scene._clear_sub.text,
		"배너에 보상 줄이 없다: %s" % scene._clear_sub.text)

	# ── 4) 두 번째는 안 준다 ──────────────────────────────────────────────
	while scene._fade_t > 0.0:
		await process_frame
	scene.stage = 10          # 같은 보스 구간을 다시 돈다 (best 는 이미 11)
	scene.gem = 0.0
	scene.tickets = {}
	scene._advance_stage()
	# 300 프레임 — 페이드 중간점(콜백 시점)이 헤드리스에서 40프레임을 넘는 것을
	# 실측했다(어서트가 콜백보다 먼저 터졌다). 조건이 차면 바로 빠져나간다.
	for i in 300:
		await process_frame
		if scene.stage > 10:
			break
	assert(is_equal_approx(scene.gem, 0.0), "재격파에 보석이 또 왔다")
	assert(scene.tickets.is_empty(), "재격파에 소환권이 또 왔다")

	# ── 5) 군림 배너 유실 회귀 — 해금 문턱을 넘으면 배너에 군림 줄이 있다 ──
	while scene._fade_t > 0.0:
		await process_frame
	scene.stage = 50
	scene.best_stage = 50
	scene._clear_view.visible = false
	scene._advance_stage()
	# 300 프레임 — 페이드 중간점(콜백 시점)이 헤드리스에서 40프레임을 넘는 것을
	# 실측했다(어서트가 콜백보다 먼저 터졌다). 조건이 차면 바로 빠져나간다.
	for i in 300:
		await process_frame
		if scene.best_stage > 50:
			break
	assert(scene._clear_view.visible and "군림" in scene._clear_sub.text,
		"군림 해금 배너가 안 떴다 — _offline_banner 유실이 재발했다: %s"
		% scene._clear_sub.text)

	print("BossRewardCheck OK  (표·지급·배너·재격파 차단·군림 회귀)")
	quit(0)
