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
	scene.gear_inventory = {}
	scene.gacha_shards = {}
	scene.dungeon_best = 0
	scene.raid_on = ""
	scene.dungeon_on = false
