extends SceneTree

# 성장 가이드 표 점검.
#   godot --headless --path . --script tests/GoalTest.gd

func _init() -> void:
	# **안전장치.** Godot 의 assert 는 실패하면 그 자리에서 함수를 멈추는데, 그러면
	# 아래 quit() 에 못 가서 프로세스가 영영 안 끝난다(타임아웃으로 죽여야 했다).
	# 먼저 시계를 걸어 두면 멈춰도 반드시 끝나고, 종료 코드로 실패가 드러난다.
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("테스트가 안 끝났다 — assert 실패로 멈춘 것이다")
		quit(1))
	assert(not GoalDefs.TRACKS.is_empty(), "트랙이 하나도 없다")
	var game = load("res://Main.gd").new()
	var seen := {}
	for t in GoalDefs.TRACKS:
		var kind := str(t["kind"])
		assert(not seen.has(kind), "트랙 kind 가 겹친다: " + kind)
		seen[kind] = true
		# **이 검사가 이 파일의 존재 이유다.** 트랙을 추가하고 Main._goal_value 에
		# 줄을 안 더하면 그 목표는 값이 영원히 0이라 절대 안 깨진다 — 화면에는
		# 멀쩡히 보이므로 눈으로는 못 잡는다.
		assert(game._goal_value(kind) >= 0, "값 조회가 없는 트랙: " + kind)
		assert(FileAccess.file_exists("res://assets/ui/%s.png" % str(t["icon"])),
			"아이콘 없음: " + str(t["icon"]))
		assert(not str(t["name"]).is_empty() and not str(t["unit"]).is_empty(),
			"이름/단위가 비었다: " + kind)

	# 사다리는 **끝없이 오른다.** 어느 단계에서 멈추면 그 뒤로는 목표가 안 바뀐다.
	for t in GoalDefs.TRACKS:
		var kind := str(t["kind"])
		for step in 40:
			var a := GoalDefs.need(kind, step)
			var b := GoalDefs.need(kind, step + 1)
			assert(b > a, "%s 목표가 %d단계에서 안 오른다: %d -> %d" % [kind, step, a, b])
			assert(GoalDefs.gem_reward(kind, step + 1) > GoalDefs.gem_reward(kind, step),
				"%s 보상이 %d단계에서 안 오른다" % [kind, step])

	# 첫 목표는 **금방** 닿아야 한다. 처음 화면에서 아무것도 못 받으면 가이드가
	# 있다는 사실 자체를 모른다.
	assert(GoalDefs.need("stage", 0) <= 5, "첫 단계 목표가 너무 멀다")
	assert(GoalDefs.need("hero_lv", 0) <= 10, "첫 영웅 레벨 목표가 너무 멀다")

	# 보상은 필요값보다 **완만하게** 는다. 같은 비율이면 후반 목표 하나가 소환
	# 수백 회가 되어 초반 보상이 의미를 잃는다.
	var need_ratio := float(GoalDefs.need("kills", 10)) / float(GoalDefs.need("kills", 0))
	var gem_ratio := GoalDefs.gem_reward("kills", 10) / GoalDefs.gem_reward("kills", 0)
	assert(gem_ratio < need_ratio,
		"보상이 목표만큼 가파르다: 목표 x%.0f vs 보상 x%.0f" % [need_ratio, gem_ratio])

	# 가이드는 **한 줄로 이어진다.** 한 바퀴 안에 트랙이 전부 한 번씩 나오고,
	# 바퀴가 돌 때마다 단계가 하나 오른다. 이게 깨지면 같은 목표가 연달아 나오거나
	# 어떤 트랙은 영영 안 나온다 — 화면에는 멀쩡히 보여서 눈으로는 못 잡는다.
	var n_tracks := GoalDefs.TRACKS.size()
	var round_seen := {}
	for i in n_tracks:
		var q := GoalDefs.quest(i)
		round_seen[str(q["kind"])] = true
		assert(int(q["step"]) == 0, "첫 바퀴인데 단계가 0이 아니다: %d" % i)
	assert(round_seen.size() == n_tracks, "한 바퀴에 같은 트랙이 두 번 나온다")
	assert(int(GoalDefs.quest(n_tracks)["step"]) == 1, "두 바퀴째에 단계가 안 올랐다")
	assert(str(GoalDefs.quest(n_tracks)["kind"]) == str(GoalDefs.quest(0)["kind"]),
		"바퀴가 같은 순서로 안 돈다")
	assert(str(GoalDefs.quest(-5)["kind"]) == str(GoalDefs.quest(0)["kind"]),
		"음수 번호가 첫 가이드로 안 접힌다")

	# 수령 — 조건을 넘겼을 때만 되고, 한 번에 하나만 오른다.
	game.goal_index = 0
	game.best_stage = 1
	assert(not game._goal_ready(), "조건도 안 됐는데 받을 수 있다고 한다")
	assert(is_equal_approx(game._claim_goal(), 0.0), "조건도 안 됐는데 보상이 나온다")
	game.best_stage = 99999
	var gem_before: float = game.gem
	assert(game._claim_goal() > 0.0, "조건을 넘겼는데 보상이 안 나온다")
	assert(game.gem > gem_before, "보상을 줬는데 보석이 안 늘었다")
	assert(game.goal_index == 1, "한 번에 여러 개가 올랐다")

	print("가이드 트랙 %d개 · 첫 목표 %s"
		% [n_tracks, GoalDefs.label(str(GoalDefs.quest(0)["kind"]), 0)])
	print("단계 사다리  %s → %s → %s → %s"
		% [GoalDefs.label("kills", 0), GoalDefs.label("kills", 5),
		GoalDefs.label("kills", 10), GoalDefs.label("kills", 20)])
	game.free()
	print("GoalTest OK")
	quit()
