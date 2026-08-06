extends SceneTree

# 사장님: "캐릭터가 몬스터를 마주했을때 공격이 더빨리 나갓으면 좋겠어 지금은 1.5초정도
# 멈췃다가 공격해". 그 시간이 어디서 오는지 **쪼개서** 잰다. 후보가 여럿이라 짐작으로는
# 못 고른다:
#   (a) 전투가 열린 뒤 표적이 잡히기까지   (_tick_engage 가 사망 연출을 기다린다)
#   (b) 표적이 잡힌 뒤 사거리에 들기까지   (영웅 이동)
#   (c) 사거리에 든 뒤 첫 피해가 들어가기까지 (_attack_t 쿨다운 + 임팩트 프레임)
#
# **스윙 시작은 안 쟌다.** `_hero_hit_t` 는 같은 프레임에 예약되고 소비돼서
# 프레임 사이 샘플링으로는 놓친다(처음에 그렇게 짜서 0회 측정이 나왔다).

const SECONDS := 45.0

func _init() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
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

	var A: Array = []
	var B: Array = []
	var C: Array = []
	var ALL: Array = []
	var t := 0.0
	var t_fight := -1.0
	var t_target := -1.0
	var t_reach := -1.0
	var hp0 := 0.0
	var prev_phase := "advance"
	var prev_engaged: Object = null

	while t < SECONDS:
		await process_frame
		t += scene.get_process_delta_time()
		var ph: String = str(scene._phase)
		if ph == "fight" and prev_phase != "fight":
			t_fight = t
			t_target = -1.0
			t_reach = -1.0
		prev_phase = ph
		var e = scene._engaged
		if not is_instance_valid(e):
			continue
		# **죽는 중인지 먼저 걸러내면 안 된다.** 1막 몹은 한 방에 죽어서, 피해가 들어간
		# 그 프레임에 이미 dying 이다 — 처음에 그렇게 짜서 0회 측정이 나왔다.
		if e != prev_engaged and not e.dying:
			prev_engaged = e
			t_target = t
			t_reach = -1.0
			hp0 = float(e.hp)
			if t_fight < 0.0:
				t_fight = t
		if t_target < 0.0:
			continue
		if t_reach < 0.0 and not e.dying and scene._in_front_reach(e):
			t_reach = t
		if t_reach >= 0.0 and float(e.hp) < hp0 - 0.001:
			A.append(maxf(0.0, t_target - t_fight))
			B.append(maxf(0.0, t_reach - t_target))
			C.append(maxf(0.0, t - t_reach))
			ALL.append(maxf(0.0, t - t_fight))
			t_fight = -1.0
			t_target = -1.0
			t_reach = -1.0

	print("")
	print("교전 %d 회 측정 (%.0f초)" % [ALL.size(), SECONDS])
	if ALL.is_empty():
		push_error("한 번도 못 쟀다")
		quit(1)
	var rows := [
		["전투 열림 -> 표적 잡힘   (_tick_engage)", A],
		["표적 잡힘 -> 사거리 진입 (영웅 이동)", B],
		["사거리 진입 -> 첫 피해    (쿨다운+임팩트)", C],
		["합계  몹을 마주하고 첫 피해까지", ALL],
	]
	for row in rows:
		var v: Array = row[1]
		var arr := PackedFloat32Array(v)
		arr.sort()
		var mean := 0.0
		for x in v:
			mean += float(x)
		mean /= float(maxi(1, v.size()))
		print("  %-40s 평균 %.2f초  중간 %.2f  최대 %.2f"
			% [row[0], mean, arr[arr.size() / 2], arr[arr.size() - 1]])
	print("")
	print("참고: 공격 주기 %.2f초 · 스윙 길이 %.2f초 · 사망 연출 %.2f초"
		% [scene.attack_interval(), scene._attack_swing(), Foe.DIE_DUR])
	# **마주치고 나서 공격 주기를 처음부터 기다리면 안 된다.** 쿨다운은 달려가는 동안
	# 돌아야 한다(`_tick_hero_attack` 의 phase 가드가 `_attack_t -= delta` **뒤에**
	# 와야 한다). 가드가 앞에 있던 동안 이 값이 0.56초(= 주기 0.60 거의 그대로)였고,
	# 화면에서는 "붙어서 한참 멈췄다가 공격"으로 보였다(사장님).
	var wait_mean := 0.0
	for x in C:
		wait_mean += float(x)
	wait_mean /= float(maxi(1, C.size()))
	assert(wait_mean < scene.attack_interval() * 0.8,
		"마주치고 공격까지 너무 오래 기다린다: %.2f초 (주기 %.2f초)"
		% [wait_mean, scene.attack_interval()])
	# 표적 선정·이동은 즉시여야 한다 — 전열을 몸통 폭에 붙여 뒀으므로(FRONT_X).
	var move_mean := 0.0
	for x in B:
		move_mean += float(x)
	move_mean /= float(maxi(1, B.size()))
	assert(move_mean < 0.2, "표적을 잡고도 사거리에 드는 데 오래 걸린다: %.2f초" % move_mean)
	print("FirstHitCheck OK")
	quit()
