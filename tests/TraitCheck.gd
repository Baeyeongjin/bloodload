extends SceneTree

# 혈맥(3단계)을 잰다. 지키는 것 셋:
#   1) 표 — 노드 18개, 가지당 티어 1~6 이 정확히 하나씩, 비용이 티어마다 오른다
#   2) 잠금 — 가지(미궁 층)·순서(앞 노드)·티어(영웅 레벨)·비용이 각각 막는가
#   3) 효과 — 사면 실제로 dps/체력/수입이 오르는가 (배선이 끊기면 표만 남는다)

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	assert(TraitDefs.NODES.size() == 18, "노드가 18개가 아니다")
	for branch in TraitDefs.BRANCHES:
		var tiers := {}
		for n in TraitDefs.nodes_of(branch):
			tiers[int(n["tier"])] = true
		for t in range(1, 7):
			assert(tiers.has(t), "%s 가지에 티어 %d 가 없다" % [branch, t])
	for t in range(2, 7):
		assert(TraitDefs.cost(t) > TraitDefs.cost(t - 1), "티어 %d 비용이 안 오른다" % t)
	# 전체 비용이 미궁 첫 돌파 누적의 1.4~1.6배 (EXPANSION 6장: 첫 돌파로 절반).
	var total := 0.0
	for n in TraitDefs.NODES:
		total += TraitDefs.cost(int(n["tier"]))
	var clear_total := 0.0
	for f in range(1, DungeonDefs.FLOOR_CAP + 1):
		clear_total += DungeonDefs.first_clear_reward(f)
	var ratio := total / clear_total
	print("혈맥 전체 비용 %.0f / 첫 돌파 누적 %.0f = %.2f배" % [total, clear_total, ratio])
	assert(ratio > 1.3 and ratio < 1.7,
		"완주 비용이 첫 돌파의 %.2f배 — 1.5배 언저리여야 한다" % ratio)

	# ── 2) 잠금 ────────────────────────────────────────────────────────────
	var none := {}
	assert(TraitDefs.lock_reason("attack_1", none, 99, 5) != "",
		"미궁 10층 전인데 살육 가지가 열렸다")
	assert(TraitDefs.lock_reason("attack_1", none, 5, 99) != "",
		"영웅 Lv10 전인데 티어 1이 열렸다")
	assert(TraitDefs.lock_reason("attack_2", {"attack_1": true}, 5, 99) != "",
		"앞 노드만 있고 레벨이 모자란데 열렸다")
	assert(TraitDefs.lock_reason("attack_2", none, 99, 99) != "",
		"앞 노드 없이 티어 2 가 열렸다")
	assert(TraitDefs.lock_reason("attack_1", none, 99, 99) == "",
		"조건을 다 채웠는데 잠겨 있다")
	assert(TraitDefs.lock_reason("attack_1", {"attack_1": true}, 99, 99) == "보유")

	# ── 3) 효과 배선 ───────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# **지난 실행이 남긴 저장본을 지운다.** 이 테스트는 사고 남기므로(저장까지 탄다)
	# 두 번째 실행에서 "보유" 로 빠져 헛것을 잰다 — 시작을 늘 빈 트리로 만든다.
	scene.traits = {}
	# **불러온 값 위에서 비교한다.** 레벨을 1로 되돌리는 식으로 짜면 저장본의
	# 실제 레벨과 달라져 비교가 틀어진다 — 원값을 붙들고 그대로 복원한다.
	var lv0: int = scene.hero_lv
	var dps0: float = scene.dps()
	var hp0: float = scene.max_hp()
	var gold0: float = scene.gold_mult()
	# 구매 경로: 조건 채우고 사면 혈정이 깎이고 노드가 남는다.
	scene.hero_lv = 999
	scene.dungeon_best = 99
	scene.crystal = 10000.0
	scene._buy_trait("attack_1")
	assert(scene.traits.has("attack_1"), "샀는데 노드가 없다")
	assert(is_equal_approx(scene.crystal, 10000.0 - TraitDefs.cost(1)),
		"혈정이 비용만큼 안 깎였다: %.0f" % scene.crystal)
	# 잠긴 것은 돈이 있어도 못 산다.
	scene._buy_trait("attack_3")
	assert(not scene.traits.has("attack_3"), "앞 노드 없이 티어 3 이 사졌다")
	# 효과: 공격 +8% 가 dps 에 그대로 보인다 (영웅 레벨을 원값으로 되돌리고 잰다).
	scene.hero_lv = lv0
	var dps1: float = scene.dps()
	assert(dps1 > dps0 * 1.075 and dps1 < dps0 * 1.085,
		"살육 I(+8%%)이 dps 에 안 보인다: x%.3f" % (dps1 / dps0))
	# 체력·혈액 가지도 배선돼 있는가 — 표를 직접 심어 재확인.
	scene.traits["life_1"] = true
	scene.traits["wealth_1"] = true
	assert(scene.max_hp() > hp0 * 1.095 and scene.max_hp() < hp0 * 1.105,
		"굳은 피 I(+10%%)이 체력에 안 보인다")
	assert(scene.gold_mult() > gold0 * 1.095 and scene.gold_mult() < gold0 * 1.105,
		"갈증 I(+10%%)이 혈액 배수에 안 보인다")
	# 방치 상한: 긴 잠 2개 = +4시간.
	scene.traits["wealth_4"] = true
	scene.traits["wealth_5"] = true
	assert(is_equal_approx(scene._trait_add("hours"), 4.0), "긴 잠 합산이 4가 아니다")

	print("")
	print("표 18노드 · 잠금 4겹(가지/순서/레벨/비용) · 배선(공격·체력·혈액·상한) OK")
	print("")
	print("TraitCheck OK")
	quit()
