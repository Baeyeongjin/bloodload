extends SceneTree

# 소환 결과 창 — 장비·펫·펫장비가 **같은 문법**으로 도는가
# (사장님 2026-08-25: "펫소환이랑 펫장비소환도 장비소환이랑 동일하게").
#
# 지키는 것 셋:
#   1. 30·50연이 실제로 그 횟수를 굴리고 결과 창이 뜨는가(카드 스크롤 포함).
#   2. 값 셈이 소환권 우선 — 권을 두고 보석이 나가면 유저가 손해를 본다.
#   3. 권이 2~9장 애매하게 남으면 "권 N장" 털기가 그만큼만 뽑는가.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).
func _init() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 1) 장비 소환 — 30연 ────────────────────────────────────────────────
	scene.best_stage = maxi(scene.best_stage, PetDefs.PET_OPEN)
	scene._set_gacha_kind("weapon")
	scene.free_pull_date = Time.get_date_string_from_system()   # 무료를 끈다
	scene.tickets["weapon"] = 0
	scene.gem = GachaDefs.COST * 30.0
	# 저장본이 남아 있을 수 있다 — **증분**으로 잰다.
	var pulls0 := int(scene.gacha_pulls.get("weapon", 0))
	scene._pull_gacha(30)
	assert(int(scene.gacha_pulls["weapon"]) - pulls0 == 30, "30연이 30번 안 굴렀다")
	assert(is_zero_approx(scene.gem), "30연 값이 보석으로 안 나갔다")
	assert(scene._gacha_reveal.visible, "30연 결과 창이 안 열렸다")

	# 소환권을 먼저 쓴다 — 권 6 + 보석 4 장이면 보석은 넷만 나간다.
	scene.tickets["weapon"] = 6
	scene.gem = GachaDefs.COST * 10.0
	scene._pull_gacha(10)
	assert(int(scene.tickets["weapon"]) == 0, "권을 두고 보석이 나갔다")
	assert(is_equal_approx(scene.gem, GachaDefs.COST * 6.0),
		"섞인 값 계산이 틀렸다: %f" % scene.gem)

	# ── 2) 펫 소환 — 30연·권 털기 ──────────────────────────────────────────
	# **굴린 횟수로 잰다.** 잔량으로 재면 천장 상자가 중간에 권을 돌려줘서
	# (_mile_add) 0 이 안 된다 — 실제로 이 검사가 그렇게 한 번 틀렸다.
	scene.tickets["pet"] = 30
	var pet_gem: float = scene.gem
	var mile0: int = scene.mileage
	scene._pet_roll_many(30)
	assert(scene.mileage - mile0 == 30, "펫 30연이 서른 번 안 굴렀다")
	assert(is_equal_approx(scene.gem, pet_gem), "권이 있는데 보석이 나갔다")
	assert(scene._pet_reveal.visible, "펫 결과 창이 안 열렸다")

	# 권 6장 털기 — 딱 여섯 번이다.
	scene.tickets["pet"] = 6
	var mile1: int = scene.mileage
	scene._pet_roll_many(6)
	assert(scene.mileage - mile1 == 6, "권 털기가 남은 권만큼 안 굴렀다")

	# ── 3) 펫 장비 소환 — 같은 문법 ────────────────────────────────────────
	scene.tickets["petgear"] = 50
	var pg_gem: float = scene.gem
	var mile2: int = scene.mileage
	scene._petgear_roll_many(50)
	assert(scene.mileage - mile2 == 50, "펫장비 50연이 쉰 번 안 굴렀다")
	assert(is_equal_approx(scene.gem, pg_gem), "펫장비에서 보석이 새어 나갔다")
	assert(scene._pet_reveal.visible, "펫장비 결과 창이 안 열렸다")

	print("PullUiCheck OK")
	quit(0)
