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
