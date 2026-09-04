extends SceneTree

# 펫 원정 — 내보내면 조각을 파 온다.
#
# 재는 것:
#   1) 표 — 등급마다 시간이 다르고 오름차순, 칸 수가 보유량을 따른다
#   2) 파 올 물건 — 5성 미만은 제 조각, 5성은 낀 장비 조각, 둘 다 막히면 못 보냄
#   3) 시간은 **나올 조각의 등급**이 정한다 (보낸 펫이 아니다 — 커먼 펫을
#      4시간에 보내 전설 장비 조각을 캐는 구멍을 막는 자리)
#   4) 보상 — 조각이 정확히 +1, 넉 장이면 승급
#   5) 칸 수 상한, 시간 전 수령 거부
#   6) 원정 중인 펫은 둥지에서 안 긁는다
#   7) 저장·복원, 알림점
#
# 시스템 시계는 못 돌린다 — pet_trip 의 완료 시각을 과거로 직접 밀어 앞당긴다.
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 1) 표 ──────────────────────────────────────────────────────────────
	var prev := 0.0
	for r in PetDefs.RARITY_KEYS:
		var h := PetDefs.trip_hours(str(r))
		assert(h > prev, "원정 시간이 %s 에서 안 오른다" % str(r))
		prev = h
	assert(PetDefs.trip_slots(5) == 2 and PetDefs.trip_slots(12) == 2
		and PetDefs.trip_slots(13) == 3 and PetDefs.trip_slots(21) == 4
		and PetDefs.trip_slots(25) == 4, "파견 칸 수가 표와 다르다")
	assert(PetDefs.trip_slots(0) == 2, "보유 0 에서 칸이 음수로 샌다")

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 커먼(밤날개)·전설 하나를 잡아 둔다 — 등급별 시간을 실제로 재려면 둘이 필요하다.
	var leg := ""
	for p in PetDefs.PETS:
		if str(p["rarity"]) == "legend":
			leg = str(p["id"])
			break
	assert(leg != "", "전설 펫이 표에 없다")

	scene.best_stage = 200
	scene.pets_got = {"nightwing": 1, leg: 1}
	scene.pet_lv = {"nightwing": 1, leg: 1}
	scene.pet_bank = {"nightwing": 0.0, leg: 0.0}
	scene.pet_gear_got = {}
	scene.pet_gear_worn = {}
	scene.gacha_shards = {}
	scene.pet_trip = {}
	scene.pet_at = Time.get_unix_time_from_system()

	# ── 2·3) 파 올 물건과 시간 ─────────────────────────────────────────────
	var pz: Dictionary = scene._trip_prize("nightwing")
	assert(str(pz["key"]) == "pet:nightwing", "5성 미만인데 제 조각을 안 판다")
	assert(str(pz["rarity"]) == "common")
	scene._trip_send("nightwing")
	assert(scene.pet_trip.has("nightwing"), "안 나갔다")
	var due: float = float(scene.pet_trip["nightwing"][0])
	var want := Time.get_unix_time_from_system() + 4.0 * 3600.0
	assert(absf(due - want) < 5.0, "커먼 원정이 4시간이 아니다")

	# 5성 펫은 낀 장비의 조각을 판다 — 그리고 **시간은 장비 등급**을 따른다.
	# (커먼 펫을 보내 전설 장비 조각을 4시간에 캐면 안 된다.)
	scene.pets_got["nightwing"] = PetDefs.MAX_STAR
	# (옛 규칙은 "장비가 없으면 못 보낸다"였다. 2026-08-27 부터 완성한 펫은
	#  심부름을 가므로, 장비가 없어도 미완성 동료가 있으면 그쪽 조각을 판다 —
	#  심부름 자체는 8절이 잰다. 여기는 장비 조각 갈래만 본다.)
	var leg_gear := ""
	for g in PetDefs.GEAR:
		if str(g["rarity"]) == "legend":
			leg_gear = str(g["id"])
			break
	scene.pet_gear_got[leg_gear] = 1
	scene.pet_gear_worn["nightwing"] = leg_gear
	var pz2: Dictionary = scene._trip_prize("nightwing")
	assert(str(pz2["key"]) == "petgear:" + leg_gear, "5성이 장비 조각을 안 판다")
	assert(str(pz2["rarity"]) == "legend",
		"시간 기준이 보낸 펫(커먼)을 따라갔다 — 나올 조각(전설)이어야 한다")
	# 장비도 5성이면 — 옛 규칙은 빈손(원정 불가)이었다. 2026-08-27 부터는
	# **심부름**이다: 보유 중 미완성 펫(여기서는 전설 1성)의 조각을 파 온다.
	scene.pet_gear_got[leg_gear] = PetDefs.MAX_STAR
	var pz3: Dictionary = scene._trip_prize("nightwing")
	assert(str(pz3.get("key", "")) == "pet:" + leg,
		"다 완성했는데 심부름을 안 간다: %s" % str(pz3))
	scene.pet_gear_got[leg_gear] = 1
	scene.pets_got["nightwing"] = 1
	scene.pet_gear_worn = {}

	# ── 4) 보상 — 조각 +1, 넉 장이면 승급 ──────────────────────────────────
	# 시간 전에는 못 받는다.
	scene._trip_claim("nightwing")
	assert(scene.pet_trip.has("nightwing"), "시간이 남았는데 받아졌다")
	assert(int(scene.gacha_shards.get("pet:nightwing", 0)) == 0, "조각이 미리 들어왔다")

	for n in range(1, PetDefs.SHARDS_PER_STAR + 1):
		scene.pet_trip["nightwing"][0] = 0.0        # 도착시킨다
		scene._trip_claim("nightwing")
		assert(not scene.pet_trip.has("nightwing"), "받았는데 자리가 안 비었다")
		if n < PetDefs.SHARDS_PER_STAR:
			assert(int(scene.gacha_shards.get("pet:nightwing", 0)) == n,
				"조각이 %d 이어야 하는데 %d" % [n,
				int(scene.gacha_shards.get("pet:nightwing", 0))])
			assert(scene.pets_got["nightwing"] == 1, "아직 승급하면 안 된다")
			scene._trip_send("nightwing")
		else:
			assert(scene.pets_got["nightwing"] == 2,
				"조각 %d 장인데 승급을 안 했다" % PetDefs.SHARDS_PER_STAR)
			assert(int(scene.gacha_shards.get("pet:nightwing", 0)) == 0,
				"승급하고 조각이 안 빠졌다")

	# ── 5) 칸 수 상한 ──────────────────────────────────────────────────────
	scene.pet_trip = {}
	scene._trip_send("nightwing")
	scene._trip_send(leg)
	assert(scene.pet_trip.size() == 2, "두 칸이 안 찼다")
	# 보유 2종이면 칸이 2개다 — 세 번째는 안 나가야 한다(더 보낼 펫도 없지만
	# 칸 검사 자체를 재기 위해 보유를 늘려 둔 뒤 다시 본다).
	var third := ""
	for p in PetDefs.PETS:
		if not scene.pets_got.has(str(p["id"])):
			third = str(p["id"])
			break
	scene.pets_got[third] = 1
	scene.pet_lv[third] = 1
	assert(PetDefs.trip_slots(scene.pets_got.size()) == 2, "보유 3종인데 칸이 늘었다")
	scene._trip_send(third)
	assert(scene.pet_trip.size() == 2, "칸이 찼는데 세 번째가 나갔다")

	# ── 6) 원정 중인 펫은 둥지에서 안 긁는다 ───────────────────────────────
	scene.pet_bank[third] = 0.0
	scene.pet_bank["nightwing"] = 0.0
	scene.pet_at = Time.get_unix_time_from_system() - 3600.0 * 6.0
	scene._pet_tick()
	assert(is_equal_approx(float(scene.pet_bank["nightwing"]), 0.0),
		"원정 중인데 둥지가 찼다: %f" % float(scene.pet_bank["nightwing"]))
	assert(float(scene.pet_bank[third]) > 0.0, "안 나간 펫이 안 모은다")

	# ── 7) 저장·복원 · 알림점 ──────────────────────────────────────────────
	scene._save_game()
	var keep: Array = (scene.pet_trip["nightwing"] as Array).duplicate()
	scene.pet_trip = {}
	scene._load_game()
	assert(scene.pet_trip.has("nightwing"), "원정이 저장·복원을 못 넘었다")
	assert(str(scene.pet_trip["nightwing"][1]) == str(keep[1]),
		"복원된 원정의 조각 키가 다르다")

	# 알림점 — 도착하면 켜지고, 나가 있는 중에는 이것 때문에 켜지지 않는다.
	scene.tickets["pet"] = 0
	scene.tickets["petgear"] = 0
	scene.feed = 0.0
	scene.pet_at = Time.get_unix_time_from_system()
	for id in scene.pets_got:
		scene.pet_bank[id] = 0.0
	scene.pet_trip = {"nightwing": [Time.get_unix_time_from_system() + 9999.0,
		"pet:nightwing"]}
	assert(not scene._tab_todo("pet"), "아직 안 왔는데 점이 켜졌다")
	scene.pet_trip["nightwing"][0] = 0.0
	assert(scene._tab_todo("pet"), "도착했는데 점이 안 켜진다")

	# ── 8) 다 완성한 펫은 심부름을 간다 (2026-08-27 새 칸) ────────────────
	# 제 별도 낀 장비도 5성이면 예전엔 빈손이라 원정을 아예 못 갔다 — 제일
	# 공들인 펫이 짐이 됐다. 이제 보유 중 미완성 펫 가운데 **제일 희귀한 놈**의
	# 조각을 파 온다. 시간은 그 조각의 등급을 따른다(기존 규칙 그대로).
	scene.pets_got = {"nightwing": PetDefs.MAX_STAR, "gravemoss": 2}
	scene.pet_gear_worn = {}
	scene.pet_trip = {}
	var errand: Dictionary = scene._trip_prize("nightwing")
	assert(str(errand.get("key", "")) == "pet:gravemoss",
		"완성한 펫이 심부름을 안 간다: %s" % str(errand))
	# 더 희귀한 미완성이 생기면 그쪽으로 간다.
	scene.pets_got[leg] = 1              # 전설 1성 (표에서 찾아 둔 진짜 id)
	var errand2: Dictionary = scene._trip_prize("nightwing")
	assert(str(errand2.get("rarity", "")) == "legend",
		"심부름이 제일 희귀한 놈을 안 고른다: %s" % str(errand2))
	# 시간은 심부름 대상 등급이 정한다 — 커먼 펫을 보내도 전설이면 16시간.
	scene.best_stage = 999
	scene._trip_send("nightwing")
	var row: Array = scene.pet_trip["nightwing"]
	var left := float(row[0]) - Time.get_unix_time_from_system()
	assert(absf(left - PetDefs.trip_hours("legend") * 3600.0) < 5.0,
		"심부름 시간이 대상 등급을 안 따른다: %.0f초" % left)
	assert(str(row[1]) == "pet:" + leg, "심부름 보상 키가 다르다: %s" % str(row[1]))
	# 미보유 펫 조각은 절대 안 준다 — 소환을 우회하게 된다.
	scene.pet_trip = {}
	scene.pets_got = {"nightwing": PetDefs.MAX_STAR}
	assert(scene._trip_prize("nightwing").is_empty(),
		"로스터가 다 끝났는데도 뭘 파 온다 — 미보유 조각이 새고 있다")

	# ── 모두 보내기 (사장님 2026-09-02) ──────────────────────────────────
	# 칸이 2~4개인데 한 마리씩 고르려면 격자 스물다섯 칸을 훑어야 했다.
	scene.pet_trip = {}
	scene.best_stage = PetDefs.TRIP_OPEN
	scene.pets_got = {}
	scene.pet_gear_worn = {}
	# 보낼 수 있는 펫을 넉넉히 쥐어 준다(별 5 미만이면 제 조각을 판다).
	for p2 in PetDefs.PETS:
		scene.pets_got[str(p2["id"])] = 1
	var slots: int = PetDefs.trip_slots(scene.pets_got.size())
	assert(slots >= 2, "파견 칸이 없다")
	assert(scene._trip_can_send_any(), "보낼 수 있는데 버튼이 꺼져 있다")
	scene._trip_send_all()
	# **칸을 넘겨 보내지 않는다.** 여기가 새면 원정이 무한이 된다.
	assert(scene.pet_trip.size() == slots,
		"칸 %d 인데 %d 마리를 보냈다" % [slots, scene.pet_trip.size()])
	# 꽉 찼으면 버튼이 꺼진다 — 버튼과 동작이 **같은 자**를 써야 "눌러도 아무
	# 일 없는" 자리가 안 생긴다.
	assert(not scene._trip_can_send_any(), "꽉 찼는데 버튼이 켜져 있다")
	var before: int = scene.pet_trip.size()
	scene._trip_send_all()
	assert(scene.pet_trip.size() == before, "꽉 찬 뒤에도 더 보냈다")

	# 문턱 아래에서는 한 마리도 안 나간다.
	scene.pet_trip = {}
	scene.best_stage = PetDefs.TRIP_OPEN - 1
	assert(not scene._trip_can_send_any(), "%d구간 전인데 버튼이 켜져 있다"
		% PetDefs.TRIP_OPEN)
	scene._trip_send_all()
	assert(scene.pet_trip.is_empty(), "문턱 전인데 원정이 나갔다")

	# 이미 나간 펫은 두 번 안 보낸다.
	scene.best_stage = PetDefs.TRIP_OPEN
	scene._trip_send_all()
	var out_ids: Array = scene.pet_trip.keys().duplicate()
	scene._trip_send_all()
	assert(scene.pet_trip.keys() == out_ids, "같은 펫을 또 보냈다")

	print("TripCheck OK  (원정 표·심부름·모두 보내기)")
	quit(0)
