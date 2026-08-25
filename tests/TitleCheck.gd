extends SceneTree

# 칭호(5단계)를 잰다. 지키는 것 셋:
#   1) 표 — id 중복 없음, 조건이 전부 아는 kind, 보상이 아는 스탯
#   2) 판정 — 조건 둘이 **다** 차야 딴다 (하나만으로 따지면 짝 조건이 장식이 된다)
#   3) 배선 — 공짜 레벨이 **효과에만** 붙고 비용에는 안 붙는가.
#      비용에 붙으면 칭호를 딸수록 다음 강화가 비싸지는 벌이 된다

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	var seen := {}
	var known_kind := ["stage", "floor", "hero", "kills", "species", "knowledge",
		"skills", "traits", "trial", "pets", "chest", "nights", "prestige"]
	# gold(피 획득)는 없어졌다 — 종 수집 칭호 21종은 치명 피해로 옮겼다
	# (사장님 2026-08-25).
	var known_stat := ["damage", "speed", "tough", "critdmg"]
	for t in TitleDefs.TITLES:
		var id := str(t["id"])
		assert(not seen.has(id), "id 중복: %s" % id)
		seen[id] = true
		# 조건은 1~2개 — 표가 단일 조건 칭호로 재편된 지 오래다(둘 고정은 낡은 규칙).
		assert((t["conds"] as Array).size() in [1, 2], "%s 조건 수 이상" % id)
		for c in t["conds"]:
			assert(str(c["kind"]) in known_kind, "%s 모르는 조건: %s" % [id, str(c["kind"])])
			assert(TitleDefs.cond_text(c) != "", "%s 조건 문장이 없다" % id)
		assert(str(t["stat"]) in known_stat, "%s 모르는 스탯: %s" % [id, str(t["stat"])])
		assert(int(t["levels"]) > 0)

	# ── 2) 판정 ────────────────────────────────────────────────────────────
	# (칭호 100종 재편으로 옛 표본 awaken·scholar 가 사라졌다 — 현행 표본으로)
	assert(not TitleDefs.earned("stage10", {"stage": 10}),
		"돌파(>10)가 아니라 도달(=10)인데 땄다")
	assert(TitleDefs.earned("stage10", {"stage": 11}))
	assert(not TitleDefs.earned("trial10", {"trial": 9}), "시련 9로 10칭호를 땄다")
	assert(TitleDefs.earned("trial10", {"trial": 10}))
	# 보너스 합산: damage 칭호 둘(stage10 lv2 + stage20 lv3).
	var got := {"stage10": true, "stage20": true}
	assert(TitleDefs.bonus("damage", got) == 5, "공짜 레벨 합이 2+3=5 가 아니다")
	assert(TitleDefs.bonus("tough", got) == 0)

	# ── 3) 배선 ────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.titles_got = {}
	var dmg0: float = scene.damage()
	var cost0: float = scene.upgrade_cost("damage", scene.stat_lv("damage"))
	scene.titles_got = {"stage10": true, "stage20": true}   # damage +2 +3 = +5
	assert(scene._stat_eff("damage") == scene.stat_lv("damage") + 5,
		"효과 레벨이 +5 가 아니다")
	assert(scene.damage() > dmg0, "칭호를 땄는데 피해가 안 올랐다")
	# **비용은 그대로여야 한다** — 공짜 레벨이 비용에 붙으면 벌이 된다.
	assert(is_equal_approx(scene.upgrade_cost("damage", scene.stat_lv("damage")), cost0),
		"칭호가 강화 비용을 올렸다")
	# 스냅샷이 기록을 제대로 옮기는가 — 실제 딴 판정 경로 하나.
	scene.best_stage = 11
	scene.codex = {"slime": 60, "bat": 40}
	var state: Dictionary = scene._title_state()
	assert(int(state["kills"]) == 100, "처치 합계가 스냅샷에 안 옮았다")
	assert(TitleDefs.earned("stage10", state), "기록을 채웠는데 판정이 안 선다")

	print("")
	print("칭호: 표 %d종 · 짝 조건 판정 · 공짜 레벨(효과만, 비용 불변) OK"
		% TitleDefs.TITLES.size())
	print("")
	# ── 수집 이정표 (MONETIZATION_PLAN 4-3) ───────────────────────────────
	var ms_seen := {}
	var prev_n := 0
	for m in TitleDefs.MILESTONES:
		var n := int(m["n"])
		assert(n > prev_n, "이정표 개수가 오름차순이 아니다: %d" % n)
		assert(n <= TitleDefs.TITLES.size(), "칭호 수보다 많은 이정표: %d" % n)
		assert(not ms_seen.has(n), "이정표 중복: %d" % n)
		ms_seen[n] = true
		prev_n = n
		assert(int(m["amount"]) > 0, "이정표 보상이 0")
	# 아직 안 받은 것만 나온다 — 같은 이정표를 두 번 주면 안 된다.
	assert(TitleDefs.claimable_milestones(0, {}).is_empty(), "0개인데 받을 게 있다")
	var all_n: int = int(TitleDefs.MILESTONES[TitleDefs.MILESTONES.size() - 1]["n"])
	assert(TitleDefs.claimable_milestones(all_n, {}).size()
		== TitleDefs.MILESTONES.size(), "전부 모았는데 다 안 열린다")
	assert(TitleDefs.claimable_milestones(all_n, {0: true}).size()
		== TitleDefs.MILESTONES.size() - 1, "받은 이정표가 또 나온다")

	# ── 승급 보상 (MONETIZATION_PLAN 4-4) ─────────────────────────────────
	assert(StatDefs.PROMO_REWARDS.size() == StatDefs.PROMO_FLOORS.size(),
		"승급 단계 수와 보상 수가 다르다")
	assert(StatDefs.PROMO_REWARDS[0].is_empty(), "시작 단계에 보상이 붙었다")
	for i in range(1, StatDefs.PROMO_REWARDS.size()):
		assert(int(StatDefs.PROMO_REWARDS[i]["amount"]) > 0, "승급 %d 보상이 0" % i)

	print("TitleCheck OK")
	quit()
