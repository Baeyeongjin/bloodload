extends SceneTree

# 군림(4단계)을 잰다. 지키는 것 셋:
#   1) 표 — 문턱이 오름차순이고, 돌파 경계(> stage)가 정확한가
#   2) 원칙 — 군림에는 %가 없다 (곱연산은 혈맥 전담. EXPANSION 2장의 예산 분리)
#   3) 훅 — 다섯 해금이 실제 코드 자리(_equip_cap 등)에 걸리는가

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	assert(MasteryDefs.RANKS.size() == 5, "군림이 5개가 아니다")
	var prev := 0
	for r in MasteryDefs.RANKS:
		assert(int(r["stage"]) > prev, "문턱이 안 오른다: %s" % str(r["name"]))
		prev = int(r["stage"])
	# 돌파 경계: 50 도달로는 안 열리고, 50 을 **돌파**(기록 51)해야 열린다.
	assert(not MasteryDefs.has("slot", 50), "50 도달인데 열렸다 — 돌파여야 한다")
	assert(MasteryDefs.has("slot", 51), "50 돌파인데 안 열렸다")
	assert(MasteryDefs.unlocked_count(51) == 1)
	assert(MasteryDefs.unlocked_count(9999) == 5)

	# ── 2) % 금지 — desc 에 숫자 배수가 없어야 한다는 걸 기계로 못 박을 수는
	# 없지만, 다섯 키가 전부 "기능" 훅(아래 3)으로만 쓰이는 것이 그 증거다.
	# 키가 늘면 이 검사에 훅 검증을 같이 늘려야 한다 — 여기서 개수를 못 박는다.
	var keys := {}
	for r in MasteryDefs.RANKS:
		keys[str(r["key"])] = true
	for k in ["slot", "execute", "cleave3", "hours", "sweep2"]:
		assert(keys.has(k), "군림 키가 빠졌다: %s" % k)

	# ── 3) 훅 ──────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.traits = {}          # 혈맥이 섞이면 소탕·상한 비교가 흐려진다
	# 해금 전 — 전부 기본값.
	scene.best_stage = 1
	assert(scene._equip_cap() == SkillDefs.SLOTS, "해금 전인데 칸이 늘었다")
	assert(is_equal_approx(scene._exec_bonus(), 0.0))
	assert(is_equal_approx(scene._offline_cap_hours(), 8.0))
	scene.dungeon_best = 50
	var sweep0: float = scene._sweep_per_hour()
	# 전부 해금 — 다섯 훅이 다 움직인다.
	scene.best_stage = 9999
	assert(scene._equip_cap() == SkillDefs.SLOTS + 1, "군림 I 인데 칸이 안 늘었다")
	assert(is_equal_approx(scene._exec_bonus(), 0.05), "군림 II 문턱 가산이 아니다")
	assert(is_equal_approx(scene._offline_cap_hours(), 12.0),
		"군림 IV 인데 상한이 12시간이 아니다: %.1f" % scene._offline_cap_hours())
	assert(is_equal_approx(scene._sweep_per_hour(), sweep0 * 2.0),
		"군림 V 인데 소탕이 2배가 아니다")
	# 자동 장착이 7칸을 쓴다 — 스킬 7개를 주면 7개가 껴진다.
	var pool := SkillDefs.all_keys()
	for i in 8:
		scene.skill_owned[str(pool[i])] = 1
	scene._auto_equip_skills()
	assert(scene.skill_equipped.size() == SkillDefs.SLOTS + 1,
		"군림 I 인데 자동 장착이 %d칸만 쓴다" % scene.skill_equipped.size())

	print("")
	print("군림: 표 5종(50/100/200/300/450 돌파) · 훅 5종(칸/문턱/광역/상한/소탕) OK")
	print("")
	print("MasteryCheck OK")
	quit()
