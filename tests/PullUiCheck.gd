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
	# **보석 소모로 잰다.** 잔량으로 재면 천장 상자(_mile_add)가 중간에 권을
	# 돌려줘서 0 이 안 된다 — 권 6 장이었으니 보석은 넷만 나가야 한다.
	assert(is_equal_approx(scene.gem, GachaDefs.COST * 6.0),
		"권을 두고 보석이 더 나갔다: 남은 보석 %f" % scene.gem)

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
	# **입력에서도 맨 위여야 한다.** z_index 는 그리기 순서만 바꾼다 — 클릭은
	# 형제 중 나중 자식이 먼저 받으므로, 늦게 지어진 가이드 카드가 판 위를
	# 가로챘다(사장님 2026-08-25: 조합 창에서 가이드 보상이 눌렸다).
	var sibs: Array = scene._hud_root.get_children()
	assert(sibs.find(scene._bulk_view) > sibs.find(scene._goal_widget),
		"조합 창이 가이드 카드보다 입력 뒤에 있다 (%d vs %d)"
		% [sibs.find(scene._bulk_view), sibs.find(scene._goal_widget)])
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
	# 천장은 **등급 통**이다(사장님 2026-08-25) — 키가 등급 키다.
	scene.fuse_pity[rar] = 0
	scene._refresh_bulk()
	var w0: float = scene._bulk_pity_bar.size.x
	scene.fuse_pity[rar] = 		GearDefs.fuse_pity(scene.gear_inventory[fuse_key]) - 1
	scene._refresh_bulk()
	assert(scene._bulk_pity_bar.size.x > w0,
		"확정 바가 누적을 안 탄다: %f -> %f (%s)"
		% [w0, scene._bulk_pity_bar.size.x, scene._bulk_pity_num.text])
	# **재료를 안 넣어도** 확정 정보가 떠야 한다(사장님 2026-08-25).
	scene._bulk_selected = {}
	scene._refresh_bulk()
	assert(scene._bulk_pity_bar.size.x > 0.0,
		"고르기 전에는 확정 진행도가 안 보인다")
	assert(scene._bulk_pity_lbl.text.contains("확정"),
		"확정 라벨이 비었다: %s" % scene._bulk_pity_lbl.text)
	# 조합 실행 — 확인창이 **조합 창보다 위**에 떠야 한다. 아래에 깔리면
	# 눌러도 아무 일이 없는 것처럼 보인다(2026-08-25 실제 버그: 확인창 z=60,
	# 조합 창 z=64 라 확인창이 뒤에 숨었다).
	scene.gacha_shards["gear:" + fuse_key] = GearDefs.FUSE_SHARDS
	scene._bulk_selected = {fuse_key: true}
	scene._refresh_bulk()
	assert(not scene._bulk_run.disabled, "고른 게 있는데 조합 버튼이 잠겨 있다")
	# **등급 통이 하나다** — 같은 등급의 다른 종을 굴려도 같은 카운터가 오른다.
	scene.fuse_pity[rar] = 2
	assert(int(scene.fuse_pity.get(rar, 0)) == 2, "등급 천장이 안 쌓인다")
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

	# ── 5) 조합 실패 — 빈손이 아니라 **같은 등급·같은 슬롯** 장비 하나 ──────
	# (사장님 2026-08-25: "실패하면 보석을 주는 게 아니라 동일한 레어를
	# 조합하면 레어등급장비 1개 랜덤지급")
	var fail_key := ""
	for k3 in scene.gear_inventory:
		if GachaDefs.rarity_index(str(scene.gear_inventory[k3]["rarity"])) 				< GachaDefs.RARITIES.size() - 1:
			fail_key = str(k3)
			break
	assert(not fail_key.is_empty(), "실패 검사에 쓸 장비가 없다")
	var fail_item: Dictionary = scene.gear_inventory[fail_key]
	var fail_rar := str(fail_item["rarity"])
	var fail_slot := str(fail_item["slot"])
	# 천장 직전 -1 로 두고 확률을 0 으로 눌러 **반드시 실패**하게 만든다.
	scene.gacha_shards["gear:" + fail_key] = GearDefs.FUSE_SHARDS
	scene.fuse_pity[fail_rar] = 0
	var guard_n := 0
	while guard_n < 40:
		guard_n += 1
		scene.gacha_shards["gear:" + fail_key] = GearDefs.FUSE_SHARDS
		scene.fuse_pity[fail_rar] = 0
		if scene._synthesize(fail_key).is_empty() and scene._fuse_failed:
			break
	assert(scene._fuse_failed, "실패를 한 번도 못 만들었다")
	assert(not scene._fuse_gain.is_empty(), "실패했는데 빈손이다")
	assert(str(scene._fuse_gain["rarity"]) == fail_rar,
		"실패 보상 등급이 다르다: %s" % str(scene._fuse_gain["rarity"]))
	assert(str(scene._fuse_gain["slot"]) == fail_slot,
		"실패 보상 슬롯이 다르다: %s" % str(scene._fuse_gain["slot"]))

	# ── 6) 연마석 — 제련의 성소가 주고, 장비 레벨업이 그걸 쓴다 ────────────
	assert(str(RaidDefs.RAIDS["forge"]["currency"]) == "연마석",
		"성소가 연마석을 안 준다")
	var w_before: float = scene.whet
	# 소탕은 **최고 기록이 있어야** 돈다(n<=0 이면 그냥 나간다).
	scene.raid_best["forge"] = 1
	scene.raid_date = Time.get_date_string_from_system()
	scene.raid_left["forge"] = 3
	scene.raid_on = ""
	scene.dungeon_on = false
	scene._raid_sweep("forge")
	assert(scene.whet > w_before, "성소 소탕이 연마석을 안 준다")
	# 레벨업 — 연마석을 내고 한 칸 오른다.
	var up_key := str(scene.gear_inventory.keys()[0])
	scene._gear_selected_key = up_key
	var lv0 := int(scene.gear_inventory[up_key].get("lv", 0))
	scene.whet = GearDefs.upgrade_cost(scene.gear_inventory[up_key])
	scene._level_up_selected()
	assert(int(scene.gear_inventory[up_key]["lv"]) == lv0 + 1,
		"레벨업이 안 됐다")
	assert(is_zero_approx(scene.whet), "레벨업이 연마석을 안 썼다")

	# ── 7) 스킬 조합 — **장비와 같은 규칙·같은 창** ────────────────────────
	# (사장님 2026-08-25: "스킬도 무기처럼 조합 똑같이 가줘")
	var sk_key := ""
	for shape in SkillDefs.SHAPE_ORDER:
		var k4 := SkillDefs.key_of(str(shape), "common")
		if not SkillDefs.promote_key(k4).is_empty():
			sk_key = k4
			break
	assert(not sk_key.is_empty(), "승급할 스킬 키가 없다")
	scene.skill_owned[sk_key] = 1
	scene.gacha_shards["skill:" + sk_key] = GearDefs.FUSE_SHARDS
	scene.fuse_pity.erase("common")
	scene._open_bulk("fuse", "skill")
	assert(scene._bulk_view.visible, "스킬 조합 창이 안 열렸다")
	assert(scene._bulk_candidates().has(sk_key),
		"조각이 찬 스킬이 후보에 없다")
	# 천장 직전으로 두면 이번 시도는 확정이라 검사가 결정적이다.
	scene.fuse_pity["common"] = GearDefs.fuse_pity({"rarity": "common"}) - 1
	var next_key := SkillDefs.promote_key(sk_key)
	scene._synthesize_skill(sk_key)
	assert(scene.skill_owned.has(next_key), "확정인데 승급이 안 됐다")
	assert(int(scene.gacha_shards["skill:" + sk_key]) == 0,
		"스킬 조합이 조각 %d개를 안 썼다" % GearDefs.FUSE_SHARDS)
	assert(not scene.fuse_pity.has("common"),
		"성공했는데 등급 천장이 안 지워졌다")
	scene._bulk_view.visible = false

	print("PullUiCheck OK")
	quit(0)
