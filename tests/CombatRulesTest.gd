extends SceneTree

# 보스/중간보스/자동 스킬의 최소 규칙 검사.
#   godot --headless --path . --script tests/CombatRulesTest.gd

func _init() -> void:
	# **안전장치.** Godot 의 assert 는 실패하면 그 자리에서 함수를 멈추는데, 그러면
	# 아래 quit() 에 못 가서 프로세스가 영영 안 끝난다(타임아웃으로 죽여야 했다).
	# 먼저 시계를 걸어 두면 멈춰도 반드시 끝나고, 종료 코드로 실패가 드러난다.
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("테스트가 안 끝났다 — assert 실패로 멈춘 것이다")
		quit(1))
	# 아래 소환·장비 검사가 굴림 결과에 걸린다. 시드를 안 고정하면 10연이 무엇을
	# 뽑았느냐에 따라 통과 여부가 갈리고, 깨질 때마다 없는 버그를 찾게 된다.
	# (GearTest 와 같은 이유·같은 방식)
	seed(20260804)
	assert(StageDefs.is_midboss_stage(5) and not StageDefs.is_midboss_stage(4))
	assert(StageDefs.is_boss_stage(10) and not StageDefs.is_boss_stage(9))
	assert(StageDefs.kills_needed(5) == 1 and StageDefs.kills_needed(10) == 1)
	assert(StageDefs.kills_needed(4) == StageDefs.KILLS_PER_STAGE)
	# 총 구간은 **표에서 읽는다** — 1000 을 박아 뒀더니 500 으로 줄일 때 깨졌다.
	assert(StageDefs.total_stages()
		== StageDefs.MAJOR_STAGE_COUNT * StageDefs.STEPS_PER_STAGE)
	assert(StageDefs.parse("1-1") == 1)
	assert(StageDefs.parse("%d-%d" % [StageDefs.MAJOR_STAGE_COUNT,
		StageDefs.STEPS_PER_STAGE]) == StageDefs.total_stages())
	assert(StageDefs.parse("10") == 10, "기존 내부 단계 플래그가 깨졌다")
	for internal in range(1, StageDefs.total_stages() + 1):
		assert(StageDefs.parse(StageDefs.label(internal)) == internal,
			"단계 표시 왕복 실패: %d -> %s" % [internal, StageDefs.label(internal)])
	assert(StageDefs.major_stage(1) == 1 and StageDefs.step_in_act(1) == 1)
	assert(StageDefs.major_stage(10) == 1 and StageDefs.step_in_act(10) == 10)
	# 끝 구간도 표에서 읽는다(1000 을 박으면 총구간을 줄일 때마다 깨진다).
	var last := StageDefs.total_stages()
	assert(StageDefs.major_stage(last - StageDefs.STEPS_PER_STAGE + 1)
		== StageDefs.MAJOR_STAGE_COUNT and StageDefs.step_in_act(last) == 10)
	assert(StageDefs.is_midboss_stage(last - 5) and StageDefs.is_boss_stage(last))
	# 막은 표 크기만큼 돌고 다시 처음으로 온다. **51 을 박으면 안 된다** —
	# 그건 "막이 5개"라는 뜻이라 막을 늘릴 때마다 깨진다(2026-08-27 실측:
	# 10막으로 늘리자 여기서 빨개졌다). 한 바퀴 뒤 = ACTS.size() x 10 + 1.
	var wrap := StageDefs.ACTS.size() * StageDefs.STEPS_PER_STAGE + 1
	assert(StageDefs.act_of(1) == StageDefs.act_of(wrap),
		"%d개 테마가 순환하지 않는다" % StageDefs.ACTS.size())
	assert(StageDefs.act_of(StageDefs.STEPS_PER_STAGE + 1) != StageDefs.act_of(1),
		"막이 안 바뀐다 — 전부 같은 테마로 읽힌다")
	assert(StageDefs.enemy_power(last) > StageDefs.enemy_power(last - 1))

	# Main 은 class_name 이 없어서 상수를 읽으려면 스크립트를 불러와야 한다.
	var main := load("res://Main.gd")
	for i in StageDefs.act_count():
		var act: Dictionary = StageDefs.ACTS[i]
		assert(FileAccess.file_exists("res://assets/anim/%s_walk/0.png" % str(act["boss_anim"])),
			"보스 walk 자산 없음: " + str(act["boss_anim"]))
		# **배경 한 장이 전투 띠를 통째로 덮어야 한다.** 그래서 하늘 그라데이션도
		# 담 잇기도 없앴는데, 짧은 그림을 하나라도 넣으면 그 보정이 없으니 화면에
		# 빈 자리가 그대로 드러난다.
		assert(Grid.BG_SRC.y * 2 == int(main.VIEW_BOTTOM),
			"배경 원본(%d줄)이 전투 띠(%d)와 안 맞는다 — 위아래에 빈 자리가 생긴다"
			% [Grid.BG_SRC.y, int(main.VIEW_BOTTOM)])
		# 지면 아래는 위젯(상자·가이드)이 앉을 만큼 남아야 한다. 안 남으면 위젯이
		# 다시 몹 몸통을 덮는다 — 화면에서는 "UI 가 캐릭터를 가리네"로만 보인다.
		assert(float((Grid.BG_SRC.y - StageDefs.GROUND_ROW) * 2) >= float(main.WIDGET_BAND),
			"지면(%d행) 아래가 위젯 띠(%d)보다 얕다"
			% [StageDefs.GROUND_ROW, int(main.WIDGET_BAND)])
		# 배경 파일이 실제로 그 규격인지 본다. 짧은 그림을 하나 끼워 넣으면 그 막에서만
		# 화면이 비는데, 다른 막은 멀쩡하니 눈으로는 한참 뒤에야 걸린다.
		var bg: Texture2D = load(str(act["bg"]))
		assert(bg != null and bg.get_size() == Vector2(Grid.BG_SRC),
			"%s 의 배경이 %s 가 아니다 — tools/fit_ground.py 를 안 돌렸다"
			% [str(act["name"]), str(Grid.BG_SRC)])
	# **애니의 프레임은 서로 달라야 한다.** 같은 그림을 9장 깔면 파일 수·크기·사거리
	# 검사는 전부 통과하는데 화면에서는 동작이 통째로 사라진다 — 실제로 커밋
	# 7e13672 가 검 든 attack 9장을 전부 같은 스틸로 넣었고(다운로드 URL 의
	# ?frame= 이 무시돼 같은 이미지를 9번 받았다), 사장님이 "휘두르는 액션이
	# 있어야 할 것 같은데"로 잡아 줄 때까지 아무 검사도 안 걸렸다.
	for motion in ["attack", "walk", "dash", "idle", "heavy", "cast"]:
		var dir := "res://assets/anim/valentino_1_%s" % motion
		var texs := Assets.frames(dir)
		assert(texs.size() >= 2, "%s 프레임이 %d장뿐이다" % [motion, texs.size()])
		var seen := {}
		for tex in texs:
			var img: Image = (tex as Texture2D).get_image()
			seen[Marshalls.raw_to_base64(img.get_data())] = true
		assert(seen.size() == texs.size(),
			"%s 의 프레임이 서로 같다 (고유 %d/%d) — 애니가 아니라 스틸이다"
			% [motion, seen.size(), texs.size()])
	assert(FileAccess.file_exists("res://assets/anim/valentino_1_cast/0.png"))

	var normal := Foe.new()
	normal.setup(FoeTiers.get_tier("slime"), 1.0, 1.0)
	var elite_tier := FoeTiers.get_tier("slime")
	elite_tier["midboss"] = true
	elite_tier["name_prefix"] = "타락한 "
	var elite := Foe.new()
	elite.setup(elite_tier, 1.0, 1.0)
	assert(is_equal_approx(elite.max_hp, normal.max_hp * FoeTiers.MIDBOSS_HP_MULT))
	# 몸집 = SPRITE x2 x (body_scale x2, 최소 2) x BOSS_BODY. 보스·중간보스는
	# 30% 작아졌다(2026-08-12 사장님) — 배수를 여기에 그대로 적어 두면 상수를
	# 고쳐도 이 검사가 안 잡는다.
	assert(is_equal_approx(elite._size(), float(Grid.SPRITE) * 4.0 * Foe.BOSS_BODY))
	assert(elite.display_name.begins_with("타락한 "))
	var boss_tier := FoeTiers.get_tier("wraith_knight")
	boss_tier["anim_key"] = "boss_1"
	var boss := Foe.new()
	boss.setup(boss_tier, 1.0, 1.0, true)
	# 장수를 박아 두지 않는다 — 5로 적어 뒀다가 걷기를 9장으로 다시 뽑자
	# 연결은 멀쩡한데 검사만 죽었다(2026-08-20). 뜻은 "전용 walk 이 붙었나"다:
	# 비어 있지 않고, 실제 폴더의 장수와 같으면 연결된 것이다.
	var walk_n := DirAccess.get_files_at("res://assets/anim/boss_1_walk").size() / 2
	assert(boss._walk_frames.size() > 0
		and boss._walk_frames.size() == walk_n,
		"boss_1_walk이 보스에 연결되지 않았다 (%d/%d)"
		% [boss._walk_frames.size(), walk_n])
	# 보스 전용 attack 은 자산이 없으면 원본 몹 것으로 **조용히** 떨어진다 — 화면상
	# 티가 안 나므로 프레임 수로 구분한다(보스 9장 vs 원본 몹 7장).
	assert(boss._attack_frames.size()
		> Assets.frames("res://assets/anim/wraith_knight_attack").size(),
		"boss_1_attack 전용 자산이 안 붙고 원본 몹 attack 으로 떨어졌다")
	# 특수 패턴 모션도 **조용히 떨어진다** — 없으면 평타가 나가서 화면상 티가 안 난다.
	# 보스 5종 전부 붙어 있어야 한다.
	assert(boss._special_frames.size() == 9,
		"boss_1_special 이 안 붙었다: %d 프레임" % boss._special_frames.size())
	for act_i in range(1, 6):
		for frame in 9:
			assert(FileAccess.file_exists(
				"res://assets/anim/boss_%d_special/%d.png" % [act_i, frame]),
				"보스 특수 프레임 없음: boss_%d_special/%d" % [act_i, frame])
	# 중간보스 내려찍기 8종. **피해는 바닥에 닿는 프레임에 들어가야 한다.**
	# 가로 자(reach_peak_frame)로 재면 안 된다 — 내려찍기는 옆으로 안 뻗어서 가로
	# 뻗음이 거의 안 변하고(용암 두꺼비 30~31), 그 잡음에서 최대를 고르면 아직
	# 들어올리는 중인 f1~f2 가 임팩트가 된다(2026-08-06 실측). 그래서 세로로 잰다.
	# 거미(spider)는 PixelLab object 가 없어 빠져 있다 — PIXELLAB_ARMOR_IDS 참고.
	#
	# **목록을 손으로 적지 않는다.** 로스터에서 뽑아 `_special` 이 있는 것만 검사한다 —
	# 손으로 적으면 모션을 새로 넣고 목록에 안 더해서 검사 없이 들어간다(실제로 8종을
	# 넣은 뒤 13종을 더할 때 그럴 뻔했다). 없는 몹은 평타로 떨어지므로 건너뛴다.
	var slam_keys: Array = []
	for act in StageDefs.ACTS:
		for k in (act["roster"] as Array):
			if not slam_keys.has(str(k)):
				slam_keys.append(str(k))
		if not slam_keys.has(str(act["boss"])):
			slam_keys.append(str(act["boss"]))
	var slam_seen := 0
	for slam_key in slam_keys:
		var slam_dir := "res://assets/anim/%s_special" % slam_key
		if Assets.frames(slam_dir).is_empty():
			continue
		slam_seen += 1
		var slam_frames := Assets.frames(slam_dir)
		assert(slam_frames.size() == 9,
			"%s 내려찍기가 9프레임이 아니다: %d" % [slam_key, slam_frames.size()])
		var heights := []
		for slam_tex in slam_frames:
			heights.append(int(slam_tex.get_image().get_used_rect().size.y))
		var h_lo: int = heights.min()
		var h_hi: int = heights.max()
		# 안 눌리면 내려찍기가 아니다 — 스틸이거나 동작이 통째로 없는 그림이다.
		assert(h_hi - h_lo >= 3,
			"%s 내려찍기가 안 눌린다 (높이 %d~%d)" % [slam_key, h_lo, h_hi])
		assert(int(heights[Assets.slam_peak_frame(slam_dir)]) == h_lo,
			"%s 임팩트가 가장 눌린 프레임이 아니다" % slam_key)
	# 하나도 안 걸리면 자산이 통째로 빠진 것이다 — 위 루프가 조용히 0번 돌면
	# "전부 통과"로 보인다. 8종은 2026-08-06 부터 있다.
	assert(slam_seen >= 8, "내려찍기 자산이 %d 종밖에 없다" % slam_seen)

	# ── 몹은 **바닥에 앉아 있어야** 한다 ────────────────────────────────────
	# `Foe._draw` 는 원점이 발밑이라, PNG 아래쪽 투명 여백이 그대로 "뜬 높이"가
	# 된다. 게다가 화면에서는 원본 px 이 아니라 `여백 x 그린높이 / 원본높이`
	# 만큼 커진다 — 32px 원본을 61px 로 그리는 몹은 여백 7px 이 화면에서 13px 다.
	#
	# 사장님(2026-08-27): "캐릭터랑 보스가 바닥보다 조금 위에있는것같아서".
	# 실측하니 기존 몹은 0~5px 뜨는데 새로 뽑은 것 일부가 8~13px 떠 있었다.
	# 눈으로는 "왠지 어색하다"까지밖에 안 가는 종류라 자로 재야 잡힌다.
	# 고치는 도구는 tools/seat_sprites.py (유닛을 통째로 같은 만큼 내린다 —
	# 프레임마다 0 으로 맞추면 걷기의 흔들림과 내려찍기의 눌림이 평평해진다).
	for act2 in StageDefs.ACTS:
		var seat_keys: Array = (act2["roster"] as Array).duplicate()
		seat_keys.append(str(act2["boss"]))
		for sk in seat_keys:
			var sf := Assets.frames("res://assets/anim/%s_walk" % str(sk))
			if sf.is_empty():
				continue
			var low := 999
			var src_h := 1
			for tex in sf:
				var img: Image = tex.get_image()
				src_h = img.get_height()
				var used: Rect2i = img.get_used_rect()
				low = mini(low, src_h - (used.position.y + used.size.y))
			if low >= 999:
				continue
			# 그려지는 높이는 Foe._size() 와 같은 식으로 낸다.
			var tier2: Dictionary = FoeTiers.get_tier(str(sk))
			var bsz := float(tier2.get("size", 1.0))
			var is_b: bool = str(sk) == str(act2["boss"])
			var drawn := float(Grid.SPRITE) * 2.0 * (maxf(2.0, bsz * 2.0) * Foe.BOSS_BODY
				if is_b else bsz)
			var float_px := float(low) * drawn / float(src_h)
			# 기존 몹 최대가 5.1px(ice_wisp) 라 8 을 넘으면 확실히 이상한 것이다.
			assert(float_px < 8.0,
				"%s 가 바닥에서 %.1fpx 떠 있다 (여백 %d) — tools/seat_sprites.py %s"
				% [str(sk), float_px, low, str(sk)])
	# 특수 스윙은 평타보다 아프고 멀리 닿는다. 오프라인 평균 배수는 그 사이에 있어야
	# 한다 — 1.0 이면 특수를 안 세는 것이고, SPECIAL_DMG 면 매번 특수로 치는 셈이다.
	var avg := Foe.avg_attack_mult(true, false)
	assert(avg > 1.0 and avg < Foe.SPECIAL_DMG,
		"보스 평균 피해 배수가 평타~특수 사이가 아니다: %f" % avg)
	assert(is_equal_approx(Foe.avg_attack_mult(false, false), 1.0),
		"잡몹에 특수 패턴 배수가 붙었다")
	assert(is_equal_approx(boss._size(),
		float(Grid.SPRITE) * 2.0 * 1.25 * 2.0 * Foe.BOSS_BODY))
	# **모션 캔버스 비율.** _draw 는 텍스처를 _size() 상자에 늘려 그리므로, 공격 모션만
	# 큰 캔버스로 뽑으면 여백까지 눌려 몹이 작아진다. 그래서 비율(모션 캔버스 / 걷기
	# 캔버스)만큼 상자를 키운다.
	#
	# 걷기 자신은 기준이므로 **늘 1.0** 이다 — 이게 깨지면 기준을 잘못 잡은 것이다.
	# 다른 모션은 여백을 주려고 캔버스를 키울 수 있으니 1.0 을 강요하지 않는다.
	# 대신 **깔끔한 정수배**여야 한다: 어긋난 비율(1.5 같은)은 잉크가 반 픽셀에 걸려
	# 도트가 뭉개진다.
	for f in [normal, boss]:
		var walk: Array = f._walk_frames
		if walk.is_empty():
			continue
		assert(is_equal_approx(f._art_ratio(walk[0]), 1.0),
			"걷기 프레임의 캔버스 비율이 1.0 이 아니다: %f" % f._art_ratio(walk[0]))
		var atk: Array = f._attack_frames
		if not atk.is_empty():
			var ratio: float = f._art_ratio(atk[0])
			assert(ratio >= 1.0 and is_equal_approx(ratio, roundf(ratio)),
				"공격 캔버스 비율이 정수배가 아니다: %f — 도트가 뭉개진다" % ratio)
	# 특수 패턴 — **보스·중간보스만**, 정해진 주기마다, 예고하는 동안은 멈춘다.
	# 화면에서는 예고 원이 0.85초만 떴다 사라져서 눈으로는 있는지조차 확인이 어렵다.
	# 여기서 스윙을 세어 확정한다.
	var pat := Foe.new()
	pat.setup(boss_tier, 1.0, 1.0, true)
	pat.combat_active = true
	pat.engaged = true                    # 보스는 혼자라 실전에서 늘 교전 상태다
	pat.hero_x = pat.position.x           # 사거리 검사를 통과시킨다
	var base_reach := pat.reach()
	var tells := 0
	var swings := 0
	var was_telling := false
	for _i in 4000:                        # 60fps 로 약 67초
		var before := pat.special_swing
		pat._tick_attack(1.0 / 60.0)
		if pat.telling() and not was_telling:
			tells += 1
		was_telling = pat.telling()
		if pat.special_swing and not before:
			swings += 1
	assert(tells > 0, "보스가 특수 패턴을 한 번도 예고하지 않는다")
	assert(tells == swings, "예고 없이 특수 패턴이 나갔다: 예고 %d / 발동 %d" % [tells, swings])
	# 예고 중에는 착탄 범위가 넓어져 있어야 한다 — 발밑에 그리는 원이 곧 이 값이라
	# 다르면 "원 밖인데 맞았다"가 된다.
	pat.special_swing = true
	assert(pat.reach() > base_reach * 1.5, "특수 패턴인데 착탄 범위가 그대로다")
	assert(pat.attack_mult() > 1.0, "특수 패턴인데 피해가 그대로다")
	pat.special_swing = false
	assert(is_equal_approx(pat.reach(), base_reach), "평타인데 범위가 특수 패턴이다")
	# 잡몹에는 안 붙는다. 여섯 마리가 동시에 예고하면 바닥이 원으로 덮인다.
	var mob := Foe.new()
	mob.setup(FoeTiers.get_tier("slime"), 1.0, 1.0)
	mob.combat_active = true
	mob.hero_x = mob.position.x
	for _i in 4000:
		mob._tick_attack(1.0 / 60.0)
		assert(not mob.telling() and not mob.special_swing, "잡몹이 특수 패턴을 쓴다")
	pat.free()
	mob.free()

	# 영웅이 **몸을 겹치지 않고 서면서 닿아야** 한다. 이 둘이 서로 다른 값을 보면
	# 만족하는 거리가 아예 없어져서, 영웅이 몹 안으로 파고든 채로 싸운다.
	# 눈으로는 "겹쳐 보이네" 정도라 원인이 사거리라는 걸 못 찾는다.
	var game = load("res://Main.gd").new()
	var stand := Foe.new()
	stand.setup(FoeTiers.get_tier("slime"), 1.0, 1.0)
	var body_half := float(main.BODY_HALF)
	var gap: float = stand._size() * 0.5 + body_half    # _strike_spot 과 같은 식
	# 몸통 밖에 선다.
	assert(gap >= stand._size() * 0.5 + 24.0, "서는 자리가 몹 몸통 안이다")
	# 그리고 거기서 **휘두르고**(_in_front_reach) **닿아야**(_can_hit_foe) 한다.
	# 둘 다 (|dx| - 몹절반) 을 max(사거리, BODY_HALF) 와 잰다. 셋 중 하나만 빠져도
	# 영웅이 제 자리에 서 놓고 dash 만 반복한다 — 실제로 _in_front_reach 를 빼먹어
	# 공격이 가끔 한 대씩만 나갔다(2026-08-05).
	var foe_gap := gap - stand._size() * 0.5
	assert(foe_gap <= body_half + 1.0,
		"그 자리에 서면 공격이 안 닿는다 — _can_hit_foe 가 갈렸다")
	assert(foe_gap <= maxf(game._front_reach(), body_half) + 1.0,
		"그 자리에 서면 휘두르지도 않는다 — _in_front_reach 가 갈렸다")
	stand.free()

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

	game.on_foe_hit(null, 1.0)
	assert(is_equal_approx(game._visual_hitstop_t, game.HITSTOP_DUR),
		"전투 시각 히트스톱이 시작되지 않았다")
	# 사거리는 **실제 경로**(_motion_reach)로 잰다. 예전엔 frame_reach 를 직접 부르며
	# 프레임 번호 3 을 적어 뒀는데, 그러면 타격 지점이 비율로 바뀐 걸 이 검사가 못 본다.
	var attack_reach: float = game._motion_reach("attack")
	var heavy_reach: float = game._motion_reach("heavy")
	# 값은 **그림에서 잰 것**이다 — 8프레임 재생성(30/24 -> 20/18), 그 뒤 크게 휘두르는
	# 포즈로 attack 만 다시 뽑아 20 -> 26 이 됐다(2026-08-05).
	# 여기 숫자를 손으로 고치는 게 맞다. 검사가 없으면 그림 교체가 사거리를 조용히
	# 바꿔서 스킬이 안 나가는 버그로 돌아온다(2026-08-04 에 실제로 그랬다).
	# 임팩트를 그림의 최대 뻗음 프레임으로 옮기면서 값이 커졌다(맨손 26 -> 검 30 ->
	# 최대프레임 46). 그림을 다시 뽑으면 이 숫자도 같이 갱신한다 — 검사가 없으면
	# 그림 교체가 사거리를 조용히 바꿔 스킬이 안 나가는 버그로 돌아온다.
	assert(attack_reach >= 40.0,
		"attack 사거리가 40 미만이다: %.1f — 여백 캔버스로 크게 휘두르는 그림인지 확인할 것"
		% attack_reach)
	# **피해는 무기가 가장 뻗은 순간에 들어가야 한다.** heavy 를 한 번 폐기한 이유가
	# 그것이었다 — 칼을 뒤로 뺀 자세에 피해가 들어가 "안 맞았는데 맞았다"로 보였다.
	# 고정 비율(IMPACT_RATIO)로는 안 된다: 생성 결과가 프롬프트의 프레임 지시를 안
	# 지킨다(2026-08-06 실측 — 프레임 4 를 명시했는데 attack f2, heavy f1 에 극단).
	# 그래서 _impact_frame 이 그림에서 읽는다. 여기서 검사하는 것은 둘이다.
	# **무기가 뻗는 모션만 본다.** 걷기·대시는 다리가 좌우로 벌어져서 폭이 그대로인데도
	# 자세는 크게 바뀐다(실측: 방향 고정 walk 은 폭 4px 인데 실루엣 18% 변화).
	# 실루엣 변화율은 픽셀을 전수 훑어야 해서 GDScript 로는 너무 느리다 —
	# **그쪽은 tools/install_motion.py 가 자산 설치 시점에 막는다**(방향 고정, 스틸,
	# 실루엣 변화, 자동 반전 후 튐까지). 여기서는 무기 사거리만 지킨다.
	for motion in ["attack", "heavy"]:
		var dir := "res://assets/anim/valentino_1_%s" % motion
		var n := Assets.frames(dir).size()
		var reaches: Array[float] = []
		for f in n:
			# flipped=true — 그림이 **왼쪽을 보므로** 무기는 왼쪽으로 뻗는다.
			# false 로 재면 반대쪽 끝을 봐서 뻗음이 거꾸로 읽힌다.
			reaches.append(Assets.frame_reach(dir, f, 2.0, true))
		var lo: float = reaches.min()
		var hi: float = reaches.max()
		# 1. 무기가 실제로 뻗어야 한다. 32px 시절엔 3~8px 라 "안 산다"로 보였다.
		assert(hi - lo >= 10.0,
			"%s 의 무기 뻗음 변화가 %.0f 화면px 뿐이다 — 여백 캔버스로 뽑을 것"
			% [motion, hi - lo])
		# 2. 코드가 그 최대 프레임을 임팩트로 쓰고 있어야 한다.
		if motion in ["attack", "heavy"]:
			var impact: int = game._impact_frame(motion)
			assert(is_equal_approx(reaches[impact], hi),
				"%s 임팩트(프레임%d)가 최대 뻗음이 아니다: %.0f (최대 %.0f)"
				% [motion, impact, reaches[impact], hi])
	# heavy 18 -> 28 (2026-08-05 재생성). 예전 그림은 **임팩트 프레임이 애니메이션에서
	# 가장 오므린 순간**이었다 — 칼을 뒤로 뺀 자세에 피해가 들어가 "안 맞았는데 맞았다"로
	# 보였다. 사거리 판정은 max(사거리, BODY_HALF)=30 이라 그대로지만 손맛이 달라진다.
	assert(heavy_reach >= 40.0, "heavy 사거리가 40 미만이다: %.1f" % heavy_reach)
	# 타격 지점은 프레임 번호가 아니라 **모션 길이의 비율**이다. 영웅과 몹이 같은 값을
	# 써야 8프레임으로 다시 뽑아도 둘의 타격 규칙이 갈리지 않는다.
	assert(is_equal_approx(game.IMPACT_RATIO, Foe.IMPACT_RATIO),
		"영웅과 몹의 타격 비율이 갈렸다")
	assert(game.IMPACT_RATIO > 0.0 and game.IMPACT_RATIO < 1.0,
		"타격 비율이 모션 밖에 있다")
	game.lv["speed"] = 1
	assert(is_equal_approx(game.attack_interval(), 0.60))
	game.lv["speed"] = 7500
	assert(game.attack_interval() < 0.60 and game.attack_interval() > 0.10)
	# 15분할: 바닥은 옛 Lv995.5 = 새 14,919 다(0.6 x 0.9982^994.53 = 0.10).
	game.lv["speed"] = int(StatDefs.of("speed")["cap"])
	assert(is_equal_approx(game.attack_interval(), 0.10),
		"공격속도가 만렙에서 0.10초가 아니다: %.4f" % game.attack_interval())
	# 15분할: 옛 Lv11(=10%) 은 새 151 이다. 표기도 소수 1자리가 됐다 —
	# 레벨당 0.067%p 라 정수로 적으면 15레벨을 눌러야 숫자가 변한다.
	game.lv["crit"] = 1 + 15 * 10
	assert(game._stat_effect("crit") == "10.0%",
		"치명타 확률 표기가 바뀌었다: %s" % game._stat_effect("crit"))
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
	target.stop_x = game.FRONT_X
	target.position.x = target.stop_x
	game._phase = "fight"
	game.hero_x = game._strike_spot(target)
	assert(game._can_hit_foe(target, "attack") and game._can_hit_foe(target, "heavy"),
		"칼끝 자리에 섰는데 근접 공격이 닿지 않는다")

	# **대시가 멈추는 자리에서는 어떤 근접 모션이든 닿아야 한다.** 안 그러면 영웅이
	# 제 자리에 서 놓고 공격이 영영 안 나간다 — 실제로 두 번 그랬다: 2026-08-04 에
	# 격 스킬 heavy 가 안 닿았고, 2026-08-05 에 _in_front_reach 만 옛 기준을 보고
	# 있어서 기본공격이 가끔 한 대씩만 나갔다("기본공격이 너무 느리다").
	#
	# 지금은 서는 자리·휘두름·피해 셋 다 BODY_HALF 를 바닥으로 깐다. 어느 하나가
	# 바닥을 빠뜨리면 여기서 걸린다.
	var stop_gap: float = maxf(game._front_reach(), game.BODY_HALF)
	for m in ["attack", "heavy"]:
		var hit_gap: float = maxf(game._motion_reach(m), game.BODY_HALF)
		assert(stop_gap <= hit_gap + 0.01,
			"대시가 멈추는 자리(%.0f)에서 %s 가 안 닿는다(%.0f)" % [stop_gap, m, hit_gap])
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

	# 줄 간격은 서 있는 몹끼리 겹치지 않을 만큼 벌어져야 한다. 겹치면 두 마리가
	# 한 마리로 보인다. 큰 몹(1.5배)의 잉크 절반이 48 남짓이라 96 이 하한이다.
	assert(game.FOE_GAP >= 96.0, "줄 간격이 좁아 큰 몹끼리 겹친다: %.0f" % game.FOE_GAP)

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

	# 격(strike) — 피해. 모션 동안 놓친 기본공격만큼 최소 피해를 보장한다.
	# **피 회수는 없어졌다**(2026-08-20): 혈액은 배급으로만 들어온다(요구 4).
	game._skill_target = target
	var hp_before := target.hp
	var gold_before: float = game.gold
	var strike_hit: float = game._combat_damage() \
		* Balance.skill_hit_mult(game.attack_interval(), game.SKILL_DUR) \
		* SkillDefs.power("strike_common", 0) / 2.2
	game._skill_cd["strike_common"] = 0.0
	game._resolve_skill("strike_common")
	assert(target.hp < hp_before, "격이 피해를 못 준다")
	# 전투가 혈액을 만들면 안 된다 — 그 예외가 하나라도 남으면 소득이 다시
	# DPS 지수를 타고, 그러면 비용을 지수로 묶어야 해서 레벨을 못 판다.
	assert(is_equal_approx(game.gold, gold_before),
		"전투가 혈액을 만들었다: %.2f -> %.2f" % [gold_before, game.gold])
	assert(is_equal_approx(hp_before - target.hp, strike_hit),
		"스킬 모션 동안 놓친 기본공격 피해가 보정되지 않았다")

	# 뒷칸 몹은 앞칸 사거리 밖이다. **움직이는 건 영웅 쪽**이라 옮겨 가면 닿는다.
	var far_target := Foe.new()
	far_target.setup(FoeTiers.get_tier("slime"), 10.0, 1.0)
	far_target.stop_x = game.FRONT_X + game.FOE_GAP
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
	for line in 3:
		lanes.append(game.FRONT_X + float(line) * game.FOE_GAP)
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
	# **순차 교전 게이트.** 기다리는 몹은 코앞에 영웅이 있어도 휘두르면 안 되고,
	# 교전으로 넘어오면 휘둘러야 한다. 깨지는 방향이 둘 다 실제 사고다: 게이트가
	# 없으면 여럿이 한꺼번에 때리고(옛 동작), 쿨다운까지 같이 안 멈추면 교전
	# 순간 밀린 쿨다운이 연타로 터진다.
	var gate := Foe.new()
	gate.setup(FoeTiers.get_tier("slime"), 1.0, 1.0)
	gate.set_combat_active(true)
	gate.position.x = 100.0
	gate.stop_x = 100.0
	gate.hero_x = 100.0
	gate.engaged = false
	var dt := 1.0 / 60.0
	var swung := false
	for i in 240:
		gate._tick_attack(dt)
		if gate.swinging():
			swung = true
	assert(not swung, "기다리는 몹이 휘둘렀다 — 순차 교전 게이트가 깨졌다")
	gate.engaged = true
	for i in 240:
		gate._tick_attack(dt)
		if gate.swinging():
			swung = true
	assert(swung, "교전 몹이 4초가 지나도 안 휘두른다")
	gate.free()
	# **앵커에서 전열의 몹에 닿아야 한다.** 전열을 영웅 몸통 두 개 폭에 붙여 뒀으므로
	# (FRONT_X 주석) 영웅은 자리를 안 옮기고 그대로 친다 — 안 닿으면 영영 못 때린다.
	# 겹치지도 않아야 한다: 겹치면 몹 몸통 안에 서서 팬다.
	var anchor_probe := Foe.new()
	anchor_probe.setup(FoeTiers.get_tier("slime"), 10.0, 1.0)
	anchor_probe.stop_x = game.FRONT_X
	anchor_probe.position.x = game.FRONT_X
	assert(game._stand_ok(anchor_probe, game.HERO_X),
		"앵커(%.0f)에서 전열 몹(%.0f)이 제 자리가 아니다 — 닿지 않거나 겹친다"
		% [game.HERO_X, game.FRONT_X])
	anchor_probe.free()
	# 앵커는 화면 **왼쪽 절반**에 있어야 한다. 방향이 하나라 앞쪽(오른쪽)을 넓게 써야
	# 다가오는 놈들이 보인다 — 레퍼런스 영상도 영웅이 42% 자리다(실측).
	assert(game.HERO_X < float(Grid.BG.x) * 0.5,
		"앵커가 화면 절반보다 오른쪽이다: %.0f" % game.HERO_X)
	# 전열은 화면 안이어야 한다 — 밖이면 싸우는 걸 못 본다.
	assert(game.FRONT_X < float(Grid.BG.x) - 40.0,
		"전열이 화면 밖이다: %.0f" % game.FRONT_X)
	# **한 마리당 달리는 시간**이 눈에 보일 만큼은 되어야 한다. 0.3초 미만이면
	# 달려가는 그림이 안 남고, 그건 곧 "찾아간다"가 사라진 것이다.
	var run: float = game.FOE_GAP / game.TRAVEL_SPEED
	assert(run > 0.3, "한 마리당 달리는 시간이 너무 짧다: %.2f 초" % run)

	# 닿지 않는 몹은 **스윙을 시작조차 하지 않는다.** 헛스윙은 화면에서 버그로 보인다.
	probe.position.x = 0.0
	probe.stop_x = 0.0
	probe.set_combat_active(true)
	probe.engaged = true            # 사거리 검사만 보려는 것 — 교전 게이트는 위에서 따로 쟀다
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
	# 조합 확인창(_ask)과 보상창(_show_reward)은 _hud_root 아래 대화상자 노드를 쓴다.
	# 씬을 통째로 띄우지 않으므로 부모만 만들어 주고 대화상자만 짓는다.
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
	var synth_owned_key := "gear:" + synth_key
	# 조합 확률·천장 (2026-08-25): 조각이 모자라면 시도 자체가 안 된다.
	game.gacha_shards[synth_owned_key] = GearDefs.FUSE_SHARDS - 1
	assert(game._synthesize(synth_key).is_empty() and not game._fuse_failed,
		"조각이 모자란데 조합이 굴렀다")
	# 천장 직전으로 맞추면 이번 시도는 **확정**이라 굴림 없이 검사가 결정적이다.
	game.gacha_shards[synth_owned_key] = GearDefs.FUSE_SHARDS
	# 천장은 **등급 통**이다(2026-08-25) — 키가 등급 키다.
	var synth_rar := str(game.gear_inventory[synth_key]["rarity"])
	game.fuse_pity[synth_rar] = GearDefs.fuse_pity(game.gear_inventory[synth_key]) - 1
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
	assert(not game.fuse_pity.has(synth_rar), "성공했는데 등급 천장이 안 지워졌다")
	var gems_before: float = game.gem
	game._grant_test_gems()
	assert(is_equal_approx(game.gem, gems_before + 3000.0), "테스트 보석 충전이 작동하지 않는다")
	target.free()
	far_target.free()
	gacha_ui.free()
	gear_ui.free()
	game.free()

	print("CombatRulesTest OK")
	quit()
