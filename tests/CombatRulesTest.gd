extends SceneTree

# 보스/중간보스/자동 스킬의 최소 규칙 검사.
#   godot --headless --path . --script tests/CombatRulesTest.gd

func _init() -> void:
	assert(StageDefs.is_midboss_stage(5) and not StageDefs.is_midboss_stage(4))
	assert(StageDefs.is_boss_stage(10) and not StageDefs.is_boss_stage(9))
	assert(StageDefs.kills_needed(5) == 1 and StageDefs.kills_needed(10) == 1)
	assert(StageDefs.kills_needed(4) == StageDefs.KILLS_PER_STAGE)

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
	assert(is_equal_approx(elite._size(), normal._size() * 1.3))
	assert(elite.display_name.begins_with("타락한 "))
	var boss_tier := FoeTiers.get_tier("wraith_knight")
	boss_tier["anim_key"] = "boss_1"
	var boss := Foe.new()
	boss.setup(boss_tier, 1.0, 1.0, true)
	assert(boss._walk_frames.size() == 5, "boss_1_walk이 보스에 연결되지 않았다")
	assert(not boss._attack_frames.is_empty(), "임시 원본 몹 attack이 연결되지 않았다")
	normal.free()
	elite.free()
	boss.free()

	var game = load("res://Main.gd").new()
	assert(str(game._next_ready_skill()["key"]) == "drain")
	game._skill_cd["drain"] = 1.0
	assert(str(game._next_ready_skill()["key"]) == "wave")
	game._skill_cd["wave"] = 1.0
	assert(str(game._next_ready_skill()["key"]) == "summon")
	game._skill_cd["summon"] = 1.0
	assert(game._next_ready_skill().is_empty())
	var target := Foe.new()
	target.setup(FoeTiers.get_tier("slime"), 10.0, 1.0)
	game._skill_target = target
	var hp_before := target.hp
	game._skill_cd["drain"] = 0.0
	game._resolve_skill("drain")
	assert(target.hp < hp_before and game.gold > 0.0, "흡혈 강타가 피해/피 회수를 못 한다")
	var damage_before: float = game._combat_damage()
	game._resolve_skill("summon")
	assert(game._summon_t == 6.0 and game._combat_damage() > damage_before,
		"망령 소환이 6초 피해 +30%를 못 건다")
	game.stage = 10
	game._phase = "fight"
	game._boss_time = 60.0
	assert(not game._tick_boss_timer(1.0) and is_equal_approx(game._boss_time, 59.0))
	target.free()
	game.free()

	print("CombatRulesTest OK")
	quit()
