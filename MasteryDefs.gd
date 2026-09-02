class_name MasteryDefs
extends RefCounted
# =====================================================================
#  군림 — 숙련 = 기능 해금 (EXPANSION 4장, 4단계)
#
#  본편 돌파가 **자동으로** 연다. 재화도 UI 선택도 없다 — 클리어가 곧 보상.
#  **% 는 없다.** 곱연산 숫자는 전부 혈맥(TraitDefs)이 전담한다 — 이 분담이
#  깨지면 EXPANSION 8장의 예산표가 무효다(BalanceTest 가 혈맥 쪽 상한을 못 박는다).
#
#  조건이 EXPANSION 초안("N막 클리어")과 다른 이유: 이 게임의 막은 50구간마다
#  **순환**한다(act_of = major % 5). "1막 클리어"가 10구간이라 다섯 개가 51구간에
#  다 열려 버린다 — 성장 시대 이정표(8장 표: 1~100 스탯 / 100~300 장비·스킬 /
#  300~ 혈맥)에 맞춘 구간 돌파로 바꿨다.
# =====================================================================

# stage 를 **돌파**하면 열린다 (best_stage > stage — 기록은 다음 구간을 가리킨다).
const RANKS := [
	{"key": "slot", "stage": 50, "name": "군림 I — 일곱 번째 손",
		"desc": "스킬 칸 6 → 7"},
	{"key": "execute", "stage": 100, "name": "군림 II — 왕의 선고",
		"desc": "처형 문턱 15% → 20%"},
	{"key": "cleave3", "stage": 200, "name": "군림 III — 파도베기",
		"desc": "3연격 마무리가 광역"},
	{"key": "hours", "stage": 300, "name": "군림 IV — 긴 군림",
		"desc": "방치 상한 +4시간"},
	{"key": "sweep2", "stage": 450, "name": "군림 V — 수확",
		"desc": "미궁 소탕 2배속"},
]


# kept 는 **군림 각인**(PrestigeDefs.OFFERS)으로 산 것들이다. 회귀가 best_stage
# 를 1 로 되돌려도 각인한 것은 안 꺼진다 — 그것이 그 상품이 파는 규칙이다.
# 기본값이 빈 사전이라 옛 호출부(검사 포함)는 그대로 통과한다.
static func has(key: String, best_stage: int, kept := {}) -> bool:
	if kept.has(key):
		return true
	for r in RANKS:
		if str(r["key"]) == key:
			return best_stage > int(r["stage"])
	return false


static func unlocked_count(best_stage: int) -> int:
	var n := 0
	for r in RANKS:
		if best_stage > int(r["stage"]):
			n += 1
	return n
