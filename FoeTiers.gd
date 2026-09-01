class_name FoeTiers
extends RefCounted

# 몹 티어. arrow-rpg GameConfig.enemy_tiers()에서 방치형에 필요한 필드만 추린 것
# (hp_mult · sprite · 이름). 속도·행동·약점·XP는 방치형에 쓰이지 않아 뺐다.
# 스프라이트 파일명이 곧 key라 arrow-rpg 자산을 그대로 복사해 쓴다.

const TIERS := {
	"slime":        {"name": "슬라임", "hp_mult": 1.0, "size": 0.85},
	"goblin":       {"name": "고블린", "hp_mult": 1.15, "size": 0.95},
	"bat":          {"name": "박쥐", "hp_mult": 1.25, "size": 0.75},
	"spider":       {"name": "거미", "hp_mult": 1.3, "size": 0.9},
	"zombie":       {"name": "좀비", "hp_mult": 1.5, "size": 1.05},
	"ghoul":        {"name": "구울", "hp_mult": 1.7, "size": 1.1},
	"skeleton":     {"name": "해골", "hp_mult": 1.6, "size": 1.0},
	"mushroom":     {"name": "독버섯", "hp_mult": 1.45, "size": 0.9},
	"fire_imp":     {"name": "파이어 임프", "hp_mult": 1.8, "size": 0.9},
	"orc":          {"name": "오크", "hp_mult": 2.1, "size": 1.25},
	"lava_toad":    {"name": "용암 두꺼비", "hp_mult": 2.0, "size": 1.2},
	"hellhound":    {"name": "헬하운드", "hp_mult": 2.2, "size": 1.15},
	"gargoyle":     {"name": "가고일", "hp_mult": 2.6, "size": 1.35},
	"demon":        {"name": "데몬", "hp_mult": 2.8, "size": 1.4},
	"frost_spider": {"name": "서리 거미", "hp_mult": 2.3, "size": 1.1},
	"ice_wisp":     {"name": "아이스 위습", "hp_mult": 2.4, "size": 0.85},
	"frost_golem":  {"name": "프로스트 골렘", "hp_mult": 3.2, "size": 1.5},
	"eye_mass":     {"name": "눈알 덩어리", "hp_mult": 3.0, "size": 1.5},
	"void_wraith":  {"name": "보이드 레이스", "hp_mult": 3.1, "size": 1.3},
	"wraith_knight":{"name": "망령 기사", "hp_mult": 3.4, "size": 1.25},
	"cultist":      {"name": "뿔 광신도", "hp_mult": 2.9, "size": 1.1},
	"dark_knight":  {"name": "다크 나이트", "hp_mult": 3.8, "size": 1.4},
	# ── 6~10막 신규 로스터 (2026-08-27 사장님 픽 — 막마다 신규 2 + 재사용 3).
	# 후보 A/B 를 뽑아 사장님이 골랐다. 애니는 픽된 스틸에서 animate_image 로.
	"crystal_crab": {"name": "수정 게", "hp_mult": 2.5, "size": 0.95},
	"crystal_wisp": {"name": "수정 정령", "hp_mult": 2.6, "size": 0.85},
	"vine_statue":  {"name": "덩굴 석상", "hp_mult": 2.8, "size": 1.1},
	"moon_moth":    {"name": "달 나방", "hp_mult": 2.4, "size": 0.8},
	"blood_acolyte":{"name": "혈월 사도", "hp_mult": 2.9, "size": 1.05},
	"blood_raven":  {"name": "핏빛 까마귀", "hp_mult": 2.5, "size": 0.8},
	"swamp_leech":  {"name": "늪 거머리", "hp_mult": 2.7, "size": 0.95},
	"bog_wisp":     {"name": "도깨비불", "hp_mult": 2.6, "size": 0.85},
	"royal_guard":  {"name": "근위 구울", "hp_mult": 3.2, "size": 1.15},
	"royal_hound":  {"name": "왕실 사냥개", "hp_mult": 3.0, "size": 1.05},
	# ── 6~10막 전용 보스 (사장님: 전부 A 안). 기존 막 보스처럼 로스터에는
	# 안 들어가고 막 끝에서만 나온다. 시련·성소 전용(ruin_warden·
	# sanctum_guardian)을 빌리는 안은 접었다 — 둘 다 "재활용하지 말라"로
	# 만들어진 얼굴이다.
	"crystal_golem":   {"name": "결정 골렘", "hp_mult": 4.0, "size": 1.45},
	"vine_colossus":   {"name": "덩굴 거상", "hp_mult": 4.2, "size": 1.45},
	"bloodmoon_avatar":{"name": "혈월의 화신", "hp_mult": 4.4, "size": 1.4},
	"drowned_king":    {"name": "익사한 왕", "hp_mult": 4.6, "size": 1.45},
	"usurper":         {"name": "찬탈자", "hp_mult": 4.8, "size": 1.35},
	# 주간 보스 전용 4종 (2026-08-13 사장님: "새로운 신규 보스"). 본편 로스터에는
	# 안 들어간다 — StageDefs.ACTS 가 안 부르므로 주간 보스에서만 나온다.
	# 걷기·공격·특수 애니를 전용으로 뽑았다(기존 보스 몸을 빌리면 "또 저놈"이 된다).
	"plague_hag":   {"name": "역병의 산파", "hp_mult": 3.5, "size": 1.35, "event": true},
	"bone_choir":   {"name": "뼈의 합창단", "hp_mult": 3.6, "size": 1.45, "event": true},
	"blood_queen":  {"name": "피의 여왕", "hp_mult": 3.7, "size": 1.3, "event": true},
	"butcher":      {"name": "잊힌 도살자", "hp_mult": 4.0, "size": 1.45, "event": true},
	# 시련 전용 보스 (2026-08-18 사장님: "재활용하지 말고 하나 만들어라") —
	# 단계가 몇이든 얼굴은 이 하나다. 힘은 TrialDefs.eq_stage 가 정한다.
	"ruin_warden":  {"name": "유적의 파수꾼", "hp_mult": 3.6, "size": 1.4, "event": true},
	# 성소 전용 수호자 (2026-08-20 사장님: "재활용 보스는 신규로 교체" — 시련의
	# ruin_warden 과 같은 결정). 성소만 본편 막 보스를 빌려 쓰고 있었다.
	# hp_mult 1.0: 판 체력은 RaidDefs.hp_mult(잡졸 100마리 몫)가 정한다 —
	# 여기에 또 얹으면 두 번 곱한다.
	"sanctum_guardian": {"name": "성소의 수호자", "hp_mult": 1.0, "size": 1.4,
		"event": true},
}


# 특수 착지 파동의 테마 — **보스마다 고유 패턴**(사장님 2026-08-20: "다
# 돌려쓰니까 고유 패턴 넣어주면 좋을듯" — 탭 UI 세트와 같은 결정이다).
# [모양, 심 색, 테두리 색]. 표에 없는 키는 돌빛 파편(기본)으로 떨어진다 —
# 중간보스·주간 보스까지 다 적으면 표가 로스터 사본이 된다.
# **색은 보스 전용 아트에서 실측했다**(사장님 2026-08-20: "색조 분석해서
# 통일성"). 임의 RGB 로 정했더니 아트와 어긋났다 — 다크 나이트는 진홍이
# 아니라 상아 뼈 갑옷이고, 가고일은 주황이 아니라 검붉은 몸이다. 파동이
# **자기 몸 색으로 터져야** 화면이 한 벌로 읽힌다. 값은 boss_N_walk/0.png
# 의 채도 상위 무리(core=밝은 강조, edge=어두운 몸통).
# **모양 이름이 아니라 이펙트의 구조 이름이다** (2026-08-20 2차, 사장님:
# "다 똑같은 이펙트"). 1차는 [전선+점선+슬롯패턴] 한 틀에 슬롯만 갈았는데
# 화면에선 공통 뼈대가 대부분이라 전부 같아 보였다. 이제 구조가 통째로 다르다
# — 그리는 코드는 Main._slam_draw 의 match 한 갈래씩이다.
const SLAM_THEME := {
	"sanctum_guardian": ["crystal", Color(0.62, 0.88, 1.0), Color(0.30, 0.55, 0.95)],
	"frost_golem": ["crack", Color(0.63, 0.87, 0.93), Color(0.18, 0.41, 0.56)],
	"wraith_knight": ["soul", Color(0.80, 0.67, 0.44), Color(0.49, 0.37, 0.21)],
	"gargoyle": ["pillar", Color(0.86, 0.36, 0.16), Color(0.40, 0.13, 0.11)],
	"eye_mass": ["lash", Color(0.55, 0.32, 0.78), Color(0.22, 0.08, 0.37)],
	"dark_knight": ["arc", Color(0.92, 0.88, 0.76), Color(0.47, 0.44, 0.36)],
	"blood_queen": ["spray", Color(0.78, 0.16, 0.38), Color(0.38, 0.02, 0.17)],
	"bone_choir": ["sonic", Color(0.78, 0.62, 0.72), Color(0.36, 0.23, 0.31)],
	"butcher": ["cross", Color(0.62, 0.16, 0.30), Color(0.36, 0.04, 0.15)],
	"plague_hag": ["boil", Color(0.44, 0.80, 0.20), Color(0.14, 0.38, 0.19)],
	"ruin_warden": ["debris", Color(0.60, 0.78, 0.10), Color(0.26, 0.46, 0.03)],
	# 6~10막 보스 — 구조는 기존 그리기 갈래를 빌리고(새 갈래를 늘리면 또
	# "다 똑같은 이펙트"의 반대 문제, 그리는 코드가 다섯 배가 된다) 색은
	# 픽된 스틸에서 실측했다(core=채도x밝기 최대, edge=어두운 몸통 —
	# 순백·순흑 하이라이트는 걸렀다).
	"crystal_golem": ["crystal", Color(0.50, 1.00, 1.00), Color(0.00, 0.11, 0.20)],
	"vine_colossus": ["lash", Color(0.69, 0.78, 0.78), Color(0.31, 0.36, 0.24)],
	"bloodmoon_avatar": ["pillar", Color(0.94, 0.70, 0.68), Color(0.40, 0.05, 0.08)],
	"drowned_king": ["crack", Color(0.95, 0.82, 0.49), Color(0.42, 0.51, 0.19)],
	"usurper": ["arc", Color(0.97, 0.87, 0.54), Color(0.18, 0.02, 0.08)],
}


# 특수 공격의 **기전** — 이펙트만 갈랐더니 규칙은 전부 같은 내려찍기였다
# (사장님: "고유 패턴 작업 들어가자"). 예고·피해·사거리·타수를 가른다.
#   [예고 초, 피해 배수, 사거리 배수, 타수, 움직임]
# 자동 전투라 상태이상은 안 넣는다(HANDOFF 8-1 닫힌 결정 — 둔화는 DPS
# 한 줄이 된다). 다섯째 축 "움직임"(2026-08-20, 사장님: "한자리에서만
# 때리는 거 말고"):
#   ""       제자리 — 2연격·촉수·처형은 서 있는 게 개성이다
#   "dash"   예고 후 영웅 앞까지 미끄러져 벤 뒤 스르륵 복귀 (유령)
#   "jump"   예고 후 뛰어올라 영웅 자리에 떨어지며 광역 (수호자 모션과 일치)
#   "meteor" 제자리 캐스팅 — 하늘에서 화염구가 영웅 자리에 떨어진다
# 여섯이 다 뛰어다니면 오히려 개성이 죽는다 — 제자리 셋은 그대로 둔다.
const SPECIAL_KIND := {
	"wraith_knight": [0.45, 2.0, 1.7, 1, "dash"],
	"gargoyle": [0.85, 2.4, 1.7, 1, "meteor"],
	"frost_golem": [0.85, 1.3, 1.7, 2, ""],
	"eye_mass": [0.85, 2.2, 2.8, 1, ""],
	"dark_knight": [1.30, 4.0, 1.7, 1, ""],
	"sanctum_guardian": [0.85, 2.4, 1.7, 1, "jump"],
	# 주간 보스 — 매주 얼굴이 바뀌는 자리라 넷이 서로도 달라야 한다.
	"blood_queen": [0.70, 2.2, 1.7, 1, "dash"],   # 흡혈 — 벤 만큼 제 피를 채운다
	"bone_choir": [0.85, 1.8, 3.2, 1, ""],        # 비명 — 판 끝까지 닿는 음파
	"butcher": [0.70, 2.8, 1.7, 1, "dash"],       # 돌진 강타 — 여왕보다 둔하고 아프다
	"plague_hag": [0.85, 2.0, 1.7, 1, "meteor"],  # 독 구슬 — 하늘에서 떨어진다
	"ruin_warden": [1.00, 3.0, 1.9, 1, "jump"],   # 대지 격노 — 유적째로 내려찍는다
	# 6~10막 보스 — 다섯이 서로 다르다(제자리 강타 · 넓은 휩쓸기 · 낙하체 ·
	# 점프 · 대시). 기존 축 다섯 개 안에서만 골랐다 — 새 움직임을 만들면
	# Foe._special_move 에 갈래가 늘어난다.
	"crystal_golem":    [0.85, 2.4, 1.7, 1, ""],        # 제자리 수정 강타
	"vine_colossus":    [0.85, 2.2, 2.4, 1, ""],        # 덩굴 휩쓸기 — 사거리가 넓다
	"bloodmoon_avatar": [0.85, 2.4, 1.7, 1, "meteor"],  # 혈월 낙하체
	"drowned_king":     [0.90, 2.6, 1.8, 1, "jump"],    # 몸통 박치기
	"usurper":          [0.70, 2.2, 1.7, 1, "dash"],    # 발도 돌진
}
const SPECIAL_DEFAULT := [0.85, 2.4, 1.7, 1, ""]   # 표에 없는 보스·중간보스


const METEOR_ART := {
	"gargoyle": "vfx_fire_ball",
	"plague_hag": "vfx_earth_ball",
	"bloodmoon_avatar": "vfx_dark_ball",   # 혈월 — 어둠 구체가 맞다
}


static func meteor_art(key: String) -> String:
	return METEOR_ART.get(key, "vfx_fire_ball")


static func special_kind(key: String) -> Array:
	return SPECIAL_KIND.get(key, SPECIAL_DEFAULT)


static func slam_theme(key: String) -> Array:
	return SLAM_THEME.get(key,
		["rock", Color(0.95, 0.78, 0.45), Color(0.55, 0.40, 0.28)])


static func get_tier(key: String) -> Dictionary:
	var t: Dictionary = TIERS.get(key, TIERS["slime"]).duplicate()
	t["key"] = key
	t["sprite"] = sprite_of(key)
	return t


static func sprite_of(key: String) -> String:
	return "res://assets/enemies/%s.png" % key


# 표에 적힌 순서 = 도감 순서 = 대략 약한 순. 따로 정렬표를 두지 않는다.
static func all_keys() -> Array:
	return TIERS.keys()


# 도감 보상 (DESIGN 13-4). 처치 수만 세고 보상이 없으면 모을 이유가 없다.
# **영구 능력치**만 준다 — 소모품은 받는 순간 끝나서 장기 목표가 안 된다.
#
# 기준은 **발견 종 수가 아니라 지식 합계**다. 종 수로 하면 한 마리씩 22번 만나면
# 끝이라 목표가 며칠 만에 닫힌다. 지식 합계(= 몹별 지식 레벨의 총합, 최대 110)는
# 방치로 계속 오르므로 오래 간다.
# 마지막 칸은 전 몹 만렙(= TIERS.size() x CODEX_KILL_STEPS.size())이어야 한다.
# 그 검사는 tests/GearTest.gd 에 있다.
# 부가 보상은 **줄마다 한 종류만** 둔다 — 두 개를 적으면 190px 칸을 넘는다.
# 소환권을 여기 태우는 이유(2026-08-13, MONETIZATION_PLAN 4-2): 도감은 가장 긴
# 수집(154종 · 10만 처치)인데 보상이 스탯 %뿐이라 눈에 안 보였다. 합 소환권 38 ·
# 종류별로 흩어 놓았다 — 끝까지 미는 사람에게 83회 소환이 걸려 있다.
# **눈금은 도감 키 수 x 숙련 단계다.** 몹을 늘리면 여기도 같이 늘려야 한다 —
# 안 고치면 마지막 보상이 영영 도달 불가가 되는데 화면에는 표시가 안 난다.
# `tests/GearTest` 가 마지막 줄과 `codex_max_knowledge()` 를 대조해서 잡는다.
#
# 2026-08-27: 10막 확장으로 도감 키가 **22 -> 37** 이 되면서 만렙 합계가
# 154 -> 259 로 뛰었다. 단계 눈금(37 x 1..7)으로 다시 깔았다.
const CODEX_REWARDS := [
	{"need": 3,   "stat": "damage", "rate": 0.02, "ticket_weapon": 3.0},
	{"need": 10,  "stat": "crit",   "rate": 0.03, "ticket_armor": 5.0},
	{"need": 37,  "stat": "damage", "rate": 0.05, "ticket_trinket": 5.0},   # 모든 몹 숙련 1단계
	{"need": 74,  "stat": "tough",  "rate": 0.08, "ticket_skill": 10.0},  # 모든 몹 2단계
	{"need": 111, "stat": "crit",   "rate": 0.10, "ticket_weapon": 10.0},
	{"need": 148, "stat": "damage", "rate": 0.12, "ticket_armor": 15.0},
	{"need": 185, "stat": "damage", "rate": 0.15, "gem": 300.0},   # 옛 만렙(5단계)
	# 6~7단계 확장분 (2026-08-12). 3만·10만 처치 구간이라 진짜 장기 목표다.
	{"need": 222, "stat": "tough",  "rate": 0.15, "ticket_trinket": 15.0},
	{"need": 259, "stat": "damage", "rate": 0.20, "ticket_skill": 20.0},
]

# 그 줄의 부가 보상 (종류, 수량). 없으면 빈 사전.
const EXTRA_KEYS := ["gem", "ticket_weapon", "ticket_armor",
	"ticket_trinket", "ticket_skill"]


static func codex_extra(r: Dictionary) -> Dictionary:
	for k in EXTRA_KEYS:
		if r.has(k):
			return {"kind": k, "amount": float(r[k])}
	return {}


# 도감에 오르는 몹 (주간 보스 제외). **주간 보스는 본편에 안 나오고 죽이는 게
# 목표도 아니라**(피해 누적이 목표다) 도감에 넣으면 만렙이 영영 안 채워진다.
static func codex_keys() -> Array:
	var out: Array = []
	for k in TIERS:
		if not bool(TIERS[k].get("event", false)):
			out.append(k)
	return out


static func codex_max_knowledge() -> int:
	return codex_keys().size() * CODEX_KILL_STEPS.size()


# 지식 합계에 해당하는 누적 배율. 단계별로 곱하지 않고 **더한다** —
# 곱하면 마지막 한 칸이 앞의 보상까지 전부 배로 튀긴다.
static func codex_bonus(knowledge: int, stat: String) -> float:
	var sum := 0.0
	for r in CODEX_REWARDS:
		if knowledge >= int(r["need"]) and str(r["stat"]) == stat:
			sum += float(r["rate"])
	return sum


# 지금 합계에서 **막 넘긴** 보상. 없으면 빈 사전.
# 합계는 한 번에 1씩만 오르므로 같은 칸을 두 번 밟을 수 없다.
static func codex_reward_at(knowledge: int) -> Dictionary:
	for r in CODEX_REWARDS:
		if int(r["need"]) == knowledge:
			return r
	return {}


static func codex_stat_name(stat: String) -> String:
	return {"damage": "공격력", "crit": "치명 확률", "tough": "체력"}.get(stat, stat)


# ── 몬스터별 지식 ──────────────────────────────────────────────────────────
# 같은 몹을 계속 잡으면 그 몹을 더 잘 잡게 된다. 방치형에서 반복 처치는 어차피
# 일어나므로 **이미 일어나는 행동에 보상을 붙이는** 가장 싼 장기 목표다.
#
# 전체 스탯이 아니라 **그 몹 상대 피해**인 이유: 전체 스탯이면 그냥 숫자가 하나 더
# 늘 뿐이고, 상대별이면 "이 막이 안 밀리네" 할 때 어디를 파야 하는지가 보인다.
# 5단계 -> 7단계 (2026-08-12, 종별 숙련 확장 — 참고작도 7단계다). 난이도 x3 로
# 벽 앞에서 같은 종을 오래 잡게 됐으니, 깊은 사냥에도 오르는 눈금이 있어야 한다.
const CODEX_KILL_STEPS := [10, 100, 500, 2000, 10000, 30000, 100000]
const CODEX_KILL_RATE := 0.04     # 숙련 단계당 그 몹 상대 피해 +4% (만렙 +28%)


static func codex_level(kills: int) -> int:
	var lv := 0
	for need in CODEX_KILL_STEPS:
		if kills >= int(need):
			lv += 1
	return lv


static func codex_kill_bonus(kills: int) -> float:
	return float(codex_level(kills)) * CODEX_KILL_RATE


# 다음 단계까지 필요한 처치 수. 만렙이면 0.
static func codex_next_need(kills: int) -> int:
	for need in CODEX_KILL_STEPS:
		if kills < int(need):
			return int(need) - kills
	return 0


static func codex_step_of(kills: int) -> int:
	var lv := codex_level(kills)
	return int(CODEX_KILL_STEPS[mini(lv, CODEX_KILL_STEPS.size() - 1)])


# ── 몹 수치 ────────────────────────────────────────────────────────────────
# 예전엔 이 공식이 Foe.setup / Main._offline_profile / BalanceTest 세 군데에
# 각각 적혀 있었다. 하나만 고치면 실시간과 오프라인과 검사가 서로 다른 게임이 된다.
#
# HP_BASE 를 10 -> 5.5 로 내렸다. 한 구간이 60마리 / 60초가 되면서 마리당 쓸 수 있는
# 시간이 1초뿐인데, 10 이면 시작하자마자 처치시간이 1.2초라 1-1 부터 시간 초과였다.
# **x3** (2026-08-20, 사장님: "일반 몬스터 체력도 상향이 필요할 것 같아").
# 실측 처치시간이 0.25초라 잡몹이 눈에 보이기도 전에 녹았다.
#
# 셋을 같이 움직인다 — 그래야 체감만 바뀌고 곡선이 안 깨진다:
#   체력 x3 · 구간 처치수 60 -> 20 · 마리당 보상 x3
# 방치 수입이 `보상 / 처치시간` 이라 위아래가 같이 3배면 그대로고, 구간 시간도
# 마리 수가 1/3 이라 그대로다. 바뀌는 건 **한 마리의 무게**뿐이다.
const HP_BASE := 16.5
# 보스·중간보스는 **한 마리로 구간을 막는다.** 12 / 3.5 였을 때는 보스 처치시간이
# 일반 몹의 12배뿐이라, 일반 구간이 45초 걸리는데 보스는 9초에 끝났다 —
# 벽이어야 할 자리가 제일 쉬웠다. 제한 시간의 절반쯤 걸리게 잡은 값이다.
#
# **공격력의 게이트는 보스의 제한 시간 하나뿐이다** — 일반 구간엔 시계가 없어
# 약해도 "느려질 뿐"이다(StageDefs.time_limit 주석). 그래서 이 배수가 헐거우면
# 공격 투자는 영영 선택으로 남는다.
# 190/120 까지 올려 봤다가 되돌렸다(2026-08-12): 같은 날 power 곡선에 선형항이
# 살아나 보스 체력이 이미 78구간 x4.8 이 됐다 — 두 배를 겹치면 초반 보스가
# 통째로 막힌다. 곡선 쪽이 근본이라 그쪽만 세운다.
#
# 그 뒤 사장님: **"막히는 걸 5구간 이렇게 더 타이트하게"**. 관문은 이미 5구간
# 마다(중간보스) 10구간마다(보스) 서 있고 **제한 시간까지 걸려 있다** — 문제는
# 문턱이 낮아 그냥 지나쳤다는 것이다. 중간보스를 크게 올려(48 -> 78) 5구간
# 리듬을 세우고, 보스는 그보다 한 뼘 위(75 -> 105)에 둔다.
# 일반 구간은 그대로다: 거기에 시계를 걸면 벽이 아니라 처리량 상한이 된다
# (StageDefs.time_limit 주석의 그 사고).
#
# **2026-08-20: 105/78 -> 35/26.** 이 값은 일반 몹의 배수라, HP_BASE 를 3배로
# 올리면 보스도 같이 3배가 된다 — 그러면 "일반이 너무 약하다"를 고치려다 보스가
# 세 배로 두꺼워진다. 같은 몫으로 나눠서 **보스의 절대 체력은 그대로** 두고
# 비율만 좁힌다(실측 처치시간 비 156배 -> 52배).
const BOSS_HP_MULT := 35.0
const MIDBOSS_HP_MULT := 26.0


static func role_hp_mult(boss: bool, midboss: bool) -> float:
	if boss:
		return BOSS_HP_MULT
	return MIDBOSS_HP_MULT if midboss else 1.0


static func foe_hp(hp_mult: float, power: float, boss: bool, midboss: bool) -> float:
	return HP_BASE * hp_mult * power * role_hp_mult(boss, midboss)
