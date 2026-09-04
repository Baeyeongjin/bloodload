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
		assert(str(p["gain"]) in ["crystal", "sigil", "feed"],
			"%s 가 모르는 재화를 준다: %s" % [p["id"], p["gain"]])
		assert(float(p["per_hour"]) > 0.0 and float(p["value"]) > 0.0,
			"%s 표값이 비었다" % p["id"])
		# 자리표시 애니가 실제로 있는가 — 없으면 화면에 빈 칸이 뜬다.
		assert(not Assets.frames(PetDefs.icon_dir(str(p["id"]))).is_empty(),
			"%s 의 애니 폴더가 비었다: %s" % [p["id"], p["anim"]])
	for g in PetDefs.GEAR:
		# 갈래는 **둘 다 전투 효과**여야 한다(사장님 2026-09-02: "수집 40% 는
		# 빼야지 저게 뭔효과임"). 재화 시급짜리 장비가 다시 들어오면 여기서 걸린다.
		assert(str(g["kind"]) in ["power", "amp"], "모르는 장비 갈래: %s" % g["kind"])
		# 아이콘은 파일명 규약(petw_<id>)이라 표가 아니라 디스크가 진실이다.
		assert(FileAccess.file_exists("res://assets/items/petw_%s.png" % g["id"]),
			"%s 아이콘이 없다" % g["id"])

	# ── 표: 성장 ───────────────────────────────────────────────────────────
	assert(PetDefs.lv_cap(1) == 10 and PetDefs.lv_cap(PetDefs.MAX_STAR) == 50,
		"레벨 상한이 표와 다르다")
	assert(PetDefs.feed_cost(10) > PetDefs.feed_cost(1), "먹이 비용이 안 오른다")
	# 확률 강화(사장님): 1레벨은 100% — 이게 깨지면 아래 강화 검사가 흔들린다.
	assert(is_equal_approx(PetDefs.feed_chance(1), 1.0), "1레벨이 100%가 아니다")
	assert(PetDefs.feed_chance(40) < PetDefs.feed_chance(10), "확률이 안 내려간다")
	assert(PetDefs.feed_chance(999) >= 0.35, "확률 바닥이 없다 — 복권이 된다")
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
	# (장비 수집 증폭은 2026-09-02 에 없어졌다 — 펫 장비가 전부 전투 효과가 됐다.)
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
	# 같은 펫에 같은 장비를 **다시** 채우면 벗겨져야 한다 — 회수 루프가 자기
	# 것까지 걷어 가며 토글 판정을 죽였던 버그(사장님: 벗기기가 안 된다).
	scene._pet_equip_gear(other, gid)
	assert(str(scene.pet_gear_worn.get(other, "")) == "", "다시 눌렀는데 안 벗겨졌다")
	scene._pet_equip_gear(other, gid)
	assert(str(scene.pet_gear_worn.get(other, "")) == gid, "벗긴 뒤 다시 안 채워진다")

	# ── 버프가 실제로 붙는가 ───────────────────────────────────────────────
	for p2 in PetDefs.PETS:
		if str(p2["stat"]) == "damage":
			scene.pets_got[str(p2["id"])] = 1
			scene.pet_lv[str(p2["id"])] = 1
			scene.pet_worn = str(p2["id"])
			break
	var with_pet: float = scene._base_hit_damage()
	var keep_worn: String = scene.pet_worn

	# ── 펫 장비가 **전투에** 붙는가 (2026-09-02) ──────────────────────────
	# 사장님: "펫장비 효과 수집 40% 는 빼야지 저게 뭔효과임 공격력이나 이런걸로".
	# 표만 power 로 바꾸고 훅을 안 달면 화면 문구만 바뀌고 아무 일도 안 난다.
	var pw := ""
	for g2 in PetDefs.GEAR:
		if str(g2["kind"]) == "power":
			pw = str(g2["id"])
			break
	assert(pw != "", "공격력 장비가 표에 없다")
	scene.pet_gear_got[pw] = 1
	scene.pet_gear_worn = {}
	var no_gear: float = scene._base_hit_damage()
	scene._pet_equip_gear(keep_worn, pw)
	assert(scene._base_hit_damage() > no_gear,
		"공격력 장비를 채웠는데 공격력이 그대로다")
	# 벗기면 되돌아온다 — 한쪽만 도는 훅이면 여기서 걸린다.
	scene._pet_equip_gear(keep_worn, pw)
	assert(is_equal_approx(scene._base_hit_damage(), no_gear),
		"장비를 벗겼는데 공격력이 안 돌아온다")
	# **수집에는 안 붙는다** — 걷어 낸 축이 되살아나면 여기서 걸린다.
	var pid := str(PetDefs.PETS[0]["id"])
	assert(is_equal_approx(
		PetDefs.accrue(pid, 0.0, PetDefs.CAP_HOURS * 100.0, 1, 1),
		PetDefs.cap(pid, 1, 1)),
		"수집이 상한을 넘는다 — 장비 증폭이 되살아났다")

	scene.pet_worn = ""
	assert(with_pet > scene._base_hit_damage(), "데려가도 공격력이 그대로다")
	scene.pet_worn = keep_worn

	# ── 보유 효과 (2026-09-02) — 데려가지 않아도 모은 것이 값한다 ──────────
	# 이 검사가 없으면 회귀가 조용히 지나간다: 위 동행 검사는 pets_got 를
	# 고정한 채 pet_worn 만 껐다 켜므로 보유분이 양변에서 상쇄된다.
	var keep_got: Dictionary = scene.pets_got.duplicate()
	scene.pet_worn = ""
	scene.pets_got = {}
	var bare_dmg: float = scene._base_hit_damage()
	var bare_hp: float = scene.max_hp()
	scene.pets_got = {str(PetDefs.PETS[0]["id"]): 1}
	assert(scene._base_hit_damage() > bare_dmg,
		"안 데려간 펫을 모아도 공격력이 그대로다")
	assert(scene.max_hp() > bare_hp, "안 데려간 펫을 모아도 체력이 그대로다")

	# **축을 안 가린다** — 공속형을 모아도 공격·체력이 오른다. 이게 안 되면
	# 공속 펫 여섯이 보유 효과에서 통째로 빠진다(비대칭).
	var speed_pet := ""
	for p3 in PetDefs.PETS:
		if str(p3["stat"]) == "speed":
			speed_pet = str(p3["id"])
			break
	assert(speed_pet != "", "공속 펫이 표에 없다")
	scene.pets_got = {speed_pet: 1}
	assert(scene._base_hit_damage() > bare_dmg,
		"공속 펫은 모아도 공격력에 안 붙는다 — 축을 가리고 있다")

	# **성장을 안 태운다** — 별을 올려도 보유분은 그대로다(동행 몫에만 붙는다).
	var one_star: float = PetDefs.owned_bonus({speed_pet: 1})
	assert(is_equal_approx(one_star, PetDefs.owned_bonus({speed_pet: 5})),
		"별이 보유 효과를 키운다 — 만별 x2 가 25종에 곱해지면 천장이 터진다")

	# **상한** — 표를 늘렸을 때 조용히 부풀지 않게 못 박는다. 눈금 근거는
	# 스킨 전량(+25%)이다(PetDefs.COLLECT_RATE 주석).
	var all_pets := {}
	for p4 in PetDefs.PETS:
		all_pets[str(p4["id"])] = PetDefs.MAX_STAR
	var full: float = PetDefs.owned_bonus(all_pets)
	assert(full > 0.15 and full < 0.30,
		"25종 전부 보유 효과가 +%.1f%% — 예산(15~30%%, 스킨 전량 +25%% 급)을 벗어났다"
		% (full * 100.0))
	scene.pets_got = keep_got
	scene.pet_worn = keep_worn

	# ── 펫 판 배치 (사장님 2026-09-04) ────────────────────────────────────
	# 강화 판에서 바로 고른다 · 보유 판 "모두 받기"는 없다 · 원정 "모두 보내기"는
	# 카드 아래 가운데. 자리는 사장님이 그림으로 지정한 것이라 숫자로 못 박는다.
	scene.best_stage = maxi(int(scene.best_stage), PetDefs.PET_OPEN)
	scene._relayout_tabs()
	scene._select_tab("pet")
	assert(not scene._pet_roots.is_empty(), "펫 판이 안 지어졌다")
	assert(scene._feed_cells.size() == PetDefs.PETS.size(),
		"강화 판에 격자가 없다: %d" % scene._feed_cells.size())
	assert(not scene._pet_detail.has("all"), "보유 판 모두 받기가 남았다")
	var allb: Control = scene._trip_ui["all"]["btn"]
	assert(allb.position.y >= scene.PET_DETAIL_Y + 156.0,
		"모두 보내기가 카드 아래가 아니다: y=%.0f" % allb.position.y)
	assert(absf(allb.position.x + allb.size.x * 0.5
		- (scene.PAD + scene.CONTENT_W * 0.5)) < 1.0,
		"모두 보내기가 가운데가 아니다: x=%.0f" % allb.position.x)
	# 강화 판이 고른 펫을 그대로 본다 — 보유 판을 거치지 않아도 된다.
	scene._pet_sel = got
	scene._pet_set_mode("feed")
	assert(scene._pet_feed_ui["name"].text.begins_with(
		str(PetDefs.of(got)["name"])),
		"강화 판이 고른 펫을 안 보여준다: %s" % scene._pet_feed_ui["name"].text)
	assert(scene._feed_sel_art() != null, "고른 펫의 격자 그림을 못 찾는다")

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
