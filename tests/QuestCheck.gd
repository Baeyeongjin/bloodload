extends SceneTree

# 일일 임무 표를 잰다 — 표가 틀리면 보상이 새거나 하루가 안 닫힌다.
#   1) id 중복 없음, need/amount 양수, 보상 종류는 지갑에 있는 것만
#   2) 아이콘 파일이 실제로 있다 (없으면 빈 줄로 뜬다)
#   3) "all"(마무리)의 need <= 기본 임무 수 - 1 — 미궁은 본편 30구간이 열어서
#      그 전에는 기본 임무가 하나 적다. need 가 기본 수와 같으면 새 유저는
#      하루를 영영 못 닫는다.
#   4) 새 날 진행표는 접속 임무가 차 있다

func _init() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var seen := {}
	var base := 0
	var has_all := false
	for q in QuestDefs.QUESTS:
		var id := str(q["id"])
		assert(not seen.has(id), "id 중복: %s" % id)
		seen[id] = true
		assert(int(q["need"]) > 0 and int(q["amount"]) > 0,
			"%s: need/amount 가 0 이하다" % id)
		assert(str(q["reward"]) in ["gem", "crystal"],
			"%s: 모르는 보상 종류 %s" % [id, str(q["reward"])])
		assert(FileAccess.file_exists("res://assets/ui/%s.png" % str(q["icon"])),
			"%s: 아이콘 파일이 없다 — %s" % [id, str(q["icon"])])
		if id == "all":
			has_all = true
		else:
			base += 1
	assert(has_all, "마무리 임무(all)가 없다")
	assert(int(QuestDefs.of("all")["need"]) <= base - 1,
		"마무리 need 가 기본 임무 수(%d)-1 을 넘는다 — 미궁 전 유저는 못 닫는다" % base)
	assert(int(QuestDefs.fresh_prog().get("login", 0)) >= 1,
		"새 날인데 접속 임무가 안 차 있다")
	print("QuestCheck OK")
	quit()
