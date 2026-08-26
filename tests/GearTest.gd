extends SceneTree

# 장비 굴림 자체 점검. 아이콘 풀이 비거나(파일명 접두어가 바뀌면 조용히 빈다)
# 등급표가 깨지면 드랍이 아무 말 없이 사라지므로 여기서 잡는다.
#   godot --headless --script tests/GearTest.gd

func _init() -> void:
	# **안전장치.** Godot 의 assert 는 실패하면 그 자리에서 함수를 멈추는데, 그러면
	# 아래 quit() 에 못 가서 프로세스가 영영 안 끝난다(타임아웃으로 죽여야 했다).
	# 먼저 시계를 걸어 두면 멈춰도 반드시 끝나고, 종료 코드로 실패가 드러난다.
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("테스트가 안 끝났다 — assert 실패로 멈춘 것이다")
		quit(1))
	# 굴림 검사를 **결정론으로** 만든다. 만렙 신화는 0.192%(0.25/130)라 2000연에
	# 한 번도 안 나올 확률이 2.1% 다 — 시드를 안 고정하면 50번에 한 번씩 그냥 깨지고,
	# 그때마다 없는 버그를 코드에서 찾게 된다. 굴림 경로는 그대로 지난다.
	seed(20260804)
	assert(GachaDefs.RARITIES.size() == 6)
	var total_weight := 0.0
	for rarity in GachaDefs.RARITIES:
		total_weight += float(rarity["weight"])
	assert(is_equal_approx(total_weight, 100.0), "공개 확률 합이 100%가 아니다")
	var ten := GachaDefs.pull(10, 0)
	var guaranteed := false
	for rarity_key in ten["rarities"]:
		guaranteed = guaranteed or GachaDefs.rarity_index(str(rarity_key)) >= GachaDefs.RARE_INDEX
	assert(guaranteed, "10연 희귀 이상 보장이 작동하지 않는다")
	var legend_lv := int(GachaDefs.RARITIES[GachaDefs.LEGEND_INDEX]["unlock"])
	var pity := GachaDefs.pull(1, 99, legend_lv)
	assert(pity["rarities"][0] == "legend" and pity["pity"] == 0,
		"100연 전설 천장이 작동하지 않는다")

	# 해금 레벨이 만렙을 넘으면 그 등급은 **영원히 안 나온다.** 화면에는 해금 조건만
	# 적혀 있어서 티가 안 난다 — 만렙을 낮출 때 제일 먼저 깨지는 곳이다.
	for r in GachaDefs.RARITIES:
		assert(int(r.get("unlock", 0)) <= GachaDefs.LEVEL_MAX,
			"%s 해금(%d레벨)이 만렙(%d)보다 높다 — 영원히 안 나온다"
			% [str(r["name"]), int(r.get("unlock", 0)), GachaDefs.LEVEL_MAX])
	assert(GachaDefs.unlocked(GachaDefs.RARITIES.size() - 1, GachaDefs.LEVEL_MAX),
		"만렙인데 최고 등급이 안 열린다")

	# 등급 해금 — 안 열린 등급은 **절대** 안 나와야 한다. 한 번이라도 새면
	# 레벨을 올릴 이유가 통째로 사라진다.
	for test_lv in [GachaDefs.LEVEL_MIN, legend_lv - 1, 3]:
		var got := GachaDefs.pull(400, 0, test_lv)
		for key in got["rarities"]:
			assert(GachaDefs.unlocked(GachaDefs.rarity_index(str(key)), test_lv),
				"Lv%d 인데 잠긴 등급이 나왔다: %s" % [test_lv, key])
	# 천장이 찼어도 전설이 안 열렸으면 터지지 않고 쌓여야 한다.
	var early := GachaDefs.pull(1, 99, legend_lv - 1)
	assert(str(early["rarities"][0]) != "legend", "잠긴 전설이 천장으로 나왔다")
	assert(int(early["pity"]) >= 100, "천장이 잠긴 동안 초기화됐다")
	# 전설은 **천장 한 바퀴(100회) 안에** 열려야 한다. 더 뒤로 밀면 천장이 여러 번
	# 헛돌고, 그동안 100연 보장이 실질적으로 없는 셈이 된다.
	assert(GachaDefs.level_total(legend_lv) <= 100,
		"전설 해금이 천장 한 바퀴보다 늦다: 누적 %d회" % GachaDefs.level_total(legend_lv))
	# 열린 뒤에는 실제로 나온다.
	var late := GachaDefs.pull(2000, 0, GachaDefs.LEVEL_MAX)
	var seen := {}
	for key in late["rarities"]:
		seen[str(key)] = true
	assert(seen.has("mythic"), "만렙인데 2000연에 신화가 한 번도 없다")

	# 소환 레벨 — 시작은 1레벨이고, 뽑을수록 오르고, 오를수록 레어 이상이 잘 나온다.
	assert(GachaDefs.level(0) == GachaDefs.LEVEL_MIN, "처음이 1레벨이 아니다")
	assert(GachaDefs.level(999999) == GachaDefs.LEVEL_MAX, "레벨이 만렙에서 안 멈춘다")
	assert(GachaDefs.level_total(GachaDefs.LEVEL_MIN) == 0, "1레벨에 소환이 필요하다")
	assert(GachaDefs.level_next_need(999999) == 0, "만렙인데 다음 레벨이 남았다고 한다")
	# 1레벨 배수는 정확히 1.0 — 공개 확률표가 그대로 성립해야 한다.
	assert(is_equal_approx(GachaDefs.level_mult(GachaDefs.LEVEL_MIN), 1.0))
	assert(is_equal_approx(GachaDefs.level_mult(GachaDefs.LEVEL_MAX),
		GachaDefs.LEVEL_TOP_MULT), "만렙 배수가 표에 적힌 값과 다르다")
	# 레벨업 비용은 **레벨마다 무거워져야** 한다. 고정 간격으로 되돌아가면 여기서 깨진다.
	for l in range(GachaDefs.LEVEL_MIN + 1, GachaDefs.LEVEL_MAX):
		var this_step := GachaDefs.level_total(l) - GachaDefs.level_total(l - 1)
		var next_step := GachaDefs.level_total(l + 1) - GachaDefs.level_total(l)
		assert(next_step > this_step,
			"%d레벨 비용(%d)이 그 전(%d)보다 안 무겁다" % [l + 1, next_step, this_step])
	# 경계 — 누적 횟수 직전/직후에 정확히 오른다. 하나 어긋나면 표와 실제가 갈린다.
	for l in range(GachaDefs.LEVEL_MIN + 1, GachaDefs.LEVEL_MAX + 1):
		var need := GachaDefs.level_total(l)
		assert(GachaDefs.level(need) == l, "누적 %d회에서 %d레벨이 아니다" % [need, l])
		assert(GachaDefs.level(need - 1) == l - 1, "누적 %d-1회에서 이미 %d레벨이다" % [need, l])
		assert(GachaDefs.level_next_need(need - 1) == 1,
			"%d레벨 직전인데 남은 횟수가 1이 아니다" % l)
	# 표시 확률은 항상 합이 100이어야 한다 — 화면에 적히는 값 그 자체다.
	for test_lv in [0, 1, 25, GachaDefs.LEVEL_MAX]:
		var sum := 0.0
		for v in GachaDefs.rates(test_lv):
			sum += float(v)
		assert(is_equal_approx(sum, 100.0), "Lv%d 확률 합이 100이 아니다" % test_lv)
	# 시작 레벨에서 잠긴 등급은 확률도 0이어야 한다.
	for i in GachaDefs.RARITIES.size():
		if not GachaDefs.unlocked(i, GachaDefs.LEVEL_MIN):
			assert(is_equal_approx(GachaDefs.rates(GachaDefs.LEVEL_MIN)[i], 0.0),
				"시작 레벨에서 잠긴 등급에 확률이 붙어 있다")
	# 레벨이 오르면 커먼은 줄고 레어 이상은 는다. 반대면 표를 거꾸로 읽고 있는 것이다.
	var lv0 := GachaDefs.rates(GachaDefs.LEVEL_MIN)
	var lv_max := GachaDefs.rates(GachaDefs.LEVEL_MAX)
	assert(lv_max[0] < lv0[0], "레벨을 올렸는데 커먼이 줄지 않는다")
	for i in range(GachaDefs.RARE_INDEX, GachaDefs.RARITIES.size()):
		assert(lv_max[i] > lv0[i], "레벨을 올렸는데 상위 등급이 늘지 않는다")
	# 스킬 소환은 커먼~레전더리 5단계다(형태 4 x 등급 5 = 20종). 신화는 굴리지 않고
	# 그 몫이 나머지에 비율대로 넘어가야 한다 — 합은 여전히 100이어야 한다.
	# 만렙에서 검사한다: 1레벨은 레전더리가 아직 잠겨 있어 신화 배제 효과가 안 보인다.
	var sk := GachaDefs.rates(GachaDefs.LEVEL_MAX, true)
	for i in range(GachaDefs.SKILL_TOP_INDEX + 1, GachaDefs.RARITIES.size()):
		assert(is_equal_approx(sk[i], 0.0), "스킬 소환에 신화가 남아 있다")
	var sk_sum := 0.0
	for v in sk:
		sk_sum += float(v)
	assert(is_equal_approx(sk_sum, 100.0), "스킬 확률 합이 100이 아니다")
	# 신화 몫이 넘어왔으니 남은 등급은 장비 소환보다 확률이 높아야 한다.
	var gear_rates := GachaDefs.rates(GachaDefs.LEVEL_MAX)
	for i in GachaDefs.SKILL_TOP_INDEX + 1:
		assert(sk[i] > gear_rates[i], "신화 몫이 다른 등급으로 안 넘어갔다")
	# 실제 굴림에도 신화가 안 나와야 한다.
	for key in GachaDefs.pull(500, 0, GachaDefs.LEVEL_MAX, true)["rarities"]:
		assert(GachaDefs.rarity_index(str(key)) <= GachaDefs.SKILL_TOP_INDEX,
			"스킬 소환에서 신화가 나왔다")
	# 스킬 아이콘은 5등급 x 4형태 = 20장이 다 있어야 한다. 하나 빠지면 빈 칸이 된다.
	for i in GachaDefs.SKILL_TOP_INDEX + 1:
		for shape in ["strike", "wave", "field", "ward"]:
			var path := "res://assets/skills/sk_%s_%s.png" \
				% [str(GachaDefs.RARITIES[i]["key"]), shape]
			assert(FileAccess.file_exists(path), "스킬 아이콘 없음: " + path)
	print("스킬 소환 확률(만렙)  커먼 %.1f%% / 레어 %.1f%% / 레전더리 %.2f%%"
		% [sk[0], sk[2], sk[GachaDefs.LEGEND_INDEX]])

	print("소환 확률  %d레벨 커먼 %.1f%% / 전설 %.2f%%  →  만렙(%d) 커먼 %.1f%% / 전설 %.2f%%"
		% [GachaDefs.LEVEL_MIN, lv0[0], lv0[GachaDefs.LEGEND_INDEX],
		GachaDefs.LEVEL_MAX, lv_max[0], lv_max[GachaDefs.LEGEND_INDEX]])
	print("소환 레벨 누적  2렙 %d · 5렙 %d · 만렙 %d 회"
		% [GachaDefs.level_total(2), GachaDefs.level_total(5),
		GachaDefs.level_total(GachaDefs.LEVEL_MAX)])

	for slot in GearDefs.SLOTS:
		var pool := GearDefs.icon_pool(slot)
		assert(pool.size() == 24, "슬롯별 아이콘이 24개가 아니다: " + slot)
		for rarity in GachaDefs.RARITIES:
			var variants := GearDefs.items_of(slot, str(rarity["key"]))
			assert(variants.size() == 4, "%s %s 장비가 4개가 아니다" % [slot, rarity["key"]])
			for spec in variants:
				assert(FileAccess.file_exists("res://assets/items/%s.png" % str(spec[0])),
					"카탈로그 아이콘 없음: " + str(spec[0]))

		var item := GearDefs.roll(slot, 10)
		assert(item["slot"] == slot)
		assert(GearDefs.power(item) > 0.0)
		assert(not str(item["name"]).is_empty())
		assert(FileAccess.file_exists(GearDefs.icon_path(item)), GearDefs.icon_path(item))
		assert(FileAccess.file_exists(GearDefs.slot_frame(item)), GearDefs.slot_frame(item))
		var uncommon := GearDefs.make(slot, 1, GachaDefs.rarity("uncommon"))
		assert(uncommon["rarity"] == "uncommon")
		assert(FileAccess.file_exists(GearDefs.slot_frame(uncommon)))

	# 단계가 오르면 같은 등급이라도 수치가 커져야 한다 — 안 그러면 진행할 이유가 없다.
	var low := 0.0
	var high := 0.0
	for i in 200:
		low += GearDefs.power(GearDefs.roll("weapon", 1))
		high += GearDefs.power(GearDefs.roll("weapon", 30))
	assert(high > low * 2.0, "단계별 성장이 없다")

	# 이름은 등급 접두어 + 명사 조합이라 등급이 바뀌면 이름도 바뀌어야 한다.
	var names := {}
	for r in GearDefs.RARITY:
		names[r["name"]] = true
	assert(names.size() == GearDefs.RARITY.size(), "등급 이름이 겹친다")

	# 강화·분해는 2026-08-25 에 삭제됐다(사장님). lv 는 옛 저장본의 유산이라
	# 식에는 남아 있고, 새로 오르지는 않는다.
	var it := GearDefs.roll("weapon", 5)
	var p0 := GearDefs.power(it)
	it["lv"] = 1
	assert(GearDefs.power(it) > p0, "레벨이 수치를 안 올린다")
	# 조합 — 등급이 높을수록 어렵고, 천장은 더 멀어야 한다.
	for i in range(1, GearDefs.FUSE_RATE.size()):
		assert(GearDefs.FUSE_RATE[i] < GearDefs.FUSE_RATE[i - 1],
			"높은 등급 조합이 더 쉽다")
		# 확률이 낮은 쪽일수록 천장은 **가깝다** — 확률로 조이고 천장으로 푼다.
		assert(GearDefs.FUSE_PITY[i] <= GearDefs.FUSE_PITY[i - 1],
			"높은 등급 천장이 더 멀다")
	assert(GearDefs.FUSE_SHARDS > 0 and GearDefs.fuse_pity(it) > 0)
	# 레벨업(연마석) — 레벨이 오를수록, 등급이 높을수록 비싸야 한다.
	var lvl_it := GearDefs.make("weapon", 5, GachaDefs.rarity("rare"))
	var c_lv0 := GearDefs.upgrade_cost(lvl_it)
	lvl_it["lv"] = 3
	assert(GearDefs.upgrade_cost(lvl_it) > c_lv0, "레벨업 비용이 안 오른다")
	var hi_it := GearDefs.make("weapon", 5, GachaDefs.rarity("epic"))
	assert(GearDefs.upgrade_cost(hi_it)
		> GearDefs.upgrade_cost(GearDefs.make("weapon", 5,
		GachaDefs.rarity("common"))), "등급이 높은데 레벨업이 더 싸다")
	assert(GearDefs.fuse_rate(it) > 0.0 and GearDefs.fuse_rate(it) <= 1.0)
	var keep0 := GearDefs.collection_rate(GearDefs.make("weapon", 5,
		GachaDefs.rarity("rare")))
	var keep_lv := GearDefs.make("weapon", 5, GachaDefs.rarity("rare"))
	keep_lv["lv"] = 4
	assert(GearDefs.collection_rate(keep_lv) > keep0, "레벨을 올려도 보유 효과가 그대로다")
	# 그래도 장착 쪽이 더 가팔라야 한다 — 안 그러면 아무것도 안 끼는 게 최적이 된다.
	# 상수 비교가 아니라 **만렙 배수**로 잰다(2026-08-26): 만렙이 등급마다 달라져
	# 증가율도 등급마다 다르다. 장착 x4 · 보유 x2 가 그 예산이다.
	for rk in GachaDefs.RARITIES:
		var probe := GearDefs.make("weapon", 5, GachaDefs.rarity(str(rk["key"])))
		var bare := GearDefs.power(probe)
		var bare_keep := GearDefs.collection_rate(probe)
		probe["lv"] = GearDefs.max_lv(probe)
		var wear := GearDefs.power(probe) / bare
		var keep := GearDefs.collection_rate(probe) / bare_keep
		assert(absf(wear - 4.0) < 0.05,
			"%s 만렙 장착 배수가 x4 가 아니다: x%.2f" % [str(rk["key"]), wear])
		assert(absf(keep - 2.0) < 0.05,
			"%s 만렙 보유 배수가 x2 가 아니다: x%.2f" % [str(rk["key"]), keep])
		assert(keep < wear, "보유가 장착보다 가파르다 — 아무것도 안 끼는 게 최적이 된다")
	var promoted := GearDefs.make("weapon", 1, GachaDefs.rarity("common"))
	var promoted_icon := str(promoted["icon"])
	var promoted_power := GearDefs.power(promoted)
	var collection_rate := GearDefs.collection_rate(promoted)
	assert(GearDefs.promote(promoted), "일반 장비를 고급으로 합성하지 못한다")
	assert(promoted["rarity"] == "uncommon" and GearDefs.power(promoted) > promoted_power)
	assert(str(promoted["icon"]) != promoted_icon, "합성 후 다음 등급 아이콘으로 바뀌지 않는다")
	assert(GearDefs.collection_rate(promoted) > collection_rate,
		"합성 후 보유 효과가 오르지 않는다")
	var legacy := {"slot": "armor", "rarity": "rare", "icon": "ga_claw_jade", "name": "희귀 발톱"}
	GearDefs.normalize_catalog_item(legacy)
	assert(str(legacy["icon"]) != "ga_claw_jade" and str(legacy["name"]) != "희귀 발톱",
		"기존의 잘못된 장비 아이콘·이름이 카탈로그로 교정되지 않는다")

	# 도감은 몹 표 전체를 덮어야 한다. 스프라이트가 빠지면 빈 칸으로 남는다.
	var keys := FoeTiers.all_keys()
	assert(keys.size() == FoeTiers.TIERS.size())
	for k in keys:
		assert(FileAccess.file_exists(FoeTiers.sprite_of(k)), "몹 그림 없음: " + str(k))
		# M1: 모든 몹은 전열 도착 후 7프레임 attack을 실제로 재생한다.
		for frame in 7:
			assert(FileAccess.file_exists("res://assets/anim/%s_attack/%d.png" % [k, frame]),
				"몹 공격 프레임 없음: %s/%d" % [k, frame])

	# 보스 전용 attack. walk 과 같은 anim_key 로 찾고, 없으면 원본 몹 것으로 조용히
	# 떨어져서 화면상 티가 안 난다 — 그래서 파일 존재를 여기서 잡는다.
	for boss in range(1, 6):
		for frame in 8:
			assert(FileAccess.file_exists(
				"res://assets/anim/boss_%d_attack/%d.png" % [boss, frame]),
				"보스 공격 프레임 없음: boss_%d/%d" % [boss, frame])

	# 영웅 피격·임팩트·사망 연출의 핵심 자산도 조용히 빠지면 안 된다.
	for frame in 7:
		assert(FileAccess.file_exists("res://assets/anim/valentino_1_attack/%d.png" % frame))
		assert(FileAccess.file_exists("res://assets/anim/fx_death_blood/%d.png" % frame))
	for frame in 5:
		assert(FileAccess.file_exists("res://assets/anim/valentino_1_hurt/%d.png" % frame))
		assert(FileAccess.file_exists("res://assets/anim/fx_cleave/%d.png" % frame))

	# 슬롯 해금 — 스탯 목록과 같은 규칙으로 잠기고 열려야 한다.
	# (보관함 탭이 이 값으로 잠기므로 어긋나면 못 여는 탭이 생긴다)
	for slot in GearDefs.SLOTS:
		var unlock := int(GearDefs.SLOT_UNLOCK[slot])
		assert(GearDefs.lock_reason(slot, unlock) == "",
			"해금 단계인데 안 열린다: " + slot)
		if unlock > 1:
			assert(GearDefs.lock_reason(slot, unlock - 1) != "",
				"해금 전인데 열려 있다: " + slot)
	# 1단계에 열려 있는 슬롯이 **적어도 하나**는 있어야 한다.
	# 없으면 보관함이 열 수 있는 탭 없이 시작한다.
	var open_at_start := 0
	for slot in GearDefs.SLOTS:
		if GearDefs.lock_reason(slot, 1) == "":
			open_at_start += 1
	assert(open_at_start > 0, "1단계에 열린 슬롯이 없다")

	# 도감 보상 — 마지막 칸은 **전 몹 만렙 합계**와 같아야 한다. 몹을 늘리거나 단계를
	# 바꾸고 표를 안 고치면 마지막 보상이 영영 도달 불가가 되는데 화면엔 표시가 안 난다.
	var last: Dictionary = FoeTiers.CODEX_REWARDS[FoeTiers.CODEX_REWARDS.size() - 1]
	assert(int(last["need"]) == FoeTiers.codex_max_knowledge(),
		"마지막 보상이 만렙 합계와 다르다: %d vs %d"
		% [int(last["need"]), FoeTiers.codex_max_knowledge()])
	# 지식 레벨 — 단계를 밟을 때만 오르고, 만렙에서 멈춘다.
	assert(FoeTiers.codex_level(0) == 0 and FoeTiers.codex_level(9) == 0)
	assert(FoeTiers.codex_level(10) == 1 and FoeTiers.codex_level(99) == 1)
	assert(FoeTiers.codex_level(999999) == FoeTiers.CODEX_KILL_STEPS.size(),
		"지식 레벨이 만렙에서 안 멈춘다")
	assert(FoeTiers.codex_next_need(10) == 90 and FoeTiers.codex_next_need(999999) == 0)
	# 누적이라 합계가 늘면 보정도 늘어야 하고, 0에서는 0이어야 한다.
	assert(is_equal_approx(FoeTiers.codex_bonus(0, "damage"), 0.0))
	assert(FoeTiers.codex_bonus(22, "damage") > FoeTiers.codex_bonus(3, "damage"),
		"도감 보정이 누적되지 않는다")
	assert(is_equal_approx(FoeTiers.codex_bonus(9, "crit"), 0.0), "치명 보상이 일찍 열린다")
	assert(FoeTiers.codex_bonus(10, "crit") > 0.0)
	assert(FoeTiers.codex_bonus(44, "tough") > 0.0, "체력 보상이 안 붙는다")
	# 칸을 정확히 밟았을 때만 수령한다 — 합계는 1씩만 오르므로 두 번 밟히지 않는다.
	assert(not FoeTiers.codex_reward_at(3).is_empty())
	assert(FoeTiers.codex_reward_at(4).is_empty())
	# 표가 오름차순이어야 "다음 보상"이 맞는 칸을 가리킨다.
	for i in range(1, FoeTiers.CODEX_REWARDS.size()):
		assert(int(FoeTiers.CODEX_REWARDS[i]["need"])
			> int(FoeTiers.CODEX_REWARDS[i - 1]["need"]), "보상표가 오름차순이 아니다")
		assert(FoeTiers.codex_stat_name(str(FoeTiers.CODEX_REWARDS[i]["stat"]))
			!= str(FoeTiers.CODEX_REWARDS[i]["stat"]), "보상 스탯 이름이 없다")

	# 글자가 칸을 넘으면 clip_text 가 조용히 잘라 낸다 — "혈액 1.4k" 가 "혈액 1." 이 됐다.
	# 잘린 숫자는 틀린 숫자보다 나쁘다(틀린 줄도 모른다). **실제 폰트로 재서** 막는다.
	# 칸 폭 = 버튼폭 - 여백(side+2 좌우 = 24) - 아이콘 - 아이콘 간격(4).
	var font: Font = load(Type.PATH)
	var boxes := [
		["혈액 999.9t", Type.SIZE_SMALL, 172.0 - 24.0 - 20.0 - 4.0, "스탯 훈련 버튼"],
		["정수 999.9t", Type.SIZE_SMALL, 160.0 - 24.0 - 20.0 - 4.0, "장비 강화 버튼"],
		["레벨업", Type.SIZE_SMALL, 100.0 - 24.0, "장비 상세 레벨업"],
		["합성 5", Type.SIZE_SMALL, 100.0 - 24.0 - 16.0 - 4.0, "장비 상세 합성"],
		["+188.8k 피해", Type.SIZE_SMALL, 120.0, "스탯 효과 칸"],
		["치명타 피해", Type.SIZE_BODY, 144.0, "스탯 이름 칸"],
		["레벨 999999", Type.SIZE_SMALL, 144.0, "스탯 레벨 칸"],
		# 잠금 칸(버튼 자리 172px 통째)에는 두 종류가 뜬다: "N단계 해금" 과
		# 선행 스탯 "치명타 확률 Lv100". 후자가 더 길다 — 이름이 가장 긴 스탯으로 잰다.
		["치명타 확률 Lv100", Type.SIZE_SMALL, 172.0, "스탯 잠금 칸(선행)"],
		["999.9t", Type.SIZE_SMALL, 156.0 - Ui.SCROLL_W - 44.0 - 14.0, "도감 목록 처치수"],
		# 상단 재화 알약: 폭 150 - 글자 시작 30 - 오른쪽 보석 30 + 6 = 96px.
		# 알약은 9-slice 라 양끝 보석(각 30px)이 native 로 남는다 — 글자가 그 위로
		# 올라타면 숫자를 못 읽는다(실제로 118px 로 잡았다가 그랬다).
		# 전투력 칸: 초상화 밑, 가운데 덩어리(132부터) 직전까지 126px
		# 전투력은 교차검 아이콘 옆 숫자만 (칸 96)
		["999.9t", Type.SIZE_SMALL, 96.0, "상단 전투력 칸"],
		# 재화 알약 118 - 아이콘이 먹는 30 - 오른쪽 여백 10 = 숫자 칸 78
		["999.9t", Type.SIZE_SMALL, 78.0, "재화 알약 숫자"],
		# 레벨 배지 96 - 좌우 여백 6씩 = 84
		["레벨 9999", Type.SIZE_SMALL, 84.0, "초상화 레벨 배지"],
		# 가이드 카드 236x88. 안쪽 = 236 - (20 여백 + 4 인셋) x 2 = 188.
		# 왼쪽 보상 48 + 간격 6 + 오른쪽 134 (미션 내용 / 진행바가 이 폭을 나눠 쓴다).
		# **이 칸들이 트랙 이름 길이를 정한다.** "누적 처치"로 되돌리면 168px 이라
		# 여기서 걸린다 — 이름을 늘리려면 카드부터 넓혀야 한다.
		["999t", Type.SIZE_SMALL, 48.0, "가이드 보상 수량(소수점 없음)"],
		["처치 999.9k마리", Type.SIZE_SMALL, 134.0, "가이드 미션 내용"],
		["100-10 도달", Type.SIZE_SMALL, 134.0, "가이드 미션 내용(단계)"],
		["눌러서 받기", Type.SIZE_SMALL, 134.0, "가이드 수령 안내"],
		["999k/999k", Type.SIZE_SMALL, 134.0, "가이드 진행바 숫자"],
		["100-10", Type.SIZE_SMALL, 134.0, "가이드 진행바(단계는 지금 자리만)"],
		["가이드 9999", Type.SIZE_SMALL, 108.0, "가이드 헤더 탭"],
		# 상단 가운데 덩어리는 **화면 가운데**에 폭 376 으로 놓인다(좌우 100 씩 남아
		# 왼쪽 레벨 배지에 안 닿는다). 진행바 글자 칸 = 376 - 좌우 화살촉(26 x 2) = 324.
		# 두 바는 같은 길이 260. 진행바 글자 칸 = 260 - 화살촉(26 x 2) = 208,
		# 타이머 글자 칸 = 260 - 모래시계 캡 21 - 오른쪽 캡 8 = 231.
		["처치 100 / 100", Type.SIZE_SMALL, 208.0, "진행바 글자(홈통 안)"],
		["피에 젖은 프로스트 골렘", Type.SIZE_SMALL, 208.0, "진행바 글자(보스 이름 최장)"],
		["100초", Type.SIZE_SMALL, 231.0, "타이머 바 글자"],
		["스테이지 100-10", Type.SIZE_MID, 376.0, "상단 스테이지 줄"],
		# 소환 창 글자 칸 376px. 레벨이 오르면 확률에 소수점이 붙어 줄이 길어진다.
		["커먼 38.5%  언커먼 23.1%  레어 26.9%", Type.SIZE_SMALL, 376.0, "소환 확률 줄"],
		["다음 20회  ·  천장 100 / 100", Type.SIZE_SMALL, 376.0, "소환 천장 줄"],
		["장신구 소환  50레벨", Type.SIZE_MID, 376.0, "소환 레벨 줄"],
		# 확률표: 이름 열 100px, 값 칸 (528-100)/5 = 85.6px
		["레전더리", Type.SIZE_SMALL, 100.0, "확률표 등급 이름"],
		["50.5%", Type.SIZE_SMALL, 85.0, "확률표 값 칸"],
		["50레벨", Type.SIZE_SMALL, 85.0, "확률표 머리글"],
		["레벨별 확률  ·  지금 50레벨", Type.SIZE_SMALL, 420.0, "확률표 제목"],
		# 스킬 상세보기. 오른쪽 패널 안쪽 폭 306px, 아래 4칸 버튼 128px(닫기 124px),
		# 재화 줄 148px. `Lv.` 는 이 폰트에서 `ℒ𝔇` 로 읽히므로 반드시 `N레벨` 이다.
		["불멸의 심장", Type.SIZE_MID, 306.0, "스킬 상세 이름"],
		["가호 · 버프 · 쿨타임 23.0초", Type.SIZE_SMALL, 306.0, "스킬 상세 형태 줄"],
		["전 피해 +120% · 9.0초", Type.SIZE_MID, 306.0, "스킬 상세 가호 효과"],
		["피해 x999.99", Type.SIZE_MID, 306.0, "스킬 상세 피해 효과"],
		["조합 +38%", Type.SIZE_MID, 306.0, "스킬 상세 조합"],
		["→ 불멸의 심장", Type.SIZE_SMALL, 148.0, "스킬 상세 승급 칸"],
		["조각 999 / 999", Type.SIZE_SMALL, 148.0, "스킬 상세 조각 칸"],
		["레벨은 위력을, 등급은 한 칸 위를 연다", Type.SIZE_SMALL, 532.0, "스킬 상세 안내"],
		["레전더리 · 99레벨", Type.SIZE_SMALL, 166.0, "스킬 상세 등급 칸"],
	]
	# **Ui.icon 은 준 크기 그대로 나와야 한다.** Control.update_minimum_size() 가
	# 트리 밖 노드에서 되돌아가는 탓에, 속성 순서가 어긋나면 원본 크기(32) 아래로
	# 조용히 안 줄어든다 — 화면에서는 "이 아이콘만 왜 크지"로만 보여서 한참 못 찾았다.
	for want in [12.0, 18.0, 26.0]:
		var probe := Ui.icon("res://assets/ui/icon_power.png", Vector2.ZERO, want)
		assert(is_equal_approx(probe.size.x, want),
			"Ui.icon(%.0f) 이 %.0f 로 나온다 — expand_mode 를 먼저 줘야 한다"
			% [want, probe.size.x])
		probe.free()

	for c in boxes:
		var wpx := font.get_string_size(str(c[0]), HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(c[1])).x
		assert(wpx <= float(c[2]), "%s: '%s' %dpx > 칸 %dpx" % [str(c[3]), str(c[0]),
			int(wpx), int(float(c[2]))])

	print("GearTest OK")
	quit()
