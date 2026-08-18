extends SceneTree

# 출석(AttendDefs)과 은총(BoonDefs).
#
# 둘 다 **보상을 주는 자리**라 조용히 새면 곧 재화 밸런스가 무너진다.
# 특히 출석은 "하루 한 번"이 유일한 방어선이다 — 그게 새면 무한히 받는다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	# ── 표: 출석 ───────────────────────────────────────────────────────────
	for d in range(1, AttendDefs.DAYS + 1):
		var a := AttendDefs.of(d)
		assert(int(a["day"]) == d, "%d일차가 자기 날을 모른다" % d)
		assert(int(a["amount"]) > 0, "%d일차 보상이 0 이다" % d)
		assert(str(a["reward"]) != "", "%d일차 보상 종류가 없다" % d)
	# 큰 날이 보통 날보다 커야 이정표로 읽힌다.
	for big in AttendDefs.REWARDS:
		assert(bool(AttendDefs.of(int(big))["big"]), "%d일차가 큰 날이 아니다" % big)
	# 한 바퀴를 돌면 1일로 — 끝이 있으면 끝난 뒤에 할 게 없다.
	assert(AttendDefs.next_day(0) == 1, "첫 칸이 1일이 아니다")
	assert(AttendDefs.next_day(AttendDefs.DAYS) == 1, "한 바퀴 뒤가 1일이 아니다")
	assert(AttendDefs.next_day(AttendDefs.DAYS + 3) == 4, "두 바퀴째가 어긋난다")

	# ── 표: 은총 ───────────────────────────────────────────────────────────
	# 여섯 주에 한 바퀴. 같은 주 열쇠는 항상 같은 은총이라야 한다 — 접속할
	# 때마다 바뀌면 그 주의 특전이라는 말이 거짓이 된다.
	var wk := "2026-08-17"
	assert(str(BoonDefs.of(wk)["id"]) == str(BoonDefs.of(wk)["id"]),
		"같은 주에 다른 은총이 나온다")
	var seen := {}
	var t := Time.get_unix_time_from_datetime_string(wk)
	for i in BoonDefs.BOONS.size():
		var key := Time.get_date_string_from_unix_time(int(t) + i * 604800)
		seen[str(BoonDefs.of(key)["id"])] = true
	assert(seen.size() == BoonDefs.BOONS.size(),
		"여섯 주에 여섯 종이 안 나온다: %d" % seen.size())
	# 다음 주 예고가 실제로 다음 주의 것과 같아야 한다.
	var nxt := Time.get_date_string_from_unix_time(int(t) + 604800)
	assert(str(BoonDefs.next_of(wk)["id"]) == str(BoonDefs.of(nxt)["id"]),
		"다음 주 예고가 틀렸다")
	# 종류가 훅 이름과 맞나 — 오타 하나면 그 은총이 조용히 아무 일도 안 한다.
	var kinds := ["gold", "sweep", "hours", "raid", "ticket", "essence"]
	for b in BoonDefs.BOONS:
		assert(kinds.has(str(b["kind"])), "모르는 훅 종류: %s" % str(b["kind"]))
		assert(BoonDefs.bonus(wk, str(b["kind"])) >= 0.0, "음수 보너스")

	# ── 씬 ─────────────────────────────────────────────────────────────────
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# **결백성** — 앞선 검사가 남긴 저장본이면 오늘 이미 받았을 수 있다.
	scene.attend_got = 0
	scene.attend_date = ""
	scene.tickets = {}
	scene.gem = 0.0
	scene.crystal = 0.0

	assert(scene._attend_claimable(), "새 판인데 못 받는다")
	scene._claim_attend()
	assert(scene.attend_got == 1, "받았는데 칸이 안 올랐다")

	# **하루 한 번** — 이게 이 기능의 유일한 방어선이다.
	scene._claim_attend()
	scene._claim_attend()
	assert(scene.attend_got == 1, "같은 날 두 번 받았다: %d" % scene.attend_got)
	assert(not scene._attend_claimable(), "받고도 또 받을 수 있다")

	# 날이 바뀌면 다음 칸.
	scene.attend_date = "2000-01-01"
	assert(scene._attend_claimable(), "날이 바뀌었는데 못 받는다")
	scene._claim_attend()
	assert(scene.attend_got == 2, "다음 날 칸이 안 올랐다")

	# 보상이 실제로 들어왔나 — 표만 맞고 지갑이 비면 아무 뜻이 없다.
	var got_any: bool = float(scene.gem) > 0.0 or float(scene.crystal) > 0.0 \
		or not scene.tickets.is_empty()
	assert(got_any, "출석 보상이 지갑에 안 들어왔다")

	# 저장.
	scene._save_game()
	scene.attend_got = 0
	scene.attend_date = ""
	scene._load_game()
	assert(scene.attend_got == 2, "출석 기록이 복원 안 됐다: %d" % scene.attend_got)

	# ── 은총이 실제로 붙는가 ───────────────────────────────────────────────
	# 표만 맞고 훅이 안 붙으면 그 주에 아무 일도 안 일어난다. 종류를 직접
	# 넣을 수는 없으니(주 열쇠가 정한다) 지금 주의 은총으로 확인한다.
	var b := BoonDefs.of(scene._quest_week_key())
	assert(is_equal_approx(scene._boon(str(b["kind"])), float(b["value"])),
		"이번 주 은총이 훅에 안 붙는다")
	assert(is_equal_approx(scene._boon("없는종류"), 0.0), "모르는 종류에 값이 붙는다")
	# 던전 보상은 **표시와 지급이 같은 함수**를 지나야 한다(_raid_gain).
	var raw: float = RaidDefs.reward("blood", 1)
	var paid: float = scene._raid_gain("blood", 1)
	assert(is_equal_approx(paid, raw * (1.0 + scene._boon("raid"))),
		"던전 보상에 은총이 어긋나게 붙는다")

	print("AttendCheck OK")
	quit()
