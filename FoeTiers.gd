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
	# 주간 보스 전용 4종 (2026-08-13 사장님: "새로운 신규 보스"). 본편 로스터에는
	# 안 들어간다 — StageDefs.ACTS 가 안 부르므로 주간 보스에서만 나온다.
	# 걷기·공격·특수 애니를 전용으로 뽑았다(기존 보스 몸을 빌리면 "또 저놈"이 된다).
	"plague_hag":   {"name": "역병의 산파", "hp_mult": 3.5, "size": 1.35},
	"bone_choir":   {"name": "뼈의 합창단", "hp_mult": 3.6, "size": 1.45},
	"blood_queen":  {"name": "피의 여왕", "hp_mult": 3.7, "size": 1.3},
	"butcher":      {"name": "잊힌 도살자", "hp_mult": 4.0, "size": 1.45},
}


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
# 고급권 18 — 끝까지 미는 사람에게 56회 소환이 걸려 있다.
const CODEX_REWARDS := [
	{"need": 3,   "stat": "damage", "rate": 0.02, "ticket": 3.0},
	{"need": 10,  "stat": "gold",   "rate": 0.03, "ticket": 5.0},
	{"need": 22,  "stat": "damage", "rate": 0.05, "ticket": 5.0},   # 모든 몹 숙련 1단계
	{"need": 44,  "stat": "tough",  "rate": 0.08, "ticket": 10.0},  # 모든 몹 2단계
	{"need": 66,  "stat": "gold",   "rate": 0.10, "ticket_hi": 3.0},
	{"need": 88,  "stat": "damage", "rate": 0.12, "ticket": 15.0},
	{"need": 110, "stat": "damage", "rate": 0.15, "gem": 300.0},   # 옛 만렙(5단계)
	# 6~7단계 확장분 (2026-08-12). 3만·10만 처치 구간이라 진짜 장기 목표다.
	{"need": 132, "stat": "tough",  "rate": 0.15, "ticket_hi": 5.0},
	{"need": 154, "stat": "damage", "rate": 0.20, "ticket_hi": 10.0},
]

# 그 줄의 부가 보상 (종류, 수량). 없으면 빈 사전.
const EXTRA_KEYS := ["gem", "ticket", "ticket_hi"]


static func codex_extra(r: Dictionary) -> Dictionary:
	for k in EXTRA_KEYS:
		if r.has(k):
			return {"kind": k, "amount": float(r[k])}
	return {}


static func codex_max_knowledge() -> int:
	return TIERS.size() * CODEX_KILL_STEPS.size()


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
	return {"damage": "공격력", "gold": "흡혈량", "tough": "체력"}.get(stat, stat)


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
const HP_BASE := 5.5
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
const BOSS_HP_MULT := 105.0
const MIDBOSS_HP_MULT := 78.0


static func role_hp_mult(boss: bool, midboss: bool) -> float:
	if boss:
		return BOSS_HP_MULT
	return MIDBOSS_HP_MULT if midboss else 1.0


static func foe_hp(hp_mult: float, power: float, boss: bool, midboss: bool) -> float:
	return HP_BASE * hp_mult * power * role_hp_mult(boss, midboss)
