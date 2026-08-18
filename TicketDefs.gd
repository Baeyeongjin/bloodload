class_name TicketDefs

# 소환권 (MONETIZATION_PLAN 3~4장). **소환에만 쓰이는 전용 재화**다.
#
# 왜 만드나: 소환 값이 보석인데, 상점과 과금이 붙으면 보석이 두 곳에서 당겨진다.
# 임무가 "소환하라"고 준 보석이 상점으로 새면 그 임무는 보상 의도를 잃는다.
# 소환권은 새지 않는다 — 임무가 소환권을 주면 그건 반드시 소환이 된다.
#
# **종류별로 나눈다** (사장님 2026-08-13). 처음엔 범용 한 종으로 뒀는데, 소환
# 화면이 이미 종류 탭으로 고르니 같은 일이라고 본 게 틀렸다 — **천장(100연)이
# 종류별로 따로 쌓인다.** 범용권만 주면 한 종류에 몰아넣게 되고 나머지 셋의
# 천장은 영영 안 찬다. 종류가 나뉘어야 "오늘은 스킬을 민다"가 성립한다.
#
# 고급권(에픽 확정)은 뺐다 (사장님) — 종류가 넷이 되면서 지갑에 다섯째 칸까지
# 두면 화면에 다 못 적고, 확정 등급은 천장이 이미 하는 일이다.
const KINDS := ["weapon", "armor", "trinket", "skill"]
# 펫 v2 (사장님 2026-08-18): 펫권·펫 장비권. **KINDS 에 안 섞는 이유** —
# 소환 탭 지갑이 KINDS 를 네 칸 폭으로 그린다. 펫권은 펫 탭이 보여 준다.
# 지갑 칸 증가는 사장님이 감수하기로 한 결정이다.
const PET_KINDS := ["pet", "petgear"]

const INFO := {
	"weapon": {"name": "무기 소환권", "short": "무기권",
		"icon": "res://assets/ui/ticket_weapon.png"},
	"armor": {"name": "방어구 소환권", "short": "방어구권",
		"icon": "res://assets/ui/ticket_armor.png"},
	"trinket": {"name": "장신구 소환권", "short": "장신구권",
		"icon": "res://assets/ui/ticket_trinket.png"},
	"skill": {"name": "스킬 소환권", "short": "스킬권",
		"icon": "res://assets/ui/ticket_skill.png"},
	# 아이콘은 자리표시(아트 배치에서 전용으로 교체).
	"pet": {"name": "펫 소환권", "short": "펫권",
		"icon": "res://assets/ui/ticket_trinket.png"},
	"petgear": {"name": "펫 장비 소환권", "short": "펫장비권",
		"icon": "res://assets/ui/ticket_armor.png"},
}

# 보상 표에 적는 이름 — "ticket_weapon" 처럼 쓴다(Main._grant_reward 가 푼다).
const PREFIX := "ticket_"


static func kind_of(reward: String) -> String:
	var k := reward.trim_prefix(PREFIX)
	return k if (k in KINDS or k in PET_KINDS) else ""


static func reward_of(kind: String) -> String:
	return PREFIX + kind


static func name_of(kind: String) -> String:
	return str(INFO.get(kind, {}).get("name", kind))


static func short_of(kind: String) -> String:
	return str(INFO.get(kind, {}).get("short", kind))


static func icon_of(kind: String) -> String:
	return str(INFO.get(kind, {}).get("icon", ""))
