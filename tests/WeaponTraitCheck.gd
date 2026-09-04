extends SceneTree

# 무기 특성 4종 (사장님 2026-09-02: "무기별 특수 능력").
#   1) 표 — 줄(lane) 넷이 서로 다른 특성이고, 모든 무기가 하나를 갖고, 다른 슬롯엔 없다
#   2) 승급이 줄을 지키는가 — 커먼 낡은 검을 신화까지 올려도 같은 특성이어야 한다
#   3) 넷이 **실제 전투에** 붙는가 — 표만 맞고 훅이 없으면 없는 규칙이다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ─────────────────────────────────────────────────────────────
	assert(GearDefs.WEAPON_TRAIT.size() == 4, "특성이 넷이 아니다")
	var seen := {}
	for t in GearDefs.WEAPON_TRAIT:
		assert(not seen.has(t), "특성이 겹친다: %s" % t)
		seen[str(t)] = true
		assert(GearDefs.trait_text(str(t)) != "",
			"%s 에 설명이 없다 — 안 적으면 없는 규칙이다" % t)
	for r in GachaDefs.RARITIES:
		var items: Array = GearDefs.items_of("weapon", str(r["key"]))
		assert(items.size() == 4, "%s 무기가 네 줄이 아니다: %d" % [r["key"], items.size()])
		var lanes := {}
		for i in items.size():
			var it := {"slot": "weapon", "rarity": str(r["key"]), "icon": str(items[i][0])}
			var wt := GearDefs.trait_of(it)
			assert(wt != "", "%s %s 에 특성이 없다" % [r["key"], items[i][1]])
			lanes[wt] = true
		assert(lanes.size() == 4, "%s 등급 안에서 특성이 겹친다" % r["key"])
	# 방어구·장신구에는 안 붙는다 — 셋 다 붙이면 규칙이 열둘이 된다.
	for slot in ["armor", "trinket"]:
		var it2 := {"slot": slot, "rarity": "common",
			"icon": str(GearDefs.items_of(slot, "common")[0][0])}
		assert(GearDefs.trait_of(it2) == "", "%s 에 특성이 붙었다" % slot)

	# ── 2) 승급이 줄을 지킨다 ─────────────────────────────────────────────
	var w := GearDefs.make("weapon", 1, GachaDefs.RARITIES[0])
	var t0 := GearDefs.trait_of(w)
	for i in GachaDefs.RARITIES.size() - 1:
		assert(GearDefs.promote(w), "승급이 안 된다")
		assert(GearDefs.trait_of(w) == t0,
			"승급하니 특성이 바뀌었다: %s -> %s (%s)" % [t0, GearDefs.trait_of(w), w["rarity"]])

	# ── 3) 전투에 붙는가 ──────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.stage = 1
	scene._restart_stage("측정")
	var wait := 0.0
	while wait < 20.0:
		await process_frame
		wait += scene.get_process_delta_time()
		if scene._phase == "fight" and (scene._aoe_targets() as Array).size() >= 3:
			break
	assert(scene._phase == "fight", "20초 안에 전투가 안 열렸다")

	# 특정 줄의 무기를 끼우는 헬퍼 — 표에서 그 특성의 아이콘을 찾아 넣는다.
	var equip := func(trait_key: String) -> void:
		for it3 in GearDefs.items_of("weapon", "common"):
			var cand := {"slot": "weapon", "rarity": "common", "icon": str(it3[0]),
				"name": str(it3[1]), "stat": "damage", "base": 1.0, "lv": 0}
			if GearDefs.trait_of(cand) == trait_key:
				scene.equipped["weapon"] = cand
				return
		assert(false, "%s 무기를 표에서 못 찾았다" % trait_key)
	var live := func() -> Array:
		var out: Array = []
		for f in scene.get_tree().get_nodes_in_group("foes"):
			if is_instance_valid(f) and not f.dying:
				out.append(f)
		out.sort_custom(func(a: Foe, b: Foe) -> bool: return a.position.x < b.position.x)
		return out

	# cleave — 표적 말고 앞의 둘만 더 맞는다(상한). 특성 없으면 아무도 안 맞는다.
	var foes: Array = live.call()
	assert(foes.size() >= 3, "몹이 셋 미만이다: %d" % foes.size())
	for f in foes:
		f.max_hp = 1e9
		f.hp = 1e9
	scene._summon_t = 0.0
	scene.oath_fx_t = 0.0        # 계약 버프(박쥐 폭풍)도 끈다 — 상한 없는 광역이 섞이면 못 잰다
	scene.equipped.erase("weapon")
	scene._cleave_swing(foes[0])
	assert(is_equal_approx(foes[1].hp, 1e9), "특성 없는데 광역이 났다")
	equip.call("cleave")
	scene._cleave_swing(foes[0])
	var hit := 0
	for f in foes:
		if f != foes[0] and f.hp < 1e9:
			hit += 1
	assert(hit == mini(GearDefs.CLEAVE_EXTRA, foes.size() - 1),
		"cleave 가 %d 마리를 더 벴다 (상한 %d)" % [hit, GearDefs.CLEAVE_EXTRA])

	# exec — 문턱 아래는 한 번에, 위는 아니다. 보스는 안 걸린다.
	equip.call("exec")
	var tgt: Foe = foes[0]
	tgt.hp = tgt.max_hp * (GearDefs.EXEC_AT + 0.05)
	scene._weapon_on_hit(tgt)
	assert(not tgt.dying, "문턱 위인데 처형됐다")
	tgt.hp = tgt.max_hp * (GearDefs.EXEC_AT - 0.02)
	scene._weapon_on_hit(tgt)
	assert(tgt.dying, "문턱 아래인데 처형이 안 됐다")
	var boss: Foe = foes[1]
	boss.is_boss = true
	boss.hp = boss.max_hp * 0.01
	scene._weapon_on_hit(boss)
	assert(not boss.dying, "보스가 처형됐다")
	boss.is_boss = false

	# stun — 걸리면 공격 시계가 안 돈다. 잠금 중엔 다시 안 걸린다. 보스는 면역.
	equip.call("stun")
	var st: Foe = foes[1]
	st.hp = st.max_hp
	st.combat_active = true
	st.engaged = true
	scene._weapon_on_hit(st)
	assert(st.stun_t > 0.0, "기절이 안 걸렸다")
	var lock0: float = st.stun_lock
	st.stun_t = 0.0
	scene._weapon_on_hit(st)
	assert(is_equal_approx(st.stun_lock, lock0), "잠금 중인데 또 걸렸다 — 무피해 루프가 된다")
	boss.is_boss = true
	boss.stun_t = 0.0
	boss.stun_lock = 0.0
	scene._weapon_on_hit(boss)
	assert(boss.stun_t <= 0.0, "보스가 기절했다")
	boss.is_boss = false
	# 얼어 있는 동안 _tick_attack 이 아무것도 안 한다(쿨다운도 보존).
	st.stun_t = 1.0
	var cd0: float = st._attack_cd
	st._tick_attack(0.5)
	assert(is_equal_approx(st._attack_cd, cd0), "기절 중에 공격 시계가 돌았다")

	# chain — 죽였을 때만 다음 놈이 맞고, 안 죽였으면 안 넘어간다.
	equip.call("chain")
	foes = live.call()
	assert(foes.size() >= 2, "chain 을 잴 몹이 둘 미만이다")
	var a: Foe = foes[0]
	var b: Foe = foes[1]
	b.hp = 1e9
	b.max_hp = 1e9
	a.hp = 1e9
	scene._weapon_on_hit(a)          # 안 죽였다
	assert(is_equal_approx(b.hp, 1e9), "안 죽였는데 다음 놈이 맞았다")
	a.take_damage(a.hp)              # 죽였다
	scene._weapon_on_hit(a)
	assert(b.hp < 1e9, "죽였는데 다음 놈에게 안 넘어갔다")

	# ── 4) 재련 — 줄만 바꾼다 (사장님 2026-09-02) ─────────────────────────
	# "어느 줄이 나오냐"가 뽑기 운이 되지 않게 하는 길. 등급·레벨·조각·장착이
	# 따라가야 하고, 보관함 키(icon)가 바뀌므로 옮기기가 새면 무기가 사라진다.
	var rw := GearDefs.make("weapon", 5, GachaDefs.RARITIES[1])   # 언커먼
	rw["lv"] = 7
	rw["copies"] = 2
	var k0 := str(rw["icon"])
	scene.gear_inventory = {k0: rw}
	scene.gacha_shards = {"gear:" + k0: 3}
	scene.equipped["weapon"] = rw.duplicate(true)
	scene.equipped["weapon"]["inventory_key"] = k0
	scene._gear_selected_key = k0
	var tr0 := GearDefs.trait_of(rw)
	var cost := GearDefs.reforge_cost(rw)
	assert(cost > 0.0, "재련 값이 0 이다")
	# 값은 레벨에 비례하지 않는다 — 오래 키운 무기가 제일 못 고치면 안 된다.
	var rw_hi := rw.duplicate(true)
	rw_hi["lv"] = 60
	assert(is_equal_approx(GearDefs.reforge_cost(rw_hi), cost),
		"재련 값이 레벨에 비례한다")
	# 연마석이 모자라면 아무 일도 없다.
	scene.whet = cost - 1.0
	scene._reforge_selected()
	assert(scene.gear_inventory.has(k0) and scene._gear_selected_key == k0,
		"연마석이 모자란데 재련됐다")
	# 되면: 줄이 다음으로, 키·조각·장착이 따라간다, 등급·레벨·묶음 그대로.
	scene.whet = cost
	scene._reforge_selected()
	var k1: String = scene._gear_selected_key
	assert(k1 != k0, "재련했는데 키가 그대로다")
	assert(is_equal_approx(scene.whet, 0.0), "연마석이 안 깎였다")
	assert(not scene.gear_inventory.has(k0), "옛 줄이 보관함에 남았다 — 무기가 둘이 됐다")
	var moved: Dictionary = scene.gear_inventory[k1]
	assert(GearDefs.trait_of(moved) != tr0, "줄이 안 바뀌었다")
	assert(str(moved["rarity"]) == "uncommon" and int(moved["lv"]) == 7
		and int(moved["copies"]) == 2, "등급·레벨·묶음이 안 따라왔다")
	assert(int(scene.gacha_shards.get("gear:" + k1, 0)) == 3
		and not scene.gacha_shards.has("gear:" + k0), "조각이 안 따라왔다")
	assert(str(scene.equipped["weapon"].get("inventory_key", "")) == k1
		and str(scene.equipped["weapon"]["icon"]) == k1, "장착본이 옛 줄을 가리킨다")
	# 네 번 돌면 제자리 — 어디든 세 번 안에 닿는다.
	scene.whet = cost * 3.0
	for i in 3:
		scene._reforge_selected()
	assert(scene._gear_selected_key == k0, "네 번 돌았는데 제자리가 아니다: %s" % scene._gear_selected_key)
	# 무기가 아니면 재련이 없다.
	var ar := GearDefs.make("armor", 5, GachaDefs.RARITIES[0])
	assert(GearDefs.next_lane_spec(ar).is_empty(), "방어구에 재련이 붙었다")

	# ── 5) 상세 카드 — 글자끼리 안 겹친다 (사장님 2026-09-04 스크린샷) ────
	# 특성 줄을 오른쪽 칸 y142(높이 18)에 끼워 넣었더니 자원 첫 줄(y146)과
	# 14px 겹쳐 **둘 다** 못 읽었다. 좌표를 손으로 박는 카드라 줄을 하나 더
	# 늘리면 또 난다 — 쌍마다 사각형이 안 물리는지 통째로 잰다.
	scene._gear_selected_key = k0
	scene._refresh_gear_detail()
	var labels: Array = []
	for ch in scene._gear_detail.get_children():
		# _refresh_gear_detail 은 queue_free 로 옛 글자를 치운다 — 같은 프레임에는
		# 아직 붙어 있어서 자기 자신과 겹친 것으로 잡힌다.
		if ch is Label and not ch.is_queued_for_deletion() and str(ch.text) != "":
			labels.append(ch)
	assert(labels.size() >= 6, "상세 카드에 글자가 안 그려졌다: %d" % labels.size())
	var trait_line := ""
	for ia in labels.size():
		var la: Label = labels[ia]
		if str(la.text).begins_with("특성"):
			trait_line = str(la.text)
		for ib in range(ia + 1, labels.size()):
			var lb: Label = labels[ib]
			assert(not Rect2(la.position, la.size).intersects(
					Rect2(lb.position, lb.size)),
				"상세 카드 글자가 겹친다: \"%s\" %s <-> \"%s\" %s"
				% [la.text, la.position, lb.text, lb.position])
	assert(trait_line != "", "무기인데 특성 줄이 없다")
	# 문구가 잘리지 않는가 — 전폭 줄(532px)로 옮긴 이유다. 제일 긴 연쇄 문구가
	# 옛 306px 칸보다 길다는 것을 폰트로 직접 잰다.
	var longest := 0.0
	for tk in GearDefs.WEAPON_TRAIT:
		var fnt := ThemeDB.fallback_font
		longest = maxf(longest, fnt.get_string_size("특성  "
			+ GearDefs.trait_text(str(tk)),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, Type.SIZE_SMALL).x)
	assert(longest < 532.0, "제일 긴 특성 문구가 전폭 줄에도 안 들어간다: %.0fpx" % longest)

	# **뒷정리.** 재련이 _save_game 을 타서 특성 무기가 저장본에 남는다. 그러면
	# 다음 검사(AoeCheck)가 스킬 이펙트를 세는 프레임에 평타 특성 이펙트가 끼어
	# 빨개진다 — 실제로 났다. 검사는 자기가 어질러 놓은 것을 치운다(PrestigeCheck 규칙).
	scene.equipped.erase("weapon")
	scene.gear_inventory = {}
	scene._save_game()

	print("WeaponTraitCheck OK  (표 4줄 · 승급이 줄을 지킴 · 광역/처형/기절/연쇄 실전 · 재련)")
	quit(0)
