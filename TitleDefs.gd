class_name TitleDefs
extends RefCounted
# =====================================================================
#  칭호 — 장기 수집 축 (EXPANSION 5장, 5단계)
#
#  조건은 **이미 기록하고 있는 것만** 쓴다(도감·구간·미궁 층·혈맥·스킬 보유) —
#  새 추적 코드가 없어야 이 축이 싸다. 참고작처럼 조건 두 개가 짝이다.
#
#  보상은 **스탯 훈련 공짜 레벨**이다. 합연산 축(1층)에 얹히므로 곱연산
#  예산(혈맥 전담)을 안 건드리고, 효과에만 붙고 **비용에는 안 붙는다** —
#  비용에 붙으면 칭호를 딸수록 다음 강화가 비싸지는 벌이 된다(Main._stat_eff).
# =====================================================================

# cond kind 와 그 값이 보는 기록:
#   stage    본편 돌파 (best_stage > n)
#   floor    미궁 최고층 (dungeon_best >= n)
#   hero     영웅 레벨 (hero_lv >= n)
#   kills    도감 처치 합계 >= n
#   species  도감 발견 종 >= n
#   knowledge 도감 지식 합계 >= n
#   skills   보유 스킬 종수 >= n
#   traits   혈맥 노드 수 >= n
#   trial    시련 격파 단계 >= n
#   pets     데려온 펫 종수 >= n
#   chest    천장 상자 개봉 횟수 >= n
#   nights   함께한 밤(플레이 시간) >= n 시간
#   prestige 핏빛 회귀 횟수 >= n
const TITLES := [
	{"id": "stage10", "name": "10구간의 주인", "stat": "damage", "levels": 2,
		"conds": [{"kind": "stage", "n": 10}]},
	{"id": "stage20", "name": "20구간의 주인", "stat": "damage", "levels": 3,
		"conds": [{"kind": "stage", "n": 20}]},
	{"id": "stage30", "name": "30구간의 주인", "stat": "damage", "levels": 3,
		"conds": [{"kind": "stage", "n": 30}]},
	{"id": "stage50", "name": "50구간의 주인", "stat": "damage", "levels": 4,
		"conds": [{"kind": "stage", "n": 50}]},
	{"id": "stage75", "name": "75구간의 주인", "stat": "damage", "levels": 4,
		"conds": [{"kind": "stage", "n": 75}]},
	{"id": "stage100", "name": "100구간의 주인", "stat": "damage", "levels": 5,
		"conds": [{"kind": "stage", "n": 100}]},
	{"id": "stage150", "name": "150구간의 주인", "stat": "damage", "levels": 6,
		"conds": [{"kind": "stage", "n": 150}]},
	{"id": "stage200", "name": "200구간의 주인", "stat": "damage", "levels": 6,
		"conds": [{"kind": "stage", "n": 200}]},
	{"id": "stage250", "name": "250구간의 주인", "stat": "damage", "levels": 7,
		"conds": [{"kind": "stage", "n": 250}]},
	{"id": "stage300", "name": "300구간의 주인", "stat": "damage", "levels": 8,
		"conds": [{"kind": "stage", "n": 300}]},
	{"id": "stage350", "name": "350구간의 주인", "stat": "damage", "levels": 8,
		"conds": [{"kind": "stage", "n": 350}]},
	{"id": "stage400", "name": "400구간의 주인", "stat": "damage", "levels": 9,
		"conds": [{"kind": "stage", "n": 400}]},
	{"id": "stage450", "name": "450구간의 주인", "stat": "damage", "levels": 9,
		"conds": [{"kind": "stage", "n": 450}]},
	{"id": "stage500", "name": "500구간의 주인", "stat": "damage", "levels": 10,
		"conds": [{"kind": "stage", "n": 500}]},
	{"id": "floor5", "name": "다섯 층의 어둠", "stat": "tough", "levels": 2,
		"conds": [{"kind": "floor", "n": 5}]},
	{"id": "floor10", "name": "열 층의 어둠", "stat": "tough", "levels": 3,
		"conds": [{"kind": "floor", "n": 10}]},
	{"id": "floor15", "name": "열다섯 층의 어둠", "stat": "tough", "levels": 3,
		"conds": [{"kind": "floor", "n": 15}]},
	{"id": "floor20", "name": "스무 층의 어둠", "stat": "tough", "levels": 4,
		"conds": [{"kind": "floor", "n": 20}]},
	{"id": "floor30", "name": "서른 층의 어둠", "stat": "tough", "levels": 5,
		"conds": [{"kind": "floor", "n": 30}]},
	{"id": "floor40", "name": "마흔 층의 어둠", "stat": "tough", "levels": 6,
		"conds": [{"kind": "floor", "n": 40}]},
	{"id": "floor50", "name": "쉰 층의 어둠", "stat": "tough", "levels": 6,
		"conds": [{"kind": "floor", "n": 50}]},
	{"id": "floor60", "name": "예순 층의 어둠", "stat": "tough", "levels": 7,
		"conds": [{"kind": "floor", "n": 60}]},
	{"id": "floor70", "name": "일흔 층의 어둠", "stat": "tough", "levels": 8,
		"conds": [{"kind": "floor", "n": 70}]},
	{"id": "floor80", "name": "여든 층의 어둠", "stat": "tough", "levels": 9,
		"conds": [{"kind": "floor", "n": 80}]},
	{"id": "floor90", "name": "90 층의 어둠", "stat": "tough", "levels": 9,
		"conds": [{"kind": "floor", "n": 90}]},
	{"id": "floor100", "name": "백 층의 어둠", "stat": "tough", "levels": 10,
		"conds": [{"kind": "floor", "n": 100}]},
	{"id": "kills100", "name": "100의 사냥", "stat": "speed", "levels": 2,
		"conds": [{"kind": "kills", "n": 100}]},
	{"id": "kills500", "name": "500의 사냥", "stat": "speed", "levels": 3,
		"conds": [{"kind": "kills", "n": 500}]},
	{"id": "kills1000", "name": "천의 사냥", "stat": "speed", "levels": 4,
		"conds": [{"kind": "kills", "n": 1000}]},
	{"id": "kills3000", "name": "천의 사냥", "stat": "speed", "levels": 5,
		"conds": [{"kind": "kills", "n": 3000}]},
	{"id": "kills10000", "name": "만의 사냥", "stat": "speed", "levels": 6,
		"conds": [{"kind": "kills", "n": 10000}]},
	{"id": "kills30000", "name": "만의 사냥", "stat": "speed", "levels": 6,
		"conds": [{"kind": "kills", "n": 30000}]},
	{"id": "kills100000", "name": "십만의 사냥", "stat": "speed", "levels": 7,
		"conds": [{"kind": "kills", "n": 100000}]},
	{"id": "kills300000", "name": "십만의 사냥", "stat": "speed", "levels": 8,
		"conds": [{"kind": "kills", "n": 300000}]},
	{"id": "kills1000000", "name": "백만의 사냥", "stat": "speed", "levels": 9,
		"conds": [{"kind": "kills", "n": 1000000}]},
	{"id": "kills3000000", "name": "백만의 사냥", "stat": "speed", "levels": 10,
		"conds": [{"kind": "kills", "n": 3000000}]},
	{"id": "species3", "name": "세 종의 기록", "stat": "critdmg", "levels": 2,
		"conds": [{"kind": "species", "n": 3}]},
	{"id": "species5", "name": "다섯 종의 기록", "stat": "critdmg", "levels": 3,
		"conds": [{"kind": "species", "n": 5}]},
	{"id": "species8", "name": "여덟 종의 기록", "stat": "critdmg", "levels": 4,
		"conds": [{"kind": "species", "n": 8}]},
	{"id": "species10", "name": "열 종의 기록", "stat": "critdmg", "levels": 5,
		"conds": [{"kind": "species", "n": 10}]},
	{"id": "species12", "name": "열두 종의 기록", "stat": "critdmg", "levels": 6,
		"conds": [{"kind": "species", "n": 12}]},
	{"id": "species15", "name": "열다섯 종의 기록", "stat": "critdmg", "levels": 7,
		"conds": [{"kind": "species", "n": 15}]},
	{"id": "species18", "name": "18 종의 기록", "stat": "critdmg", "levels": 8,
		"conds": [{"kind": "species", "n": 18}]},
	{"id": "species20", "name": "스무 종의 기록", "stat": "critdmg", "levels": 9,
		"conds": [{"kind": "species", "n": 20}]},
	{"id": "species22", "name": "22 종의 기록", "stat": "critdmg", "levels": 10,
		"conds": [{"kind": "species", "n": 22}]},
	{"id": "knowledge5", "name": "지식 5의 학자", "stat": "damage", "levels": 2,
		"conds": [{"kind": "knowledge", "n": 5}]},
	{"id": "knowledge10", "name": "지식 10의 학자", "stat": "damage", "levels": 3,
		"conds": [{"kind": "knowledge", "n": 10}]},
	{"id": "knowledge20", "name": "지식 20의 학자", "stat": "damage", "levels": 4,
		"conds": [{"kind": "knowledge", "n": 20}]},
	{"id": "knowledge30", "name": "지식 30의 학자", "stat": "damage", "levels": 5,
		"conds": [{"kind": "knowledge", "n": 30}]},
	{"id": "knowledge45", "name": "지식 45의 학자", "stat": "damage", "levels": 6,
		"conds": [{"kind": "knowledge", "n": 45}]},
	{"id": "knowledge60", "name": "지식 60의 학자", "stat": "damage", "levels": 7,
		"conds": [{"kind": "knowledge", "n": 60}]},
	{"id": "knowledge80", "name": "지식 80의 학자", "stat": "damage", "levels": 8,
		"conds": [{"kind": "knowledge", "n": 80}]},
	{"id": "knowledge100", "name": "지식 100의 학자", "stat": "damage", "levels": 9,
		"conds": [{"kind": "knowledge", "n": 100}]},
	{"id": "knowledge130", "name": "지식 130의 학자", "stat": "damage", "levels": 10,
		"conds": [{"kind": "knowledge", "n": 130}]},
	{"id": "skills3", "name": "세 개의 손", "stat": "speed", "levels": 2,
		"conds": [{"kind": "skills", "n": 3}]},
	{"id": "skills6", "name": "6 개의 손", "stat": "speed", "levels": 3,
		"conds": [{"kind": "skills", "n": 6}]},
	{"id": "skills9", "name": "9 개의 손", "stat": "speed", "levels": 4,
		"conds": [{"kind": "skills", "n": 9}]},
	{"id": "skills12", "name": "열두 개의 손", "stat": "speed", "levels": 5,
		"conds": [{"kind": "skills", "n": 12}]},
	{"id": "skills14", "name": "14 개의 손", "stat": "speed", "levels": 7,
		"conds": [{"kind": "skills", "n": 14}]},
	{"id": "skills16", "name": "16 개의 손", "stat": "speed", "levels": 8,
		"conds": [{"kind": "skills", "n": 16}]},
	{"id": "skills18", "name": "18 개의 손", "stat": "speed", "levels": 9,
		"conds": [{"kind": "skills", "n": 18}]},
	{"id": "skills20", "name": "스무 개의 손", "stat": "speed", "levels": 10,
		"conds": [{"kind": "skills", "n": 20}]},
	{"id": "traits3", "name": "핏줄 3갈래", "stat": "critdmg", "levels": 2,
		"conds": [{"kind": "traits", "n": 3}]},
	{"id": "traits6", "name": "핏줄 6갈래", "stat": "critdmg", "levels": 3,
		"conds": [{"kind": "traits", "n": 6}]},
	{"id": "traits9", "name": "핏줄 9갈래", "stat": "critdmg", "levels": 4,
		"conds": [{"kind": "traits", "n": 9}]},
	{"id": "traits12", "name": "핏줄 12갈래", "stat": "critdmg", "levels": 5,
		"conds": [{"kind": "traits", "n": 12}]},
	{"id": "traits16", "name": "핏줄 16갈래", "stat": "critdmg", "levels": 7,
		"conds": [{"kind": "traits", "n": 16}]},
	{"id": "traits20", "name": "핏줄 20갈래", "stat": "critdmg", "levels": 8,
		"conds": [{"kind": "traits", "n": 20}]},
	{"id": "traits24", "name": "핏줄 24갈래", "stat": "critdmg", "levels": 9,
		"conds": [{"kind": "traits", "n": 24}]},
	{"id": "traits28", "name": "핏줄 28갈래", "stat": "critdmg", "levels": 10,
		"conds": [{"kind": "traits", "n": 28}]},
	{"id": "hero5", "name": "5레벨의 군주", "stat": "tough", "levels": 2,
		"conds": [{"kind": "hero", "n": 5}]},
	{"id": "hero10", "name": "10레벨의 군주", "stat": "tough", "levels": 3,
		"conds": [{"kind": "hero", "n": 10}]},
	{"id": "hero15", "name": "15레벨의 군주", "stat": "tough", "levels": 4,
		"conds": [{"kind": "hero", "n": 15}]},
	{"id": "hero25", "name": "25레벨의 군주", "stat": "tough", "levels": 5,
		"conds": [{"kind": "hero", "n": 25}]},
	{"id": "hero40", "name": "40레벨의 군주", "stat": "tough", "levels": 6,
		"conds": [{"kind": "hero", "n": 40}]},
	{"id": "hero60", "name": "60레벨의 군주", "stat": "tough", "levels": 7,
		"conds": [{"kind": "hero", "n": 60}]},
	{"id": "hero80", "name": "80레벨의 군주", "stat": "tough", "levels": 8,
		"conds": [{"kind": "hero", "n": 80}]},
	{"id": "hero100", "name": "100레벨의 군주", "stat": "tough", "levels": 9,
		"conds": [{"kind": "hero", "n": 100}]},
	{"id": "hero120", "name": "120레벨의 군주", "stat": "tough", "levels": 10,
		"conds": [{"kind": "hero", "n": 120}]},
	{"id": "pair0", "name": "깨어난 군주", "stat": "damage", "levels": 3,
		"conds": [{"kind": "stage", "n": 10}, {"kind": "kills", "n": 100}]},
	{"id": "pair1", "name": "피맛", "stat": "critdmg", "levels": 4,
		"conds": [{"kind": "kills", "n": 500}, {"kind": "species", "n": 5}]},
	{"id": "pair2", "name": "미궁의 문", "stat": "tough", "levels": 4,
		"conds": [{"kind": "floor", "n": 5}, {"kind": "stage", "n": 30}]},
	{"id": "pair3", "name": "선혈 학자", "stat": "damage", "levels": 6,
		"conds": [{"kind": "knowledge", "n": 10}, {"kind": "species", "n": 10}]},
	{"id": "pair4", "name": "여섯 개의 손", "stat": "speed", "levels": 4,
		"conds": [{"kind": "skills", "n": 6}, {"kind": "hero", "n": 10}]},
	{"id": "pair5", "name": "백 걸음", "stat": "damage", "levels": 6,
		"conds": [{"kind": "stage", "n": 100}, {"kind": "hero", "n": 25}]},
	{"id": "pair6", "name": "스무 층의 어둠", "stat": "tough", "levels": 6,
		"conds": [{"kind": "floor", "n": 20}, {"kind": "kills", "n": 3000}]},
	{"id": "pair7", "name": "핏줄 각성", "stat": "critdmg", "levels": 4,
		"conds": [{"kind": "traits", "n": 3}, {"kind": "floor", "n": 10}]},
	{"id": "pair8", "name": "이백 고지", "stat": "damage", "levels": 7,
		"conds": [{"kind": "stage", "n": 200}, {"kind": "knowledge", "n": 30}]},
	{"id": "pair9", "name": "학살자", "stat": "speed", "levels": 8,
		"conds": [{"kind": "kills", "n": 10000}, {"kind": "species", "n": 15}]},
	{"id": "pair10", "name": "혈맥의 주인", "stat": "tough", "levels": 8,
		"conds": [{"kind": "traits", "n": 12}, {"kind": "floor", "n": 60}]},
	{"id": "pair11", "name": "군림하는 왕", "stat": "damage", "levels": 10,
		"conds": [{"kind": "stage", "n": 450}, {"kind": "floor", "n": 80}]},
	{"id": "pair12", "name": "탐식", "stat": "critdmg", "levels": 7,
		"conds": [{"kind": "kills", "n": 30000}, {"kind": "traits", "n": 9}]},
	{"id": "pair13", "name": "불면", "stat": "speed", "levels": 7,
		"conds": [{"kind": "hero", "n": 40}, {"kind": "skills", "n": 12}]},
	{"id": "pair14", "name": "옛 이름", "stat": "damage", "levels": 9,
		"conds": [{"kind": "species", "n": 18}, {"kind": "knowledge", "n": 45}]},
	{"id": "pair15", "name": "깊은 곳의 것", "stat": "tough", "levels": 7,
		"conds": [{"kind": "floor", "n": 50}, {"kind": "hero", "n": 40}]},
	{"id": "pair16", "name": "피의 계보", "stat": "critdmg", "levels": 8,
		"conds": [{"kind": "traits", "n": 16}, {"kind": "knowledge", "n": 60}]},
	{"id": "pair17", "name": "삼백의 밤", "stat": "damage", "levels": 9,
		"conds": [{"kind": "stage", "n": 300}, {"kind": "floor", "n": 40}]},
	{"id": "pair18", "name": "끝의 문턱", "stat": "tough", "levels": 10,
		"conds": [{"kind": "stage", "n": 400}, {"kind": "traits", "n": 20}]},
	{"id": "pair19", "name": "모든 것을 본 자", "stat": "damage", "levels": 10,
		"conds": [{"kind": "species", "n": 22}, {"kind": "knowledge", "n": 100}]},
	{"id": "pair20", "name": "영원한 밤", "stat": "tough", "levels": 10,
		"conds": [{"kind": "stage", "n": 500}, {"kind": "hero", "n": 100}]},
	# ── 특별 칭호 (사장님 2026-08-18) — 새 축들의 기록에 상을 건다 ──────────
	{"id": "trial10", "name": "유적을 넘은 자", "stat": "damage", "levels": 5,
		"conds": [{"kind": "trial", "n": 10}]},
	{"id": "trial25", "name": "파수꾼의 공포", "stat": "damage", "levels": 8,
		"conds": [{"kind": "trial", "n": 25}]},
	{"id": "pets25", "name": "만물의 벗", "stat": "tough", "levels": 6,
		"conds": [{"kind": "pets", "n": 25}]},
	{"id": "chest10", "name": "천장을 부순 자", "stat": "tough", "levels": 5,
		"conds": [{"kind": "chest", "n": 10}]},
	{"id": "night24", "name": "불면의 군주", "stat": "speed", "levels": 5,
		"conds": [{"kind": "nights", "n": 24}]},
	{"id": "rebirth3", "name": "세 번 되살아난 왕", "stat": "damage", "levels": 7,
		"conds": [{"kind": "prestige", "n": 3}]},
]


static func title(id: String) -> Dictionary:
	for t in TITLES:
		if str(t["id"]) == id:
			return t
	return {}


# state 는 Main 이 만든 기록 스냅샷이다(Main._title_state) — 조건이 새 종류를
# 원하면 여기 kind 하나와 그 스냅샷 키 하나가 같이 늘어야 한다.
static func cond_met(cond: Dictionary, state: Dictionary) -> bool:
	var n := int(cond["n"])
	match str(cond["kind"]):
		"stage": return int(state.get("stage", 1)) > n
		"floor": return int(state.get("floor", 0)) >= n
		"hero": return int(state.get("hero", 1)) >= n
		"kills": return int(state.get("kills", 0)) >= n
		"species": return int(state.get("species", 0)) >= n
		"knowledge": return int(state.get("knowledge", 0)) >= n
		"skills": return int(state.get("skills", 0)) >= n
		"traits": return int(state.get("traits", 0)) >= n
		"trial": return int(state.get("trial", 0)) >= n
		"pets": return int(state.get("pets", 0)) >= n
		"chest": return int(state.get("chest", 0)) >= n
		"nights": return int(state.get("nights", 0)) >= n
		"prestige": return int(state.get("prestige", 0)) >= n
	return false


static func earned(id: String, state: Dictionary) -> bool:
	var t := title(id)
	if t.is_empty():
		return false
	for c in t["conds"]:
		if not cond_met(c, state):
			return false
	return true


# 딴 칭호(got)가 그 스탯에 주는 공짜 레벨 합.
# ── 수집 이정표 (MONETIZATION_PLAN 4-3) ────────────────────────────────────
# 칭호 하나하나는 이미 "공짜 스탯 레벨"이 보상이라, 거기에 소환권을 또 얹으면
# 이중이다. 대신 **몇 개를 모았는가**에 따로 상을 건다 — 칭호는 조건이 제각각이라
# 하나씩 보면 순서가 안 보이는데, 개수 이정표가 그 줄을 세워 준다.
# 칭호가 100개가 되면서 이정표도 다시 폈다(사장님 2026-08-18). 넷은 앞쪽에
# 몰려 있어서 10개를 딴 뒤로는 **더 모을 이유가 없었다** — 100개까지 계단을
# 세운다. 뒤로 갈수록 뭉치가 커지되 개수는 성기게: 촘촘하면 이정표가 일상이 되고
# 그러면 이정표가 아니다.
const MILESTONES := [
	{"n": 3, "reward": "ticket_weapon", "amount": 10},
	{"n": 5, "reward": "ticket_armor", "amount": 10},
	{"n": 8, "reward": "ticket_trinket", "amount": 20},
	{"n": 12, "reward": "ticket_skill", "amount": 20},
	{"n": 18, "reward": "ticket_weapon", "amount": 30},
	{"n": 25, "reward": "ticket_armor", "amount": 30},
	{"n": 35, "reward": "ticket_trinket", "amount": 40},
	{"n": 45, "reward": "ticket_skill", "amount": 40},
	{"n": 60, "reward": "gem", "amount": 600},
	{"n": 75, "reward": "ticket_skill", "amount": 60},
	{"n": 90, "reward": "gem", "amount": 1000},
	{"n": 100, "reward": "ticket_skill", "amount": 100},
]


# 지금 개수로 받을 수 있는 이정표 번호들 (아직 안 받은 것만).
static func claimable_milestones(count: int, got: Dictionary) -> Array:
	var out: Array = []
	for i in MILESTONES.size():
		if count >= int(MILESTONES[i]["n"]) and not got.has(i):
			out.append(i)
	return out


static func bonus(stat: String, got: Dictionary) -> int:
	var out := 0
	for t in TITLES:
		if str(t["stat"]) == stat and got.has(str(t["id"])):
			out += int(t["levels"])
	return out


static func cond_text(cond: Dictionary) -> String:
	var n := int(cond["n"])
	match str(cond["kind"]):
		"stage": return "%d구간 돌파" % n
		"floor": return "미궁 %d층" % n
		# "Lv" 금지 — 블랙레터 폰트에서 "LD" 로 읽힌다(Main 3318줄의 그 함정).
		"hero": return "영웅 %d레벨" % n
		"kills": return "처치 %s" % ("%d" % n if n < 1000 else "%.0fK" % (n / 1000.0))
		"species": return "도감 %d종" % n
		"knowledge": return "지식 %d" % n
		"skills": return "스킬 %d종" % n
		"traits": return "혈맥 %d노드" % n
		"trial": return "시련 %d단계" % n
		"pets": return "펫 %d종" % n
		"chest": return "천장 상자 %d회" % n
		"nights": return "함께한 밤 %d시간" % n
		"prestige": return "회귀 %d회" % n
	return ""


static func stat_name(stat: String) -> String:
	match stat:
		"damage": return "공격력"
		"speed": return "공격속도"
		"tough": return "체력"
		"gold": return "흡혈량"
	return stat
