extends SceneTree

# 주간 보스(EventDefs)를 잰다. 이 기능의 핵심은 **못 죽여도 성과가 남는다** 이므로
# 그 두 갈래를 다 짚는다:
#   1) 표 — 이정표가 단조증가, 보상 종류가 지갑에 있는 것, 보스 순환이 도는가
#   2) 도전 횟수 — 하루 3번에서 줄고, 0이면 못 들어간다
#   3) 누적 — 넣은 피해가 그 주 기록에 쌓이고, 이탈해도 남는다
#   4) 이정표 — 넘기 전엔 못 받고, 넘으면 재화가 들어오고, 두 번은 못 받는다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	assert(EventDefs.BOSSES.size() >= 2, "보스가 하나뿐이면 주간이 아니다")
	var prev := 0.0
	for i in EventDefs.MILESTONES.size():
		var m: Dictionary = EventDefs.MILESTONES[i]
		assert(float(m["need"]) > prev, "이정표 %d 가 안 오른다" % i)
		prev = float(m["need"])
		# 지급은 Main._grant_reward 한 곳이 한다 — QuestCheck 의 그 목록과 같은 이유로
		# 여기 이름이 있는데 거기 없으면 조용히 안 들어온다.
		assert(str(m["reward"]) in ["gem", "crystal", "sigil", "essence", "gold"]
			or TicketDefs.kind_of(str(m["reward"])) != "",
			"모르는 보상 종류: %s" % str(m["reward"]))
		assert(int(m["amount"]) > 0)
	# 순환 — 주가 바뀌면 다음 보스, 한 바퀴 돌면 처음으로.
	var n := EventDefs.BOSSES.size()
	assert(EventDefs.boss_of(0)["name"] != EventDefs.boss_of(1)["name"])
	assert(EventDefs.boss_of(0)["name"] == EventDefs.boss_of(n)["name"],
		"보스 순환이 안 돈다")
	# 보스 체력은 한 판에 못 눕히는 규모여야 한다(그게 이 모드의 전제다).
	assert(EventDefs.boss_hp(100.0) > 100.0 * EventDefs.TIME_LIMIT * 5.0,
		"보스가 한 판에 죽는다 — 누적형이 아니다")

	# ── 2~4) 씬 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# 결백성 — 지난 실행 값 되돌리기.
	scene.stage = 45
	scene.best_stage = 45
	scene.boss_dmg = 0.0
	scene.boss_got = {}
	scene.boss_date = ""
	scene.boss_week = ""
	scene.raid_on = ""
	scene.gem = 0.0
	scene._boss_roll()
	scene._restart_stage("측정")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var home_stage: int = scene.stage
	assert(scene.boss_tries == EventDefs.TRIES_PER_DAY, "새 날인데 도전이 안 찼다")

	# 도전 — 횟수가 줄고 래퍼가 갈린다.
	scene._boss_enter()
	assert(scene.raid_on == "boss", "보스 도전 입장이 안 됐다")
	assert(scene.boss_tries == EventDefs.TRIES_PER_DAY - 1, "도전 횟수가 안 줄었다")
	assert(scene.stage == home_stage, "입장이 본편 stage 를 건드렸다")
	assert(scene._c_is_boss(), "보스 판정이 안 뜬다")
	assert(scene._c_kills_needed() == 1)
	assert(is_equal_approx(scene._c_time_limit(), EventDefs.TIME_LIMIT))

	# 누적 — 피해가 그 주 기록에 쌓인다.
	var snap: float = scene._boss_dps_snap
	assert(snap > 0.0, "화력 스냅이 0이다")
	var need0 := EventDefs.milestone_damage(0, snap)
	scene.on_foe_hit(null, need0 * 0.5)
	assert(scene.boss_dmg > 0.0, "피해가 안 쌓인다")
	# 이정표 — 아직 못 받는다.
	scene._claim_milestone(0)
	assert(not scene.boss_got.has(0), "이정표를 미리 받았다")
	# 넘기면 받는다.
	scene.on_foe_hit(null, need0)
	var gem0: float = scene.gem
	scene._claim_milestone(0)
	assert(scene.boss_got.has(0), "이정표를 못 받았다")
	assert(scene.gem > gem0, "이정표 보상이 안 들어왔다")
	# 두 번은 못 받는다.
	var gem1: float = scene.gem
	scene._claim_milestone(0)
	assert(is_equal_approx(scene.gem, gem1), "이정표를 두 번 받았다")

	# 이탈 — 성과는 남고 본편 그 자리로.
	# **암전 꼬리까지 기다린다.** 입장이 건 페이드가 도는 중에는 이탈이 조용히
	# 빠진다(반쪽 상태 방지 가드) — 게임에선 맞는 가드고 테스트가 기다릴 몫이다.
	while scene._fade_t > 0.0:
		await process_frame
	var dmg_keep: float = scene.boss_dmg
	scene._boss_exit("측정 종료")
	assert(scene.raid_on == "", "이탈이 안 됐다")
	assert(is_equal_approx(scene.boss_dmg, dmg_keep), "이탈에 누적이 날아갔다")
	assert(scene.stage == home_stage, "이탈이 본편 stage 를 건드렸다")
	assert(scene._c_kills_needed() == StageDefs.kills_needed(home_stage),
		"래퍼가 본편으로 안 돌아왔다")

	# 도전 0회 — 못 들어간다.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene.boss_tries = 0
	scene._boss_enter()
	assert(scene.raid_on == "", "도전 횟수가 0인데 들어갔다")

	# ── 단계 (사장님 2026-08-13) ───────────────────────────────────────────
	# 재화 던전이 격파마다 세지듯 주간 보스도 이정표 넷을 다 받으면 다음 단계다.
	assert(is_equal_approx(EventDefs.tier_mult(1), 1.0), "1단계에 배수가 붙었다")
	var prev_m := 0.0
	for t in range(1, 12):
		var m := EventDefs.tier_mult(t)
		assert(m > prev_m, "%d단계에서 배수가 안 올랐다" % t)
		prev_m = m
	# 요구와 보상이 **같이** 올라야 한다 — 요구만 오르면 단계를 올릴 이유가 없다.
	for i in EventDefs.MILESTONES.size():
		assert(EventDefs.milestone_damage(i, 100.0, 3)
			> EventDefs.milestone_damage(i, 100.0, 1), "%d차 요구가 안 올랐다" % i)
		assert(EventDefs.milestone_amount(i, 3)
			> EventDefs.milestone_amount(i, 1), "%d차 보상이 안 올랐다" % i)
	assert(EventDefs.boss_hp(100.0, 3) > EventDefs.boss_hp(100.0, 1),
		"단계가 올랐는데 보스 체력이 그대로다")
	# 초상화 — 판이 이걸 건다. 없으면 빈 액자가 뜬다.
	for b in EventDefs.BOSSES:
		assert(FileAccess.file_exists(EventDefs.art_path(b)),
			"%s 초상화가 없다: %s" % [str(b["name"]), EventDefs.art_path(b)])

	print("EventCheck OK")
	quit()
