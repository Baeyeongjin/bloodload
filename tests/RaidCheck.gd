extends SceneTree

# 재화 던전(RaidDefs)을 잰다. 지키는 것 넷:
#   1) 표 — 등가 구간이 단조증가·상한, 보상이 양수·단조증가
#   2) 래퍼 3분기 — raid_on 이면 던전 값, 나오면 본편 값 그대로
#   3) 입장권 — 하루 한 장: 입장에서 소모, 겹입장 금지, 같은 날 재입장 금지
#   4) 격파 — 뭉치 지급 + 도전 단계 상승 + 본편 복귀 (stage 불변)
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	var prev_eq := 0
	for n in range(1, 200):
		var eq := RaidDefs.eq_stage(n, "blood")
		assert(eq >= prev_eq, "%d단계 등가 구간이 내려간다" % n)
		assert(eq <= StageDefs.total_stages(), "%d단계가 본편 밖이다" % n)
		prev_eq = eq
	for kind in ["blood", "essence"]:
		var prev_r := 0.0
		for n in range(1, 50):
			var r := RaidDefs.reward(kind, n)
			assert(r > 0.0 and r >= prev_r,
				"%s %d단계 보상이 줄었다: %f -> %f" % [kind, n, prev_r, r])
			prev_r = r
		assert(FileAccess.file_exists(str(RaidDefs.RAIDS[kind]["icon"])),
			"%s 아이콘 파일이 없다" % kind)

	# ── 2~4) 씬 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# **결백성** — 지난 실행의 저장본 값을 전부 0으로 되돌린다.
	scene.stage = 25
	scene.best_stage = 25
	scene.raid_best = {"blood": 0, "essence": 0, "pact": 0}
	scene.raid_left = {}
	scene.raid_date = ""
	# 구독도 지운다 — 혈세는 하루 표를 +1 하므로, 앞선 IapCheck 가 남긴 저장본을
	# 물려받으면 이 검사가 재는 값이 조용히 달라진다(실제로 그렇게 깨졌다).
	scene.iap_subs = {}
	scene._restart_stage("측정")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var home_stage: int = scene.stage

	scene._raid_enter("blood")
	assert(scene.raid_on == "blood", "입장이 안 됐다")
	assert(scene._raid_left("blood") == RaidDefs.TRIES_PER_DAY,
		"입장에서 표가 깎였다 — 표는 격파에만 깎인다")
	assert(scene.stage == home_stage, "입장이 본편 stage 를 건드렸다")
	# 겹입장 금지 — 표도 안 쓴다.
	scene._raid_enter("essence")
	assert(scene.raid_on == "blood", "던전 안에서 다른 던전에 들어갔다")
	# 래퍼가 던전 값으로 갈렸는가.
	# 목표가 **던전마다 다르다**(2026-08-14) — 상수를 박지 말고 표를 읽는다.
	assert(scene._c_kills_needed() == RaidDefs.kills_needed("blood"))
	assert(is_equal_approx(scene._c_time_limit(), RaidDefs.time_limit("blood")))
	assert(is_equal_approx(scene._c_enemy_power(),
		StageDefs.enemy_power(RaidDefs.eq_stage(1, "blood"))), "몹 세기가 등가 구간 값이 아니다")
	assert("혈액의 동굴" in scene._c_label())
	assert(not scene._c_is_boss(), "재화 던전에 보스 판정이 떴다")
	assert(is_equal_approx(scene._c_gold_per_kill(),
		StageDefs.gold_per_kill(home_stage)), "던전 킬 혈액이 본편 시세가 아니다")

	# 격파 — 암전 꼬리까지 기다렸다가 처치 수를 채운다.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	var gold_before: float = scene.gold
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	var waited := 0.0
	while scene._fade_t > 0.0 and waited < 5.0:
		await process_frame
		waited += scene.get_process_delta_time()
	assert(scene.raid_on == "", "격파했는데 본편으로 안 나왔다")
	assert(int(scene.raid_best["blood"]) == 1, "도전 단계가 안 올랐다")
	assert(scene.stage == home_stage, "격파가 본편 stage 를 건드렸다")
	# **근사로 견준다** — 수입 곡선이 지수가 되면서 마지막 자리에서 갈린다
	# (실측: 3196.816 vs 3197.0). 여기서 보려는 건 "뭉치가 들어왔는가"이지
	# 소수점이 아니다.
	assert(scene.gold - gold_before >= RaidDefs.reward("blood", 1) * 0.99,
		"격파 뭉치가 안 들어왔다: +%f" % (scene.gold - gold_before))
	# 래퍼가 본편으로 돌아왔는가.
	assert(scene._c_kills_needed() == StageDefs.kills_needed(home_stage))
	# 같은 날 재입장 금지.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	# 격파했으니 표가 하나 깎였다 — 아직 남았으니 또 들어갈 수 있다.
	assert(scene._raid_left("blood") == RaidDefs.TRIES_PER_DAY - 1,
		"격파했는데 표가 안 깎였다: %d" % scene._raid_left("blood"))
	scene._raid_enter("blood")
	assert(scene.raid_on == "blood", "표가 남았는데 못 들어갔다")
	# 입장이 건 페이드가 도는 중에는 이탈이 조용히 빠진다(반쪽 상태 방지 가드).
	while scene._fade_t > 0.0:
		await process_frame
	scene._raid_exit("측정")
	assert(scene.raid_on == "", "이탈이 안 됐다")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	# 실패로 나온 판은 표를 안 먹는다.
	assert(scene._raid_left("blood") == RaidDefs.TRIES_PER_DAY - 1,
		"실패한 판이 표를 먹었다")
	# 표를 다 쓰면 못 들어간다.
	scene.raid_left["blood"] = 0
	scene._raid_enter("blood")
	assert(scene.raid_on == "", "표가 0인데 들어갔다")

	# ── 던전별 목표 (사장님 2026-08-14: 테마가 달라야 한다) ────────────────
	# 셋이 **서로 다른 방법으로** 끝나야 한다 — 같으면 이름만 다른 판이 셋이다.
	var goals := {}
	for k in RaidDefs.RAIDS:
		goals[RaidDefs.goal(str(k))] = true
		assert(RaidDefs.goal_line(str(k)) != "", "%s 목표 문구가 없다" % k)
	assert(goals.size() == 3, "던전 목표가 안 갈렸다: %d" % goals.size())
	# 버티기는 처치가 판정이 아니고(0), 시계가 더 길다.
	assert(RaidDefs.kills_needed("pact") == 0, "버티기에 처치 목표가 있다")
	assert(RaidDefs.time_limit("pact") > RaidDefs.time_limit("blood"),
		"버티기 시간이 안 길다")
	# 단일 강적은 한 마리인 대신 두껍다 — 물량과 총량이 비슷해야 공짜가 안 된다.
	assert(RaidDefs.kills_needed("essence") == 1, "단일 강적이 한 마리가 아니다")
	# 물량 판의 몹은 **잡졸**이다(2026-08-20, 100마리/60초로 바꾸면서). 본편 몹
	# 그대로면 100마리에 75초가 걸려 시계 안에 못 든다 — 얇은 게 이 판의 정체다.
	assert(RaidDefs.hp_mult("blood") < 1.0, "물량 몹이 잡졸이 아니다")
	assert(is_equal_approx(RaidDefs.hp_mult("blood"), RaidDefs.hp_mult("hunt")),
		"물량 판 둘의 몹 두께가 다르다")
	# 수호자 한 마리 == 잡졸 SWARM_KILLS 마리. 둘이 어긋나면 한쪽이 공짜가 된다.
	#
	# **단위를 맞춰서 잰다.** 수호자는 보스 판정을 받아 FoeTiers 배수가 이미
	# 곱해지므로 hp_mult 만 보면 1보다 작다 — 그걸 "안 두껍다"로 읽으면
	# 630배짜리 못 잡는 판을 통과시킨다(실제 사고). 그렇다고 배수를 물량 판의
	# **마리 수**와 견주면 이번엔 반대로 틀린다: 왼쪽은 본편 몹 단위(25)고
	# 오른쪽은 잡졸 마리(100)다. 양쪽 다 잡졸 몫으로 환산해서 잰다.
	var guard := RaidDefs.hp_mult("essence") * FoeTiers.BOSS_HP_MULT
	assert(is_equal_approx(guard,
		RaidDefs.SLAY_WAVE_WORTH * RaidDefs.SWARM_HP_MULT),
		"수호자가 잡졸 %d마리 몫이 아니다: %.1f (기대 %.1f)"
		% [int(RaidDefs.SLAY_WAVE_WORTH), guard,
		RaidDefs.SLAY_WAVE_WORTH * RaidDefs.SWARM_HP_MULT])
	assert(guard <= float(RaidDefs.kills_needed("blood")) * 2.0,
		"수호자가 웨이브 몫보다 지나치게 두껍다: %.1f" % guard)
	# 성소는 **보스 판정**을 받아야 한 마리로 선다(그래야 웨이브가 안 깔린다).
	scene.raid_on = "essence"
	assert(scene._c_is_boss(), "수호자가 보스 판정을 못 받았다 — 웨이브로 깔린다")
	scene.raid_on = "blood"
	assert(not scene._c_is_boss(), "물량 던전에 보스 판정이 떴다")
	scene.raid_on = ""

	# **버티기는 시간이 다 가면 격파다** — 다른 던전은 그때 빈손으로 나온다.
	scene.raid_left = {"pact": 3}
	scene.raid_date = Time.get_date_string_from_system()
	scene.best_stage = RaidDefs.open_stage("pact")
	scene._raid_enter("pact")
	assert(scene.raid_on == "pact", "제단 입장이 안 됐다")
	while scene._fade_t > 0.0:
		await process_frame
	var sigil_before: float = scene.sigil
	scene._boss_time = 0.01                  # 시계를 끝으로 밀어 놓는다
	scene._tick_boss_timer(0.02)
	var w2 := 0.0
	while scene._fade_t > 0.0 and w2 < 5.0:
		await process_frame
		w2 += scene.get_process_delta_time()
	assert(scene.raid_on == "", "버티기가 안 끝났다")
	assert(scene.sigil > sigil_before, "끝까지 버텼는데 보상이 없다")

	# ── 연속 도전 (사장님 2026-08-14) ──────────────────────────────────────
	# 켜 두면 격파하고 나온 뒤 표가 남아 있는 동안 그 던전에 다시 들어간다.
	scene.best_stage = 100
	scene.raid_left = {"blood": 3}
	scene.raid_date = Time.get_date_string_from_system()
	scene._raid_repeat = true
	scene._raid_enter("blood")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	var w3 := 0.0
	while scene._fade_t > 0.0 and w3 < 5.0:
		await process_frame
		w3 += scene.get_process_delta_time()
	await process_frame
	assert(scene.raid_on == "blood", "연속 도전인데 다시 안 들어갔다")
	# 표가 떨어지면 멈춘다 — 안 그러면 켠 채로 잊었을 때 하루치를 다 태운다.
	# **전투가 설 때까지 기다린다** — 암전 중에 부르면 _advance_stage 가 조용히
	# 빠져서(가드) 격파가 없던 일이 된다.
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	scene.raid_left["blood"] = 0
	scene.kills = scene._c_kills_needed()
	scene._advance_stage()
	var w4 := 0.0
	while scene._fade_t > 0.0 and w4 < 5.0:
		await process_frame
		w4 += scene.get_process_delta_time()
	await process_frame
	assert(scene.raid_on == "", "표가 없는데 연속 도전이 들어갔다")
	scene._raid_repeat = false

	# ── 소탕 (사장님 2026-08-14, 레퍼런스) ─────────────────────────────────
	# 이미 깬 단계를 전투 없이 받는다. 지키는 것 셋:
	scene.raid_on = ""
	scene.raid_left = {"blood": 3}
	scene.raid_date = Time.get_date_string_from_system()
	# 1) **깬 적이 없으면 못 한다** — 소탕이 선행 도전을 건너뛰면 아무도 안 돈다.
	scene.raid_best["blood"] = 0
	var g0: float = scene.gold
	scene._raid_sweep("blood")
	assert(is_equal_approx(scene.gold, g0), "기록도 없는데 소탕이 됐다")
	assert(scene._raid_left("blood") == 3, "실패한 소탕이 표를 먹었다")
	# 2) 기록이 있으면 **그 단계 뭉치**가 그대로 들어오고 표를 한 장 쓴다.
	scene.raid_best["blood"] = 2
	scene._raid_sweep("blood")
	assert(scene.gold - g0 >= RaidDefs.reward("blood", 2) * 0.99,
		"소탕 보상이 안 들어왔다")
	assert(scene._raid_left("blood") == 2, "소탕이 표를 안 먹었다")
	# 3) **단계는 안 오른다** — 소탕이 기록을 밀면 벽이 사라진다.
	assert(int(scene.raid_best["blood"]) == 2, "소탕이 도전 단계를 올렸다")
	# 표가 없으면 못 한다.
	scene.raid_left["blood"] = 0
	var g1: float = scene.gold
	scene._raid_sweep("blood")
	assert(is_equal_approx(scene.gold, g1), "표가 0인데 소탕이 됐다")

	print("RaidCheck OK")
	quit()
