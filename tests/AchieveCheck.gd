extends SceneTree
# 업적 표 회귀 — 계단이 오름차순인가, 값의 출처가 살아 있는가, 수령이 두 번
# 안 되는가. 셋 다 "크래시 없이 조용히 틀리는" 종류다.

func _init() -> void:
	# 1) 표 자체 — 계단은 오르고, 보상은 계단 수와 짝이 맞아야 한다.
	for t in AchieveDefs.TRACKS:
		var steps: Array = t["steps"]
		var amounts: Array = t["amounts"]
		assert(steps.size() == amounts.size(),
			"%s: 계단 %d개에 보상 %d개" % [t["kind"], steps.size(), amounts.size()])
		for i in range(1, steps.size()):
			assert(int(steps[i]) > int(steps[i - 1]),
				"%s: 계단이 안 오른다 %s" % [t["kind"], str(steps)])
			assert(float(amounts[i]) >= float(amounts[i - 1]),
				"%s: 보상이 줄어든다 %s" % [t["kind"], str(amounts)])
	# 소환권은 여섯 갈래를 다 덮어야 한다 — 한 종류만 주면 나머지 천장이 안 찬다.
	var kinds := {}
	for t in AchieveDefs.TRACKS:
		kinds[str(t["reward"])] = true
	for k in TicketDefs.KINDS + TicketDefs.PET_KINDS:
		assert(kinds.has("ticket_" + k), "업적이 %s 소환권을 안 준다" % k)

	# 2) reached / at 의 경계
	var first: Dictionary = AchieveDefs.at("kills", 0)
	assert(AchieveDefs.reached("kills", int(first["need"]) - 1) == 0, "덜 찼는데 셌다")
	assert(AchieveDefs.reached("kills", int(first["need"])) == 1, "딱 맞는데 안 셌다")
	assert(AchieveDefs.at("kills", 999).is_empty(), "없는 계단이 값을 냈다")

	# 3) 값의 출처 — 트랙마다 Main._goal_value 가 답을 알아야 한다.
	#    (모르면 늘 0 이라 영원히 못 받는 업적이 된다)
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for t in AchieveDefs.TRACKS:
		var kind := str(t["kind"])
		scene._goal_value(kind)   # 모르는 열쇠면 0 인데, 아래에서 실제로 움직이는지 본다
	scene.codex["slime"] = 999999
	assert(scene._goal_value("kills") > 0, "kills 가 안 읽힌다")
	scene.dungeon_best = 7
	assert(scene._goal_value("dungeon") == 7, "dungeon 이 안 읽힌다")
	scene.trial_stage = 4
	assert(scene._goal_value("trial") == 4, "trial 이 안 읽힌다")

	# 4) 수령 — 닿은 계단을 한 번에 다 주고, 두 번 누르면 아무것도 안 나온다.
	scene.achieve_got = {}
	var before := int(scene.tickets.get("weapon", 0))
	scene._claim_achieve("kills")      # 500/2000/... 여러 계단이 한 번에
	var got := int(scene.achieve_got.get("kills", 0))
	assert(got >= 4, "999,999 처치인데 계단을 %d개만 줬다" % got)
	var mid := int(scene.tickets.get("weapon", 0))
	assert(mid > before, "보상이 안 들어왔다")
	scene._claim_achieve("kills")
	assert(int(scene.tickets.get("weapon", 0)) == mid, "두 번째 수령이 또 줬다")
	print("AchieveCheck OK  (트랙 %d · 계단 %d)"
		% [AchieveDefs.TRACKS.size(), AchieveDefs.total_steps()])
	quit()
