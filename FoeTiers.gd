class_name FoeTiers
extends RefCounted

# 몹 티어. arrow-rpg GameConfig.enemy_tiers()에서 방치형에 필요한 필드만 추린 것
# (hp_mult · sprite · 이름). 속도·행동·약점·XP는 방치형에 쓰이지 않아 뺐다.
# 스프라이트 파일명이 곧 key라 arrow-rpg 자산을 그대로 복사해 쓴다.

const TIERS := {
	"slime":        {"name": "슬라임", "hp_mult": 1.0},
	"goblin":       {"name": "고블린", "hp_mult": 1.15},
	"bat":          {"name": "박쥐", "hp_mult": 1.25},
	"spider":       {"name": "거미", "hp_mult": 1.3},
	"zombie":       {"name": "좀비", "hp_mult": 1.5},
	"ghoul":        {"name": "구울", "hp_mult": 1.7},
	"skeleton":     {"name": "해골", "hp_mult": 1.6},
	"mushroom":     {"name": "독버섯", "hp_mult": 1.45},
	"fire_imp":     {"name": "파이어 임프", "hp_mult": 1.8},
	"orc":          {"name": "오크", "hp_mult": 2.1},
	"lava_toad":    {"name": "용암 두꺼비", "hp_mult": 2.0},
	"hellhound":    {"name": "헬하운드", "hp_mult": 2.2},
	"gargoyle":     {"name": "가고일", "hp_mult": 2.6},
	"demon":        {"name": "데몬", "hp_mult": 2.8},
	"frost_spider": {"name": "서리 거미", "hp_mult": 2.3},
	"ice_wisp":     {"name": "아이스 위습", "hp_mult": 2.4},
	"frost_golem":  {"name": "프로스트 골렘", "hp_mult": 3.2},
	"eye_mass":     {"name": "눈알 덩어리", "hp_mult": 3.0},
	"void_wraith":  {"name": "보이드 레이스", "hp_mult": 3.1},
	"wraith_knight":{"name": "망령 기사", "hp_mult": 3.4},
	"cultist":      {"name": "뿔 광신도", "hp_mult": 2.9},
	"dark_knight":  {"name": "다크 나이트", "hp_mult": 3.8},
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
