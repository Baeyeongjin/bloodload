extends SceneTree

# 보스/중간보스/자동 스킬의 최소 규칙 검사.
#   godot --headless --path . --script tests/CombatRulesTest.gd

func _init() -> void:
	# 아래 소환·장비 검사가 굴림 결과에 걸린다. 시드를 안 고정하면 10연이 무엇을
	# 뽑았느냐에 따라 통과 여부가 갈리고, 깨질 때마다 없는 버그를 찾게 된다.
	# (GearTest 와 같은 이유·같은 방식)
	seed(20260804)
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
	assert(is_equal_approx(elite.max_hp, normal.max_hp * FoeTiers.MIDBOSS_HP_MULT))
	assert(is_equal_approx(elite._size(), float(Grid.SPRITE) * 4.0))
	assert(elite.display_name.begins_with("타락한 "))
	var boss_tier := FoeTiers.get_tier("wraith_knight")
	boss_tier["anim_key"] = "boss_1"
	var boss := Foe.new()
	boss.setup(boss_tier, 1.0, 1.0, true)
	assert(boss._walk_frames.size() == 5, "boss_1_walk이 보스에 연결되지 않았다")
	# 보스 전용 attack 은 자산이 없으면 원본 몹 것으로 **조용히** 떨어진다 — 화면상
	# 티가 안 나므로 프레임 수로 구분한다(보스 9장 vs 원본 몹 7장).
	assert(boss._attack_frames.size()
		> Assets.frames("res://assets/anim/wraith_knight_attack").size(),
		"boss_1_attack 전용 자산이 안 붙고 원본 몹 attack 으로 떨어졌다")
	assert(is_equal_approx(boss._size(), float(Grid.SPRITE) * 2.0 * 1.25 * 2.0))
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
	# 사거리는 **실제 경로**(_motion_reach)로 잰다. 예전엔 frame_reach 를 직접 부르며
	# 프레임 번호 3 을 적어 뒀는데, 그러면 타격 지점이 비율로 바뀐 걸 이 검사가 못 본다.
	var attack_reach: float = game._motion_reach("attack")
	var heavy_reach: float = game._motion_reach("heavy")
	assert(is_equal_approx(attack_reach, 30.0), "attack 불투명 픽셀 사거리 측정 실패")
	assert(is_equal_approx(heavy_reach, 24.0), "heavy 불투명 픽셀 사거리 측정 실패")
	assert(not is_equal_approx(attack_reach, heavy_reach), "모션별 사거리가 구분되지 않는다")
	# 타격 지점은 프레임 번호가 아니라 **모션 길이의 비율**이다. 영웅과 몹이 같은 값을
	# 써야 8프레임으로 다시 뽑아도 둘의 타격 규칙이 갈리지 않는다.
	assert(is_equal_approx(game.IMPACT_RATIO, Foe.IMPACT_RATIO),
		"영웅과 몹의 타격 비율이 갈렸다")
	assert(game.IMPACT_RATIO > 0.0 and game.IMPACT_RATIO < 1.0,
		"타격 비율이 모션 밖에 있다")
	game.lv["speed"] = 1
	assert(is_equal_approx(game.attack_interval(), 0.60))
	game.lv["speed"] = 500
	assert(game.attack_interval() < 0.60 and game.attack_interval() > 0.10)
	game.lv["speed"] = 1000
	assert(is_equal_approx(game.attack_interval(), 0.10), "공격속도가 Lv1000에서 0.10초가 아니다")
	game.lv["crit"] = 11
	assert(game._stat_effect("crit") == "10%", "치명타 확률 표기는 숫자+%만 쓴다")
	assert(game._base_hit_damage() > game.damage(), "실시간 타격에 치명타 기대값이 빠졌다")
	# 스킬은 **장착 순서가 곧 우선순위**다. 예전 하드코딩 3종(drain/wave/summon)은
	# M3 에서 SkillDefs 표(형태_등급)로 바뀌었다.
	var equipped: Array[String] = ["strike_common", "wave_common", "ward_common"]
	game.skill_equipped = equipped
	assert(str(game._next_ready_skill()["key"]) == "strike_common")
	game._skill_cd["strike_common"] = 1.0
	assert(str(game._next_ready_skill()["key"]) == "wave_common")
	game._skill_cd["wave_common"] = 1.0
	assert(str(game._next_ready_skill()["key"]) == "ward_common")
	game._skill_cd["ward_common"] = 1.0
	assert(game._next_ready_skill().is_empty())

	# ── 근접 접촉 ────────────────────────────────────────────────────────────
	# 2026-08-04 개편으로 **몹이 영웅 앞에 줄 서지 않는다.** 몹은 화면 기준 고정 칸에
	# 서고 영웅이 달려가 때린다. 그래서 예전 _foe_stop_x/_front_reach_x 는 없어졌다.
	game.lv["speed"] = 1
	var target := Foe.new()
	target.setup(FoeTiers.get_tier("slime"), 10.0, 1.0)
	target.stop_x = game._lane_x(1, 0)
	target.position.x = target.stop_x
	game._phase = "fight"
	game.hero_x = game._strike_spot(target)
	assert(game._can_hit_foe(target, "attack") and game._can_hit_foe(target, "heavy"),
		"칼끝 자리에 섰는데 근접 공격이 닿지 않는다")

	# **대시는 가장 짧은 근접 모션까지 닿게 붙는다.** 기본공격(30)만 보고 멈추면
	# 격 스킬의 heavy(24)가 안 닿아 스킬이 영영 안 나간다 — 실제로 그 버그가 있었다.
	assert(game._front_reach() <= game._motion_reach("attack"),
		"대시 정지 기준이 기본공격 사거리보다 느슨하다")
	game.hero_x = target.position.x \
		- (target._size() * 0.5 + game._motion_reach("attack"))
	assert(game._can_hit_foe(target, "attack"), "기본공격 사거리 계산이 틀렸다")
	assert(not game._in_front_reach(target),
		"기본공격만 닿는 거리인데 대시가 멈춘다 — 그 자리에선 스킬 모션이 안 닿는다")
	game.hero_x = game._strike_spot(target)

	# **도착 전에는 절대 안 맞는다** (HANDOFF 4-5 검증 1번이 보증한다는 규칙).
	# 거리는 닿는 자리로 다시 맞춰 두고 **도착 여부만** 어긋나게 한다 — 안 그러면
	# 거리 검사에 가려서 도착 검사가 통째로 빠져도 이 검사가 통과한다.
	target.position.x = target.stop_x + 40.0
	game.hero_x = game._strike_spot(target)
	assert(not game._can_hit_foe(target, "attack"), "전열 도착 전 몬스터를 공격할 수 있다")
	target.position.x = target.stop_x
	game.hero_x = game._strike_spot(target)
	assert(game._can_hit_foe(target, "attack"), "도착했는데 공격이 안 닿는다")
	# 전진 구간에는 아무도 못 때린다 — 걸어가는 중에 피해가 들어가면 안 된다.
	game._phase = "advance"
	assert(not game._can_hit_foe(target, "attack"), "전진 중에 공격이 들어간다")
	game._phase = "fight"

	# 칸은 서로 겹치지 않는다. 겹치면 두 마리가 같은 자리에 서서 한 마리로 보인다.
	assert(not is_equal_approx(game._lane_x(1, 0), game._lane_x(1, 1)), "오른쪽 칸이 겹친다")
	assert(not is_equal_approx(game._lane_x(1, 0), game._lane_x(-1, 0)), "좌우 칸이 겹친다")

	# 1순위 스킬의 대상이 없으면 **다음 스킬을 본다.** 예전엔 통째로 포기했다 —
	# 격이 안 나가면 그 쿨다운도 안 돌아서 파·진·가호까지 영영 막혔다(스킬 미발동 버그).
	game._skill_action = ""
	game._skill_target = null
	game._hero_hit_t = -1.0
	game._skill_cd.clear()
	game.hero_x = target.position.x - 400.0   # 격(heavy)이 절대 안 닿는 거리
	game._tick_skills(0.0, [target])
	assert(game._skill_action == "wave_common",
		"1순위(격)가 사거리 밖인데 다음 스킬(파)로 안 넘어간다: '%s'" % game._skill_action)
	game._skill_action = ""
	game._skill_target = null
	game._skill_cd.clear()
	game.hero_x = game._strike_spot(target)

	# 격(strike) — 피해 + 20% 피 회수. 모션 동안 놓친 기본공격만큼 최소 피해를 보장한다.
	game._skill_target = target
	var hp_before := target.hp
	var strike_hit: float = game._combat_damage() \
		* Balance.skill_hit_mult(game.attack_interval(), game.SKILL_DUR) \
		* SkillDefs.power("strike_common", 0) / 2.2
	game._skill_cd["strike_common"] = 0.0
	game._resolve_skill("strike_common")
	assert(target.hp < hp_before and game.gold > 0.0, "격이 피해/피 회수를 못 한다")
	assert(is_equal_approx(hp_before - target.hp, strike_hit),
		"스킬 모션 동안 놓친 기본공격 피해가 보정되지 않았다")

	# 뒷칸 몹은 앞칸 사거리 밖이다. **움직이는 건 영웅 쪽**이라 옮겨 가면 닿는다.
	var far_target := Foe.new()
	far_target.setup(FoeTiers.get_tier("slime"), 10.0, 1.0)
	far_target.stop_x = game._lane_x(1, 1)
	far_target.position.x = far_target.stop_x
	game.hero_x = game._strike_spot(target)
	assert(not game._can_hit_foe(far_target), "뒷칸 몹이 앞칸 사거리 안에 들어와 있다")
	game.hero_x = game._strike_spot(far_target)
	assert(game._can_hit_foe(far_target), "뒷칸으로 옮겨 갔는데 공격이 안 닿는다")

	# ── 계측: "공격이 나갔다 안 나갔다" 의 정체 ──────────────────────────────
	# 화면으로는 "가끔 안 나간다"를 못 가른다. **세어서** 본다.
	#
	# 영웅이 어느 칸에 붙어 있을 때, 다른 칸의 몹 몇 마리가 영웅에게 닿는가.
	# 닿지 않는 몹은 모션만 휘두르고 피해가 0이다 — 화면에서는 그게 곧 "안 나간다".
	var probe := Foe.new()
	probe.setup(FoeTiers.get_tier("slime"), 1.0, 1.0)
	var lanes: Array[float] = []
	for side in [1, -1]:
		for line in 3:
			lanes.append(game._lane_x(side, line))
	var reach_hits := 0
	var reach_total := 0
	var worst := 99
	for at in lanes:
		probe.position.x = at
		# 영웅이 그 칸의 몹을 치려고 선 자리
		game.hero_x = at - (probe._size() * 0.5 + game._front_reach() - 8.0)
		var in_reach := 0
		for other in lanes:
			reach_total += 1
			if absf(other - game.hero_x) <= probe.reach():
				reach_hits += 1
				in_reach += 1
		worst = mini(worst, in_reach)
	var reach_rate := float(reach_hits) / float(maxi(1, reach_total))
	print("계측 A 몹 사거리: 6칸 중 평균 %.1f마리가 닿는다 (%.0f%%), 최소 %d마리"
		% [reach_rate * 6.0, reach_rate * 100.0, worst])
	# 붙어 있는 그 한 마리는 **무조건** 닿아야 한다. 이게 깨지면 아무도 안 때린다.
	assert(worst >= 1, "영웅이 붙어 선 칸의 몹조차 안 닿는다")
	# 오프라인이 세는 동시 타격 수는 실측을 넘으면 안 된다 — 넘으면 받는 피해를
	# 과대평가해서 실시간에서는 넘는 구간을 오프라인이 못 넘는다.
	assert(float(game.FOES_IN_REACH) >= reach_rate * 6.0 - 0.5
		and float(game.FOES_IN_REACH) <= float(lanes.size()),
		"FOES_IN_REACH(%d)가 실측 %.1f 과 어긋난다 — 칸 좌표를 옮겼으면 같이 고칠 것"
		% [game.FOES_IN_REACH, reach_rate * 6.0])

	# 닿지 않는 몹은 **스윙을 시작조차 하지 않는다.** 헛스윙은 화면에서 버그로 보인다.
	probe.position.x = 0.0
	probe.stop_x = 0.0
	probe.set_combat_active(true)
	probe.hero_x = 10000.0          # 사거리 밖
	probe._tick_attack(99.0)
	assert(probe._attack_anim < 0.0, "사거리 밖인데 몹이 허공에 휘두른다")
	probe.hero_x = probe.position.x  # 붙었다
	probe._tick_attack(99.0)
	assert(probe._attack_anim >= 0.0, "붙어 있는데 몹이 안 휘두른다")
	probe.free()

	# 스킬 발동 창 — 기본공격 임팩트 전(_hero_hit_t >= 0)에는 스킬이 통째로 막힌다.
	# 공속이 오를수록 창이 좁아진다. 몇 프레임까지 줄어드는지 센다(60fps 기준).
	var slow_window: float = Balance.attack_interval(1) * (1.0 - game.IMPACT_RATIO)
	var fast_window: float = Balance.attack_interval(999999) * (1.0 - game.IMPACT_RATIO)
	print("계측 B 스킬 창: 옛 게이트였다면 1레벨 %.1f프레임 → 만렙 %.1f프레임 (지금은 상시)"
		% [slow_window * 60.0, fast_window * 60.0])
	# 한 프레임보다 좁아지면 스킬은 **운으로만** 나간다 — 그건 버그와 구분이 안 된다.
	assert(fast_window * 60.0 >= 1.0,
		"공속 만렙에서 스킬 발동 창이 한 프레임보다 좁다: %.1f프레임" % [fast_window * 60.0])
	# 게이트를 뺐으므로 **기본공격 임팩트를 기다리는 중에도** 스킬이 나가야 한다.
	# 이게 깨지면 창이 다시 4/7 로 줄어 만렙에서 스킬이 운으로만 나간다.
	game.lv["speed"] = 1
	game._skill_action = ""
	game._skill_cd.clear()
	game._hero_hit_t = 0.2          # 기본공격 임팩트 대기 중
	game._pending_target = target
	target.position.x = target.stop_x
	game.hero_x = game._strike_spot(target)
	game._tick_skills(0.016, [target])
	assert(game._skill_action != "",
		"기본공격 임팩트를 기다리는 동안 스킬이 막힌다 — 발동 창이 다시 좁아졌다")
	# 스킬 시전 중에도 기본공격 쿨다운은 돌아야 스킬 직후 바로 이어진다.
	game._attack_t = 0.5
	game._tick_hero_attack(0.1, [target])
	assert(game._attack_t < 0.5,
		"스킬 시전 중에 기본공격 쿨다운이 멈춘다 — 스킬이 끝나고 또 기다린다")
	game._skill_action = ""
	game._hero_hit_t = -1.0
	game._pending_target = null
	game._skill_cd.clear()

	# 스킬 시전 중 기본공격이 멈추면 그만큼 DPS 가 통째로 빈다.
	var uptime := 0.0
	for shape in SkillDefs.SHAPE_ORDER:
		uptime += float(game.SKILL_DUR) / float(SkillDefs.SHAPES[shape]["cooldown"])
	print("계측 C 스킬 점유율: 네 형태를 다 끼면 시간의 %.0f%%" % [uptime * 100.0])

	# 가호(ward) — 지속 버프. 배수는 **표에서 온다.** 예전엔 _combat_damage 가 1.3 을
	# 따로 적어 둬서 화면 DPS(dps())와 실제 피해가 갈릴 수 있었다.
	var damage_before: float = game._combat_damage()
	game._skill_cd["ward_common"] = 0.0
	game._resolve_skill("ward_common")
	assert(is_equal_approx(game._summon_t, SkillDefs.ward_duration("ward_common", 0))
		and game._combat_damage() > damage_before, "가호가 지속 버프를 못 건다")
	assert(is_equal_approx(game._summon_bonus, SkillDefs.ward_bonus("ward_common")),
		"가호 배수가 표와 다르다")
	# **등급이 가호에도 붙어야 한다.** 예전엔 duration/bonus 를 SHAPES 에서 그대로
	# 복사해서 레전더리 `불멸의 심장`과 커먼 `피의 결계`가 완전히 같은 스킬이었다 —
	# 소환 풀의 4분의 1이 등급 차이 없이 돌고 있었다.
	assert(SkillDefs.ward_bonus("ward_legend") > SkillDefs.ward_bonus("ward_common"),
		"레전더리 가호가 커먼 가호와 같은 배수다")
	for i in GachaDefs.SKILL_TOP_INDEX:
		var lo := str(GachaDefs.RARITIES[i]["key"])
		var hi := str(GachaDefs.RARITIES[i + 1]["key"])
		assert(SkillDefs.ward_bonus("ward_" + hi) > SkillDefs.ward_bonus("ward_" + lo),
			"가호 등급이 %s -> %s 에서 안 오른다" % [lo, hi])
	assert(SkillDefs.ward_duration("ward_common", 5)
		> SkillDefs.ward_duration("ward_common", 0), "가호 지속이 레벨을 안 탄다")
	game.stage = 10
	game._phase = "fight"
	game._boss_time = 60.0
	assert(not game._tick_boss_timer(1.0) and is_equal_approx(game._boss_time, 59.0))
	# 분해 확인창(_ask)과 보상창(_show_reward)은 _hud_root 아래 대화상자 노드를 쓴다.
	# 씬을 통째로 띄우지 않으므로 부모만 만들어 주고 대화상자만 짓는다 —
	# 이게 없으면 _confirm_body 가 nil 이라 "분해 확인" 검사 자체를 못 한다.
	game._hud_root = Control.new()
	game.add_child(game._hud_root)
	game._build_dialogs()
	var gacha_ui := Control.new()
	game._build_gacha(gacha_ui)
	assert(GearDefs.lock_reason("weapon", 1).is_empty())
	assert(not GearDefs.lock_reason("armor", 4).is_empty() \
		and GearDefs.lock_reason("armor", 5).is_empty())
	assert(not GearDefs.lock_reason("trinket", 9).is_empty() \
		and GearDefs.lock_reason("trinket", 10).is_empty())
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
	# M3 에서 skill_quality 는 없어졌다. 보유는 skill_owned(키 -> 레벨)이고,
	# 자동 장착이 켜져 있으면 뽑은 순간 skill_equipped 에 들어간다 —
	# "더 센 걸 뽑았는데 안 끼고 있었다"는 플레이어 잘못이 아니라 UI 잘못이다.
	assert(game.skill_owned.size() == 1, "뽑은 스킬이 보유 목록에 안 들어온다")
	assert(game.skill_equipped.has(str(game.skill_owned.keys()[0])),
		"뽑은 스킬이 자동 장착되지 않는다")
	game._pull_gacha(1)
	assert(game.mileage == 1, "하루 무료 소환을 두 번 사용했다")
	game._set_gacha_kind("weapon")
	game.gem = GachaDefs.COST * 10.0
	game._pull_gacha(10)
	assert(game.gear_inventory.size() > 0 and int(game.gacha_pulls["weapon"]) == 10,
		"10연 무기가 보관함에 저장되지 않는다")
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
		if game.gear_inventory[candidate]["rarity"] != "mythic":
			synth_key = str(candidate)
			break
	assert(not synth_key.is_empty(), "합성할 비신화 장비가 없다")
	game._gear_selected_key = synth_key
	var level_before := int(game.gear_inventory[synth_key].get("lv", 0))
	var level_cost := GearDefs.upgrade_cost(game.gear_inventory[synth_key])
	game.essence = level_cost
	game._level_up_selected()
	assert(int(game.gear_inventory[synth_key]["lv"]) == level_before + 1 \
		and is_zero_approx(game.essence), "보관 장비 레벨업이 정수를 소모하지 않는다")
	var synth_owned_key := "gear:" + synth_key
	game.gacha_shards[synth_owned_key] = 5
	var shards_before := int(game.gacha_shards[synth_owned_key])
	var rarity_before := GachaDefs.rarity_index(str(game.gear_inventory[synth_key]["rarity"]))
	game._synthesize_selected()
	var promoted_key: String = str(game._gear_selected_key)
	assert(promoted_key != synth_key, "합성 후 다음 등급 아이콘으로 바뀌지 않는다")
	assert(GachaDefs.rarity_index(str(game.gear_inventory[promoted_key]["rarity"]))
		== rarity_before + 1, "합성이 등급을 한 칸 올리지 않는다")
	# **재료 쪽 조각만 센다.** 승급 결과 키는 10연에서 이미 조각이 붙어 있을 수 있고,
	# 병합 분기면 중복분 1개가 더 들어온다 — 두 키의 수량을 비교하면 굴림 결과에 따라
	# 통과 여부가 갈린다(실제로 5 -> 3 으로 나와 이 검사가 한 번 틀렸다).
	assert(int(game.gacha_shards.get(synth_owned_key, 0)) < shards_before,
		"합성이 재료 조각을 소모하지 않는다")
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
	# 낱개 분해도 **확인창을 지난다**(2026-08-04). 예전 "버튼을 두 번 누르기"는
	# 없어졌으므로 한 번 더 불러도 창만 다시 뜨지 실행되지 않는다 — 확인을 눌러야 한다.
	game._dismantle_selected()
	assert(game.gear_inventory.has(dismantle_key), "확인 없이 장비가 사라졌다")
	assert(game._confirm_view.visible and game._confirm_action.is_valid(),
		"되돌릴 수 없는 분해가 확인창 없이 실행된다")
	game._confirm_action.call()
	assert(not game.gear_inventory.has(dismantle_key) \
		and is_equal_approx(game.essence, essence_before_dismantle + salvage),
		"확인을 눌러도 분해가 장비를 지우고 정수를 지급하지 않는다")
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
