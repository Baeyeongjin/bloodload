extends SceneTree

# 프레스티지 "핏빛 회귀"(PrestigeDefs + Main._prestige_do).
#
# 이 기능은 **되돌릴 수 없다** — 한 번 잘못 지우면 그 유저의 진행이 끝난다.
# 그래서 "무엇이 사라지고 무엇이 남는가"를 코드가 아니라 검사가 지킨다:
#   1. 조건 — 200구간 전에는 안 열린다
#   2. 혈흔 — 도달 구간에 비례, 누적된다
#   3. **뽑은 것은 안 뺏는다** — 장비·스킬·유물·기록·다른 재화 축
#   4. 배율 — 공격력에 실제로 붙는다
#   5. 저장 — 혈흔이 복원된다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표 ─────────────────────────────────────────────────────────────────
	assert(not PrestigeDefs.can(PrestigeDefs.OPEN_STAGE - 1), "조건 전에 열렸다")
	assert(PrestigeDefs.can(PrestigeDefs.OPEN_STAGE), "조건에서 안 열렸다")
	assert(PrestigeDefs.marks_for(PrestigeDefs.OPEN_STAGE) == 5,
		"첫 회귀 혈흔이 5가 아니다: %d" % PrestigeDefs.marks_for(PrestigeDefs.OPEN_STAGE))
	# 더 간 사람이 더 받는다 — 아니면 일찍 접는 게 이득이 된다.
	assert(PrestigeDefs.marks_for(300) > PrestigeDefs.marks_for(200),
		"멀리 가도 혈흔이 안 는다")
	assert(is_equal_approx(PrestigeDefs.power_mult(0), 1.0), "혈흔 0에 배율이 있다")
	assert(PrestigeDefs.power_mult(20) > PrestigeDefs.power_mult(5),
		"혈흔이 쌓여도 배율이 안 는다")
	# 배율이 실제로 구간을 벌어야 의미가 있다(설계: 혈흔 20 -> 20구간 이상).
	assert(PrestigeDefs.stages_worth(20) >= 20,
		"혈흔 20이 20구간도 못 번다: %d" % PrestigeDefs.stages_worth(20))

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 조건 미달이면 아무 일도 없다.
	scene.best_stage = 100
	scene.prestige_marks = 0
	scene._prestige_do()
	assert(scene.prestige_marks == 0, "조건 미달인데 회귀했다")
	assert(scene.best_stage == 100, "실패한 회귀가 구간을 건드렸다")

	# ── 회귀 ───────────────────────────────────────────────────────────────
	# **결백성** — 앞선 검사가 남긴 저장본을 물려받으면 횟수가 이미 올라 있다.
	scene.prestige_marks = 0
	scene.prestige_count = 0
	scene.best_stage = 250
	scene.stage = 250
	scene.gold = 1e9
	scene.lv = {"damage": 100}
	# 남아야 하는 것들을 심어 둔다.
	scene.gear_inventory = {"keep_gear": {"name": "표식", "lv": 3}}
	scene.skill_owned = {"keep_skill": 2}
	scene.relics = {"keep_relic": 2}
	scene.dungeon_best = 40
	scene.codex = {"keep_foe": 5}
	scene.crystal = 5000.0
	scene.sigil = 3000.0
	scene.pact_lv = 12
	var want := PrestigeDefs.marks_for(250)
	scene._prestige_do()
	while scene._fade_t > 0.0:
		await process_frame

	# 2) 혈흔 — 받았고 누적된다.
	assert(scene.prestige_marks == want, "혈흔이 안 들어왔다: %d" % scene.prestige_marks)
	assert(scene.prestige_count == 1, "회귀 횟수가 안 올랐다")

	# 3) **되돌아간 것**: 구간·스탯·혈액.
	assert(scene.best_stage == 1 and scene.stage == 1, "구간이 안 돌아갔다")
	assert(scene.lv.is_empty(), "스탯 레벨이 남았다")
	assert(is_equal_approx(scene.gold, 0.0), "혈액이 남았다")

	# 3) **남아야 하는 것**: 뽑은 것과 기록과 다른 재화 축.
	assert(scene.gear_inventory.has("keep_gear"), "장비가 사라졌다")
	assert(scene.skill_owned.has("keep_skill"), "스킬이 사라졌다")
	assert(scene.relics.has("keep_relic"), "유물이 사라졌다")
	assert(scene.dungeon_best == 40, "미궁 기록이 사라졌다")
	assert(scene.codex.has("keep_foe"), "도감이 사라졌다")
	assert(scene.crystal > 0.0 and scene.sigil > 0.0, "혈정·인장이 사라졌다")
	assert(scene.pact_lv == 12, "혈맹이 사라졌다")

	# 4) 배율이 **공격력에 실제로** 붙는가.
	var with_marks: float = scene._base_hit_damage()
	var keep: int = scene.prestige_marks
	scene.prestige_marks = 0
	var without: float = scene._base_hit_damage()
	scene.prestige_marks = keep
	assert(with_marks > without, "회귀 배율이 공격력에 안 붙었다")
	assert(is_equal_approx(with_marks / without, PrestigeDefs.power_mult(keep)),
		"배율 크기가 표와 다르다")

	# 5) 저장.
	scene._save_game()
	scene.prestige_marks = 0
	scene.prestige_count = 0
	scene._load_game()
	assert(scene.prestige_marks == want and scene.prestige_count == 1,
		"혈흔이 복원 안 됐다")

	print("PrestigeCheck OK")
	quit()
