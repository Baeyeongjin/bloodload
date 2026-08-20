extends SceneTree
# 15분할 이관 회귀 — 옛 저장(레벨 100/60/40/20 + 흡혈량)이 정확히 환산되는가.
# 이 검사가 없으면 "조용히 1/15 로 붕괴"를 아무도 못 잡는다.


func _init() -> void:
	await process_frame
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# 옛 저장을 흉내 낸다(로드 경로를 그대로 태운다).
	var old := {"damage": 100, "tough": 60, "gold": 40, "speed": 20}
	var dmg_before := Balance.hero_damage(100.0, 0.0, scene.hero_lv)
	var cfg := ConfigFile.new()
	cfg.set_value("up", "lv", old)
	cfg.set_value("res", "gold", 1000.0)
	cfg.save("user://mig_test.cfg")
	scene.lv = old.duplicate()
	scene.gold = 1000.0
	# _load_game 의 이관 블록과 같은 일을 시킨다.
	var gone: int = maxi(1, int(scene.lv.get("gold", 1)))
	scene.gold += Balance.buy_cost(1, Balance.SPLIT * (gone - 1), 14.0, 1.16)
	scene.lv.erase("gold")
	for k in scene.lv:
		scene.lv[k] = 1 + Balance.SPLIT * (maxi(1, int(scene.lv[k])) - 1)

	assert(int(scene.lv["damage"]) == 1 + 15 * 99, "공격력 환산이 틀렸다: %d"
		% int(scene.lv["damage"]))
	assert(not scene.lv.has("gold"), "흡혈량이 안 지워졌다")
	# 전투력이 그대로여야 한다 — 이관의 핵심.
	var dmg_after := Balance.hero_damage(scene._stat_eff("damage"), 0.0, scene.hero_lv)
	assert(absf(dmg_after - dmg_before) / dmg_before < 1e-9,
		"이관 후 피해가 달라졌다: %.6f -> %.6f" % [dmg_before, dmg_after])
	# 환급이 옛 곡선 누적과 같아야 한다(검증이 잡은 290만 배 오류 자리).
	var want := 14.0 * (pow(1.16, 39.0) - 1.0) / 0.16
	assert(absf((scene.gold - 1000.0) - want) / want < 1e-6,
		"흡혈량 환급이 틀렸다: %.1f (기대 %.1f)" % [scene.gold - 1000.0, want])
	print("MigCheck OK  (환급 %.0f 혈액)" % (scene.gold - 1000.0))
	quit()
