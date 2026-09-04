extends SceneTree

# 알림점 정비 (2026-08-27 사장님: "빨간점 세세하게 다 표시해줘").
#
# 재는 것:
#   1) 소탭 점이 실제로 붙어 있다 — 성장 6 · 상점 6 · 계약 옆줄 1
#   2) **스킬 조각은 성장 탭이 켠다** — 소환 탭이 아니라. (스킬 화면이 성장
#      탭으로 이사했는데 점이 소환 탭에 남아 있던 배선 사고의 회귀 검사)
#   3) 탭 점과 소탭 점이 **같은 함수**를 본다 — 성장 탭 점 = 소탭 여섯의 합
#   4) 계약 옆줄 점 — 카드가 꽉 찼을 때만 (40분마다 켜지는 잔소리 금지)
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(docs/CHECKS.md).

func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 1) 점이 실제로 붙어 있다 ──────────────────────────────────────────
	assert(scene._growth_mode_dots.size() == 6,
		"성장 소탭 점이 %d 개다 (6 이어야)" % scene._growth_mode_dots.size())
	assert(scene._shop_mode_dots.size() == 6,
		"상점 소탭 점이 %d 개다 (6 이어야)" % scene._shop_mode_dots.size())
	assert(scene._oath_side_dot != null, "계약 옆줄 점이 없다")

	# ── 2) 스킬 조각 — 성장이 켜고 소환은 안 켠다 ─────────────────────────
	# 조각이 충분한 스킬 하나를 꾸민다.
	scene.skill_owned = {"strike_common": 1}
	scene.gacha_shards = {"skill:strike_common": 9999}
	scene.free_pull_date = Time.get_date_string_from_system()   # 무료 소환은 끔
	# 소환권도 비운다 — 2026-09-04 부터 권을 들고 있으면 소환 탭이 켜진다.
	# 여기서 재는 건 "**조각이** 소환 탭을 켜는가"라 다른 축은 꺼 둬야 한다.
	# (씬 검사는 저장본을 공유해서 앞 검사가 남긴 권이 그대로 들어온다.)
	scene.tickets = {}
	assert(scene._growth_mode_todo("skill"), "조각이 충분한데 스킬 소탭이 안 켜진다")
	assert(scene._tab_todo("growth"), "스킬 조각이 성장 탭 점을 안 켠다")
	assert(not scene._tab_todo("summon"),
		"스킬 조각이 소환 탭을 켠다 — 옮긴 배선이 되돌아갔다")
	# 조각을 비우면 스킬 소탭은 꺼진다.
	scene.gacha_shards = {}
	assert(not scene._growth_mode_todo("skill"), "조각이 없는데 스킬 소탭이 켜져 있다")

	# ── 3) 탭 점 = 소탭 합 ────────────────────────────────────────────────
	# 어떤 상태에서든 성장 탭 점은 소탭 여섯의 논리합과 같아야 한다.
	var any := false
	for m in ["stat", "skill", "trait", "pact", "relic", "prestige"]:
		if scene._growth_mode_todo(str(m)):
			any = true
	assert(scene._tab_todo("growth") == any,
		"성장 탭 점(%s)과 소탭 합(%s)이 다르다 — 조건이 두 벌이 됐다"
		% [scene._tab_todo("growth"), any])
	# 상점도 같은 규칙 — **화면에 있는 소탭 전부**의 합이다. 이름을 손으로
	# 적어 두면 갈래를 늘릴 때 여기가 낡는다(2026-09-04 교환 갈래에서 그랬다).
	var sany := false
	for k in scene._shop_mode_dots:
		if scene._shop_mode_todo(str(k)):
			sany = true
	assert(scene._tab_todo("shop") == sany,
		"상점 탭 점(%s)과 소탭 합(%s)이 다르다" % [scene._tab_todo("shop"), sany])

	# ── 4) 계약 옆줄 — 꽉 찼을 때만 ───────────────────────────────────────
	scene.oath_cards = 1
	scene._refresh_tab_dots()
	var one_card: bool = scene._oath_side_dot.visible
	scene.oath_cards = OathDefs.card_cap(scene._oath_member())
	scene._refresh_tab_dots()
	assert(scene._oath_side_dot.visible, "카드가 꽉 찼는데 계약 점이 안 켜진다")
	# 한 장일 때 켜져 있었다면 그건 40분마다 켜지는 잔소리다.
	# (수집 보상이 차 있는 저장본이면 한 장에도 켜질 수 있다 — 그 경우만 허용.)
	var nx: Dictionary = scene._oath_col_next()
	var col_ready: bool = not nx.is_empty() \
			and scene._oath_col_count() >= int(nx["need"])
	if not col_ready:
		assert(not one_card, "카드 한 장에 계약 점이 켜졌다 — 잔소리 점이다")

	print("DotCheck2 OK  (소탭 점 13개 · 스킬 조각은 성장 탭 · 탭=소탭 합 · 계약 꽉참)")
	quit(0)
