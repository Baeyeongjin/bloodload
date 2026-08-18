extends SceneTree

# 펫 v2 (PetDefs + Main._pet_*) — 25종 로스터, 레벨(먹이) x 승급(조각), 장비.
#
# 지키는 것 셋:
#   1. **수집이 새지 않는가** — 상한 초과·빈 그릇 재수령·공짜 뽑기.
#   2. **성장 두 축이 실제로 붙는가** — 표만 맞고 공격력이 그대로면 뜻이 없다.
#   3. **먹이 경제가 닫혀 있는가** — 야수 우리가 주고 강화가 쓴다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표: 로스터 ─────────────────────────────────────────────────────────
	assert(PetDefs.PETS.size() == 25, "펫이 25종이 아니다: %d" % PetDefs.PETS.size())
	assert(PetDefs.GEAR.size() == 25, "장비가 25종이 아니다: %d" % PetDefs.GEAR.size())
	var ids := {}
	for r in PetDefs.RARITY_KEYS:
		assert(PetDefs.of_rarity(str(r)).size() == 5, "%s 펫이 5종이 아니다" % r)
		assert(PetDefs.gear_of_rarity(str(r)).size() == 5, "%s 장비가 5종이 아니다" % r)
	for p in PetDefs.PETS:
		assert(not ids.has(p["id"]), "id 충돌: %s" % p["id"])
		ids[p["id"]] = true
		# **방치 상자(혈액)와 겹치면 안 된다** — 같은 걸 주면 상자의 값이 깎인다.
		assert(str(p["gain"]) in ["crystal", "essence", "sigil", "feed"],
			"%s 가 모르는 재화를 준다: %s" % [p["id"], p["gain"]])
		assert(float(p["per_hour"]) > 0.0 and float(p["value"]) > 0.0,
			"%s 표값이 비었다" % p["id"])
		# 자리표시 애니가 실제로 있는가 — 없으면 화면에 빈 칸이 뜬다.
		assert(not Assets.frames(PetDefs.icon_dir(str(p["id"]))).is_empty(),
			"%s 의 애니 폴더가 비었다: %s" % [p["id"], p["anim"]])
	for g in PetDefs.GEAR:
		assert(str(g["kind"]) in ["gather", "amp"], "모르는 장비 갈래: %s" % g["kind"])
		# 아이콘은 파일명 규약(petw_<id>)이라 표가 아니라 디스크가 진실이다.
		assert(FileAccess.file_exists("res://assets/items/petw_%s.png" % g["id"]),
			"%s 아이콘이 없다" % g["id"])

	# ── 표: 성장 ───────────────────────────────────────────────────────────
	assert(PetDefs.lv_cap(1) == 10 and PetDefs.lv_cap(PetDefs.MAX_STAR) == 50,
		"레벨 상한이 표와 다르다")
	assert(PetDefs.feed_cost(10) > PetDefs.feed_cost(1), "먹이 비용이 안 오른다")
	assert(PetDefs.growth_mult(10, 1) > PetDefs.growth_mult(1, 1), "레벨이 안 는다")
	assert(PetDefs.growth_mult(1, 3) > PetDefs.growth_mult(1, 1), "승급이 안 는다")
	var id := str(PetDefs.PETS[0]["id"])
	assert(PetDefs.cap(id, 1, 2) > PetDefs.cap(id, 1, 1), "승급이 상한을 안 올린다")
	# 상한 초과 — 여기가 새면 오래 안 켠 사람이 무한히 번다.
	var cap1 := PetDefs.cap(id, 1, 1)
	assert(is_equal_approx(PetDefs.accrue(id, 0.0, PetDefs.CAP_HOURS * 100.0, 1, 1),
		cap1), "상한을 넘겼다")
	assert(is_equal_approx(PetDefs.accrue(id, cap1, 5.0, 1, 1), cap1),
		"가득인데 더 쌓였다")
	# 장비 gather 는 시급과 상한을 같이 올린다 — 시급만 올리면 상한이 금방 찬다.
	assert(PetDefs.accrue(id, 0.0, PetDefs.CAP_HOURS * 100.0, 1, 1, 0.5) > cap1,
		"gather 가 상한을 안 올린다")
	assert(str(PetDefs.roll_rarity()) in PetDefs.RARITY_KEYS, "등급 굴림이 밖을 쏜다")

	# ── 표: 던전(야수 우리) ────────────────────────────────────────────────
	assert(RaidDefs.RAIDS.has("hunt"), "야수 우리가 없다")
	assert(RaidDefs.reward("hunt", 2) > RaidDefs.reward("hunt", 1),
		"먹이 보상이 단계로 안 는다")
	assert(RaidDefs.open_stage("hunt") > PetDefs.PET_OPEN,
		"먹이 던전이 펫보다 먼저 열린다 — 쓸 데 없는 재화가 먼저 온다")

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# **결백성** — 앞선 검사가 남긴 저장본이면 이미 데려온 펫이 있다.
	scene.pets_got = {}
	scene.pet_lv = {}
	scene.pet_bank = {}
	scene.pet_worn = ""
	scene.pet_at = 0.0
	scene.pet_gear_got = {}
	scene.pet_gear_worn = {}
	scene.gacha_shards = {}
	scene.tickets = {}
	scene.feed = 0.0

	# ── 뽑기 — 펫권 우선, 없으면 보석(본편 소환과 같은 시세). ─────────────
	scene.best_stage = PetDefs.PET_OPEN
	scene.gem = 0.0
	assert(not scene._pet_roll(), "권도 보석도 없는데 뽑혔다")
	# 보석 결제 — 권이 없어도 GachaDefs.COST 로 뽑힌다.
	scene.gem = GachaDefs.COST
	assert(scene._pet_roll(), "보석이 있는데 안 뽑힌다")
	assert(scene.gem < GachaDefs.COST, "보석이 안 깎였다")
	scene.pets_got = {}
	scene.pet_lv = {}
	scene.pet_worn = ""
	scene.gacha_shards = {}
	scene.tickets = {"pet": 3}
	scene.best_stage = 1
	assert(not scene._pet_roll(), "안 열린 구간인데 뽑혔다")
	scene.best_stage = PetDefs.PET_OPEN
	assert(scene._pet_roll(), "열렸는데 안 뽑힌다")
	assert(int(scene.tickets.get("pet", 0)) == 2, "펫권이 안 깎였다")
	assert(scene.pets_got.size() == 1, "뽑았는데 펫이 없다")
	var got := str(scene.pets_got.keys()[0])
	assert(scene.pet_worn == got, "첫 펫을 자동으로 안 데려간다")
	assert(scene._pet_star(got) == 1 and scene._pet_lv(got) == 1,
		"시작이 1성 1레벨이 아니다")

	# **10연도 보석 폴백을 안다** — 소환권 선검사가 남아 있으면 권 0장에
	# 보석만 있을 때 한 장도 안 열린다(사장님 실측).
	scene.tickets = {}
	scene.gem = GachaDefs.COST * 3.0
	scene._pet_roll_many(3)
	assert(scene.gem < GachaDefs.COST, "보석 10연이 안 돈다: %f" % scene.gem)

	# **중복 -> 조각 -> 승급** — 언젠가는 어느 펫이든 별이 올라야 한다.
	scene.tickets = {"pet": 999}
	var guard := 0
	var promoted := false
	while not promoted and guard < 400:
		scene._pet_roll()
		guard += 1
		for k in scene.pets_got:
			if scene._pet_star(str(k)) >= 2:
				promoted = true
				break
	assert(promoted, "400연에 승급이 한 번도 없다 — 조각이 안 이어진다")

	# ── 먹이 강화 ──────────────────────────────────────────────────────────
	scene.feed = 0.0
	assert(not scene._pet_feed(got), "먹이가 없는데 강화됐다")
	var lv0: int = scene._pet_lv(got)
	scene.feed = PetDefs.feed_cost(lv0) + 5.0
	assert(scene._pet_feed(got), "먹이가 있는데 강화가 안 된다")
	assert(scene._pet_lv(got) == lv0 + 1, "레벨이 안 올랐다")
	assert(scene.feed < PetDefs.feed_cost(lv0) + 5.0, "먹이가 안 깎였다")
	# 상한 — 별이 열어 준 데까지만.
	scene.pet_lv[got] = PetDefs.lv_cap(scene._pet_star(got))
	scene.feed = 1e9
	assert(not scene._pet_feed(got), "레벨 상한을 넘겼다")

	# ── 장비 ───────────────────────────────────────────────────────────────
	scene.tickets["petgear"] = 5
	assert(scene._petgear_roll(), "장비권이 있는데 안 뽑힌다")
	assert(scene.pet_gear_got.size() >= 1, "장비가 안 들어왔다")
	var gid := str(scene.pet_gear_got.keys()[0])
	scene._pet_equip_gear(got, gid)
	assert(str(scene.pet_gear_worn.get(got, "")) == gid, "장비가 안 채워졌다")
	# 같은 장비를 다른 펫에 채우면 앞 펫에서 벗겨져야 한다 — 증폭 복제 방지.
	var other := "nightwing" if got != "nightwing" else "gravemoss"
	scene.pets_got[other] = 1
	scene.pet_lv[other] = 1
	scene._pet_equip_gear(other, gid)
	assert(str(scene.pet_gear_worn.get(got, "")) != gid, "한 장비가 두 펫에 걸렸다")

	# ── 버프가 실제로 붙는가 ───────────────────────────────────────────────
	for p2 in PetDefs.PETS:
		if str(p2["stat"]) == "damage":
			scene.pets_got[str(p2["id"])] = 1
			scene.pet_lv[str(p2["id"])] = 1
			scene.pet_worn = str(p2["id"])
			break
	var with_pet: float = scene._base_hit_damage()
	var keep_worn: String = scene.pet_worn
	scene.pet_worn = ""
	assert(with_pet > scene._base_hit_damage(), "데려가도 공격력이 그대로다")
	scene.pet_worn = keep_worn

	# ── 먹이 지급 경로 ─────────────────────────────────────────────────────
	var f0: float = scene.feed
	scene._grant_reward("feed", 123.0)
	assert(is_equal_approx(scene.feed, f0 + 123.0), "먹이 지급이 샌다")

	# ── 저장 · v1 이전 초기화 ─────────────────────────────────────────────
	scene._save_game()
	var keep_star: int = scene._pet_star(got)
	scene.pets_got = {}
	scene.pet_lv = {}
	scene._load_game()
	assert(scene._pet_star(got) == keep_star, "별이 복원 안 됐다")
	assert(scene.feed > 0.0, "먹이가 복원 안 됐다")
	# v1 저장본(몹 id)이 섞여 있으면 통째로 초기화 — 새 로스터와 id 가 안 맞는다.
	scene.pets_got = {"bat": 3}
	scene._save_game()
	scene._load_game()
	assert(scene.pets_got.is_empty(), "v1 저장본이 안 지워졌다")

	print("PetCheck OK")
	quit()
