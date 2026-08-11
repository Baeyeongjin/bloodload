extends SceneTree

# 광역 스킬 세 가지를 잰다. 눈으로는 "아이콘 튀고 끝"까지밖에 못 가고, 원인이
# 판정 범위인지 이펙트 개수인지 틱 유무인지 안 갈린다.
#
#   1) 광역이 **화면 밖 몹**을 때리는가        (_aoe_targets)
#   2) 이펙트가 **맞는 놈마다** 뜨는가         (혈우만 그랬다)
#   3) 진이 **여러 번** 때리는가               (다단히트)

func _init() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.stage = 1
	scene._restart_stage("측정")
	while scene._phase != "fight":
		await process_frame
	# **전투 phase 안에서 재야 한다.** `_aoe_targets` 는 `_foe_arrived` 를 보고 그건
	# `_phase == "fight"` 를 요구한다 — 전진 구간에서 재면 늘 0 이 나온다(처음에 그렇게
	# 짜서 "화면 안에 몹이 있는데 대상 0" 이 나왔다).
	var wait := 0.0
	while wait < 20.0:
		await process_frame
		wait += scene.get_process_delta_time()
		if scene._phase == "fight" and not (scene._aoe_targets() as Array).is_empty():
			break
	assert(scene._phase == "fight", "20초 안에 전투가 안 열렸다")

	var all: Array = scene.get_tree().get_nodes_in_group("foes")
	var on := 0
	var off := 0
	for f in all:
		if is_instance_valid(f):
			if f.position.x - f.body_half() > float(Grid.BG.x):
				off += 1
			else:
				on += 1
	var targets: Array = scene._aoe_targets()
	print("")
	print("살아 있는 몹 %d  (화면 안 %d / 화면 밖 %d)" % [all.size(), on, off])
	print("광역 판정 대상 %d 마리" % targets.size())
	for f in targets:
		print("   x %6.1f  %s" % [f.position.x, str(f.display_name)])
	assert(targets.size() <= on,
		"화면 밖 몹을 때린다: 판정 %d > 화면 안 %d" % [targets.size(), on])
	assert(targets.size() > 0, "화면 안에 몹이 있는데 광역 대상이 0이다")

	# ── 2) 광역이 **무리 가운데 하나로** 뜨는가 ──────────────────────────────
	# **2026-08-10 에 규칙이 뒤집혔다.** 예전 검사는 "맞는 놈마다 뜨는가"(>= 대상 수)를
	# 봤는데, 사장님이 "각몬스터 밑에있으면 너무지저분해보임 / 다 가운데 하나로 바꿔"로
	# 정했고 맞는 놈마다 뜨던 **피격 이펙트도 전부 껐다**(SkillDefs.HIT_FX_ON).
	# 그래서 지금 옳은 값은 대상이 몇이든 **정확히 1** 이다.
	#
	# 옛 검사를 그대로 두면 규칙을 지킨 코드가 실패한다 — 실제로 그렇게 걸렸다.
	scene._skill_action = ""
	scene._skill_cd.clear()
	var fx_before := _count_fx(scene)
	scene._skill_target = targets[0]
	scene._resolve_skill("wave_epic")
	await process_frame
	var fx_after := _count_fx(scene)
	var made := fx_after - fx_before
	print("")
	print("파(wave_epic) 1회 -> 이펙트 %d 개 생성 (대상 %d 마리, 가운데 하나여야 한다)"
		% [made, targets.size()])
	assert(made == 1,
		"광역 이펙트가 %d 개다 (대상 %d) — 가운데 하나여야 한다" % [made, targets.size()])
	# 피의 손길(관통) — 손바닥 **하나**가 날아간다. 맞는 놈마다 뜨면 규칙이 안 먹은 것.
	#
	# **`== 1` 로는 못 잰다.** `_count_fx` 는 스킬 이펙트와 피격 이펙트를 구분 못 하고,
	# 피격은 맞는 놈마다 뜬다 — 예전엔 앞의 파가 몹을 다 죽여서 우연히 1이 나왔을
	# 뿐이다(뱀의 무리를 가운데 하나로 바꾸자 몹이 살아남아 2가 됐다).
	# 상한을 `1 + 대상 수`로 둔다: 관통이 안 먹으면 스킬 이펙트만 대상 수만큼 떠서
	# 총 2N 이 되므로 N>=1 이면 반드시 걸린다.
	scene._skill_action = ""
	scene._skill_cd.clear()
	scene._phase = "fight"
	# **앞 스킬의 이펙트가 다 사라진 뒤에 잰다.** 피격 이펙트는 조금 늦게 뜨는 것이
	# 있어서, 바로 재면 그게 이번 시전의 것으로 잡힌다(실측: 대상 0인데 2개로 셌다).
	var settle := 0.0
	var last := -1
	while settle < 1.5:
		await process_frame
		settle += scene.get_process_delta_time()
		var now := _count_fx(scene)
		if now == last and now == 0:
			break
		last = now
	# 기다리는 동안 게임이 돌아 구간이 전진으로 넘어갔을 수 있다 — `_resolve_skill` 은
	# 첫 줄에서 `_phase != "fight"` 면 통째로 빠져나간다(그래서 0장이 나왔다).
	scene._phase = "fight"
	scene._skill_action = ""
	scene._skill_cd.clear()
	var live_now: int = (scene._aoe_targets() as Array).size()
	var pierce_before := _count_fx(scene)
	scene._resolve_skill("wave_common")
	await process_frame
	var pierce_made := _count_fx(scene) - pierce_before
	print("피의 손길(관통) 1회 -> 이펙트 %d 개 (스킬 1 + 피격 %d 이하여야 한다)"
		% [pierce_made, live_now])
	# 피격 이펙트를 전부 끈 뒤로는(HIT_FX_ON) 상한도 **정확히 1** 이다. 느슨한 상한을
	# 남겨 두면 관통이 깨져도 안 걸린다.
	assert(pierce_made == 1,
		"관통인데 이펙트가 %d 개다 (대상 %d) — 하나여야 한다" % [pierce_made, live_now])

	# ── 3) 진이 여러 번 때리는가 ──────────────────────────────────────────
	# **표적을 여기서 다시 뽑는다.** 위의 파(wave)가 1막 몹을 한 방에 죽이므로
	# targets[0] 은 이미 `dying` 이다 — hp 를 키워도 `_die()` 가 지난 뒤라 안 살아난다.
	# 처음에 그걸 몰라 "피해 0 번"이 나왔고, 원인은 계측 쪽이었다.
	# 장판이 깔릴 자리(_aoe_targets()[0])와 같은 놈이어야 문양 안에 든다.
	scene._phase = "fight"
	var wait2 := 0.0
	var alive: Array = scene._aoe_targets()
	while alive.is_empty() and wait2 < 20.0:
		await process_frame
		wait2 += scene.get_process_delta_time()
		if scene._phase == "fight":
			alive = scene._aoe_targets()
	assert(not alive.is_empty(), "살아 있는 광역 대상을 못 찾았다")
	var probe: Foe = alive[0]
	probe.max_hp = 1.0e9
	probe.hp = 1.0e9
	var hp0: float = probe.hp
	var drops := 0
	var prev := hp0
	scene._skill_action = ""
	scene._skill_cd.clear()
	scene._skill_target = probe
	# **_resolve_skill 첫 줄이 `_phase != "fight"` 면 통째로 빠져나간다.** 앞의 파가
	# 몹을 다 죽여 전진 구간으로 넘어가 있으면 장판이 아예 안 깔린다 - 처음에 그렇게
	# 재서 "피해 0 번"이 나왔다. 장판 자체는 phase 를 안 보지만 시전은 본다.
	scene._phase = "fight"
	var sk := SkillDefs.SHAPES["field"]
	# **설계 틱 수를 여기서 다시 계산하지 않는다.** 스킬 고유 규칙(RULES.ticks·
	# one_shot)이 얹히므로 `duration x tick_rate` 로 재면 규칙을 얹는 순간 갈린다 —
	# 감시의 눈을 3틱으로 바꿨을 때 실제로 그렇게 걸렸다.
	var want := SkillDefs.ticks_of("field_rare")
	var gen0: int = scene._field_gen
	# **world_fx 로 세면 안 된다**(2026-08-11). `fixed`·`screen` 인 진은 화면에 붙어서
	# 일부러 그 그룹에 안 들어간다 — 그룹으로 세면 그려도 0장으로 잡힌다.
	var world0: int = _count_fx(scene)
	# **`field_rare` 로 잰다** — 다만 이제 감시의 눈도 규칙을 달았다(screen + puddle:
	# 큰 문양 하나). 그래서 기대값은 "맞는 놈마다 한 장"이 아니라 아래 `want_marks`
	# 가 정한다. 2026-08-11 에 다섯 형태가 전부 규칙을 갖게 돼서, "형태 기본 그대로인
	# 진"이라는 기준 자체가 사라졌다.
	scene._resolve_skill("field_rare")
	await process_frame
	# **시간차 소환(RULES.stagger)을 기다린다.** 감시의 눈은 문양이 차례로 뜨므로
	# 한 프레임 뒤에 세면 첫 장밖에 안 보인다. 첫 피해도 소환이 끝난 뒤에 들어가므로
	# (`_start_field` 의 lead) 여기서 기다려도 "문양 없이 맞았다"를 놓치지 않는다.
	var lead: float = float(SkillDefs.rule_of("field_rare").get("stagger", 0.0)) * 4.0
	var waited := 0.0
	while waited < lead:
		await process_frame
		waited += scene.get_process_delta_time()
	var laid: int = _count_fx(scene) - world0
	var marked: int = (scene._field_targets() as Array).size()
	# 큰 문양 하나로 덮는 규칙(puddle·screen)이면 1장이 정답이고, 아니면 맞는 놈마다다.
	var rr: Dictionary = SkillDefs.rule_of("field_rare")
	var one_mark := float(rr.get("puddle", 0.0)) > 0.0 or bool(rr.get("screen", false))
	var want_marks: int = 1 if one_mark else marked
	print("   깔린 뒤: _field_x %.1f  판정반폭 %.0f  gen %d->%d  문양 %d장  대상 %d (기대 %d)"
		% [scene._field_x, scene._field_reach, gen0, scene._field_gen,
		laid, marked, want_marks])
	# **피해가 들어가는 자리에는 문양이 있어야 한다.** 판정 폭을 아트 폭에서 떼어 낸
	# 대가가 이것이다 - 이 검사가 없으면 판정 반폭을 키우는 순간 아무것도 안 그려진
	# 자리에서 피해가 나간다. 큰 문양 하나로 덮는 규칙에서는 그 한 장이 폭을 맡는다.
	assert(laid >= want_marks,
		"문양이 모자라다: %d장 / 기대 %d (대상 %d마리) - 안 보이는 자리에서 피해가 난다"
		% [laid, want_marks, marked])
	print("   probe x %.1f  잉크반폭 %.1f  거리 %.1f  dying %s"
		% [probe.position.x, probe.body_half(),
		absf(probe.position.x - scene._field_x), str(probe.dying)])
	var t := 0.0
	while t < float(sk["duration"]) + 1.0:
		await process_frame
		t += scene.get_process_delta_time()
		# **평타와 다른 스킬을 막는다.** 안 그러면 0.6초마다 기본공격이, 그리고 쿨다운이
		# 풀린 다른 스킬이 같은 놈을 때려서 틱과 섞인다 - 처음에 6틱 설계인데 13번,
		# 스킬만 남겼을 때 8번으로 나왔다.
		scene._attack_t = 99.0
		for k in scene.skill_equipped:
			scene._skill_cd[str(k)] = 99.0
		if not is_instance_valid(probe):
			break
		if probe.hp < prev - 0.0001:
			drops += 1
			prev = probe.hp
	print("")
	print("진(field) 1회 -> 피해가 %d 번 들어갔다 (설계 %d 틱: %.1f초 x 초당 %.0f)"
		% [drops, want, float(sk["duration"]), float(sk["tick_rate"])])
	print("   총 피해 %.1f  (%.1f -> %.1f)" % [hp0 - prev, hp0, prev])
	assert(drops >= 2, "진이 다단히트가 아니다: %d 번" % drops)
	assert(drops >= want - 1, "틱이 모자라다: %d / %d" % [drops, want])
	assert(drops <= want + 1, "틱이 설계보다 많다: %d / %d (평타가 섞였나)" % [drops, want])
	# **판정 폭이 몹 간격보다 좁으면 광역이 아니다.** 예전엔 아트 폭(64px)이 판정이라
	# 반폭 32 + 몹 22 = +-54px 였고 몹은 FOE_GAP(160) 간격이라 한 번에 한 마리였다 -
	# 다단히트는 되지만 광역은 아니었다. 이제 FIELD_REACH 가 판정이고 두 칸을 덮는다.
	var reach: float = scene.FIELD_REACH + probe.body_half()
	var mobs := 1 + int(reach / scene.FOE_GAP)
	print("")
	print("진 판정 폭 +-%.0f px  ·  몹 간격 %.0f px  ->  한 번에 최대 %d 마리"
		% [reach, scene.FOE_GAP, mobs])
	assert(mobs >= 2, "진이 광역이 아니다: 판정 +-%.0f 로 %d 마리" % [reach, mobs])

	# ── 4) 비명의 흔적 웅덩이 규칙 — 문양이 **하나만** 깔린다 ─────────────────
	# 대상이 몇이든 무리 가운데 웅덩이 하나다(RULES.puddle). 맞는 놈마다 깔리면
	# 규칙이 안 먹은 것이고, 0장이면 스킬이 통째로 안 나간 것이다.
	scene._phase = "fight"
	scene._skill_action = ""
	scene._skill_cd.clear()
	# world_fx 로 세면 안 된다 — 비명의 흔적은 `fixed` 라 그 그룹에 안 들어간다(위 참고).
	var world1: int = _count_fx(scene)
	scene._resolve_skill("field_common")
	await process_frame
	var puddle_laid: int = _count_fx(scene) - world1
	print("")
	print("비명의 흔적(웅덩이) 1회 -> 문양 %d 장" % puddle_laid)
	assert(puddle_laid == 1, "웅덩이가 %d장이다 — 무리 가운데 하나여야 한다" % puddle_laid)

	# ── 5) 튀는 피 — 표창처럼 **최대 3명**이 맞는다 ──────────────────────────
	# 이펙트는 0.13초 간격이라 화면 캡처로는 못 잡는다 — 체력으로 센다.
	#
	# **대상을 기다리지 않고 만든다.** 앞 검사들이 phase 를 강제로 만져서 스폰 흐름이
	# 그대로라는 보장이 없다 — 살아 있는 몹 넷을 화면 안 제 자리에 옮겨 세우면
	# `_foe_arrived`(fight + 제 자리) 조건이 그대로 차서 `_aoe_targets` 에 든다.
	# **앞 검사의 장판을 끊는다.** 웅덩이(테스트 4)의 틱이 3초를 돌므로, 안 끊으면
	# 그 틱이 여기 프로브까지 때려 4마리가 깎인다 — 실제로 그렇게 한 번 터졌다.
	# gen 을 올리면 지난 장판의 남은 틱이 전부 빠져나간다(구간 교체와 같은 장치).
	scene._field_gen += 1
	var pool: Array = []
	for f in scene.get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f) and not f.dying:
			pool.append(f)
	assert(pool.size() >= 2, "살아 있는 몹이 %d 마리뿐이라 튕김을 못 잰다" % pool.size())
	var bounce_probes: Array = []
	# 넷 다 **화면 안**에 세운다(80px 간격). 160px 간격으로 넷을 세우면 뒤 둘이
	# 화면(576px) 밖이라 상한 검사가 안 된다 — 3마리만 맞고 4번째가 남아야
	# "상한 3" 이 증명된다.
	for i in mini(4, pool.size()):
		var f: Foe = pool[i]
		f.position.x = scene.hero_x + 80.0 + 80.0 * float(i)
		f.stop_x = f.position.x
		f.max_hp = 1.0e9
		f.hp = 1.0e9
		bounce_probes.append(f)
	scene._phase = "fight"
	var bt := bounce_probes
	# 이미 예약된 평타 임팩트가 끼면 한 마리가 더 깎인 것으로 보인다 — 지운다.
	scene._hero_hit_t = -1.0
	scene._pending_target = null
	scene._skill_action = ""
	scene._skill_cd.clear()
	scene._phase = "fight"
	scene._resolve_skill("wave_uncommon")
	var btime := 0.0
	while btime < 0.7:
		await process_frame
		btime += scene.get_process_delta_time()
		# **phase 를 매 프레임 다시 잡는다.** 게임 상태기가 되돌리면 `_foe_arrived` 가
		# 죽어서 2·3번째 튕김이 표적을 못 찾는다 — 실제로 1마리에서 끊겼다.
		scene._phase = "fight"
		scene._attack_t = 99.0
		for k in scene.skill_equipped:
			scene._skill_cd[str(k)] = 99.0
	var struck_n := 0
	for f in bounce_probes:
		if is_instance_valid(f) and f.hp < 1.0e9 - 0.5:
			struck_n += 1
	print("")
	print("튀는 피(튕김) 1회 -> %d 마리 깎임 (대상 %d, 상한 3)" % [struck_n, bt.size()])
	# 대상이 4인데 정확히 3이어야 한다 — 1이면 튕김이 끊긴 것, 4면 상한이 안 걸린 것.
	assert(struck_n == 3, "튀는 피가 %d 마리를 맞혔다 — 3마리여야 한다" % struck_n)
	# ── 처형(RULES.execute) — 왕좌 안에서 체력이 문턱 아래면 즉사한다 ────────────
	# 이건 **피해가 아니라 규칙**이라 위력을 바꿔도 안 잡힌다. 문턱 위/아래 두 놈을
	# 나란히 세워, 아래만 죽고 위는 사는지를 본다. 하나만 두면 "그냥 피해로 죽었다"와
	# 구분이 안 된다.
	var exec_at: float = float(SkillDefs.rule_of("field_legend").get("execute", 0.0))
	assert(exec_at > 0.0, "field_legend 에 execute 규칙이 없다")
	var et: Array = scene._aoe_targets()
	assert(et.size() >= 2, "처형 검사에 몹이 둘 이상 필요하다 (%d)" % et.size())
	var low: Foe = et[0]
	var high: Foe = et[1]
	# 피해로는 절대 안 죽을 만큼 체력을 키워 두고, 비율만 문턱 위아래로 갈라 놓는다.
	low.max_hp = 1.0e9
	low.hp = low.max_hp * (exec_at * 0.5)
	high.max_hp = 1.0e9
	high.hp = high.max_hp * (exec_at + 0.30)
	var high_before: float = high.hp
	var exec_fx0: int = _count_fx(scene)
	scene._skill_cd.clear()
	scene._phase = "fight"
	scene._resolve_skill("field_legend")
	var etime := 0.0
	# **가장 많이 떠 있던 순간을 기억한다.** 왕관은 0.45초짜리라 끝에서 세면 이미
	# 사라진 뒤다 — 처음에 그렇게 재서 0장이 나왔다.
	var exec_peak := 0
	while etime < 1.2:
		await process_frame
		etime += scene.get_process_delta_time()
		exec_peak = maxi(exec_peak, _count_fx(scene) - exec_fx0)
		scene._phase = "fight"
		scene._attack_t = 99.0
		for k in scene.skill_equipped:
			scene._skill_cd[str(k)] = 99.0
	var low_dead := not is_instance_valid(low) or low.dying or low.hp <= 0.0
	var high_alive := is_instance_valid(high) and not high.dying and high.hp > 0.0
	print("")
	print("처형 문턱 %d%% — 문턱 아래(%s) / 문턱 위(%s, %.0f -> %.0f)"
		% [int(exec_at * 100.0), "죽음" if low_dead else "살아남음",
		"살아남음" if high_alive else "죽음", high_before,
		high.hp if is_instance_valid(high) else 0.0])
	assert(low_dead, "문턱 아래인데 안 죽었다 — 처형이 안 걸렸다")
	assert(high_alive, "문턱 위인데 죽었다 — 처형 문턱이 안 먹었다")
	# **처형이 화면에 보이는가.** 규칙만 있고 연출이 없으면 사장님 화면에서는
	# 몹이 그냥 사라진다 — "왜 죽었지"가 된다. 왕관(그림)과 무너지는 자세(exec_fall)
	# 둘 다 본다. 왕관은 문양 1장 + 왕관 1장이므로 최소 2장이 늘어야 한다.
	var exec_fx: int = exec_peak
	var marked_exec := (not is_instance_valid(low)) or low.exec_fall
	print("   처형 연출: 이펙트 +%d장 (문양+왕관, 2장 이상)  ·  무너지는 자세 %s"
		% [exec_fx, "켜짐" if marked_exec else "꺼짐"])
	assert(marked_exec, "처형인데 exec_fall 이 안 켜졌다 — 그냥 맞아 죽은 것과 똑같이 보인다")
	assert(exec_fx >= 2, "처형인데 이펙트가 %d장뿐이다 — 왕관이 안 떴다" % exec_fx)

	print("")
	print("AoeCheck OK")
	quit()


func _count_fx(scene: Node) -> int:
	var n := 0
	for c in scene.get_children():
		if c is AnimatedSprite2D:
			n += 1
	return n
