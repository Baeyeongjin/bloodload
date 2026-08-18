extends SceneTree

# 펫(PetDefs + Main._pet_*).
#
# 두 가지를 지킨다:
#   1. **수집이 새지 않는가** — 상한을 넘겨 쌓이거나, 받고도 그릇이 안 비거나,
#      껐다 켠 사이가 통째로 빠지면 재화 밸런스가 조용히 무너진다.
#   2. **버프가 실제로 붙는가** — 표만 맞고 공격력이 그대로면 아무 뜻이 없다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표 ─────────────────────────────────────────────────────────────────
	assert(PetDefs.PETS.size() > 0, "펫이 없다")
	var prev := 0
	for p in PetDefs.PETS:
		# 해금 구간이 올라가기만 해야 "다음은 저것"이 읽힌다.
		assert(int(p["open"]) > prev, "해금 구간이 안 오른다: %s" % str(p["id"]))
		prev = int(p["open"])
		assert(float(p["per_hour"]) > 0.0, "%s 가 아무것도 안 물어온다" % p["id"])
		# **방치 상자(혈액)와 겹치면 안 된다** — 같은 걸 주면 상자의 값이 깎인다.
		assert(str(p["gain"]) != "blood" and str(p["gain"]) != "gold",
			"%s 가 방치 상자와 같은 재화를 준다" % p["id"])
		assert(float(p["value"]) > 0.0, "%s 버프가 0" % p["id"])
	assert(PetDefs.unlocked("bat", 10), "10구간인데 첫 펫이 안 열린다")
	assert(not PetDefs.unlocked("bat", 9), "9구간인데 열렸다")

	# 상한 — 시간으로 재야 모든 펫에서 "여섯 시간이면 찬다"가 같은 말이 된다.
	var id := str(PetDefs.PETS[0]["id"])
	var cap := PetDefs.cap(id)
	assert(cap > 0.0, "상한이 0")
	assert(is_equal_approx(PetDefs.accrue(id, 0.0, PetDefs.CAP_HOURS), cap),
		"상한 시간을 채웠는데 상한이 아니다")
	# **넘겨서 쌓이면 안 된다.** 여기가 새면 오래 안 켠 사람이 무한히 번다.
	assert(is_equal_approx(PetDefs.accrue(id, 0.0, PetDefs.CAP_HOURS * 100.0), cap),
		"상한을 넘겼다")
	assert(is_equal_approx(PetDefs.accrue(id, cap, 5.0), cap), "가득인데 더 쌓였다")

	# 버프는 **데리고 다니는 하나만** 준다.
	var w := str(PetDefs.PETS[0]["id"])
	var stat := str(PetDefs.PETS[0]["stat"])
	assert(PetDefs.bonus(w, stat) > 0.0, "장착 펫이 제 능력치를 안 준다")
	assert(is_equal_approx(PetDefs.bonus("", stat), 0.0), "안 데려갔는데 붙는다")
	assert(is_equal_approx(PetDefs.bonus(w, "없는스탯"), 0.0), "엉뚱한 스탯에 붙는다")

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# **결백성** — 앞선 검사가 남긴 저장본이면 이미 데려온 펫이 있다.
	scene.pets_got = {}
	scene.pet_bank = {}
	scene.pet_worn = ""
	scene.pet_at = 0.0
	scene.crystal = 0.0
	scene.gacha_shards = {}

	# ── 뽑기 ── **보석으로 뽑는다**(소환권 다섯째를 안 만든다 — 지갑 칸).
	scene.best_stage = 1
	scene.gem = 99999.0
	assert(not scene._pet_roll(), "뽑기가 안 열린 구간인데 나왔다")
	assert(scene.pets_got.is_empty(), "1구간인데 펫이 생겼다")
	scene.best_stage = int(PetDefs.PETS[0]["open"])
	# 보석이 모자라면 안 나온다 — 여기가 새면 공짜 뽑기가 된다.
	scene.gem = PetDefs.ROLL_COST - 1.0
	assert(not scene._pet_roll(), "보석이 모자란데 뽑혔다")
	scene.gem = PetDefs.ROLL_COST * 40.0
	var before_gem: float = scene.gem
	assert(scene._pet_roll(), "열린 구간인데 안 뽑힌다")
	assert(scene.gem < before_gem, "뽑았는데 보석이 그대로다")
	assert(scene.pets_got.has(id), "뽑았는데 안 들어왔다")
	assert(scene.pet_worn == id, "첫 펫을 자동으로 안 데려간다")

	# **중복은 조각이고, 조각이 차면 한 단계.** 빈손으로 돌려보내지 않는다.
	var lv0: int = scene._pet_lv(id)
	for i in PetDefs.SHARDS_PER_LV:
		scene._pet_roll()
	assert(scene._pet_lv(id) > lv0, "조각을 채웠는데 단계가 안 올랐다")
	assert(scene._pet_lv(id) <= PetDefs.MAX_LV, "만렙을 넘겼다")
	# 단계가 오르면 물어오는 양과 버프가 같이 는다.
	assert(PetDefs.cap(id, 2) > PetDefs.cap(id, 1), "단계가 올라도 상한이 그대로")
	assert(PetDefs.bonus(id, str(PetDefs.of(id)["stat"]), 2)
		> PetDefs.bonus(id, str(PetDefs.of(id)["stat"]), 1),
		"단계가 올라도 버프가 그대로")

	# 시간이 지나면 쌓인다. pet_at 을 과거로 밀어 흉내 낸다.
	scene.pet_at = Time.get_unix_time_from_system() - 3600.0 * 2.0
	scene._pet_tick()
	var have := float(scene.pet_bank.get(id, 0.0))
	assert(have > 0.0, "두 시간이 지났는데 안 쌓였다")
	assert(have <= cap + 0.001, "상한을 넘겼다: %f" % have)

	# **받으면 그릇이 비고 지갑이 찬다.**
	var before: float = scene.crystal
	scene._pet_collect(id)
	# **0 을 재지 않는다.** 받고 화면을 새로 그리는 사이에도 시간이 흘러
	# 몇 만분의 일이 다시 쌓인다(실측) — 받을 수 있는 최소는 1 이므로
	# "다시 받을 수 없는 상태"인지를 본다.
	assert(float(scene.pet_bank.get(id, 0.0)) < 1.0,
		"받았는데 그릇이 안 비었다: %f" % float(scene.pet_bank.get(id, 0.0)))
	assert(scene.crystal > before, "받았는데 지갑이 그대로다")
	# 빈 그릇을 또 받아도 아무 일이 없어야 한다.
	var after: float = scene.crystal
	scene._pet_collect(id)
	assert(is_equal_approx(scene.crystal, after), "빈 그릇에서 또 받았다")

	# 버프가 **공격력에 실제로** 붙는가.
	var dmg_pet := str(PetDefs.of(id)["stat"]) == "damage"
	if dmg_pet:
		var with_pet: float = scene._base_hit_damage()
		scene.pet_worn = ""
		var without: float = scene._base_hit_damage()
		scene.pet_worn = id
		assert(with_pet > without, "데려가도 공격력이 그대로다")

	# 저장.
	scene._save_game()
	scene.pets_got = {}
	scene.pet_worn = ""
	scene._load_game()
	assert(scene.pets_got.has(id), "펫이 복원 안 됐다")
	assert(scene.pet_worn == id, "데려가던 펫이 복원 안 됐다")

	print("PetCheck OK")
	quit()
