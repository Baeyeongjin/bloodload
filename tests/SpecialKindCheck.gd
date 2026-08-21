extends SceneTree
# 보스 특수 기전 표 — 이펙트만 갈랐다가 규칙이 전부 같은 내려찍기였던
# 자리다(사장님 "고유 패턴"). 표·평균·2연격이 서로 맞는지 본다.

func _init() -> void:
	# 1) 표의 값이 말이 되는가 — 예고 0.3~2초, 피해 1~5배, 타수 1~2.
	for k in FoeTiers.SPECIAL_KIND:
		var sp: Array = FoeTiers.SPECIAL_KIND[k]
		assert(float(sp[0]) >= 0.3 and float(sp[0]) <= 2.0, "%s 예고" % k)
		assert(float(sp[1]) >= 1.0 and float(sp[1]) <= 5.0, "%s 피해" % k)
		assert(float(sp[2]) >= 1.0 and float(sp[2]) <= 3.5, "%s 사거리" % k)
		assert(int(sp[3]) in [1, 2], "%s 타수" % k)

	# 2) 막 보스 다섯이 전부 표에 있고, 기전이 실제로 갈렸는가 —
	#    돌려쓰기를 다시 만들면 여기서 걸린다.
	var seen := {}
	for k in ["wraith_knight", "gargoyle", "frost_golem", "eye_mass",
			"dark_knight"]:
		assert(FoeTiers.SPECIAL_KIND.has(k), "%s 가 기전 표에 없다" % k)
		var sp2: Array = FoeTiers.special_kind(k)
		seen[str(sp2)] = true
	assert(seen.size() >= 4, "막 보스 기전이 %d종뿐 — 돌려쓰고 있다" % seen.size())

	# 3) 평균 배수가 기전을 따라가는가 — 오프라인 판정이 이 값으로 계산한다.
	var n := float(Foe.SPECIAL_EVERY)
	assert(is_equal_approx(Foe.avg_attack_mult(true, false, "dark_knight"),
		(n - 1.0 + 4.0) / n), "처형 평균이 틀렸다")
	assert(is_equal_approx(Foe.avg_attack_mult(true, false, "frost_golem"),
		(n - 1.0 + 1.3 * 2.0) / n), "2연격 평균이 타수를 안 센다")
	assert(is_equal_approx(Foe.avg_attack_mult(true, false),
		(n - 1.0 + Foe.SPECIAL_DMG) / n), "기본형 평균이 옛값과 다르다")
	assert(is_equal_approx(Foe.avg_attack_mult(false, false, "dark_knight"), 1.0),
		"잡몹에 특수 배수가 붙었다")

	# 4) 몹이 표를 실제로 읽는가 + 2연격 타이머가 걸리는가.
	var f := Foe.new()
	f.setup(FoeTiers.get_tier("frost_golem"), 1.0, 0.0, true)
	f.special_swing = true
	assert(is_equal_approx(f.attack_mult(), 1.3), "2연격 한 타가 1.3이 아니다")
	var g := Foe.new()
	g.setup(FoeTiers.get_tier("eye_mass"), 1.0, 0.0, true)
	g.special_swing = true
	var h := Foe.new()
	h.setup(FoeTiers.get_tier("gargoyle"), 1.0, 0.0, true)
	h.special_swing = true
	assert(g.reach() > h.reach() * 1.5, "촉수 사거리가 안 길다")
	print("SpecialKindCheck OK  (기전 %d종)" % seen.size())
	quit()
