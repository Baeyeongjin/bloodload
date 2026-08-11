extends SceneTree

# 스킬 표 자체 점검.
#   godot --headless --script tests/SkillTest.gd

func _init() -> void:
	# **안전장치.** Godot 의 assert 는 실패하면 그 자리에서 함수를 멈추는데, 그러면
	# 아래 quit() 에 못 가서 프로세스가 영영 안 끝난다(타임아웃으로 죽여야 했다).
	# 먼저 시계를 걸어 두면 멈춰도 반드시 끝나고, 종료 코드로 실패가 드러난다.
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("테스트가 안 끝났다 — assert 실패로 멈춘 것이다")
		quit(1))
	var keys := SkillDefs.all_keys()
	# 형태 4 x 등급 5 = 20. 신화가 섞이면 아이콘이 없어서 빈 칸이 된다.
	assert(keys.size() == 20, "스킬이 20종이 아니다: %d" % keys.size())
	for key in keys:
		assert(not SkillDefs.name_of(key).is_empty() and SkillDefs.name_of(key) != key,
			"이름이 없다: " + key)
		assert(FileAccess.file_exists(SkillDefs.icon_path(key)),
			"아이콘 없음: " + SkillDefs.icon_path(key))
		assert(GachaDefs.rarity_index(str(SkillDefs.split(key)[1]))
			<= GachaDefs.SKILL_TOP_INDEX, "신화 스킬이 표에 있다: " + key)
	# 이름은 20개가 전부 달라야 한다 — 겹치면 목록에서 같은 스킬로 보인다.
	var seen := {}
	for key in keys:
		seen[SkillDefs.name_of(key)] = true
	assert(seen.size() == keys.size(), "스킬 이름이 겹친다")

	# 이펙트 자산. 없으면 스킬이 아무 표시 없이 조용히 나간다 — 화면상 티가 안 나서
	# 여기서 잡는다. **20종이 전부 다른 폴더**를 봐야 한다.
	var fx_seen := {}
	for key in keys:
		var fx := SkillDefs.fx_of(key)
		assert(not fx_seen.has(fx), "이펙트가 겹친다: " + fx)
		fx_seen[fx] = true
		for frame in 8:
			assert(FileAccess.file_exists("res://assets/anim/%s/%d.png" % [fx, frame]),
				"이펙트 프레임 없음: %s/%d" % [fx, frame])
	# **프레임 자체가 성한지** 본다. 파일이 있는 것만으로는 모자라다 — PixelLab 결과에
	# 배경이 통째로 딸려온 프레임(전부 불투명)이나 빈 프레임(전부 투명)이 섞이면
	# 화면에서 이펙트가 붉은 네모로 번쩍이거나 중간에 사라진다. 실제로 fx_hit_splash 가
	# 그랬고(2,4번 불투명 / 1번 빈), 눈으로는 "가끔 깨진다"로만 보여서 원인을 못 찾았다.
	# 마지막 프레임이 비는 건 페이드아웃이라 정상이다.
	for key in keys:
		_check_frames(SkillDefs.fx_of(key))

	# 피격 이펙트는 형태별 3종(가호는 버프라 없다).
	for shape in SkillDefs.SHAPE_ORDER:
		var hit := str(SkillDefs.HIT_FX[shape])
		if shape == "ward":
			assert(hit.is_empty(), "버프에 피격 이펙트가 붙어 있다")
			continue
		# 장수는 고정하지 않는다 — 깨진 프레임을 걷어내면 줄어들 수 있고, 몇 장인지가
		# 아니라 **성한지**가 중요하다. _check_frames 가 존재·장수·알파를 다 본다.
		_check_frames(hit)

	# 등급이 오르면 세지고, 레벨이 올라도 세져야 한다.
	assert(SkillDefs.power("strike_legend", 0) > SkillDefs.power("strike_common", 0),
		"등급이 위력에 반영되지 않는다")
	assert(SkillDefs.power("strike_common", 5) > SkillDefs.power("strike_common", 0),
		"레벨이 위력에 반영되지 않는다")

	# 쿨다운은 **정해진 지점에서만** 내려간다. 매 레벨 깎이면 후반에 상시 발동이 된다.
	var cd0 := SkillDefs.cooldown("strike_common", 0)
	assert(is_equal_approx(SkillDefs.cooldown("strike_common", 4), cd0),
		"계단 전인데 쿨다운이 깎였다")
	assert(SkillDefs.cooldown("strike_common", 5) < cd0, "5레벨 쿨다운 감소가 없다")
	assert(SkillDefs.cooldown("strike_common", 10)
		< SkillDefs.cooldown("strike_common", 5), "10레벨 쿨다운 감소가 없다")
	assert(SkillDefs.cooldown("strike_common", 9999)
		>= cd0 * SkillDefs.CD_FLOOR - 0.001, "쿨다운 하한이 없다")

	# 형태별 쿨다운이 서로 달라야 "6칸을 껴도 동시에 안 터진다"가 성립한다.
	var cds := {}
	for shape in SkillDefs.SHAPE_ORDER:
		cds[float(SkillDefs.SHAPES[shape]["cooldown"])] = true
	assert(cds.size() == SkillDefs.SHAPE_ORDER.size(), "형태별 쿨다운이 겹친다")

	# 조합 — 모으기와 펼치기가 **둘 다** 이득이어야 한다.
	var same3 := SkillDefs.combo_power(["strike_common", "strike_rare", "strike_epic"])
	assert(float(same3["strike"]) > 0.0, "같은 형태 3개에 보정이 없다")
	var same2 := SkillDefs.combo_power(["strike_common", "strike_rare"])
	assert(float(same3["strike"]) > float(same2["strike"]), "3개가 2개보다 안 세다")
	var one := SkillDefs.combo_power(["strike_common"])
	assert(is_equal_approx(float(one["strike"]), 0.0), "1개인데 조합 보정이 붙는다")
	var spread := ["strike_common", "wave_common", "field_common", "ward_common"]
	assert(SkillDefs.combo_spread(spread) > 0.0, "네 형태를 모아도 보정이 없다")
	assert(is_equal_approx(SkillDefs.combo_spread(["strike_common", "wave_common"]), 0.0),
		"두 형태만으로 펼치기 보정이 붙는다")
	# 슬롯 6칸은 네 형태를 다 넣고도 두 칸이 남아야 한다 — 그래야 선택지가 생긴다.
	assert(SkillDefs.SLOTS > SkillDefs.SHAPE_ORDER.size(),
		"슬롯이 형태 수 이하라 펼치기 조합에 선택의 여지가 없다")

	# 승급 — 형태는 그대로, 등급만 한 칸 위. 형태가 바뀌면 조합이 도박이 된다.
	for key in keys:
		var next := SkillDefs.promote_key(key)
		var idx := GachaDefs.rarity_index(str(SkillDefs.split(key)[1]))
		if idx >= GachaDefs.SKILL_TOP_INDEX:
			assert(next.is_empty(), "최고 등급인데 승급이 된다: " + key)
			continue
		assert(str(SkillDefs.split(next)[0]) == str(SkillDefs.split(key)[0]),
			"승급하면서 형태가 바뀐다: %s -> %s" % [key, next])
		assert(GachaDefs.rarity_index(str(SkillDefs.split(next)[1])) == idx + 1,
			"승급이 한 칸이 아니다: %s -> %s" % [key, next])
		# **rank 로 잰다, power 가 아니라.** 가호는 피해가 0이라 power 로는 등급을
		# 못 가른다(0 > 0 은 거짓). rank 가 바로 그 경우를 위해 있는 함수다.
		assert(SkillDefs.rank(next, 0) > SkillDefs.rank(key, 0),
			"승급했는데 안 세다: " + key)
		assert(keys.has(next), "승급 결과가 표에 없다: " + next)

	# 조각 비용은 레벨마다 무거워진다.
	for l in 8:
		assert(SkillDefs.shard_cost(l + 1) > SkillDefs.shard_cost(l),
			"조각 비용이 안 오른다: Lv%d" % l)

	# ── 아이콘이 **화면에서** 이름과 맞는가 ────────────────────────────────────
	# 2026-08-10: 사장님 화면에서 "피의 제단"에 감시의 눈 아이콘이 떴다. 파일도 코드도
	# 정상이었고 **`.godot/imported` 캐시가 낡아** 한 등급씩 밀려 나왔다(캐시 안에
	# `sk_blood_field.png` 라는 지금 없는 이름이 남아 있었다 — 이름을 바꾼 이력이다).
	#
	# `.godot` 는 git 에 안 올라가므로 **PC 마다 따로 생긴다.** 파일을 아무리 확인해도
	# 안 잡히고, 고칠 사람이 엉뚱하게 파일을 맞바꾸면 그때 진짜로 어긋난다.
	#
	# 원본 PNG 를 **임포트를 거치지 않고** 직접 디코드해서 맞춰 본다. 투명 픽셀의 RGB 는
	# `fix_alpha_border` 가 건드리므로 **불투명 픽셀만** 본다.
	var icon_checked := 0
	for key in keys:
		var icon_p: String = SkillDefs.icon_path(key)
		var tex: Texture2D = load(icon_p)
		assert(tex != null, "%s 아이콘을 못 읽는다: %s" % [key, icon_p])
		var shown := tex.get_image()
		var bytes := FileAccess.get_file_as_bytes(icon_p)
		if bytes.is_empty():
			continue          # 내보낸 빌드에는 원본 PNG 가 없다 — 그때는 건너뛴다
		var raw := Image.new()
		assert(raw.load_png_from_buffer(bytes) == OK, "원본 PNG 디코드 실패: %s" % icon_p)
		assert(shown.get_size() == raw.get_size(),
			"%s 아이콘 크기가 원본과 다르다" % key)
		var diff := 0
		for y in raw.get_height():
			for x in raw.get_width():
				var src := raw.get_pixel(x, y)
				if src.a < 0.5:
					continue
				if not src.is_equal_approx(shown.get_pixel(x, y)):
					diff += 1
		assert(diff == 0,
			"%s 아이콘이 원본과 다르다 (%d px). `.godot/imported` 를 지우고 다시 임포트할 것"
			% [key, diff])
		icon_checked += 1
	print("아이콘 %d종 원본 대조 통과" % icon_checked)

	print("스킬 %d종 · 쿨다운 격 %.0f 파 %.0f 진 %.0f 가호 %.0f 초"
		% [keys.size(), SkillDefs.cooldown("strike_common", 0),
		SkillDefs.cooldown("wave_common", 0), SkillDefs.cooldown("field_common", 0),
		SkillDefs.cooldown("ward_common", 0)])
	print("위력  커먼 %.1f -> 레전더리 %.1f (같은 형태, 0레벨)"
		% [SkillDefs.power("strike_common", 0), SkillDefs.power("strike_legend", 0)])

	# ── 규칙이 상세 창에 적히는가 ──────────────────────────────────────────
	# **규칙을 넣고 설명을 안 적으면 화면에 안 보이는 규칙이 된다.** 사장님은
	# 몇 명을 때리는지·몇 연타인지를 창에서 읽는데, 표(RULES)만 고치고 문장을
	# 안 고치면 창은 옛말을 계속 한다.
	#
	# **말로 옮겨야 하는 키**를 여기 적어 두고, 그 키가 붙은 스킬의 문장이
	# 비어 있지 않은지 본다. 새 규칙을 표에 넣으면 이 목록에도 넣어야 하고,
	# 넣는 순간 문장이 없으면 여기서 걸린다.
	var must_say := ["max_targets", "bounce", "hits", "ticks", "execute",
		"pierce", "cleave", "pit_kill"]
	print("")
	for key in keys:
		var line := SkillDefs.rule_text(str(key))
		var r: Dictionary = SkillDefs.rule_of(str(key))
		var loud := false
		for k in must_say:
			if r.has(k):
				loud = true
		print("  %-16s %s" % [str(key), line if line != "" else "(없음)"])
		if loud:
			assert(line != "",
				"%s 에 규칙이 있는데 상세 창에 적을 문장이 없다 — 화면에 안 보이는 규칙이다"
				% str(key))
	# 위력 표시가 전투 식과 같은 자를 쓰는가. 창에 "평타의 N%" 를 적는데 그 N 은
	# `power / POWER_NORM` 이다 — 격 커먼이 정확히 100% 여야 기준이 선다.
	var base_pct := SkillDefs.power("strike_common", 0) / SkillDefs.POWER_NORM * 100.0
	print("")
	print("격 커먼 0레벨 = 평타의 %.0f%% (기준)" % base_pct)
	assert(is_equal_approx(base_pct, 100.0),
		"격 커먼이 평타의 %.0f%% 다 — 기준이 100%% 가 아니면 창의 숫자를 못 읽는다"
		% base_pct)
	print("SkillTest OK")
	quit()


# 한 폴더의 프레임이 성한지 본다. 마지막 프레임은 페이드아웃이라 비어도 정상이고,
# 그 앞은 **투명 픽셀이 하나라도** 있어야 한다(전부 불투명 = 배경이 딸려온 것).
#
# **픽셀을 전수로 훑지 않는다.** 20종 x 9프레임 x 4096px = 737k 번 get_pixel 이라
# 이 검사 하나가 테스트 전체 시간을 먹었다. 잡으려는 건 "프레임 통째로 불투명"과
# "프레임 통째로 빈" 두 가지뿐이라 그렇게 촘촘히 볼 이유가 없다:
#   - 빈 프레임: get_used_rect() 가 비면 그게 곧 빈 프레임이다 (엔진이 계산해 준다)
#   - 불투명 프레임: 배경이 딸려오면 **네 모서리가 전부** 불투명하다. 정상 이펙트는
#     가운데서 터지고 모서리는 비어 있으므로 모서리 넷만 봐도 갈린다.
func _check_frames(name: String) -> void:
	var dir := "res://assets/anim/%s" % name
	var i := 0
	var frames: Array[Image] = []
	while ResourceLoader.exists("%s/%d.png" % [dir, i]):
		# **임포트된 텍스처**를 본다. Image.load_from_file 은 원본 파일을 직접 읽어서
		# 경고를 쏟고, 게임이 실제로 그리는 것과 다른 것을 검사하게 된다.
		var tex: Texture2D = load("%s/%d.png" % [dir, i])
		frames.append(tex.get_image())
		i += 1
	assert(frames.size() >= 4, "프레임이 너무 적다(%d장): %s" % [frames.size(), name])
	for f in frames.size():
		var img: Image = frames[f]
		var w := img.get_width() - 1
		var h := img.get_height() - 1
		var corners := [Vector2i(0, 0), Vector2i(w, 0), Vector2i(0, h), Vector2i(w, h)]
		var opaque := 0
		for c in corners:
			if img.get_pixelv(c).a >= 0.999:
				opaque += 1
		assert(opaque < corners.size(),
			"%s/%d 이 네 모서리까지 불투명하다 — 배경이 딸려온 프레임이다" % [name, f])
		if f < frames.size() - 1:
			assert(img.get_used_rect().size.x > 0,
				"%s/%d 이 빈 프레임이다 — 이펙트가 중간에 사라진다" % [name, f])
	# **움직이는가.** 위 검사들은 프레임 수·모서리·빈 프레임만 봐서, **모양이 하나도
	# 안 변하는 이펙트가 전부 통과한다.** 2026-08-06 실측에서 세 종이 그랬다:
	#
	#   fx_sk_uncommon_ward   9장인데 서로 다른 파일이 2종뿐 (진짜 중복 설치)
	#   fx_sk_epic_ward       파일은 8종인데 실루엣 변화 0.0% (색만 바뀐다)
	#   fx_sk_legend_strike   파일은 9종인데 실루엣 변화 0.0%
	#
	# 바이트 비교로는 뒤 둘을 못 잡는다 — 파일이 다르기 때문이다. 화면에서 읽히는 것은
	# **모양**이므로 알파를 본다.
	#
	# 전수(4096px)는 느리다는 게 위 주석이고, **4픽셀 간격 격자**면 프레임당 256점이라
	# 20종을 다 재도 46k 번이다. 정밀도는 떨어지지만 "아예 안 움직인다"는 확실히 걸린다.
	# **같은 그림을 여러 장 깐 것**만 잡는다. 프레임 수·모서리·빈 프레임 검사를 전부
	# 통과하는데 화면에서는 동작이 없다 — `install_motion.py` 머리의 사고 #1 과 같다
	# (다운로드 URL 이 `?frame=N` 이면 조용히 무시되고 같은 이미지가 온다).
	#
	# **실루엣이 안 변하는 것까지는 안 막는다.** 이 게임은 크기·투명도 곡선을 코드로
	# 씌워(`Main._anim_fx`) 자산을 다시 안 뽑고 살리는 설계다 — 원본이 제자리에 있어도
	# 화면에서는 커졌다 사라진다. 그걸 실패로 잡으면 설계와 싸우게 된다.
	# 다만 그 값은 재 뒀다(2026-08-06 실측, 첫 프레임 대비 실루엣 변화율):
	#
	#   fx_sk_epic_ward 0.0%  ·  fx_sk_legend_strike 0.0%  ·  fx_sk_legend_field 1.4%
	#   (가장 큰 쪽은 fx_sk_rare_wave 70%, fx_sk_common_ward 54%)
	#
	# 고유 동작을 원하면 그건 재생성 판단이지 검사로 막을 것이 아니다.
	var seen := {}
	for img in frames:
		seen[img.get_data()] = true
	assert(seen.size() * 2 >= frames.size(),
		"%s 이 %d장인데 서로 다른 그림이 %d종뿐이다 — 같은 프레임을 깔았다"
		% [name, frames.size(), seen.size()])
