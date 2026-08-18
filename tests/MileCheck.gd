extends SceneTree

# 천장 상자 (GachaDefs.mile_* + Main._mile_*) — 뽑을수록 차고, 차면 돌려준다.
#
# 지키는 것 셋:
#   1. **상자가 새지 않는가** — 넘친 몫이 다음 상자로 이월되고, 두 번 안 준다.
#   2. **보상이 실제로 들어오는가** — 소환권 판은 소환권, 없는 판(유물)은 보석.
#   3. **펫 소환도 같은 상자를 채우는가** — 지불이 곧 적립이다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표 ─────────────────────────────────────────────────────────────────
	assert(GachaDefs.mile_cap(1) > GachaDefs.mile_cap(0), "상자가 안 커진다")
	assert(GachaDefs.mile_cap(99) == GachaDefs.MILE_CAP_MAX, "상한이 안 걸린다")

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.tickets = {}
	scene.mile_fill = 0
	scene.mile_lv = 0
	scene._mile_pending = []

	# 가득 + 1 — 보상이 오고, 넘친 1이 다음 상자로 이월된다.
	scene._mile_add("weapon", GachaDefs.mile_cap(0) + 1)
	assert(scene.mile_lv == 1, "상자가 안 열렸다")
	assert(scene.mile_fill == 1, "넘친 몫이 이월되지 않았다: %d" % scene.mile_fill)
	assert(int(scene.tickets.get("weapon", 0)) == GachaDefs.MILE_TICKETS,
		"소환권 보상이 안 들어왔다")
	assert(scene._mile_pending.size() == 1, "보상 창 줄이 안 쌓였다")

	# 소환권 없는 판(유물)은 보석으로.
	var gem0: float = scene.gem
	scene._mile_add("relic", GachaDefs.mile_cap(1))
	assert(scene.mile_lv == 2, "둘째 상자가 안 열렸다")
	assert(scene.gem - gem0 >= float(GachaDefs.MILE_GEM) - 0.5,
		"유물 판 보석 보상이 안 들어왔다")

	# 한 번에 두 상자를 넘기면 두 번 준다.
	var lv0: int = scene.mile_lv
	scene._mile_add("skill", GachaDefs.mile_cap(lv0) + GachaDefs.mile_cap(lv0 + 1))
	assert(scene.mile_lv == lv0 + 2, "두 상자가 한 번으로 접혔다")

	# 펫 소환도 같은 상자다 — 지불이 곧 적립.
	scene.tickets["pet"] = 1
	var fill0: int = scene.mile_fill
	scene._pet_pay("pet")
	assert(scene.mile_fill == fill0 + 1 or scene.mile_lv > lv0 + 2,
		"펫 지불이 상자를 안 채운다")

	# 보상 창 — 한 번 열면 비운다.
	scene._mile_pop()
	assert(scene._mile_pending.is_empty(), "보상 줄이 안 비워졌다")

	print("MileCheck OK")
	quit(0)
