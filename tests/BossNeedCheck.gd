extends SceneTree

# 버그 셋을 붙잡아 두는 검사다. 앞의 둘은 뿌리가 하나였다 — 이정표 요구치의
# **분모(화력)** 를 세 함수가 서로 다르게 재고, 그 값이 저장도 안 됐다.
#
#   1) 회귀 — _prestige_do 가 lv 를 비우면 화력이 바닥나는데 누적 피해는 그대로다.
#      분모가 같이 내려가면 이정표 넷이 통째로 공짜가 됐다(보석 60 + 혈정 80 +
#      장신구권 10 + 스킬권 10 + 단계 +1 을 회귀할 때마다).
#   2) 재시작 — 화력 기준이 저장이 안 돼 0 이 되면 milestone_damage 의
#      maxf(1.0, dps) 때문에 요구치가 30 까지 내려앉는다. 넷이 전부 "받을 수
#      있다"가 되어 알림점이 영영 켜져 있었다
#      ("늘 켜진 점은 없는 점과 같다" — Main.gd 의 그 자리 주석).
#   3) 펫 점 — pet_bank 는 펫 탭을 열 때만 갱신되므로, 한 번 걷고 나면 저장값이
#      0 에 머물러 점이 다시는 안 켜졌다.
#
# 씬 테스트다 — 반드시 APPDATA 격리로 돌린다(godot-verify).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))

	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# ── 준비: 주간 보스에 피해를 쌓아 둔 **고인물** 상태 ────────────────────
	# 회귀는 200구간부터 열린다. 그리고 혈흔이 이미 쌓여 있어야 한다 — 첫 회귀는
	# 혈흔 배수가 0 에서 뛰는 바람에 화력이 오히려 **오른다**(실측 x1.41).
	# 배수가 포화한 뒤라야 lv 를 비운 손해가 그대로 드러난다(실측 x0.29).
	scene.stage = 260
	scene.best_stage = 260
	scene.prestige_marks = 300
	scene.prestige_peak = 259
	scene._fade_t = 0.0
	scene.raid_on = ""
	scene.dungeon_on = false
	scene.boss_week = ""
	scene.boss_date = ""
	scene.boss_got = {}
	scene.boss_tier = 1
	# 회귀가 되돌리는 것은 **혈액으로 산 스탯 레벨**이다. lv 가 비어 있으면
	# 회귀해도 화력이 안 떨어져서 이 검사가 재는 게 없어진다.
	scene.lv = {"damage": 900, "speed": 300, "crit": 150, "critdmg": 450,
		"tough": 900, "regen": 220}
	scene._boss_roll()
	scene.boss_dps = scene.dps()
	assert(scene.boss_dps > 0.0, "화력이 0이면 이 검사가 무의미하다")
	# 첫 이정표(need 30)는 넘고 둘째(need 90)는 못 넘는 자리.
	scene.boss_dmg = scene.boss_dps * 60.0

	var need1: float = scene._boss_need(1)
	assert(scene.boss_dmg >= scene._boss_need(0), "준비가 틀렸다 — 첫 이정표를 못 넘었다")
	assert(scene.boss_dmg < need1, "준비가 틀렸다 — 둘째 이정표를 넘었다")

	# ── 1) 회귀해도 요구치가 안 내려간다 ────────────────────────────────────
	var gem_before: float = scene.gem
	var high_dps: float = scene.boss_dps
	scene.prestige_peak = 0
	scene._prestige_do()
	assert(scene.dps() < high_dps * 0.5,
		"회귀가 화력을 안 떨어뜨렸다 — 이 검사가 재는 게 없다 (실측 x0.29)")
	assert(scene._boss_need(1) >= need1,
		"회귀로 이정표 요구치가 내려갔다 — 쌓아 둔 누적이 공짜로 넘긴다")
	# 실제 수령 경로로도 확인한다. 둘째 이정표는 아직 못 받아야 한다.
	scene._claim_milestone(1)
	assert(not scene.boss_got.has(1), "회귀 뒤 이정표를 공짜로 받았다")
	assert(scene.boss_tier == 1, "회귀 뒤 단계가 올라갔다")
	assert(is_equal_approx(scene.gem, gem_before), "회귀 뒤 보석이 들어왔다")

	# ── 2) 저장·복원을 건너도 요구치가 살아 있다 ────────────────────────────
	scene.boss_got = {}
	scene.boss_dmg = high_dps * 60.0
	scene._save_game()
	scene.boss_dps = 0.0                     # 재시작 직후 = 옛 버그 상태
	scene._load_game()
	assert(is_equal_approx(scene.boss_dps, high_dps),
		"화력 기준이 저장·복원을 못 넘었다")
	# 받을 수 있는 이정표는 첫 칸 하나뿐이어야 한다. 옛 버그에서는 요구치가
	# 30/90/200/400 절대값으로 내려앉아 넷이 전부 켜졌다.
	var pending := 0
	for i in EventDefs.MILESTONES.size():
		if scene.boss_dmg >= scene._boss_need(i):
			pending += 1
	assert(pending == 1, "복원 뒤 받을 이정표가 %d 개다 — 하나여야 한다" % pending)

	# ── 3) 펫 점은 걷은 뒤에도 다시 켜진다 ──────────────────────────────────
	# 걷은 직후 상태: 곳간이 비었고 소환권·먹이도 없다(다른 이유로 켜지면 안 된다).
	scene.tickets["pet"] = 0
	scene.tickets["petgear"] = 0
	scene.feed = 0.0
	scene.pets_got = {"nightwing": 1}
	scene.pet_bank = {"nightwing": 0.0}
	scene.pet_gear_worn = {}
	scene.pet_at = Time.get_unix_time_from_system()
	assert(not scene._tab_todo("pet"), "막 걷었는데 점이 켜져 있다")
	scene.pet_at -= 3600.0 * 6.0             # 여섯 시간 뒀다
	assert(scene._tab_todo("pet"),
		"여섯 시간이 지났는데 펫 점이 안 켜진다 — pet_bank 가 탭 밖에서 안 도는 탓")
	# 값을 실제로 바꾸지는 않아야 한다 — 매 프레임 도는 자리다.
	assert(is_equal_approx(float(scene.pet_bank["nightwing"]), 0.0),
		"알림점이 pet_bank 를 건드렸다")

	print("BossNeedCheck ok")
	quit(0)
