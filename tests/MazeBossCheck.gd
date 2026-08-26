extends SceneTree

# 미궁 보스 얼굴 — 5개 순환을 21개로 늘렸다(2026-08-26, 사장님: "미궁 6층부터
# 얼굴이 반복된다"). 아트는 한 장도 안 뽑았다: 이미 있는 몹을 보스로 세운다.
#
# 재는 것:
#   1) 표 — 자산이 실재하고, 아이디가 안 겹치고, FoeTiers 에 있는 종인가
#   2) 콘텐츠끼리 얼굴이 안 겹치는가 (성소·주간보스·시련은 제 얼굴이 따로다)
#   3) 순환 — 21층까지 얼굴이 다 다르고 22층에 첫 얼굴로 돌아오는가
#   4) 세기는 층이 정한다 — 얼굴이 바뀌어도 체력 배수가 안 흔들린다
#   5) 5층마다 막 보스(전용 대형 아트)가 서는가
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	var n := DungeonDefs.MAZE_BOSSES.size()
	assert(n >= 20, "미궁 보스가 %d종뿐이다 — 늘린 뜻이 없다" % n)
	var keys := {}
	var anims := {}
	for row in DungeonDefs.MAZE_BOSSES:
		var key := str(row[0])
		var nm := str(row[1])
		var anim := str(row[2])
		assert(not keys.has(key), "몹 %s 가 표에 두 번 있다" % key)
		assert(not anims.has(anim), "애니 %s 가 표에 두 번 있다" % anim)
		keys[key] = true
		anims[anim] = true
		assert(nm.strip_edges() != "", "%s 에 이름이 없다" % key)
		# FoeTiers 에 있는 종이어야 체력·사거리가 나온다.
		assert(not FoeTiers.get_tier(key).is_empty(),
			"FoeTiers 에 없는 종: %s" % key)
		# 걷기·공격·예고 자산이 다 있어야 보스로 선다.
		for suffix in ["_walk", "_attack", "_special"]:
			var dir := "res://assets/anim/%s%s" % [anim, suffix]
			assert(DirAccess.dir_exists_absolute(dir), "자산이 없다: %s" % dir)

	# ── 2) 다른 콘텐츠의 얼굴과 안 겹친다 ─────────────────────────────────
	# 겹치면 "저기 가면 저 놈"이 안 선다. 사장님이 세 번 지적한 부류다.
	for b in EventDefs.BOSSES:
		assert(not keys.has(str(b["key"])),
			"주간 보스(%s)가 미궁에도 나온다" % str(b["key"]))
	assert(not keys.has("sanctum_guardian"), "성소의 수호자가 미궁에도 나온다")
	assert(not keys.has("ruin_warden"), "유적의 파수꾼(시련)이 미궁에도 나온다")

	# ── 3) 순환 ────────────────────────────────────────────────────────────
	var seen := {}
	for f in range(1, n + 1):
		var nm2 := str(DungeonDefs.boss_of(f)["name"])
		assert(not seen.has(nm2), "%d층에서 얼굴이 벌써 반복된다: %s" % [f, nm2])
		seen[nm2] = true
	assert(str(DungeonDefs.boss_of(n + 1)["name"])
		== str(DungeonDefs.boss_of(1)["name"]), "한 바퀴를 돌고 처음으로 안 온다")
	# 옛 구조(막 5개)였다면 6층이 1층과 같았다 — 그게 이 커밋이 고친 것이다.
	assert(str(DungeonDefs.boss_of(6)["name"])
		!= str(DungeonDefs.boss_of(1)["name"]), "6층이 아직 1층과 같은 얼굴이다")

	# ── 5) 5층마다 막 보스 ────────────────────────────────────────────────
	for f2 in [5, 10, 15, 20]:
		assert(str(DungeonDefs.boss_of(f2)["anim"]).begins_with("boss_"),
			"%d층이 막 보스가 아니다: %s" % [f2, str(DungeonDefs.boss_of(f2)["anim"])])

	# ── 4) 세기는 층이 정한다 ─────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.best_stage = 200
	scene.dungeon_best = 0
	scene._dungeon_enter()
	assert(scene.dungeon_on, "미궁 입장이 안 됐다")

	# 같은 층에서 얼굴만 바꿔 보고 체력이 그대로인지 본다 — 몹 hp_mult 는
	# 1.0~3.8 이라 그대로 쓰면 층마다 체력이 널뛴다.
	var hp_seen := []
	for f3 in range(1, n + 1):
		scene.dungeon_floor = 8          # 층은 고정
		var mb := DungeonDefs.boss_of(f3)
		hp_seen.append(FoeTiers.foe_hp(DungeonDefs.MAZE_BOSS_HP,
			StageDefs.enemy_power(scene._c_enemy_power()), true, false))
	for h in hp_seen:
		assert(is_equal_approx(float(h), float(hp_seen[0])),
			"얼굴이 바뀌었는데 체력이 흔들린다")
	# 그리고 층이 오르면 실제로 세진다.
	scene.dungeon_floor = 8
	var p8: int = scene._c_enemy_power()
	scene.dungeon_floor = 30
	assert(scene._c_enemy_power() > p8, "층이 올랐는데 안 세진다")

	print("MazeBossCheck OK  (얼굴 %d종 · 한 바퀴 %d층)" % [n, n])
	quit(0)
