class_name SkillDefs
extends RefCounted

# 스킬. 형태 4 x 등급 5 = 20종, 장착 슬롯 6칸.
# 설계 근거는 docs/SKILL_PLAN.md 에 있다.
#
# **원소는 없다.** 전부 피(血) 계열이고, 갈리는 축은 형태(무엇을 하는가)와
# 등급(얼마나 센가) 둘뿐이다. 자동 전투에서 속성 상성은 플레이어가 개입할 수 없는
# 곳에서 결과만 흔들어서 뺐다.
#
# 등급 배수는 GachaDefs.RARITIES 의 power 를 그대로 쓴다 — 장비와 같은 표를 봐야
# "레전더리는 대충 이 정도"라는 감이 한 게임 안에서 일관된다.

# 형태. 쿨다운을 여기서 가른다 — **6칸을 다 껴도 동시에 터지는 게 2개를 안 넘는**
# 근거가 이 표다. 등급이 올라도 쿨다운은 그대로다(등급은 위력만 올린다).
const SHAPES := {
	"strike": {
		"name": "격", "role": "단일", "cooldown": 7.0, "power": 2.2,
		"motion": "heavy", "fx_y": -36.0, "fx_fps": 16.0,
		"fx_style": "burst",
	},
	"wave": {
		# heavy(내려치기)를 격과 나눠 쓰다가 sweep(횡베기)을 따로 뽑았다 —
		# 같은 모션이면 격이 나갔는지 파가 나갔는지 캐릭터 몸으로는 구분이 안 된다.
		"name": "파", "role": "광역", "cooldown": 13.0, "power": 1.4,
		"motion": "sweep", "fx_y": -36.0, "fx_fps": 16.0,
		"fx_style": "sweep",
	},
	"field": {
		# 바닥에 깔리는 문양이라 기준 높이가 발밑(0)이다. 다른 것과 같은 높이에 두면
		# 공중에 뜬 표지판으로 보인다 — 실제로 그렇게 보였다.
		# fx_y 가 0 이면 지면 정중앙이라 **원래부터 절반이 땅 밑**이었다. 타원으로
		# 눕혀 그리므로 조금만 올리면 바닥에 놓인 것으로 읽힌다.
		#
		# **유일한 다단히트다**(2026-08-06). `hold` 스타일로 바닥에 **머무는** 그림인데
		# 피해는 깔리는 순간 한 번뿐이라 그림과 규칙이 어긋나 있었다 — 틱으로 바꾸니
		# 오히려 맞아진다. 이펙트를 새로 뽑을 필요가 없는 유일한 형태이기도 하다
		# (격·파를 다단히트로 만들면 터지는 한 번짜리 그림이 연타를 못 표현한다).
		#
		# 수치는 damage_lab(Godot 참조 구현)의 **정액형** DoT 를 따른다: 지속시간
		# 동안 초당 2틱, 틱마다 같은 피해. 감쇠형(화상: 첫 틱 40%, 틱마다 -10%)은
		# "터진 여파"고, 정액형이 "머무는 장판"이다 — 우리 그림은 후자다.
		# 총량은 power 로 맞춘다: 한 방 0.9 를 틱 수로 나눠 넣으므로 DPS 는 그대로고,
		# **서 있는 동안 계속 맞는다**는 규칙만 새로 생긴다.
		"name": "진", "role": "광역", "cooldown": 19.0, "power": 0.9,
		"motion": "cast", "fx_y": -14.0, "fx_fps": 10.0,
		"fx_style": "hold", "duration": 3.0, "tick_rate": 2.0,
	},
	"ward": {
		# ward 는 자기한테 거는 동작이라 앞으로 뻗는 cast 와 자세가 다르다.
		"name": "가호", "role": "버프", "cooldown": 23.0, "power": 0.0,
		"motion": "ward", "fx_y": -40.0, "fx_fps": 12.0,
		"fx_style": "orbit", "duration": 6.0, "bonus": 0.30,
	},
}

const SHAPE_ORDER := ["strike", "wave", "field", "ward"]

# 이름표. 형태 x 등급으로 20칸이 정확히 찬다.
# 세로줄이 같은 형태의 상위 버전이라 아이콘도 같은 계열로 골라 뒀다.
const NAMES := {
	"strike": {"common": "피의 송곳니", "uncommon": "핏빛 창", "rare": "사혈 발톱",
		"epic": "처형자의 아가리", "legend": "심연의 손"},
	"wave": {"common": "피의 손길", "uncommon": "튀는 피", "rare": "혈우",
		"epic": "뱀의 무리", "legend": "붉은 소용돌이"},
	"field": {"common": "비명의 흔적", "uncommon": "갈라진 대지", "rare": "감시의 눈",
		"epic": "피의 제단", "legend": "피의 왕좌"},
	"ward": {"common": "피의 결계", "uncommon": "진홍 방패", "rare": "붉은 성배",
		"epic": "혈월", "legend": "불멸의 심장"},
}

const SLOTS := 6            # 장착 칸
const LV_POWER := 0.12      # 레벨당 위력 +12%
const LV_CD_STEPS := [5, 10]   # 이 레벨에 도달할 때마다 쿨다운 -8%
const LV_CD_CUT := 0.08
const CD_FLOOR := 0.45      # 쿨다운 하한 배수. 이게 없으면 후반에 스킬이 상시 발동이 된다
const SHARD_PER_LV := 3     # N -> N+1 레벨에 조각 3N 개
const SYNTH_SHARDS := 5     # 같은 스킬 조각 5개로 **다음 등급**으로 승급 (장비와 같은 값)


static func key_of(shape: String, rarity: String) -> String:
	return "%s_%s" % [shape, rarity]


static func split(key: String) -> Array:
	var parts := key.split("_")
	return [str(parts[0]), str(parts[1])] if parts.size() >= 2 else ["strike", "common"]


static func all_keys() -> Array[String]:
	var out: Array[String] = []
	for shape in SHAPE_ORDER:
		for r in GachaDefs.RARITIES:
			if GachaDefs.rarity_index(str(r["key"])) > GachaDefs.SKILL_TOP_INDEX:
				continue   # 스킬은 신화가 없다
			out.append(key_of(shape, str(r["key"])))
	return out


static func name_of(key: String) -> String:
	var sr := split(key)
	return str(NAMES.get(sr[0], {}).get(sr[1], key))


static func shape_of(key: String) -> Dictionary:
	return SHAPES.get(split(key)[0], SHAPES["strike"])


static func icon_path(key: String) -> String:
	var sr := split(key)
	return "res://assets/skills/sk_%s_%s.png" % [sr[1], sr[0]]


# 이펙트는 **스킬마다 다르다.** 형태 4종만 두면 1,000회 뽑아 나온 레전더리가
# 커먼과 똑같이 터져서 뽑은 보람이 없다. 대신 실루엣 계열은 형태별로 묶어 뒀다 —
# 격은 전부 터지는 점, 파는 옆으로 쓸기, 진은 바닥에 눕기, 가호는 가운데가 빈 고리.
# 그래야 "무엇이 나갔나"는 계속 읽히면서 등급 차이도 보인다.
static func fx_of(key: String) -> String:
	var sr := split(key)
	return "fx_sk_%s_%s" % [sr[1], sr[0]]


# 피격 이펙트. 몹 위에 뜨는 거라 32px 로 작다 — 스킬 이펙트만 하면 몹이 안 보인다.
# 가호는 버프라 피격이 없다.
const HIT_FX := {"strike": "fx_hit_pierce", "wave": "fx_hit_splash",
	"field": "fx_hit_mark", "ward": ""}


static func hit_fx_of(key: String) -> String:
	return str(HIT_FX.get(split(key)[0], ""))


# 등급이 오를수록 같은 형태라도 **더 크고, 잔상이 붙고, 화면이 흔들린다.**
# 그림 20종이 다 달라도 움직임까지 달라야 등급 차이가 전투에서 읽힌다 —
# 목록에서만 다르고 화면에서 같으면 뽑은 보람이 없다.
#
# 잔상(echo)은 같은 이펙트를 조금 늦게·작게·흐리게 한 번 더 띄우는 것이다.
# 새 자산이 필요 없고 "빠르게 지나갔다"가 그것만으로 읽힌다.
const FX_TIER := [
	{"scale": 1.00, "echo": 0, "shake": 0.0},   # 커먼
	{"scale": 1.12, "echo": 1, "shake": 2.0},   # 언커먼
	{"scale": 1.26, "echo": 2, "shake": 3.5},   # 레어
	{"scale": 1.42, "echo": 3, "shake": 5.0},   # 에픽
	{"scale": 1.60, "echo": 4, "shake": 7.0},   # 레전더리
]


# 형태 기본값을 그대로 쓰면 어긋나는 스킬만 적는다.
#
# **서 있는 물건은 돌리지 않는다.** 형태 하나에 스타일 하나를 묶었더니 방패·성배·심장이
# 뒤집히고, 얼굴과 눈이 기울고, 비가 옆으로 날아갔다. 그림이 구체적이라 형태로는 못 묶는다.
# 근거와 전체 표는 docs/SKILL_VFX_RECIPE.md 4-3.
const FX_OVERRIDE := {
	# 혈우 — 비는 위에서 내려온다. y 는 **떨어져 도착하는 자리**이고 거기서
	# FALL_DROP 만큼 위에서 시작한다. -78 은 너무 높아 나무 높이에서 떨어졌다.
	"wave_rare": {"style": "fall", "y": -48.0},
	# skew 0 = 안 기울인다. **정면 대칭인 그림은 기울이면 깊이감이 아니라
	# 찌그러진 그림이 된다.** 비스듬히 그려진 것(송곳니·창)만 기울여야 산다.
	"strike_rare": {"skew": 0.0},       # 사혈 발톱 — 교차 베기라 정면이 맞다
	"strike_epic": {"skew": 0.0},       # 처형자의 아가리 — 정면으로 벌린 입
	# 심연의 손 — **바닥에서 손이 올라와 몹을 끌고 내려간다.** 격인데도 rise 를 쓰는
	# 유일한 스킬이다. 몹 발밑에서 시작해야 "끌려간다"가 읽히므로 y 도 지면 가까이 둔다.
	"strike_legend": {"style": "rise", "y": -16.0, "skew": 0.0},
	"field_epic": {"style": "rise"},                   # 피의 제단 — 솟아오른다
	"field_legend": {"style": "rise"},                 # 피의 왕좌 — 솟아오른다
	"ward_common": {"style": "pulse"},                 # 피의 결계 — 돔은 안 돈다
	"ward_uncommon": {"style": "pulse"},               # 진홍 방패 — 세워져 있어야 한다
	"ward_rare": {"style": "pulse"},                   # 붉은 성배 — 세워져 있어야 한다
	"ward_legend": {"style": "pulse"},                 # 불멸의 심장 — 뛰지, 돌지 않는다
}


# 이펙트 재생에 필요한 값을 한 사전으로. Main 이 형태·등급을 따로 캐지 않게 한다.
static func fx_profile(key: String) -> Dictionary:
	var shape := shape_of(key)
	var tier: Dictionary = FX_TIER[clampi(
		GachaDefs.rarity_index(str(split(key)[1])), 0, FX_TIER.size() - 1)]
	var over: Dictionary = FX_OVERRIDE.get(key, {})
	return {
		"fx": fx_of(key),
		"style": str(over.get("style", shape.get("fx_style", "burst"))),
		"y": float(over.get("y", shape["fx_y"])),
		# 1.0 = 스타일 기본 기울기, 0.0 = 안 기울인다
		"skew": float(over.get("skew", 1.0)),
		"fps": float(shape["fx_fps"]),
		"scale": float(tier["scale"]),
		"echo": int(tier["echo"]),
		"shake": float(tier["shake"]),
	}


static func rarity_of(key: String) -> Dictionary:
	return GachaDefs.rarity(split(key)[1])


# 위력 배수 = 형태 기본 x 등급 x 레벨. 곱셈으로 쌓는 이유: 등급을 올려도, 레벨을
# 올려도 체감이 같은 비율로 붙어야 "무엇을 키울까"가 취향 문제로 남는다.
static func power(key: String, lv: int) -> float:
	return float(shape_of(key)["power"]) * float(rarity_of(key)["power"]) \
		* (1.0 + LV_POWER * float(maxi(0, lv)))


# 자동 장착·정렬이 쓰는 "세기". 등급만 보지 않는 이유: 커먼을 5레벨까지 올린 게
# 갓 뽑은 레어보다 셀 수 있는데, 등급으로만 고르면 그걸 빼고 낀다.
#
# 가호는 피해가 0이라 power 로는 서로 못 가른다 — 그때만 등급·레벨로 잰다.
static func rank(key: String, lv: int) -> float:
	var p := power(key, lv)
	if p > 0.0:
		return p
	return float(rarity_of(key)["power"]) * (1.0 + LV_POWER * float(maxi(0, lv)))


# 쿨다운은 **레벨마다 깎지 않는다.** 매 레벨 깎으면 후반에 스킬이 상시 발동이 되고
# 기본 공격이 사라진다. 정해진 두 지점에서만 계단으로 내린다.
static func cooldown(key: String, lv: int) -> float:
	var cut := 0.0
	for step in LV_CD_STEPS:
		if lv >= int(step):
			cut += LV_CD_CUT
	return float(shape_of(key)["cooldown"]) * maxf(CD_FLOOR, 1.0 - cut)


# ── 가호(ward) 등급 성장 ───────────────────────────────────────────────────
# **가호는 피해가 0이라 power() 로 등급이 안 갈린다.** 그래서 `duration 6.0` ·
# `bonus 0.30` 이 SHAPES 표에서 그대로 복사돼, 레전더리 `불멸의 심장`과 커먼
# `피의 결계`가 **완전히 같은 스킬**이었다 — 소환 풀의 4분의 1(가호 5종)이
# 등급 차이 없이 돌고 있었다.
#
# 축을 둘로 나눈다: **등급은 배수를, 레벨은 지속시간을** 올린다.
# 등급 배수를 rarity power(1.0~5.5)로 곱하면 레전더리가 +165% 가 되는데,
# 23초 쿨다운에 6초 지속이면 평균 +43% 라 다른 형태를 다 눌러 버린다.
# 표로 직접 적어 완만하게 잡았다 — 값을 보고 정할 수 있는 게 낫다.
const WARD_BONUS := [0.30, 0.45, 0.65, 0.90, 1.20]   # 등급별 피해 배수
const WARD_LV_DURATION := 0.3    # 레벨당 지속 +0.3초


static func ward_bonus(key: String) -> float:
	var idx := clampi(GachaDefs.rarity_index(str(split(key)[1])), 0, WARD_BONUS.size() - 1)
	return float(WARD_BONUS[idx])


static func ward_duration(key: String, lv: int) -> float:
	return float(shape_of(key).get("duration", 0.0)) \
		+ WARD_LV_DURATION * float(maxi(0, lv))


# 다음 레벨에 드는 조각. 레벨이 오를수록 무거워진다.
static func shard_cost(lv: int) -> int:
	return SHARD_PER_LV * (maxi(0, lv) + 1)


# 승급 결과 키. **형태는 그대로, 등급만 한 칸 위.** 최고 등급이면 빈 문자열.
# 형태를 바꾸면 "격을 올렸는데 버프가 나왔다"가 되어 조합이 도박이 된다.
static func promote_key(key: String) -> String:
	var sr := split(key)
	var idx := GachaDefs.rarity_index(str(sr[1]))
	if idx >= GachaDefs.SKILL_TOP_INDEX:
		return ""
	return key_of(str(sr[0]), str(GachaDefs.RARITIES[idx + 1]["key"]))


# ── 조합 버프 ──────────────────────────────────────────────────────────────
# 이게 없으면 장착은 "제일 센 것 6개"라서 결정이 아니다.
# **모으기와 펼치기가 둘 다 답이어야** 조합이 성립한다 — 한쪽만 이득이면 그건 정답이다.
const COMBO_SAME_2 := 0.15   # 같은 형태 2개: 그 형태 위력 +15%
const COMBO_SAME_3 := 0.30   # 3개: +30%
const COMBO_ALL_SHAPES := 0.08   # 네 형태를 모두 장착: 전 스탯 +8%


# keys: 장착 중인 스킬 키 목록. 형태별 위력 보정을 돌려준다.
static func combo_power(keys: Array) -> Dictionary:
	var count := {}
	for k in keys:
		var shape := str(split(str(k))[0])
		count[shape] = int(count.get(shape, 0)) + 1
	var out := {}
	for shape_key in count:
		var n := int(count[shape_key])
		out[shape_key] = COMBO_SAME_3 if n >= 3 else (COMBO_SAME_2 if n == 2 else 0.0)
	return out


# 네 형태를 모두 갖췄을 때의 전 스탯 보너스. 없으면 0.
static func combo_spread(keys: Array) -> float:
	var seen := {}
	for k in keys:
		seen[str(split(str(k))[0])] = true
	return COMBO_ALL_SHAPES if seen.size() >= SHAPE_ORDER.size() else 0.0
