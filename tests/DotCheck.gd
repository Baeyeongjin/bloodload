extends SceneTree

# 알림 점 — **방치형에서 제일 중요한 화면 요소다**(사장님 2026-08-26:
# "모든 컨텐츠에서 레벨업 or 진행 가능한 던전 or 업적 or 보상 있으면 알림").
#
# 점이 안 켜지면 그 콘텐츠는 없는 것과 같다. 반대로 늘 켜져 있어도 없는 것과
# 같다. 그래서 켜지는 조건과 **꺼지는 조건을 같이** 못 박는다.
#
# 재는 것:
#   1) 성장 — 스탯·혈맥·혈맹·유물·회귀 다섯이 각각 혼자서도 점을 켜는가
#   2) 장비 — 레벨업만 가능해도 켜지는가(예전엔 조합만 봤다)
#   3) 장비 격자 — 칸마다 붙는 점의 자(_gear_can_level)가 만렙·재화를 다 보는가
#   4) 던전 — 안 뚫은 미궁 층이 열려 있으면 켜지는가
#   5) 빈손이면 전부 꺼지는가
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 0) 빈손 — 아무 점도 안 켜진다 ──────────────────────────────────────
	_broke(scene)
	assert(not scene._growth_todo(), "빈손인데 성장 점이 켜졌다")
	assert(not scene._tab_todo("gear"), "빈손인데 장비 점이 켜졌다")

	# ── 1) 성장 다섯 축이 각각 혼자서 켠다 ────────────────────────────────
	# (a) 스탯 — 혈액만 준다.
	_broke(scene)
	scene.gold = 1.0e9
	assert(scene._growth_todo(), "혈액이 있는데 성장 점이 안 켜진다")

	# (b) 혈맥 — 혈정만 준다.
	_broke(scene)
	scene.crystal = 1.0e6
	assert(scene._growth_todo(), "혈정이 있는데 성장 점이 안 켜진다")

	# (c) 혈맹 — 인장만 준다.
	_broke(scene)
	scene.sigil = 1.0e6
	assert(scene._growth_todo(), "인장이 있는데 성장 점이 안 켜진다")

	# (d) 유물 — 조각이 다 모인 유물 하나.
	_broke(scene)
	var rid := str(RelicDefs.RELICS[0]["id"])
	scene.relics = {rid: 1}
	scene.gacha_shards["relic:" + rid] = RelicDefs.SHARDS_PER_LV
	assert(scene._growth_todo(), "유물 조각이 찼는데 성장 점이 안 켜진다")

	# (e) 회귀 — 혈흔이 나오는 구간.
	_broke(scene)
	scene.best_stage = PrestigeDefs.OPEN_STAGE + 20
	scene.prestige_peak = 0
	assert(scene._growth_todo(), "회귀로 혈흔이 나오는데 성장 점이 안 켜진다")

	# ── 2·3) 장비 — 레벨업만 가능해도 켜진다 ──────────────────────────────
	_broke(scene)
	var item: Dictionary = GearDefs.make("weapon", 1, GachaDefs.rarity("common"))
	var key := str(item["icon"])
	item["lv"] = 0
	scene.gear_inventory = {key: item}
	scene.gacha_shards = {}          # 조각 0 — 조합은 못 한다
	assert(not scene._gear_can_fuse(key), "조각이 없는데 조합이 된다")
	assert(not scene._gear_can_level(key), "연마석이 없는데 레벨업이 된다")
	assert(not scene._tab_todo("gear"), "할 게 없는데 장비 점이 켜졌다")
	scene.whet = 1.0e9
	assert(scene._gear_can_level(key), "연마석이 있는데 레벨업이 안 된다")
	assert(scene._tab_todo("gear"),
		"레벨업만 가능한데 장비 점이 안 켜진다 — 예전엔 조합만 봤다")

	# 만렙이면 꺼진다. 연마석이 아무리 많아도.
	item["lv"] = GearDefs.max_lv(item)
	assert(not scene._gear_can_level(key), "만렙인데 레벨업이 된다")
	assert(not scene._tab_todo("gear"), "만렙인데 장비 점이 켜져 있다")

	# 신화는 100렙부터 조각도 본다 — 연마석만으로는 안 올라간다.
	var myth: Dictionary = GearDefs.make("weapon", 1, GachaDefs.rarity("mythic"))
	var mkey := str(myth["icon"])
	myth["lv"] = GearDefs.SHARD_FROM_LV
	scene.gear_inventory = {mkey: myth}
	scene.gacha_shards = {}
	assert(GearDefs.upgrade_shards(myth) > 0, "신화 100렙에 조각을 안 요구한다")
	assert(not scene._gear_can_level(mkey), "조각이 없는데 신화가 올라간다")
	scene.gacha_shards["gear:" + mkey] = GearDefs.upgrade_shards(myth)
	assert(scene._gear_can_level(mkey), "조각을 줬는데 신화가 안 올라간다")
	# 100렙 전에는 조각을 안 본다.
	myth["lv"] = GearDefs.SHARD_FROM_LV - 1
	assert(GearDefs.upgrade_shards(myth) == 0, "100렙 전인데 조각을 요구한다")

	# 레전더리 -> 신화 조합은 만렙을 요구한다.
	var leg: Dictionary = GearDefs.make("weapon", 1, GachaDefs.rarity("legend"))
	var lkey := str(leg["icon"])
	leg["lv"] = 0
	scene.gear_inventory = {lkey: leg}
	scene.gacha_shards = {"gear:" + lkey: GearDefs.FUSE_SHARDS}
	assert(not scene._gear_can_fuse(lkey),
		"레전더리가 만렙이 아닌데 신화 조합이 된다")
	leg["lv"] = GearDefs.max_lv(leg)
	assert(scene._gear_can_fuse(lkey), "레전더리 만렙인데 신화 조합이 안 된다")
	# 아래 등급은 만렙을 안 요구한다 — 초반에 강제하면 조합이 벌이 된다.
	var com: Dictionary = GearDefs.make("weapon", 1, GachaDefs.rarity("common"))
	var ckey := str(com["icon"])
	com["lv"] = 0
	scene.gear_inventory = {ckey: com}
	scene.gacha_shards = {"gear:" + ckey: GearDefs.FUSE_SHARDS}
	assert(scene._gear_can_fuse(ckey), "커먼이 만렙이 아니라고 조합을 막는다")

	# ── 4) 던전 — 안 뚫은 미궁 층이 열려 있으면 켜진다 ────────────────────
	_broke(scene)
	scene.best_stage = DungeonDefs.OPEN_STAGE + 40
	scene.dungeon_best = 0
	scene.raid_on = ""
	scene.dungeon_on = false
	assert(DungeonDefs.open_floors(scene.best_stage) > 0, "준비가 틀렸다")
	assert(scene._tab_todo("raid"), "안 뚫은 미궁 층이 있는데 던전 점이 안 켜진다")
	# 다 뚫었으면 꺼진다 — 제자리를 도는 건 첫 돌파 보상이 없다.
	# 던전 탭은 넷을 본다(표·주간보스·시련·미궁). 미궁만 재려면 나머지 셋을
	# 꺼 둬야 한다 — 안 그러면 시련이 켜 놓은 점을 미궁의 것으로 오독한다.
	scene.dungeon_best = DungeonDefs.open_floors(scene.best_stage)
	scene.raid_date = Time.get_date_string_from_system()
	for k in RaidDefs.RAIDS:
		scene.raid_left[str(k)] = 0
	scene.trial_stage = TrialDefs.max_stage()
	scene.boss_dmg = 0.0
	scene.boss_got = {}
	assert(not scene._tab_todo("raid"),
		"미궁을 다 뚫고 표도 없는데 던전 점이 켜져 있다")
	# 그리고 시련이 열리면 다시 켜진다 — 넷 중 하나만 있어도 켜야 한다.
	scene.trial_stage = 0
	assert(scene._tab_todo("raid"), "시련이 열렸는데 던전 점이 안 켜진다")

	# ── 5) 보상 — 임무 창 점이 다섯 축을 다 보는가 ────────────────────────
	# 창 안에 소탭이 다섯인데(일일·주간·업적·출석·패스) 점은 앞의 둘만 봤다.
	_broke(scene)
	scene.quest_got = {}
	scene.quest_wgot = {}
	scene.quest_prog = {}
	scene.quest_wprog = {}
	scene.achieve_got = {}
	scene.pass_points = 0
	scene.pass_free_got = {}
	scene.pass_paid_got = {}
	scene.iap_subs = {}          # 구독을 꺼 둔다 — 유료 줄이 섞이면 무료 줄만 못 잰다
	scene.attend_date = Time.get_date_string_from_system()   # 오늘 이미 받았다
	assert(not scene._attend_claimable(), "오늘 받았는데 출석이 또 켜진다")
	assert(not scene._pass_claimable(), "패스 단계가 0인데 받을 게 있다")

	# 출석 — 날짜만 어제로 돌리면 켜진다.
	scene.attend_date = ""
	assert(scene._attend_claimable(), "출석을 안 받았는데 안 켜진다")
	scene.attend_date = Time.get_date_string_from_system()

	# 패스 — 단계가 열리면 켜진다.
	scene.pass_points = PassDefs.POINT_QUEST * 999
	assert(PassDefs.step_of(scene.pass_points) > 0, "준비가 틀렸다")
	assert(scene._pass_claimable(), "패스 단계가 열렸는데 안 켜진다")
	# 다 받으면 꺼진다(무료 줄만 — 구독이 없으면 유료 줄은 안 센다).
	for i in range(1, PassDefs.step_of(scene.pass_points) + 1):
		scene.pass_free_got[i] = true
	assert(not scene._pass_claimable(),
		"무료 줄을 다 받았는데 패스 점이 켜져 있다(구독도 없다)")

	# 업적 — **받을 게 남았으면 켜지고 다 받으면 꺼진다.**
	# 게임 시작부터 첫 계단이 달성돼 있는 트랙이 있으므로(구간 1 도달 등)
	# "빈손이면 꺼진다"로는 못 잰다. 다 받은 상태를 만들어 놓고 재는 게 맞다.
	scene.achieve_got = {}
	var had: bool = scene._achieve_claimable()
	for t in AchieveDefs.TRACKS:
		var kd := str(t["kind"])
		var g := 0
		while true:
			var st: Dictionary = AchieveDefs.at(kd, g)
			if st.is_empty() or scene._goal_value(kd) < int(st["need"]):
				break
			g += 1
		scene.achieve_got[kd] = g
	assert(not scene._achieve_claimable(),
		"업적을 다 받았는데 점이 켜져 있다 — 늘 켜진 점은 없는 점과 같다")
	# 하나를 되돌리면 다시 켜진다(위에서 받을 게 하나라도 있었을 때만 잰다).
	if had:
		scene.achieve_got = {}
		assert(scene._achieve_claimable(), "받을 업적이 있는데 점이 안 켜진다")

	# ── 7) 보관함 점 = 레벨업만 (사장님 2026-09-04) ───────────────────────
	# 조각은 뽑을 때마다 쌓여 조합 점이 안 꺼졌다. 칸 점과 탭 점이 같은 자를
	# 쓰는지도 여기서 잠근다 — 다르면 "탭은 켜졌는데 켜진 칸이 없는" 자리가 난다.
	_broke(scene)
	var fit: Dictionary = GearDefs.make("weapon", 1, GachaDefs.rarity("common"))
	var fkey := str(fit["icon"])
	fit["lv"] = 0
	scene.gear_inventory = {fkey: fit}
	scene.gacha_shards = {"gear:" + fkey: GearDefs.FUSE_SHARDS}
	scene.whet = 0.0
	assert(scene._gear_can_fuse(fkey), "준비가 틀렸다 — 조합이 돼야 한다")
	assert(not scene._tab_todo("gear"),
		"조합만 되는데 장비 점이 켜졌다 — 조각은 늘 쌓여서 안 꺼진다")
	scene.whet = GearDefs.upgrade_cost(fit)
	assert(scene._gear_can_level(fkey), "준비가 틀렸다 — 레벨업이 돼야 한다")
	assert(scene._tab_todo("gear"), "레벨업이 되는데 장비 점이 안 켜진다")

	# ── 8) 던전 — 소탭 다섯이 각각 자기 것만 켠다 ─────────────────────────
	_broke(scene)
	scene.best_stage = DungeonDefs.OPEN_STAGE + 40
	scene.dungeon_best = 0
	assert(scene._raid_mode_todo("maze"),
		"안 뚫은 층이 있는데 미궁 소탭 점이 안 켜진다")
	for m in scene.RAID_MODES:
		if str(m[0]) != "maze":
			assert(not scene._raid_mode_todo(str(m[0])),
				"미궁만 열었는데 %s 소탭 점이 켜졌다" % str(m[0]))
	assert(scene._tab_todo("raid"), "소탭이 켜졌는데 던전 탭 점이 안 켜진다")
	# 다 뚫으면 다섯이 다 꺼지고 탭 점도 꺼진다 — 탭 점은 소탭의 합이다.
	scene.dungeon_best = DungeonDefs.open_floors(scene.best_stage)
	assert(not scene._raid_mode_todo("maze"), "다 뚫었는데 미궁 점이 켜져 있다")
	assert(not scene._tab_todo("raid"), "다섯이 다 꺼졌는데 던전 탭 점이 켜졌다")
	# 시련만 열면 시련 소탭만 켜진다 — 점이 어디인지를 말해야 소탭이 의미가 있다.
	scene.trial_stage = 0
	assert(scene._raid_mode_todo("trial"), "시련이 열렸는데 시련 점이 안 켜진다")
	assert(not scene._raid_mode_todo("maze"), "시련이 미궁 점을 켰다")
	assert(scene._tab_todo("raid"), "시련이 켜졌는데 던전 탭 점이 안 켜진다")

	# ── 9) 펫 — 먹이면 강화 소탭만 (사장님: "펫도 강화 가능한 거 빨간점") ──
	_broke(scene)
	scene.best_stage = PetDefs.PET_OPEN
	var pid := str(PetDefs.PETS[0]["id"])
	scene.pets_got = {pid: 1}
	for pm in scene.PET_TABS:
		assert(not scene._pet_mode_todo(str(pm[0])),
			"빈손인데 펫 %s 소탭 점이 켜졌다" % str(pm[0]))
	assert(not scene._tab_todo("pet"), "빈손인데 펫 탭 점이 켜졌다")
	scene.feed = PetDefs.feed_cost(scene._pet_lv(pid))
	assert(scene._pet_can_feed(pid), "먹이가 찼는데 강화가 안 된다")
	assert(scene._pet_mode_todo("feed"), "먹이가 찼는데 강화 소탭 점이 안 켜진다")
	assert(not scene._pet_mode_todo("own"), "먹이가 보유 소탭 점까지 켰다")
	assert(scene._tab_todo("pet"), "펫 소탭이 켜졌는데 펫 탭 점이 안 켜진다")
	# 못 만난 동행은 안 켠다 — 실루엣 칸에 점이 뜨면 만난 줄 안다.
	scene.pets_got = {}
	assert(not scene._pet_can_feed(pid), "못 만난 동행을 먹일 수 있다")

	# ── 10) 소환권 · 상점 교환 · 혈맥 제련 (사장님: "구매나 받기 가능한 거 다") ─
	_broke(scene)
	assert(not scene._tab_todo("summon"), "빈손인데 소환 점이 켜졌다")
	scene.tickets = {str(TicketDefs.KINDS[0]): 1}
	assert(scene._tab_todo("summon"), "소환권이 있는데 소환 점이 안 켜진다")

	_broke(scene)
	assert(not scene._shop_mode_todo("trade"), "빈손인데 교환 점이 켜졌다")
	scene.best_stage = 9999
	scene.gem = 100000.0
	assert(scene._shop_mode_todo("trade"), "살 수 있는데 교환 점이 안 켜진다")
	assert(scene._tab_todo("shop"), "교환이 켜졌는데 상점 탭 점이 안 켜진다")

	_broke(scene)
	assert(not scene._growth_mode_todo("trait"), "빈손인데 혈맥 점이 켜졌다")
	scene.trait_bake = {"x": [Time.get_unix_time_from_system() - 10.0, "rare"]}
	assert(scene._growth_mode_todo("trait"), "제련이 끝났는데 혈맥 점이 안 켜진다")
	scene.trait_bake = {"x": [Time.get_unix_time_from_system() + 9999.0, "rare"]}
	assert(not scene._growth_mode_todo("trait"), "제련 중인데 혈맥 점이 켜졌다")

	print("DotCheck OK")
	quit(0)


# 아무것도 못 하는 상태로 되돌린다. 각 절이 **한 축만** 켜는지 재려면
# 나머지가 전부 꺼져 있어야 한다.
func _broke(scene: Node) -> void:
	scene.gold = 0.0
	scene.crystal = 0.0
	scene.sigil = 0.0
	scene.whet = 0.0
	scene.gem = 0.0
	scene.feed = 0.0
	scene.stage = 1
	scene.best_stage = 1
	scene.lv = {}
	scene.traits = {}
	scene.relics = {}
	scene.pact_lv = 0
	scene.prestige_peak = 9999
	# 혈흔도 비운다 — 군림 각인이 생기면서(2026-09-02) 혈흔이 **쓰는 재화**가
	# 됐다. 안 비우면 "놀고 있는 혈흔"으로 점이 켜지고, 그건 점이 맞다.
	scene.prestige_marks = 0
	scene.prestige_keeps = {}
	scene.gear_inventory = {}
	scene.gacha_shards = {}
	scene.dungeon_best = 0
	scene.raid_on = ""
	scene.dungeon_on = false
	# 새 점 갈래들(2026-09-04)도 여기서 끈다 — "한 축만 켜는지"를 재려면
	# 나머지가 전부 꺼져 있어야 한다. 날짜 축은 **오늘로 박는다**: 안 박으면
	# 자정에 스스로 켜져서 검사가 날짜에 따라 빨개진다.
	scene.tickets = {}
	scene.trait_bake = {}
	scene.shop_used = {}
	scene.pets_got = {}
	scene.pet_bank = {}
	scene.pet_trip = {}
	scene.pet_lv = {}
	scene.pet_at = Time.get_unix_time_from_system()
	scene.boss_dmg = 0.0
	scene.boss_got = {}
	scene.trial_stage = TrialDefs.max_stage()
	var today := Time.get_date_string_from_system()
	scene.raid_date = today
	scene.rush_date = today
	scene.free_pull_date = today
	for k in RaidDefs.RAIDS:
		scene.raid_left[str(k)] = 0
