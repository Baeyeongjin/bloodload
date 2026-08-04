extends SceneTree

# 스킬 표 자체 점검.
#   godot --headless --script tests/SkillTest.gd

func _init() -> void:
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
	# 피격 이펙트는 형태별 3종(가호는 버프라 없다).
	for shape in SkillDefs.SHAPE_ORDER:
		var hit := str(SkillDefs.HIT_FX[shape])
		if shape == "ward":
			assert(hit.is_empty(), "버프에 피격 이펙트가 붙어 있다")
			continue
		for frame in 6:
			assert(FileAccess.file_exists("res://assets/anim/%s/%d.png" % [hit, frame]),
				"피격 프레임 없음: %s/%d" % [hit, frame])

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
		assert(SkillDefs.power(next, 0) > SkillDefs.power(key, 0),
			"승급했는데 안 세다: " + key)
		assert(keys.has(next), "승급 결과가 표에 없다: " + next)

	# 조각 비용은 레벨마다 무거워진다.
	for l in 8:
		assert(SkillDefs.shard_cost(l + 1) > SkillDefs.shard_cost(l),
			"조각 비용이 안 오른다: Lv%d" % l)

	print("스킬 %d종 · 쿨다운 격 %.0f 파 %.0f 진 %.0f 가호 %.0f 초"
		% [keys.size(), SkillDefs.cooldown("strike_common", 0),
		SkillDefs.cooldown("wave_common", 0), SkillDefs.cooldown("field_common", 0),
		SkillDefs.cooldown("ward_common", 0)])
	print("위력  커먼 %.1f -> 레전더리 %.1f (같은 형태, 0레벨)"
		% [SkillDefs.power("strike_common", 0), SkillDefs.power("strike_legend", 0)])
	print("SkillTest OK")
	quit()
