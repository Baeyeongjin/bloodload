extends SceneTree

# 신화 스킬 (2026-09-01 사장님: "잠김을 없애고 신화 스킬을 추가해서 신화만
# 잠김 조건. 뽑기에서는 레전더리까지").
#
# 형태별 등급 천장(숙련 사다리)은 하루 만에 폐기됐다 — 이 파일이 그 검사였고,
# 지금은 그 자리를 이어받아 신화 규칙을 잰다:
#   1) 뽑기 — 등급 보존 + 형태 4종 전부 나옴 (천장이 사라졌다는 증거)
#   2) 뽑기·조합에서 신화가 절대 안 나온다
#   3) 문턱 전 미지급 · 문턱 도달 시 완성형(만렙) 지급 + 배너
#   4) 잠긴 카드 문구 — "격 레벨합 N/200" (은어 금지, 사장님이 못 알아들었다)
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 0) 표 성질 ────────────────────────────────────────────────────────
	assert(SkillDefs.mythic_key("strike") == "strike_mythic")
	assert(SkillDefs.name_of("strike_mythic") == "혈신의 송곳니",
		"신화 이름이 표에 없다: %s" % SkillDefs.name_of("strike_mythic"))
	# 아이콘은 레전더리를 빌린다(전용 그림은 사장님 픽 대기) — 파일이 실존해야 한다.
	assert(FileAccess.file_exists(SkillDefs.icon_path("wave_mythic")),
		"신화 아이콘 폴백이 없는 파일을 가리킨다: %s"
		% SkillDefs.icon_path("wave_mythic"))
	# 조합은 레전더리에서 멈춘다 — 신화는 잠김 조건 전용이다.
	assert(SkillDefs.promote_key("strike_legend") == "",
		"조합이 레전더리 위로 간다 — 신화가 조합으로 샌다")

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 1) 뽑기 — 등급 보존 + 형태 4종 전부 ───────────────────────────────
	# 천장이 있던 시절엔 안 열린 형태가 빠졌다. 이제 어떤 보유 상태에서든
	# 네 형태가 다 나오고, 들어간 등급이 그대로 나온다.
	scene.skill_owned = {"strike_common": 0}
	scene.gacha_shards = {}
	for want in ["common", "uncommon", "rare", "epic", "legend"]:
		var shapes := {}
		for i in 120:
			var got: Dictionary = scene._receive_gacha_skill(want)
			assert(str(got["rarity"]) == want,
				"등급이 갈렸다: %s -> %s" % [want, str(got["rarity"])])
			shapes[str(SkillDefs.split(str(got["key"]))[0])] = true
		assert(shapes.size() == SkillDefs.SHAPE_ORDER.size(),
			"%s 가 형태 %d 종에서만 나온다 — 천장이 남아 있다" % [want, shapes.size()])

	# ── 2) 신화는 뽑기 밖 ─────────────────────────────────────────────────
	var seen_mythic := false
	for i in 200:
		var got2: Dictionary = scene._receive_gacha_skill("legend")
		if str(SkillDefs.split(str(got2["key"]))[1]) == "mythic":
			seen_mythic = true
	assert(not seen_mythic, "뽑기에서 신화가 나왔다")

	# ── 3) 문턱 전 미지급 · 도달 시 완성형 지급 ───────────────────────────
	scene.skill_owned = {"strike_common": 50, "strike_uncommon": 50,
		"strike_rare": 50, "strike_epic": 49}   # 합 199 — 한 끗 모자란다
	scene.gacha_shards = {}
	scene._check_mythic()
	assert(not scene.skill_owned.has("strike_mythic"),
		"합 199 인데 신화가 지급됐다 (문턱 %d)" % SkillDefs.MYTHIC_NEED)
	scene.skill_owned["strike_epic"] = 50       # 합 200
	scene._clear_view.visible = false
	scene._check_mythic()
	assert(scene.skill_owned.has("strike_mythic"), "합 200 인데 신화가 안 왔다")
	assert(int(scene.skill_owned["strike_mythic"]) == SkillDefs.MAX_LV,
		"신화가 완성형이 아니다: %d" % int(scene.skill_owned["strike_mythic"]))
	# 배너 — 조용히 주면 없는 기능이다.
	assert(scene._clear_view.visible and "신화" in scene._clear_title.text,
		"신화 지급 배너가 안 떴다")
	# 다른 형태는 안 열렸다 — 형태별이다.
	assert(not scene.skill_owned.has("wave_mythic"), "안 부은 형태의 신화가 왔다")
	# 두 번 부르면 두 번 안 준다.
	scene._check_mythic()
	assert(int(scene.skill_owned["strike_mythic"]) == SkillDefs.MAX_LV, "재지급됐다")

	# ── 4) 잠긴 카드 문구 ─────────────────────────────────────────────────
	scene.skill_owned = {"strike_common": 7}
	var lock_card: Control = scene._skill_unknown_card(
		GachaDefs.rarity("mythic"), "strike")
	var lock_txt := ""
	for c in lock_card.get_children():
		if c is Label and "레벨합" in (c as Label).text:
			lock_txt = (c as Label).text
	assert(lock_txt == "격 레벨합 7/%d" % SkillDefs.MYTHIC_NEED,
		"잠긴 카드 문구가 다르다: %s" % lock_txt)
	# 커먼~레전더리 미획득 칸에는 잠김이 없다 — "뽑으면 나온다"가 맞는 말이다.
	var open_card: Control = scene._skill_unknown_card(
		GachaDefs.rarity("uncommon"), "strike")
	for c in open_card.get_children():
		if c is Label:
			assert(not ("레벨합" in (c as Label).text),
				"커먼~레전더리 칸에 잠김 문구가 남았다: %s" % (c as Label).text)

	print("SkillUnlockCheck OK  (천장 폐기 · 신화 문턱 지급 · 뽑기 밖 · 문구)")
	quit(0)
