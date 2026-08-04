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
const CODEX_REWARDS := [
	{"need": 3,   "stat": "damage", "rate": 0.02},
	{"need": 10,  "stat": "gold",   "rate": 0.03},
	{"need": 22,  "stat": "damage", "rate": 0.05},   # 모든 몹 지식 1레벨
	{"need": 44,  "stat": "tough",  "rate": 0.08},   # 모든 몹 2레벨
	{"need": 66,  "stat": "gold",   "rate": 0.10},
	{"need": 88,  "stat": "damage", "rate": 0.12},
	{"need": 110, "stat": "damage", "rate": 0.15, "gem": 300.0},
]


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
const CODEX_KILL_STEPS := [10, 100, 500, 2000, 10000]
const CODEX_KILL_RATE := 0.04     # 지식 레벨당 그 몹 상대 피해 +4% (만렙 +20%)


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
