extends SceneTree

# 장비 굴림 자체 점검. 아이콘 풀이 비거나(파일명 접두어가 바뀌면 조용히 빈다)
# 등급표가 깨지면 드랍이 아무 말 없이 사라지므로 여기서 잡는다.
#   godot --headless --script tests/GearTest.gd

func _init() -> void:
	for slot in GearDefs.SLOTS:
		var pool := GearDefs.icon_pool(slot)
		assert(pool.size() > 0, "아이콘 풀이 비었다: " + slot)

		var item := GearDefs.roll(slot, 10)
		assert(item["slot"] == slot)
		assert(GearDefs.power(item) > 0.0)
		assert(not str(item["name"]).is_empty())
		assert(FileAccess.file_exists(GearDefs.icon_path(item)), GearDefs.icon_path(item))
		assert(FileAccess.file_exists(GearDefs.slot_frame(item)), GearDefs.slot_frame(item))

	# 단계가 오르면 같은 등급이라도 수치가 커져야 한다 — 안 그러면 진행할 이유가 없다.
	var low := 0.0
	var high := 0.0
	for i in 200:
		low += GearDefs.power(GearDefs.roll("weapon", 1))
		high += GearDefs.power(GearDefs.roll("weapon", 30))
	assert(high > low * 2.0, "단계별 성장이 없다")

	# 이름은 등급 접두어 + 명사 조합이라 등급이 바뀌면 이름도 바뀌어야 한다.
	var names := {}
	for r in GearDefs.RARITY:
		names[r["name"]] = true
	assert(names.size() == GearDefs.RARITY.size(), "등급 이름이 겹친다")

	# 강화는 수치를 올리고 비용은 매번 비싸져야 한다 — 아니면 무한 강화가 최적이 된다.
	var it := GearDefs.roll("weapon", 5)
	var p0 := GearDefs.power(it)
	var c0 := GearDefs.upgrade_cost(it)
	it["lv"] = 1
	assert(GearDefs.power(it) > p0, "강화가 수치를 안 올린다")
	assert(GearDefs.upgrade_cost(it) > c0, "강화 비용이 안 오른다")

	# 도감은 몹 표 전체를 덮어야 한다. 스프라이트가 빠지면 빈 칸으로 남는다.
	var keys := FoeTiers.all_keys()
	assert(keys.size() == FoeTiers.TIERS.size())
	for k in keys:
		assert(FileAccess.file_exists(FoeTiers.sprite_of(k)), "몹 그림 없음: " + str(k))
		# M1: 모든 몹은 전열 도착 후 7프레임 attack을 실제로 재생한다.
		for frame in 7:
			assert(FileAccess.file_exists("res://assets/anim/%s_attack/%d.png" % [k, frame]),
				"몹 공격 프레임 없음: %s/%d" % [k, frame])

	# 영웅 피격·임팩트·사망 연출의 핵심 자산도 조용히 빠지면 안 된다.
	for frame in 7:
		assert(FileAccess.file_exists("res://assets/anim/valentino_1_attack/%d.png" % frame))
		assert(FileAccess.file_exists("res://assets/anim/fx_death_blood/%d.png" % frame))
	for frame in 5:
		assert(FileAccess.file_exists("res://assets/anim/valentino_1_hurt/%d.png" % frame))
		assert(FileAccess.file_exists("res://assets/anim/fx_cleave/%d.png" % frame))

	print("GearTest OK")
	quit()
