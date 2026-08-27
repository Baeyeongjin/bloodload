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

	# 사거리가 열린 프레임(또는 그 다음)에 스윙이 나갔나 — 아래 assert 참고.
	var SWING: Array = []
	var _reach_frame := false
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
			_reach_frame = true
			# 스킬 중이면 뺀다. 기본공격 봉쇄는 **별개 결함**이라 여기 섞으면
			# 둘 다 못 읽는다(_skill_action != "" 이면 10174 에서 조기 반환).
			if scene._skill_action == "":
				SWING.append(1.0 if scene._pending_target != null else 0.0)
		elif _reach_frame:
			# **한 프레임은 봐준다.** 사거리를 여는 이동(_tick_dash)이 공격 판정
			# (_tick_hero_attack)보다 뒤에 돌아서(Main.gd 틱 순서), 열린 그
			# 프레임엔 구조적으로 스윙이 못 나는 경우가 있다. 실측: 그 프레임만
			# 보면 0.89, 한 프레임 봐주면 1.00.
			_reach_frame = false
			if not SWING.is_empty() and float(SWING[SWING.size() - 1]) < 0.5 					and scene._pending_target != null:
				SWING[SWING.size() - 1] = 1.0
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
	# **재는 것을 바꿨다**(2026-08-27). 옛 문턱은 `대기 < 주기 x 0.8` 이었는데
	# 밸런스 개편으로 주기가 0.60 -> 0.22 로 줄면서 **통과가 불가능해졌다**:
	# _attack_swing() 이 min(ATTACK_SWING 0.34, 주기) 라 스윙만으로 0.22 초이고,
	# 임팩트는 그림이 제일 뻗는 프레임(9장 중 5·6·8번 = 스윙의 0.61~0.94)에서
	# 난다. 하한 0.195초 > 문턱 0.176초 — 완벽한 코드도 못 넘는다.
	# 문턱을 옮겨 봐야 공속이 또 오르면 다시 빨개진다. 축이 틀린 것이다.
	#
	# 이 검사가 지키려던 건 총 대기시간 예산이 아니라 **"달려가는 동안 쿨다운이
	# 도는가"** 하나다. 그러면 그것만 직접 잰다: 사거리가 열린 프레임에 스윙이
	# 나가는가. 스윙 길이·임팩트 프레임·스킬 점유가 자동으로 빠지고 주기에도
	# 안 묶인다. 대기시간(C)은 아래에 찍기만 하고 문턱으로 쓰지 않는다.
	#
	# **실측**(주기 0.60, 표본 27 / 되돌림 21). 세 후보를 다 찍어서 골랐다:
	#     신호                          고쳐진 상태   버그 되돌림
	#     사거리 열린 프레임에 스윙         0.89        0.14
	#     +1프레임까지 스윙                 1.00        0.19   <- 쓴다
	#     사거리 열릴 때 쿨다운 끝남        0.11        0.05   <- 버렸다
	#
	# 쿨다운 잔량(_attack_t)을 보는 건 **안 된다.** 가드가 `_attack_t > 0` 이라
	# 0 이 되는 순간 스윙이 나가고 같은 프레임에 _attack_t 가 주기로 되돌려져서,
	# 프레임 끝에서 재면 고쳐진 상태에서도 늘 양수다. 코드를 읽어서는 이걸
	# 몰랐고 두 상태를 다 돌려 보고 알았다.
	#
	# 문턱 0.9 는 1.00 과 0.19 사이다. 딱 1.00 을 요구하지 않는 이유는 스킬이
	# 사거리 다음 프레임에 시작하면(위 필터는 열린 프레임에서 본다) 정상인데도
	# 0 이 하나 섞일 수 있어서다. 0.19 와는 4.7 배 벌어져 있어 튜닝이 필요 없다.
	var swing_rate := 0.0
	for x in SWING:
		swing_rate += float(x)
	swing_rate /= float(maxi(1, SWING.size()))
	print("사거리 열린 프레임(+1)에 스윙: %.2f  (표본 %d · 스킬 중 제외)"
		% [swing_rate, SWING.size()])
	assert(SWING.size() >= 8, "표본이 %d 개뿐이라 못 믿는다" % SWING.size())
	assert(swing_rate >= 0.9,
		"사거리가 열렸는데 스윙이 안 나간다: %.0f%% (달려가는 동안 공격 쿨다운이 얼어붙는다)"
		% (swing_rate * 100.0))
	# 표적 선정·이동은 즉시여야 한다 — 전열을 몸통 폭에 붙여 뒀으므로(FRONT_X).
	var move_mean := 0.0
	for x in B:
		move_mean += float(x)
	move_mean /= float(maxi(1, B.size()))
	assert(move_mean < 0.2, "표적을 잡고도 사거리에 드는 데 오래 걸린다: %.2f초" % move_mean)
	print("FirstHitCheck OK")
	quit()
