class_name TicketDefs

# 소환권 (MONETIZATION_PLAN 3~4장). **소환에만 쓰이는 전용 재화**다.
#
# 왜 만드나: 소환 값이 보석인데, 상점과 과금이 붙으면 보석이 두 곳에서 당겨진다.
# 임무가 "소환하라"고 준 보석이 상점으로 새면 그 임무는 보상 의도를 잃는다.
# 소환권은 새지 않는다 — 임무가 소환권을 주면 그건 반드시 소환이 된다.
# 동시에 보석은 **상점·과금의 통화**로 성격이 정리된다. 재화를 늘리는 게 아니라
# 하나가 하던 두 일을 둘로 쪼개는 것이다.
#
# **두 종류뿐이다.** 설계 초안의 "지정 소환권"(종류를 골라 뽑는 권)은 접었다 —
# 소환 화면이 이미 종류 탭(무기·방어구·장신구·스킬)으로 고르게 되어 있어서
# 일반권과 하는 일이 같았다. 화면을 보기 전에 표부터 그린 대가다.
const BASIC := "ticket"
const HIGH := "ticket_hi"

# 고급권의 바닥 등급 — 에픽 이상만 나온다. 확률표는 안 건드린다(GachaDefs.pull).
const HIGH_FLOOR := GachaDefs.EPIC_INDEX

const INFO := {
	BASIC: {"name": "소환권", "icon": "res://assets/ui/ticket.png"},
	HIGH: {"name": "고급 소환권", "icon": "res://assets/ui/ticket_hi.png"},
}


static func name_of(key: String) -> String:
	return str(INFO.get(key, {}).get("name", key))


static func icon_of(key: String) -> String:
	return str(INFO.get(key, {}).get("icon", ""))
