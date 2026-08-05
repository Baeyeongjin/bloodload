extends SceneTree

# 성장 가이드 표 점검.
#   godot --headless --path . --script tests/GoalTest.gd

func _init() -> void:
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

	# 수령 — 조건을 넘겼을 때만 되고, 한 번에 한 단계만 오른다.
	game.goal_step = {}
	game.best_stage = 1
	assert(not game._claim_goal("stage"), "조건도 안 됐는데 보상이 나온다")
	game.best_stage = 99999
	var gem_before: float = game.gem
	assert(game._claim_goal("stage"), "조건을 넘겼는데 보상이 안 나온다")
	assert(game.gem > gem_before, "보상을 줬는데 보석이 안 늘었다")
	assert(int(game.goal_step["stage"]) == 1, "한 번에 여러 단계가 올랐다")
	assert(game._goal_ready_count() > 0, "아직 받을 게 있는데 0으로 센다")

	print("가이드 트랙 %d개 · 첫 목표 %s"
		% [GoalDefs.TRACKS.size(), GoalDefs.label("stage", 0)])
	print("단계 사다리  %s → %s → %s → %s"
		% [GoalDefs.label("kills", 0), GoalDefs.label("kills", 5),
		GoalDefs.label("kills", 10), GoalDefs.label("kills", 20)])
	game.free()
	print("GoalTest OK")
	quit()
