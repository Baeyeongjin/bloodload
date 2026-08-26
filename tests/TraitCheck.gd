extends SceneTree

# 혈맥(3단계)을 잰다. 지키는 것 셋:
#   1) 표 — 노드 18개, 가지당 티어 1~6 이 정확히 하나씩, 비용이 티어마다 오른다
#   2) 잠금 — **앞 노드 만렙** 하나와 비용이 막는가 (2026-08-12: 미궁 층·영웅
#      레벨 문턱은 뺐다. 미궁은 혈정을 주는 곳이지 잠그는 곳이 아니다)
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
	# 완주 비용은 **레벨까지 다 채운 값**이다 (2026-08-12 노드 10레벨제).
	# 첫 돌파 누적의 4~5배 — 첫 돌파로 1/4 을 채우고 나머지는 소탕이 도는
	# 몇 주다(EXPANSION 6장의 "절반"은 노드가 1레벨이던 시절 값).
	var total := 0.0
	for n in TraitDefs.NODES:
		total += TraitDefs.cost(int(n["tier"])) * float(TraitDefs.MAX_LV)
	var clear_total := 0.0
	for f in range(1, DungeonDefs.FLOOR_CAP + 1):
		clear_total += DungeonDefs.first_clear_reward(f)
	var ratio := total / clear_total
	print("혈맥 완주 비용 %.0f / 첫 돌파 누적 %.0f = %.2f배" % [total, clear_total, ratio])
	assert(ratio > 3.8 and ratio < 5.2,
		"완주 비용이 첫 돌파의 %.2f배 — 4.4배 언저리여야 한다" % ratio)

	# ── 2) 잠금 ────────────────────────────────────────────────────────────
	var none := {}
	var max_lv := TraitDefs.MAX_LV
	# 줄기 순서 — 18노드가 한 줄이고, 티어를 돌며 세 가지를 번갈아 오른다.
	var seq := TraitDefs.order()
	assert(seq.size() == TraitDefs.NODES.size(), "줄기가 표의 노드 수와 다르다")
	assert(str(seq[0]) == "attack_1" and str(seq[1]) == "life_1"
		and str(seq[3]) == "attack_2", "줄기 순서가 티어 순환이 아니다")
	# 첫 노드는 처음부터 열려 있다 — 미궁 층·영웅 레벨 문턱이 없어졌다.
	assert(TraitDefs.lock_reason(str(seq[0]), none, 1, 0) == "",
		"첫 노드가 처음부터 안 열린다")
	# 다음 노드는 **줄기의 바로 앞이 만렙일 때만** 열린다.
	var second := str(seq[1])
	assert(TraitDefs.lock_reason(second, none, 99, 99) != "",
		"앞 노드 없이 둘째가 열렸다")
	assert(TraitDefs.lock_reason(second, {"attack_1": max_lv - 1}, 99, 99) != "",
		"앞 노드가 만렙 직전인데 다음이 열렸다")
	assert(TraitDefs.lock_reason(second, {"attack_1": max_lv}, 99, 99) == "",
		"앞 노드가 만렙인데 다음이 안 열린다")
	assert(TraitDefs.lock_reason("attack_1", {"attack_1": max_lv}, 99, 99) == "만렙")
	# 옛 저장본 호환 — `true` 는 만렙으로 읽는다.
	assert(TraitDefs.level_of("attack_1", {"attack_1": true}) == max_lv,
		"옛 저장본(true)이 만렙으로 안 읽힌다")
	# 레벨에 비례해 효과가 오른다(표의 value 는 만렙 기준 총량).
	var half := TraitDefs.mult("attack", {"attack_1": max_lv / 2})
	var full := TraitDefs.mult("attack", {"attack_1": max_lv})
	assert(full > half and half > 1.0, "레벨이 효과에 안 실린다")

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
	# 한 번 사면 **한 레벨** 오른다.
	scene._buy_trait("attack_1")
	assert(TraitDefs.level_of("attack_1", scene.traits) == 1,
		"한 번 샀는데 1레벨이 아니다")
	assert(is_equal_approx(scene.crystal, 10000.0 - TraitDefs.cost(1)),
		"혈정이 비용만큼 안 깎였다: %.0f" % scene.crystal)
	# 잠긴 것은 돈이 있어도 못 산다.
	scene._buy_trait("attack_3")
	assert(not scene.traits.has("attack_3"), "앞 노드 없이 티어 3 이 사졌다")
	# 만렙까지 채우면 줄기의 다음이 열린다 — 이게 이 축의 유일한 문턱이다.
	scene.crystal = 1.0e6
	for i in TraitDefs.MAX_LV:
		scene._buy_trait("attack_1")
	assert(TraitDefs.level_of("attack_1", scene.traits) == TraitDefs.MAX_LV,
		"만렙까지 안 올라간다")
	assert(TraitDefs.lock_reason(str(TraitDefs.order()[1]), scene.traits, 1, 0) == "",
		"아래를 만렙으로 채웠는데 다음이 안 열린다")
	# 효과: 만렙 공격 +8% 가 dps 에 그대로 보인다.
	scene.hero_lv = lv0
	var dps1: float = scene.dps()
	assert(dps1 > dps0 * 1.075 and dps1 < dps0 * 1.085,
		"살육 I(만렙 +8%%)이 dps 에 안 보인다: x%.3f" % (dps1 / dps0))
	# 체력·혈액 가지도 배선돼 있는가 — 표를 직접 심어 재확인(만렙으로).
	scene.traits["life_1"] = TraitDefs.MAX_LV
	scene.traits["wealth_1"] = TraitDefs.MAX_LV
	assert(scene.max_hp() > hp0 * 1.095 and scene.max_hp() < hp0 * 1.105,
		"굳은 피 I(+10%%)이 체력에 안 보인다")
	# 갈증(혈액)은 없어졌다 — 탐욕 1~3 티어는 치명 피해로 옮겼다(2026-08-25).
	assert(is_equal_approx(scene._trait_add("critdmg"), 0.10),
		"잔혹 I(+10%%)이 치명 피해에 안 보인다: %f" % scene._trait_add("critdmg"))
	# 방치 상한: 긴 잠 2개 = +4시간.
	scene.traits["wealth_4"] = TraitDefs.MAX_LV
	scene.traits["wealth_5"] = TraitDefs.MAX_LV
	assert(is_equal_approx(scene._trait_add("hours"), 4.0), "긴 잠 합산이 4가 아니다")

	# ── 저장·복원이 **레벨**을 실어 나르는가 ────────────────────────────────
	# 로드가 값을 true 로 뭉개면 level_of 가 그걸 만렙으로 읽는다 — 1레벨만 사고
	# 껐다 켜면 만렙으로 부활해서 10레벨제가 통째로 무효가 된다.
	scene.traits = {"attack_1": 3}
	scene._save_game()
	scene.traits = {}
	scene._load_game()
	assert(TraitDefs.level_of("attack_1", scene.traits) == 3,
		"저장·복원이 혈맥 레벨을 잃었다: %d 레벨" %
		TraitDefs.level_of("attack_1", scene.traits))
	# 옛 저장본(bool)은 여전히 만렙으로 읽혀야 한다 — 쓰던 배수가 사라지면 안 된다.
	assert(TraitDefs.level_of("x", {"x": true}) == TraitDefs.MAX_LV,
		"옛 bool 저장본 하위호환이 깨졌다")

	print("")
	print("표 18노드 · 노드 10레벨 · 잠금(앞 노드 만렙/비용) · 배선 · 저장 OK")
	print("")
	print("TraitCheck OK")
	quit()
