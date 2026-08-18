extends SceneTree

# **켤 때 무엇이 얼마나 걸리는가.** 로딩 막대를 붙이기 전에 재는 자리다 —
# 잴 것이 없는데 막대만 그리면 그건 거짓 진행률이고, 유저는 그걸 알아본다.
#
# 자산은 게으르게 읽힌다(Assets.tex 가 필요할 때 읽고 캐시한다). 그래서
# 시작 비용은 "2293장"이 아니라 **첫 화면이 실제로 만지는 몇 장**이다.
# 게임 중에 새 몹이 처음 나올 때 또 읽으므로, 그쪽 끊김도 같이 잰다.
#
#     godot --headless --path . --script tests/BootProbe.gd

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var packed: PackedScene = load("res://Main.tscn")
	var t1 := Time.get_ticks_msec()
	var scene: Node = packed.instantiate()
	var t2 := Time.get_ticks_msec()
	root.add_child(scene)          # 여기서 _ready 가 돈다
	var t3 := Time.get_ticks_msec()
	await process_frame
	await process_frame
	var t4 := Time.get_ticks_msec()

	print("")
	print("켤 때 걸리는 시간")
	print("  씬 파일 읽기      %4d ms" % (t1 - t0))
	print("  인스턴스화        %4d ms" % (t2 - t1))
	print("  _ready(화면 조립) %4d ms" % (t3 - t2))
	print("  첫 두 프레임      %4d ms" % (t4 - t3))
	print("  ─────────────────────────")
	print("  합계              %4d ms" % (t4 - t0))
	print("")
	print("시작하며 읽은 자산: 텍스처 %d장 · 애니 %d벌"
		% [Assets._cache.size(), Assets._fcache.size()])

	# **게임 중 끊김.** 새 막의 몹은 그때 처음 읽힌다 — 그 비용을 재 둔다.
	var worst := 0
	var worst_name := ""
	for act in StageDefs.ACTS:
		for key in act.get("roster", []):
			var t := Time.get_ticks_msec()
			Assets.frames("res://assets/anim/%s_walk" % str(key))
			var dt := Time.get_ticks_msec() - t
			if dt > worst:
				worst = dt
				worst_name = str(key)
	print("몹 한 종 처음 읽기: 최악 %d ms (%s)" % [worst, worst_name])
	print("BootProbe OK")
	quit()
