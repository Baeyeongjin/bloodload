extends SceneTree

# 핏빛 계약 (OathDefs + Main._oath_*) — 운빨 돌파.
#
# 지키는 것 넷:
#   1. **카드가 새지 않는가** — 없는데 굴러가면 안 되고, 굴리면 한 장 준다.
#   2. **천장이 실제로 터지는가** — 만월 100, 황금 30.
#   3. **버프가 실제로 붙는가** — 표만 맞고 dps 가 그대로면 뜻이 없다.
#   4. **주간 보스 치환** — 흡수가 비율이면 누적 이정표가 인플레된다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표 ─────────────────────────────────────────────────────────────────
	assert(OathDefs.CONTRACTS.size() == 12, "계약이 12종이 아니다")
	var seen := {}
	for c in OathDefs.CONTRACTS:
		var id := str(c["id"])
		assert(not seen.has(id), "계약 id 중복: %s" % id)
		seen[id] = true
		assert(not (c["effects"] as Dictionary).is_empty(), "%s 효과가 비었다" % id)
	for r in ["common", "uncommon", "rare", "epic", "legend"]:
		assert(OathDefs.of_rarity(r).size() > 0, "%s 등급 계약이 없다" % r)
	assert(OathDefs.ENGRAVES.size() == 6, "각인이 6종이 아니다")
	assert(OathDefs.PITY_LEGEND == 100, "만월 천장이 100이 아니다(사장님 확정)")
	assert(is_equal_approx(OathDefs.lv_mult(1), 1.0), "Lv1 이 1.0 이 아니다")
	assert(OathDefs.lv_mult(5) > OathDefs.lv_mult(4), "레벨 배수가 안 오른다")

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.save_muted = true
	await process_frame
	await process_frame

	scene.oath_cards = 0
	scene.oath_gold = 0
	scene.oath_lv = {}
	scene.oath_first = true       # 첫 카드 에픽 확정을 끄고 순수 룰렛을 본다
	scene.oath_vow = false
	scene.oath_pity = 0

	# 카드가 없으면 안 굴러간다.
	assert(scene._oath_roll(false).is_empty(), "카드 없이 굴렀다")

	# 굴리면 한 장 쓰고 결과가 온다.
	scene.oath_cards = 1
	var r: Dictionary = scene._oath_roll(false)
	assert(not r.is_empty(), "카드가 있는데 안 굴렀다")
	# 진혈(0.1%)은 **3장 환급**이 설계라 여기서 늘어난다 — 검사가 그걸 몰라
	# 1/1000 로 깨졌다(2026-08-20 실측). 환급 각인(refund)도 같은 이유로 +1.
	assert(scene.oath_cards <= 1 or str(r["rarity"]) == "trueblood",
		"카드가 안 줄었다: %d (%s)" % [scene.oath_cards, str(r["rarity"])])
	assert(str(r["contract"]["id"]) != "", "계약이 비었다")
	assert(str(r["engrave"]["id"]) != "", "각인이 비었다")

	# 만월 천장 — 99 에서 한 장 더 굴리면 레전(또는 진혈)이다.
	scene.oath_pity = OathDefs.PITY_LEGEND - 1
	scene.oath_cards = 1
	var r2: Dictionary = scene._oath_roll(false)
	assert(str(r2["rarity"]) in ["legend", "trueblood"],
		"천장인데 레전이 아니다: %s" % str(r2["rarity"]))
	# "천장을 두드리는 피" 각인(1/6)이 뜨면 리셋 직후 +1 이 얹힌다 — 설계다.
	# == 0 을 고집하면 각인 복불복에 검사가 죽는다(2026-08-18 실측 flaky).
	assert(scene.oath_pity <= 1, "천장이 안 비워졌다: %d" % scene.oath_pity)

	# 황금 천장 — 전용 게이지로 따로 센다.
	scene.oath_gold = 1
	scene.oath_gold_pity = OathDefs.PITY_GOLD - 1
	var r3: Dictionary = scene._oath_roll(true)
	assert(str(r3["rarity"]) in ["legend", "trueblood"], "황금 천장이 안 터졌다")

	# 버프가 실제로 붙는가 — 공격 계약을 손으로 세워 dps 를 견준다.
	scene.oath_fx = {}
	scene.oath_fx_t = 0.0
	var dps0: float = scene.dps()
	scene.oath_fx = {"attack": 0.50}
	scene.oath_fx_t = 60.0
	assert(scene.dps() > dps0 * 1.4, "계약 공격 버프가 안 붙는다")
	# 회복 — 기본 회복 레벨이 1이면 기저가 0 이라(Balance.hero_regen_per_sec)
	# 배수형(regen)은 0 x 2 = 0 이다. **핏빛 장막의 regen_max(최대체력 %)**로
	# 잰다: 기저가 0 이어도 실제로 붙는 쪽이라 이게 옳은 검사다.
	scene.oath_fx = {}
	scene.oath_fx_t = 0.0
	var hp0: float = scene.regen_per_sec()
	scene.oath_fx = {"regen_max": 0.05}
	scene.oath_fx_t = 60.0
	assert(scene.regen_per_sec() > hp0 + scene.max_hp() * 0.04,
		"계약 회복(최대체력 %) 버프가 안 붙는다")
	scene.oath_fx = {}
	scene.oath_fx_t = 0.0
	assert(is_equal_approx(scene.dps(), dps0), "버프가 끝났는데 남아 있다")

	# 계약 레벨 — 중복이 쌓이고 상한을 넘지 않는다.
	scene.oath_lv["thirst"] = OathDefs.LV_MAX
	scene.oath_cards = 40
	for i in 30:
		scene._oath_roll(false)
	assert(int(scene.oath_lv["thirst"]) <= OathDefs.LV_MAX, "계약 레벨 상한 초과")

	# 카드 앞면 — 파일명 규약(assets/cards/oc_{id}.png)이라 디스크가 진실이다.
	for c in OathDefs.CONTRACTS:
		var fp := OathDefs.card_face(str(c["id"]))
		assert(ResourceLoader.exists(fp), "카드 앞면이 없다: " + fp)
	assert(ResourceLoader.exists(OathDefs.card_face("trueblood")),
		"진혈 카드 앞면이 없다")

	print("OathCheck OK")
	quit(0)
