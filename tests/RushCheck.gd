extends SceneTree

# 혈전 회랑 (사장님 픽 2026-09-02) — 하루 한 판, 층마다 본편 보스 재대결.
#   1) 표 성질 — 곡선·이정표·소환권 회전
#   2) 잠금 — 문턱 아래선 안 들어가진다
#   3) 입장 — 판이 서고, "지금 어디인가" 허브가 혈전을 안다
#   4) 층 격파 — 혈액 즉시 지급 + 오늘 판 소모(1층 격파에) + 층 전진
#   5) 이정표 — 보석·소환권
#   6) 종료·하루 1판 — 나가면 그날은 끝
#   7) _c_is_raid 회귀 — "boss·trial 이 아니면 던전"이라는 옛 물음이 죽었는지
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 성질 ────────────────────────────────────────────────────────
	assert(RushDefs.eq_stage(1, 200) == 200 - RushDefs.START_BACK,
		"1층 등가가 틀렸다: %d" % RushDefs.eq_stage(1, 200))
	assert(RushDefs.eq_stage(7, 200) == 200, "7층쯤 본편 최고를 넘어야 한다")
	assert(RushDefs.eq_stage(1, 5) >= 1, "초반 보정이 0 아래로 내려간다")
	assert(not RushDefs.is_milestone(4) and RushDefs.is_milestone(5),
		"이정표 판정이 틀렸다")
	assert(RushDefs.milestone_ticket(5) == "ticket_weapon"
		and RushDefs.milestone_ticket(10) == "ticket_armor"
		and RushDefs.milestone_ticket(25) == "ticket_weapon",
		"소환권 회전이 틀렸다: %s" % RushDefs.milestone_ticket(5))
	assert(RushDefs.gold_reward(1, 100) > 0.0, "층 혈액이 0이다")

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 2) 잠금 ───────────────────────────────────────────────────────────
	scene.best_stage = RushDefs.OPEN_STAGE - 1
	scene.rush_date = ""
	scene._rush_enter()
	assert(scene.raid_on == "", "문턱 아래인데 들어가졌다")

	# ── 3) 입장 + 허브 ────────────────────────────────────────────────────
	# 입장 직후 곧바로 잰다 — process_frame 을 돌리면 자동 전투가 끼어들어
	# rush_floor 를 비결정적으로 진행시킨다(BossRewardCheck 와 같은 함정).
	scene.best_stage = RushDefs.OPEN_STAGE
	scene._fade_t = 0.0
	scene._rush_enter()
	assert(scene.raid_on == "rush", "안 들어가졌다")
	assert(scene.rush_floor == 1, "1층에서 시작해야 한다: %d" % scene.rush_floor)
	assert(scene._c_is_boss(), "혈전이 보스 판이 아니다")
	assert(scene._c_kills_needed() == 1, "한 마리면 끝이어야 한다")
	assert(is_equal_approx(scene._c_time_limit(), RushDefs.TIME_LIMIT),
		"시계가 혈전 것이 아니다")
	assert(scene._c_label() == "혈전 1층", "이름표가 다르다: %s" % scene._c_label())
	assert(not scene._c_is_raid(), "혈전이 재화 던전으로 읽힌다")

	# ── 4) 층 격파 — 혈액 즉시 + 오늘 판 소모 + 층 전진 ──────────────────
	# 상태를 직접 구성해 결정론적으로 잰다(자동 전투 개입 없이).
	scene.raid_on = "rush"
	scene.rush_floor = 1
	scene.rush_best = 0
	scene.rush_date = ""
	scene._fade_t = 0.0
	var gold0: float = scene.gold
	var expect: float = RushDefs.gold_reward(1, scene.best_stage)
	scene._advance_stage()
	assert(scene.gold > gold0, "층 혈액이 안 들어왔다")
	assert(is_equal_approx(scene.gold - gold0, expect),
		"층 혈액 크기가 다르다: %f != %f" % [scene.gold - gold0, expect])
	assert(scene.rush_date == Time.get_date_string_from_system(),
		"1층 격파에 오늘 판이 안 적혔다")
	assert(scene.rush_best == 1, "최고층 기록이 안 남았다")
	assert(scene._clear_view.visible, "격파 배너가 안 떴다")
	# 층 전진은 여운(CLEAR_HOLD) 뒤 finish 콜백이 한다.
	for i in 5000:
		if scene.rush_floor == 2:
			break
		await process_frame
	assert(scene.rush_floor == 2, "다음 층으로 안 갔다: %d" % scene.rush_floor)

	# ── 5) 이정표 — 보석·소환권 ───────────────────────────────────────────
	scene.raid_on = "rush"
	scene.rush_floor = 5
	scene._fade_t = 0.0
	var gem0: float = scene.gem
	var tk0: int = int(scene.tickets.get("weapon", 0))
	scene._advance_stage()
	assert(is_equal_approx(scene.gem - gem0, RushDefs.MILESTONE_GEM),
		"이정표 보석이 안 들어왔다")
	assert(int(scene.tickets.get("weapon", 0)) == tk0 + 1,
		"이정표 소환권이 안 들어왔다")
	assert(scene.rush_best == 5, "최고층이 이정표 층으로 안 올랐다")

	# ── 6) 종료 + 하루 1판 ────────────────────────────────────────────────
	scene.raid_on = "rush"
	scene.rush_floor = 6
	scene._fade_t = 0.0
	scene._rush_exit("쓰러짐")
	assert(scene.raid_on == "", "나갔는데 판이 남아 있다")
	assert(scene.rush_floor == 0, "층 시계가 안 꺼졌다")
	# 오늘 판은 이미 4절에서 썼다(rush_date=오늘) — 다시 못 들어간다.
	scene._fade_t = 0.0
	scene._rush_enter()
	assert(scene.raid_on == "", "하루 한 판인데 또 들어가졌다")

	# ── 7) 소탭 전환 — 눌러서 판이 뜬다 ───────────────────────────────────
	# 렌더 캡처(--autoshot)가 이 환경에서 안 돌아 눈으로 못 봤다. 최소한
	# **누르면 돌아온다**(멈추지 않는다)와 판이 뜬다는 것은 여기서 잰다.
	scene.raid_on = ""
	scene._raid_set_mode("rush")
	assert(scene._rush_panel.visible, "혈전 소탭을 눌렀는데 판이 안 뜬다")
	assert(not scene._trial_panel.visible and not scene._raid_list.visible,
		"혈전 판이 떴는데 다른 판이 같이 남아 있다")
	scene._raid_set_mode("trial")
	assert(not scene._rush_panel.visible, "다른 소탭으로 옮겼는데 혈전 판이 남았다")

	# ── 8) _c_is_raid 회귀 ────────────────────────────────────────────────
	scene.raid_on = "blood"
	assert(scene._c_is_raid(), "재화 던전이 재화 던전이 아니라고 한다")
	scene.raid_on = "trial"
	assert(not scene._c_is_raid(), "시련이 재화 던전으로 읽힌다")
	scene.raid_on = ""

	print("RushCheck OK  (곡선 · 입장 · 층 전진 · 이정표 · 하루 1판 · 가드)")
	quit(0)
