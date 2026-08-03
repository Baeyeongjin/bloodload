extends SceneTree

# 보스/중간보스/자동 스킬의 최소 규칙 검사.
#   godot --headless --path . --script tests/CombatRulesTest.gd

func _init() -> void:
	assert(StageDefs.is_midboss_stage(5) and not StageDefs.is_midboss_stage(4))
	assert(StageDefs.is_boss_stage(10) and not StageDefs.is_boss_stage(9))
	assert(StageDefs.kills_needed(5) == 1 and StageDefs.kills_needed(10) == 1)
	assert(StageDefs.kills_needed(4) == StageDefs.KILLS_PER_STAGE)
	assert(StageDefs.total_stages() == 1000)
	assert(StageDefs.parse("1-1") == 1 and StageDefs.parse("100-10") == 1000)
	assert(StageDefs.parse("10") == 10, "기존 내부 단계 플래그가 깨졌다")
	for internal in range(1, StageDefs.total_stages() + 1):
		assert(StageDefs.parse(StageDefs.label(internal)) == internal,
			"단계 표시 왕복 실패: %d -> %s" % [internal, StageDefs.label(internal)])
	assert(StageDefs.major_stage(1) == 1 and StageDefs.step_in_act(1) == 1)
	assert(StageDefs.major_stage(10) == 1 and StageDefs.step_in_act(10) == 10)
	assert(StageDefs.major_stage(991) == 100 and StageDefs.step_in_act(1000) == 10)
	assert(StageDefs.is_midboss_stage(995) and StageDefs.is_boss_stage(1000))
	assert(is_equal_approx(StageDefs.boss_essence(10), 25.0))
	assert(StageDefs.boss_essence(1000) > StageDefs.boss_essence(10))
	assert(StageDefs.act_of(1) == StageDefs.act_of(51), "5개 테마가 순환하지 않는다")
	assert(StageDefs.enemy_power(1000) > StageDefs.enemy_power(999))

	for i in StageDefs.act_count():
		var act: Dictionary = StageDefs.ACTS[i]
		assert(FileAccess.file_exists("res://assets/anim/%s_walk/0.png" % str(act["boss_anim"])),
			"보스 walk 자산 없음: " + str(act["boss_anim"]))
	assert(FileAccess.file_exists("res://assets/anim/valentino_1_heavy/0.png"))
	assert(FileAccess.file_exists("res://assets/anim/valentino_1_cast/0.png"))

	var normal := Foe.new()
	normal.setup(FoeTiers.get_tier("slime"), 1.0, 1.0)
	var elite_tier := FoeTiers.get_tier("slime")
	elite_tier["midboss"] = true
	elite_tier["name_prefix"] = "타락한 "
	var elite := Foe.new()
	elite.setup(elite_tier, 1.0, 1.0)
	assert(is_equal_approx(elite.max_hp, normal.max_hp * 3.5))
	assert(is_equal_approx(elite._size(), normal._size() * 1.5))
	assert(elite.display_name.begins_with("타락한 "))
	var boss_tier := FoeTiers.get_tier("wraith_knight")
	boss_tier["anim_key"] = "boss_1"
	var boss := Foe.new()
	boss.setup(boss_tier, 1.0, 1.0, true)
	assert(boss._walk_frames.size() == 5, "boss_1_walk이 보스에 연결되지 않았다")
	assert(not boss._attack_frames.is_empty(), "임시 원본 몹 attack이 연결되지 않았다")
	assert(is_equal_approx(boss._size(), normal._size() * 2.0))
	var reaction := Foe.new()
	reaction.setup(FoeTiers.get_tier("slime"), 10.0, 1.0)
	reaction.position = Vector2(200.0, 0.0)
	reaction.stop_x = 200.0
	var reaction_origin := reaction.position
	reaction.take_damage(1.0)
	assert(reaction.hit_offset() > 0.0 and reaction.position == reaction_origin,
		"피격 반응이 기준 전열 좌표를 직접 밀었다")
	reaction.set_visual_frozen(true)
	var frozen_offset := reaction.hit_offset()
	reaction._process(0.10)
	assert(is_equal_approx(reaction.hit_offset(), frozen_offset), "히트스톱 중 반응이 진행됐다")
	reaction.set_visual_frozen(false)
	reaction._process(Foe.HIT_REACT_DUR)
	assert(is_zero_approx(reaction.hit_offset()) and reaction.position == reaction_origin,
		"피격 반응이 기준 위치로 복귀하지 않았다")
	for i in 20:
		reaction.take_damage(0.1)
	assert(reaction.position == reaction_origin, "연타 피격으로 전열 위치가 누적 이동했다")
	assert(is_equal_approx(Balance.skill_hit_mult(0.10, 0.70), 7.0),
		"고공속 스킬의 기본공격 손실 보정이 깨졌다")
	normal.free()
	elite.free()
	boss.free()
	reaction.free()

	var game = load("res://Main.gd").new()
	game.on_foe_hit(null, 1.0)
	assert(is_equal_approx(game._visual_hitstop_t, game.HITSTOP_DUR),
		"전투 시각 히트스톱이 시작되지 않았다")
	var attack_reach := Assets.frame_reach(
		"res://assets/anim/valentino_1_attack", 3, 2.0, true)
	var heavy_reach := Assets.frame_reach(
		"res://assets/anim/valentino_1_heavy", 3, 2.0, true)
	assert(is_equal_approx(attack_reach, 30.0), "attack 불투명 픽셀 사거리 측정 실패")
	assert(is_equal_approx(heavy_reach, 24.0), "heavy 불투명 픽셀 사거리 측정 실패")
	assert(not is_equal_approx(attack_reach, heavy_reach), "모션별 사거리가 구분되지 않는다")
	game.lv["speed"] = 1
	assert(is_equal_approx(game.attack_interval(), 0.60))
	game.lv["speed"] = 500
	assert(game.attack_interval() < 0.60 and game.attack_interval() > 0.10)
	game.lv["speed"] = 1000
	assert(is_equal_approx(game.attack_interval(), 0.10), "공격속도가 Lv1000에서 0.10초가 아니다")
	game.lv["crit"] = 11
	assert(game._stat_effect("crit") == "10%", "치명타 확률 표기는 숫자+%만 쓴다")
	assert(game._base_hit_damage() > game.damage(), "실시간 타격에 치명타 기대값이 빠졌다")
	assert(str(game._next_ready_skill()["key"]) == "drain")
	game._skill_cd["drain"] = 1.0
	assert(str(game._next_ready_skill()["key"]) == "wave")
	game._skill_cd["wave"] = 1.0
	assert(str(game._next_ready_skill()["key"]) == "summon")
	game._skill_cd["summon"] = 1.0
	assert(game._next_ready_skill().is_empty())
	game.lv["speed"] = 1
	var target := Foe.new()
	target.setup(FoeTiers.get_tier("slime"), 10.0, 1.0)
	target.stop_x = game._foe_stop_x(target, 0)
	target.position.x = target.stop_x
	assert(is_equal_approx(target.position.x - target._size() * 0.5, game._front_reach_x()),
		"영웅 칼끝과 적 외곽이 맞닿지 않는다")
	game._phase = "fight"
	assert(game._can_hit_foe(target, "attack") and game._can_hit_foe(target, "heavy"),
		"실제 모션 사거리에서 근접 공격이 닿지 않는다")
	game._skill_target = target
	var hp_before := target.hp
	var drain_hit: float = game._combat_damage() \
		* Balance.skill_hit_mult(game.attack_interval(), game.SKILL_DUR)
	game._skill_cd["drain"] = 0.0
	game._resolve_skill("drain")
	assert(target.hp < hp_before and game.gold > 0.0, "흡혈 강타가 피해/피 회수를 못 한다")
	assert(is_equal_approx(hp_before - target.hp, drain_hit),
		"스킬 모션 동안 놓친 기본공격 피해가 보정되지 않았다")
	var far_target := Foe.new()
	far_target.setup(FoeTiers.get_tier("slime"), 10.0, 1.0)
	far_target.stop_x = game._foe_stop_x(far_target, 1)
	far_target.position.x = far_target.stop_x + 20.0
	assert(not game._can_hit_foe(far_target), "전열 도착 전 몬스터를 공격할 수 있다")
	game._compact_foe_line([target, far_target])
	assert(far_target.stop_x > target.stop_x, "후열 간격이 사라졌다")
	game._compact_foe_line([far_target])
	assert(is_equal_approx(far_target.stop_x, game._foe_stop_x(far_target, 0)),
		"앞 몬스터 사망 뒤 후열이 전진하지 않는다")
	var damage_before: float = game._combat_damage()
	game._resolve_skill("summon")
	assert(game._summon_t == 6.0 and game._combat_damage() > damage_before,
		"망령 소환이 6초 피해 +30%를 못 건다")
	game.stage = 10
	game._phase = "fight"
	game._boss_time = 60.0
	assert(not game._tick_boss_timer(1.0) and is_equal_approx(game._boss_time, 59.0))
	var gacha_ui := Control.new()
	game._build_gacha(gacha_ui)
	var gear_ui := Control.new()
	game._build_gear(gear_ui)
	assert(game._gear_equipped_view.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(game._gear_inventory_view.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"투명 장비 화면이 상단 탭 클릭을 가로챈다")
	game._set_gear_mode("inventory")
	game._set_gear_mode("equipped")
	assert(game._gear_equipped_view.visible and not game._gear_inventory_view.visible,
		"장착 장비 탭으로 돌아가지 못한다")
	game._set_gacha_kind("skill")
	game.gem = 0.0
	game.free_pull_date = ""
	game._pull_gacha(1)
	assert(game.mileage == 1 and int(game.gacha_pulls["skill"]) == 1,
		"하루 무료 스킬 소환이 실행되지 않는다")
	assert(not game.skill_quality.is_empty(), "뽑은 스킬이 자동 장착 후보에 들어오지 않는다")
	game._pull_gacha(1)
	assert(game.mileage == 1, "하루 무료 소환을 두 번 사용했다")
	game._set_gacha_kind("gear")
	game.gem = GachaDefs.COST * 10.0
	game._pull_gacha(10)
	assert(game.gear_inventory.size() > 0 and int(game.gacha_pulls["gear"]) == 10,
		"10연 장비가 보관함에 저장되지 않는다")
	assert(game._gacha_reveal.visible, "장비 소환 결과 연출이 열리지 않는다")
	var inventory_key := str(game.gear_inventory.keys()[0])
	var stored_item: Dictionary = game.gear_inventory[inventory_key]
	game._open_gear_detail(inventory_key)
	assert(game._gear_detail.visible, "보관 장비 상세 팝업이 열리지 않는다")
	game._equip_inventory_item(inventory_key)
	assert(str(game.equipped[str(stored_item["slot"])]["inventory_key"]) == inventory_key,
		"보관 장비를 수동 장착하지 못한다")
	var synth_key := ""
	for candidate in game.gear_inventory:
		if game.gear_inventory[candidate]["rarity"] != "legend":
			synth_key = str(candidate)
			break
	assert(not synth_key.is_empty(), "합성할 비전설 장비가 없다")
	game._gear_selected_key = synth_key
	var level_before := int(game.gear_inventory[synth_key].get("lv", 0))
	var level_cost := GearDefs.upgrade_cost(game.gear_inventory[synth_key])
	game.essence = level_cost
	game._level_up_selected()
	assert(int(game.gear_inventory[synth_key]["lv"]) == level_before + 1 \
		and is_zero_approx(game.essence), "보관 장비 레벨업이 정수를 소모하지 않는다")
	var synth_owned_key := "gear:" + synth_key
	game.gacha_shards[synth_owned_key] = 5
	var rarity_before := GachaDefs.rarity_index(str(game.gear_inventory[synth_key]["rarity"]))
	game._synthesize_selected()
	assert(GachaDefs.rarity_index(str(game.gear_inventory[synth_key]["rarity"])) \
		== rarity_before + 1 and int(game.gacha_shards[synth_owned_key]) == 0,
		"조각 5개 합성이 등급을 올리지 못한다")
	var dismantle_item := GearDefs.make("trinket", 1, GachaDefs.rarity("common"))
	var dismantle_key := ""
	for icon in GearDefs.icon_pool("trinket"):
		if not game.gear_inventory.has(str(icon)):
			dismantle_key = str(icon)
			break
	assert(not dismantle_key.is_empty(), "분해 검사에 쓸 고유 장비가 없다")
	dismantle_item["icon"] = dismantle_key
	game.gear_inventory[dismantle_key] = dismantle_item
	game._gear_selected_key = dismantle_key
	var essence_before_dismantle: float = game.essence
	var salvage := GearDefs.salvage_value(dismantle_item)
	game._dismantle_selected()
	assert(game.gear_inventory.has(dismantle_key), "분해 확인 없이 장비가 사라졌다")
	game._dismantle_selected()
	assert(not game.gear_inventory.has(dismantle_key) \
		and is_equal_approx(game.essence, essence_before_dismantle + salvage),
		"장비 분해가 장비를 지우고 정수를 지급하지 않는다")
	var gems_before: float = game.gem
	game._grant_test_gems()
	assert(is_equal_approx(game.gem, gems_before + 3000.0), "테스트 보석 충전이 작동하지 않는다")
	var gear := GearDefs.roll("weapon", 1)
	game.equipped["weapon"] = gear
	var enhance_cost := GearDefs.upgrade_cost(gear)
	var blood_before: float = game.gold
	game.essence = enhance_cost
	game._enhance("weapon")
	assert(int(gear["lv"]) == 1 and is_zero_approx(game.essence),
		"장비 강화가 정수를 소모하지 않는다")
	assert(is_equal_approx(game.gold, blood_before), "장비 강화가 피를 소모한다")
	target.free()
	far_target.free()
	gacha_ui.free()
	gear_ui.free()
	game.free()

	print("CombatRulesTest OK")
	quit()
