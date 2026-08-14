extends SceneTree

# 과금(IapDefs + Main._iap_buy)을 잰다. **결제 SDK 는 아직 없다** — 그래서
# 더더욱 이 검사가 필요하다: SDK 가 붙는 날 처음 돌아가는 코드가 아니라,
# 이미 검증된 코드에 결제 결과만 이으면 되는 상태로 둔다.
#
# 지키는 것 다섯:
#   1) 표 — 가격·기간·보상 키가 성립하고, 보상 이름을 _grant_reward 가 안다
#   2) 1회성 — 팩은 계정당 한 번. 두 번째 구매는 거절된다
#   3) 구독 — 만료일이 서고, 재구매는 남은 날에 이어 붙는다
#   4) 상시 효과 — 방치 상한 +4(단 16 상한) · 던전 표 +1
#   5) 저장 — 구독·구매 이력·첫 구매 표식이 복원된다
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	assert(IapDefs.SUBS.size() >= 1 and IapDefs.PACKS.size() >= 3
		and IapDefs.GEMS.size() >= 3, "상품 표가 비었다")
	for p in IapDefs.PACKS:
		assert(int(p["price"]) > 0 and int(p["open"]) >= 1, "팩 값이 이상하다")
		assert(not Dictionary(p["reward"]).is_empty(), "팩에 보상이 없다")
		assert(int(p["value"]) >= 100, "가치 배지가 100%% 미만이다: %s" % str(p["id"]))
	for s in IapDefs.SUBS:
		assert(int(s["days"]) > 0 and int(s["price"]) > 0, "구독 값이 이상하다")
	# 값이 오르면 주는 것도 늘어야 한다 — 보석 표가 뒤집혀 있으면 안 판다.
	for i in range(1, IapDefs.GEMS.size()):
		assert(int(IapDefs.GEMS[i]["gem"]) > int(IapDefs.GEMS[i - 1]["gem"])
			and int(IapDefs.GEMS[i]["price"]) > int(IapDefs.GEMS[i - 1]["price"]),
			"보석 표가 단조롭지 않다")
	assert(IapDefs.price_text(11000) == "11,000원", "값 표기가 깨졌다")

	# ── 씬 ────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.best_stage = 100
	scene.iap_subs = {}
	scene.iap_bought = {}
	scene.iap_first_buy = false

	# ── 2) 1회성 ───────────────────────────────────────────────────────────
	var pack: Dictionary = IapDefs.PACKS[0]
	var pid := str(pack["id"])
	var gem0: float = scene.gem
	assert(scene._iap_buy(pid), "첫 구매가 거절됐다")
	assert(scene.gem > gem0, "팩 보상이 안 들어왔다")
	var gem1: float = scene.gem
	assert(not scene._iap_buy(pid), "계정당 1회를 두 번 팔았다")
	assert(is_equal_approx(scene.gem, gem1), "두 번째 구매가 지급을 또 했다")

	# 아직 못 간 구간의 팩은 안 팔린다.
	scene.best_stage = 1
	var far := ""
	for p2 in IapDefs.PACKS:
		if int(p2["open"]) > 1:
			far = str(p2["id"])
			break
	assert(far != "" and not scene._iap_buy(far), "잠긴 팩이 팔렸다")
	scene.best_stage = 100

	# ── 3) 구독 ────────────────────────────────────────────────────────────
	var sub: Dictionary = IapDefs.SUBS[0]
	var sid := str(sub["id"])
	assert(not IapDefs.sub_active(scene.iap_subs, sid), "안 산 구독이 살아 있다")
	assert(scene._iap_buy(sid), "구독 구매가 거절됐다")
	assert(IapDefs.sub_active(scene.iap_subs, sid), "구독이 안 붙었다")
	var until1 := str(scene.iap_subs[sid])
	# 재구매는 **이어 붙는다** — 남은 날을 버리면 미리 사는 사람이 손해다.
	scene._iap_buy(sid)
	assert(str(scene.iap_subs[sid]) > until1, "재구매가 기간을 안 늘렸다")
	# 지난 날짜는 죽은 것으로 본다.
	scene.iap_subs[sid] = "2000-01-01"
	assert(not IapDefs.sub_active(scene.iap_subs, sid), "만료된 구독이 살아 있다")

	# ── 4) 상시 효과 ───────────────────────────────────────────────────────
	scene.iap_subs = {}
	var cap0: float = scene._offline_cap_hours()
	var tries0 := RaidDefs.TRIES_PER_DAY + IapDefs.raid_bonus_tries(scene.iap_subs)
	scene._iap_buy("blood_tax")
	assert(scene._offline_cap_hours() > cap0, "혈세가 방치 상한을 안 올렸다")
	assert(scene._offline_cap_hours() <= scene.IDLE_CAP_MAX, "상한 16을 넘었다")
	assert(IapDefs.raid_bonus_tries(scene.iap_subs) == 1, "던전 표가 안 늘었다")
	assert(IapDefs.ads_removed(scene.iap_subs), "광고 제거가 안 붙었다")
	# 표는 **하루가 바뀔 때** 다시 나뉜다 — 그날부터 한 판 더다.
	scene.raid_date = ""
	scene._raid_roll_day()
	assert(scene._raid_left("blood") == tries0 + 1, "새 하루에 표가 안 늘었다")

	# 첫 구매 2배는 **한 번뿐**이다 — 상시 배수는 정가를 거짓말로 만든다.
	scene.gem = 0.0
	scene.iap_first_buy = false
	var g: Dictionary = IapDefs.GEMS[0]
	scene._iap_buy(str(g["id"]))
	assert(is_equal_approx(scene.gem, float(g["gem"]) * IapDefs.FIRST_BUY_MULT),
		"첫 구매가 두 배가 아니다: %f" % scene.gem)
	scene.gem = 0.0
	scene._iap_buy(str(g["id"]))
	assert(is_equal_approx(scene.gem, float(g["gem"])), "두 번째도 두 배로 줬다")

	# ── 5) 저장 ────────────────────────────────────────────────────────────
	scene._save_game()
	var subs_before: Dictionary = scene.iap_subs.duplicate()
	var bought_before: Dictionary = scene.iap_bought.duplicate()
	scene.iap_subs = {}
	scene.iap_bought = {}
	scene.iap_first_buy = false
	scene._load_game()
	assert(scene.iap_subs == subs_before and scene.iap_bought == bought_before,
		"구매 이력이 복원 안 됐다")
	assert(scene.iap_first_buy, "첫 구매 표식이 복원 안 됐다")

	print("IapCheck OK")
	quit()
