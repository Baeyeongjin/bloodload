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

	# ── 4) 조합 창(전체 화면) — 열리고, 탭이 갈리고, 확정 바가 도는가 ────────
	# 조각을 채워 후보를 만든다 — 없으면 격자가 비어 검사가 헛돈다.
	var fuse_key := ""
	for k in scene.gear_inventory:
		if GachaDefs.rarity_index(str(scene.gear_inventory[k]["rarity"])) 				< GachaDefs.RARITIES.size() - 1:
			fuse_key = str(k)
			break
	assert(not fuse_key.is_empty(), "조합할 비신화 장비가 없다")
	scene.gacha_shards["gear:" + fuse_key] = GearDefs.FUSE_SHARDS
	scene._set_gear_mode("inventory")
	scene._open_bulk("fuse")
	assert(scene._bulk_view.visible, "조합 창이 안 열렸다")
	assert(scene._bulk_candidates().has(fuse_key), "조각이 찬 장비가 후보에 없다")
	# 등급 탭 — 다른 등급을 고르면 그 등급만 남는다.
	var rar := str(scene.gear_inventory[fuse_key]["rarity"])
	scene._bulk_tab = rar
	scene._refresh_bulk()
	for k2 in scene._bulk_candidates():
		assert(str(scene.gear_inventory[k2]["rarity"]) == rar,
			"등급 탭이 다른 등급을 걸렀다")
	# 확정 바 — 누적이 늘면 막대도 길어진다.
	scene._bulk_selected = {fuse_key: true}
	scene._refresh_bulk()
	var w0: float = scene._bulk_pity_bar.size.x
	scene.fuse_pity["gear:" + fuse_key] = 1
	scene._refresh_bulk()
	assert(scene._bulk_pity_bar.size.x > w0, "확정 바가 누적을 안 탄다")
	# 조합 실행 — 확인창이 **조합 창보다 위**에 떠야 한다. 아래에 깔리면
	# 눌러도 아무 일이 없는 것처럼 보인다(2026-08-25 실제 버그: 확인창 z=60,
	# 조합 창 z=64 라 확인창이 뒤에 숨었다).
	scene.gacha_shards["gear:" + fuse_key] = GearDefs.FUSE_SHARDS
	scene._bulk_selected = {fuse_key: true}
	scene._refresh_bulk()
	assert(not scene._bulk_run.disabled, "고른 게 있는데 조합 버튼이 잠겨 있다")
	scene._run_bulk()
	assert(scene._confirm_view.visible, "조합 확인창이 안 떴다")
	assert(scene._confirm_view.z_index > scene._bulk_view.z_index,
		"확인창이 조합 창 뒤에 깔린다 — 눌러도 반응이 없어 보인다")
	assert(scene._confirm_action.is_valid(), "확인창에 실행이 안 걸렸다")
	var shards_before := int(scene.gacha_shards.get("gear:" + fuse_key, 0))
	scene._confirm_action.call()
	assert(int(scene.gacha_shards.get("gear:" + fuse_key, 0)) < shards_before,
		"확인을 눌러도 조합이 조각을 안 쓴다")
	scene._bulk_view.visible = false

	print("PullUiCheck OK")
	quit(0)
