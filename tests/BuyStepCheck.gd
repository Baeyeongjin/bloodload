extends SceneTree

# 배수 버튼(x1 / x10 / x100 / MAX) — **화면에 눌린 것과 실제로 사는 양이 같은가.**
#
# 사장님이 x1 이 눌린 화면에서 눌렀는데 레벨이 100 씩 올라갔다(2026-08-27).
# _build_growth() 가 _load_game() 앞에 돌아서, 버튼은 빌드 때 기본값 1 을 그리고
# buy_step 은 그 뒤에 저장본의 100 으로 덮였다. 둘이 갈라지면 가격은 100 개
# 값을 받고 사람은 1 개를 산 줄 안다 — 돈이 걸린 거짓말이다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

const SAVE_PATH := "user://bloodlord.cfg"


func _init() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# **격리 확인이 먼저다.** 이 검사는 진짜 저장본 자리에 쓴다. 격리 없이 돌면
	# 사장님 저장본을 민다 — 전에 장비가 실제로 사라진 적이 있다.
	#
	# "진행이 있나"로는 못 가른다 — 격리 저장본에도 앞선 검사들이 남긴 진행이
	# 있다(실측). **경로로 가른다**: 격리하면 APPDATA 가 임시 폴더를 가리키고,
	# 안 하면 AppData\Roaming 이다.
	var udir := OS.get_user_data_dir().to_lower().replace("\\", "/")
	if not (udir.contains("/temp/") or udir.contains("/tmp/")):
		push_error("격리 없이 돌렸다(%s) — docs/CHECKS.md 의 APPDATA 를 주고 다시."
			% OS.get_user_data_dir())
		quit(1)
		return

	# 원래 저장본은 돌려놓는다 — 다른 검사가 쌓아 둔 상태를 밀지 않게.
	var backup := PackedByteArray()
	if FileAccess.file_exists(SAVE_PATH):
		backup = FileAccess.get_file_as_bytes(SAVE_PATH)

	# 저장본에 x100 을 심어 둔다. 켜면 화면도 x100 이어야 한다.
	var cfg := ConfigFile.new()
	cfg.set_value("up", "buy_step", 100)
	cfg.save(SAVE_PATH)

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var steps: Array = scene.BUY_STEPS
	assert(int(scene.buy_step) == 100,
		"저장본의 배수를 안 읽었다: %d" % int(scene.buy_step))

	# ── 1) 눌린 버튼이 정확히 하나이고, 그게 buy_step 이다 ────────────────────
	var lit: Array = []
	for i in scene._step_btns.size():
		if scene._step_btns[i].button_pressed:
			lit.append(steps[i])
	assert(lit.size() == 1, "눌린 배수 버튼이 %d 개다: %s" % [lit.size(), str(lit)])
	assert(int(lit[0]) == int(scene.buy_step),
		"화면은 x%s 인데 실제 배수는 x%d 다" % [str(lit[0]), int(scene.buy_step)])

	# ── 2) 눌린 버튼과 **실제로 사는 단계 수**가 같다 ────────────────────────
	# 버튼만 맞춰 놓고 _step_for 가 다른 값을 쓰면 같은 거짓말이 남는다.
	# 상한에 안 걸리게 여유를 확인하고 잰다.
	var key := "attack"
	var room: int = int(scene._stat_cap(key)) - int(scene.stat_lv(key))
	assert(room > 100, "상한 여유가 없어서 못 잰다(여유 %d)" % room)
	assert(int(scene._step_for(key)) == int(lit[0]),
		"x%s 가 눌렸는데 %d 단계를 산다" % [str(lit[0]), int(scene._step_for(key))])

	# ── 3) 눌러서 바꾸면 둘이 같이 움직인다 ─────────────────────────────────
	for want in [1, 10, 100]:
		scene._set_step(want)
		var on: Array = []
		for i in scene._step_btns.size():
			if scene._step_btns[i].button_pressed:
				on.append(steps[i])
		assert(on.size() == 1 and int(on[0]) == want,
			"x%d 로 바꿨는데 화면은 %s" % [want, str(on)])
		assert(int(scene._step_for(key)) == want,
			"x%d 로 바꿨는데 %d 단계를 산다" % [want, int(scene._step_for(key))])

	# ── 4) 진짜로 사면 그만큼만 오른다 ──────────────────────────────────────
	scene._set_step(10)
	scene.gold = 1e30            # 값 때문에 막히지 않게
	var before: int = int(scene.stat_lv(key))
	scene._buy(key)
	assert(int(scene.stat_lv(key)) == before + 10,
		"x10 인데 %d 만큼 올랐다" % (int(scene.stat_lv(key)) - before))

	if not backup.is_empty():
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()

	print("BuyStepCheck OK  (저장본 x100 -> 화면 x100 · 사는 양 일치)")
	quit(0)
