extends SceneTree

# [개발 도구] 검수 치트(_dev_god)를 잰다. 치트가 조용히 반쪽만 듣는 일을 막는다 —
# 실제로 스탯이 안 올라간 적이 있다(lv 는 올린 적 있는 스탯만 갖고 있었다).
#
# **F8 키와 --god 플래그가 같은 함수를 부른다.** 여기서 함수를 재면 둘 다 재는 것이다.
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene._dev_god(100)

	# 1) 구간 — 재화 던전 셋과 유물이 다 열려야 검수가 된다.
	assert(scene.best_stage == 100, "구간이 안 올랐다: %d" % scene.best_stage)
	for k in RaidDefs.RAIDS:
		assert(scene.best_stage >= RaidDefs.open_stage(str(k)),
			"%s 던전이 안 열렸다" % k)
	assert(scene.best_stage >= RelicDefs.OPEN_STAGE, "유물이 안 열렸다")
	assert(scene.dungeon_best > 0, "미궁 기록이 없다")

	# 2) 장비 — **최고 등급 한 벌**. 굴리면 등급이 들쭉날쭉해 비교가 안 된다.
	var top := str(GearDefs.RARITY[GearDefs.RARITY.size() - 1]["key"])
	for slot in GearDefs.SLOTS:
		var it: Dictionary = scene.equipped.get(slot, {})
		assert(not it.is_empty(), "%s 가 비었다" % slot)
		assert(str(it.get("rarity", "")) == top,
			"%s 가 최고 등급이 아니다: %s" % [slot, it.get("rarity", "")])

	# 3) 스킬 — 전종 보유 + 실제 장착.
	# **크기가 아니라 내용을 본다** — 앞선 검사가 남긴 키가 섞이면 수가 안 맞는다
	# (실측: PrestigeCheck 의 "keep_skill" 이 따라 들어와 깨졌다). 여기서 보려는
	# 건 "치트가 전종을 줬는가"이지 사전 크기가 아니다.
	for k in SkillDefs.all_keys():
		assert(scene.skill_owned.has(str(k)), "스킬 %s 가 없다" % k)
	assert(scene.skill_equipped.size() > 0, "스킬이 장착 안 됐다")

	# 4) 스탯 — 상한까지. 여기가 실제로 깨졌던 자리다.
	var cap := StatDefs.train_cap(scene.dungeon_best, scene.best_stage)
	for st in StatDefs.STATS:
		if not bool(st.get("impl", false)):
			continue
		assert(int(scene.lv.get(str(st["key"]), 0)) == cap,
			"%s 레벨이 상한이 아니다: %d / %d"
			% [st["key"], int(scene.lv.get(str(st["key"]), 0)), cap])

	# 5) 재화·소환권 — 소환과 상점을 다 눌러 볼 수 있어야 한다.
	assert(scene.gem > 0.0 and scene.crystal > 0.0 and scene.sigil > 0.0,
		"재화가 안 들어왔다")
	for tk in TicketDefs.KINDS:
		assert(int(scene.tickets.get(tk, 0)) > 0, "%s 권이 없다" % tk)

	print("GodCheck OK")
	quit()
