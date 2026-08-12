extends SceneTree

# 승급(훈련 공통 상한)을 잰다 — 표가 틀리면 성장이 조용히 잠기거나 안 잠긴다.
#   1) 경계값: 층을 채우기 전에는 안 열리고, 채우는 순간 열린다
#   2) 상한은 층이 오를수록 단조증가
#   3) 다음 열쇠 층 안내가 표와 일치 (마지막 상한이면 0)

func _init() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	# 경계값 — 표(TRAIN_CAP)의 양쪽 끝을 하나씩 짚는다.
	assert(StatDefs.train_cap(0) == 60, "시작 상한이 60이 아니다")
	assert(StatDefs.train_cap(19) == 60, "20층 전인데 상한이 열렸다")
	assert(StatDefs.train_cap(20) == 120, "20층인데 상한이 안 열렸다")
	assert(StatDefs.train_cap(39) == 120)
	assert(StatDefs.train_cap(40) == 220)
	assert(StatDefs.train_cap(79) == 220)
	assert(StatDefs.train_cap(80) == 400)
	assert(StatDefs.train_cap(100) == 400, "표 밖에서 상한이 변했다")
	# 단조증가.
	var prev := 0
	for f in range(0, 101):
		var cap := StatDefs.train_cap(f)
		assert(cap >= prev, "%d층에서 상한이 내려갔다" % f)
		prev = cap
	# 다음 열쇠 층.
	assert(StatDefs.next_cap_floor(0) == 20)
	assert(StatDefs.next_cap_floor(19) == 20)
	assert(StatDefs.next_cap_floor(20) == 40)
	assert(StatDefs.next_cap_floor(40) == 80)
	assert(StatDefs.next_cap_floor(80) == 0, "마지막 상한인데 다음 층이 나온다")
	print("PromoCheck OK")
	quit()
