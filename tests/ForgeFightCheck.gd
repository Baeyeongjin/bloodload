extends SceneTree

# 제련의 성소(단일 강적) — **실제로 때리는가**.
# 사장님 2026-08-25: "저기서 공격을 멈추는 버그". 수호자 앞에 서서 idle 로
# 굳는 증상이라, 입장 뒤 몇 초를 돌려 적 체력이 실제로 깎이는지 본다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).
func _init() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.best_stage = maxi(scene.best_stage, RaidDefs.open_stage("forge") + 10)
	scene.stage = scene.best_stage
	scene.raid_on = ""
	scene.dungeon_on = false
	scene.raid_date = Time.get_date_string_from_system()
	scene.raid_left = {}
	scene.iap_subs = {}
	scene._restart_stage("측정")
	while scene._phase != "fight" or scene._fade_t > 0.0:
		await process_frame
	print("enter")
	# **스킬을 끼고 싸운다.** 실제 판은 네 형태가 다 걸려 있고, 스킬 시전 중에는
	# 기본공격이 통째로 멈춘다(_skill_action 가드) — 스킬이 안 끝나면 그대로 굳는다.
	scene.skill_equipped.clear()
	for sk in SkillDefs.SHAPES:
		var key3 := str(sk)
		scene.skill_owned[key3] = 3
		scene.skill_equipped.append(key3)
	print("skills=", scene.skill_equipped.size())
	scene._raid_enter("forge")
	assert(scene.raid_on == "forge", "성소에 못 들어갔다")
	var w1 := 0.0
	while scene._fade_t > 0.0 and w1 < 20.0:
		await process_frame
		w1 += scene.get_process_delta_time()
	print("entered raid_on=", scene.raid_on)
	assert(scene._c_is_boss(), "수호자가 보스 판정을 못 받았다")
	# 적이 자리를 잡을 때까지 기다린다.
	var waited := 0.0
	var foe: Node = null
	while waited < 12.0:
		await process_frame
		waited += scene.get_process_delta_time()
		for f in scene.get_tree().get_nodes_in_group("foes"):
			if is_instance_valid(f) and not f.dying:
				foe = f
				break
		if foe != null and scene._foe_arrived(foe):
			break
	print("foe=", foe, " waited=", waited)
	assert(foe != null, "수호자가 안 나왔다")
	# **한 마리만 선다.** 여섯이 서면 각자 보스 체력이라 영영 안 끝난다.
	var live := 0
	for f2 in scene.get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f2) and not f2.dying:
			live += 1
	assert(live == 1, "성소에 수호자가 %d마리 섰다" % live)
	assert(scene._foe_arrived(foe), "수호자가 제자리에 안 섰다: x=%f stop=%f"
		% [foe.position.x, foe.stop_x])
	# **때리는가** — 몇 초 돌려서 체력이 깎이는지 본다.
	var hp0: float = foe.hp
	var t := 0.0
	while t < 6.0 and is_instance_valid(foe) and not foe.dying:
		await process_frame
		t += scene.get_process_delta_time()
		if foe.hp < hp0:
			break
	assert(not is_instance_valid(foe) or foe.dying or foe.hp < hp0,
		"6초 동안 수호자를 한 대도 못 때렸다 (사거리 %f, 간격 %f, 모션 %s)"
		% [scene._front_reach(), scene._foe_gap(foe), scene._motion])
	# **피가 조금 남았을 때도 계속 때리는가** (사장님 2026-08-25:
	# "보스피가 조금남으면 우리캐릭터가 공격을안함").
	if is_instance_valid(foe) and not foe.dying:
		foe.hp = maxf(1.0, foe.max_hp * 0.02)
		var hp1: float = foe.hp
		var t2 := 0.0
		var hit := false
		while t2 < 8.0 and is_instance_valid(foe) and not foe.dying:
			await process_frame
			t2 += scene.get_process_delta_time()
			if foe.hp < hp1:
				hit = true
				break
		assert(hit or not is_instance_valid(foe) or foe.dying,
			"피가 2%% 남았는데 8초간 못 때렸다 (사거리 %f, 간격 %f, 모션 %s, 도착 %s, 몸통 %f)"
			% [scene._front_reach(), scene._foe_gap(foe), scene._motion,
			str(scene._foe_arrived(foe)), foe.body_half()])
	# ── 점프 공격 뒤에도 때리는가 ──────────────────────────────────────────
	# 수호자(sanctum_guardian)는 특수 패턴이 **jump** 다. 뛰어든 자리에 남는데
	# stop_x 를 안 옮기면 _foe_arrived 가 영영 거짓이 되어 공격이 통째로 멈춘다
	# (사장님 2026-08-25 실측). 특수를 강제로 켜서 그 상태를 태운다.
	assert(str(FoeTiers.special_kind("sanctum_guardian")[4]) == "jump",
		"수호자가 점프 패턴이 아니다 — 이 검사의 전제가 깨졌다")
	if is_instance_valid(foe) and not foe.dying:
		foe.hp = foe.max_hp        # 점프를 여러 번 볼 수 있게 되살린다
		Foe.force_special = true
		var jumped := false
		var t3 := 0.0
		while t3 < 10.0 and is_instance_valid(foe) and not foe.dying:
			await process_frame
			t3 += scene.get_process_delta_time()
			if absf(foe.position.x - foe.stop_x) > 2.0:
				jumped = true
			elif jumped:
				break              # 착지했다 — 여기서부터 다시 때려야 한다
		Foe.force_special = false
		assert(jumped, "특수(점프)가 한 번도 안 나왔다")
		assert(scene._foe_arrived(foe) or not is_instance_valid(foe) or foe.dying,
			"점프 착지 뒤에도 제자리 판정이 거짓이다 (x=%f stop=%f)"
			% [foe.position.x, foe.stop_x])
		var hp2: float = foe.hp
		var t4 := 0.0
		var hit2 := false
		while t4 < 8.0 and is_instance_valid(foe) and not foe.dying:
			await process_frame
			t4 += scene.get_process_delta_time()
			if foe.hp < hp2:
				hit2 = true
				break
		assert(hit2 or not is_instance_valid(foe) or foe.dying,
			"점프 뒤 8초간 못 때렸다 (x=%f stop=%f 도착=%s)"
			% [foe.position.x, foe.stop_x, str(scene._foe_arrived(foe))])
	print("ForgeFightCheck OK")
	quit(0)
