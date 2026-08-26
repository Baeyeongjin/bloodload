extends SceneTree

# 승급(훈련 공통 상한)을 잰다 — 식이 틀리면 성장이 조용히 잠기거나 안 잠긴다.
#   1) 상한은 **층마다** 열린다 — 계단으로 두면 그 사이에서 자물쇠가 걸린다
#      (훈련이 막혀 미궁을 못 오르고, 미궁이 안 올라 다음 계단이 안 열린다)
#   2) 상한은 층이 오를수록 단조증가
#   3) 승급 배지가 바뀌는 층 안내 (마지막 단계면 0)

func _init() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	# 시작 상한은 CAP_BASE(200) — 1구간 몹을 한 대에 눕히는 지점이라
	# 그 위는 효과가 0 이다(2026-08-26 실측). 초반 브레이크가 여기 있다.
	assert(StatDefs.train_cap(0) == StatDefs.CAP_BASE, "시작 상한이 바뀌었다")
	# **한 층만 올라도 살 게 생겨야 한다.** 이게 안 되면 교착이 돌아온다.
	var prev := 0
	for f in range(0, 101):
		var cap := StatDefs.train_cap(f)
		if f > 0:
			assert(cap > prev, "%d층에서 상한이 안 열렸다 — 자물쇠 자리다" % f)
		prev = cap
	assert(StatDefs.train_cap(100) > StatDefs.train_cap(0) * 10,
		"100층 상한이 너무 낮다 — 후반에 혈액이 죽는다")
	# 승급 배지가 바뀌는 층.
	assert(StatDefs.next_cap_floor(0) == 20)
	assert(StatDefs.next_cap_floor(19) == 20)
	assert(StatDefs.next_cap_floor(20) == 40)
	assert(StatDefs.next_cap_floor(40) == 80)
	assert(StatDefs.next_cap_floor(80) == 0, "마지막 상한인데 다음 층이 나온다")
	print("PromoCheck OK")
	quit()
