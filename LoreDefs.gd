class_name LoreDefs

# 도감의 나머지 셋 — **장비 · 스킬 · 연대기**.
#
# 몬스터 도감(FoeTiers)은 잡은 수가 지식이 되는데, 이 셋은 **본 적 있는가**만
# 센다. 장비는 갈아 끼우면 사라지고 스킬은 장착이 다섯 칸뿐이라, "지금 가진 것"
# 으로 세면 모을수록 줄어드는 이상한 표가 된다.
#
# 왜 붙이나: 소환은 이미 도는 루프인데 **더 센 게 나오면 갈아 끼우고 끝**이라
# 목적이 하나뿐이었다. 도감이 있으면 "아직 안 나온 것"이 생긴다 — 새 그라인드를
# 만들지 않고 이미 하는 행동에 목적을 하나 더 얹는 자리다(QuestDefs 와 같은 원칙).
#
# 보상은 **작게** 잡았다. 성장 축 여덟이 이미 곡선을 채우고 있어서, 여기서 크게
# 주면 방금 맞춘 페이스가 흔들린다. 수집의 값은 배율이 아니라 "칸이 찬다"는 것이다.

# 칸을 몇 개 채우면 무엇을 주는가. need 는 **모은 종수**다.
# 장비 72종 · 스킬 20종 — 종수가 달라서 이정표도 따로 둔다.
const GEAR_MARKS := [
	{"need": 10, "stat": "damage", "rate": 0.02},
	{"need": 24, "stat": "hp", "rate": 0.03},
	{"need": 40, "stat": "damage", "rate": 0.03},
	{"need": 56, "stat": "crit", "rate": 0.05},
	{"need": 72, "stat": "damage", "rate": 0.05},
]

const SKILL_MARKS := [
	{"need": 5, "stat": "damage", "rate": 0.02},
	{"need": 10, "stat": "hp", "rate": 0.03},
	{"need": 15, "stat": "damage", "rate": 0.03},
	{"need": 20, "stat": "damage", "rate": 0.05},
]

# 연대기는 막을 **밟기만 하면** 열린다 — 기록이지 수집이 아니다.
#
# 막마다 작은 영구 보너스를 준다(사장님 2026-08-18: 소탭마다 무엇을 주는지
# 보여야 한다). **밟으면 자동이라 읽지 않아도 받는다** — 읽을거리에 조건을
# 걸면 안 읽는 사람이 벌을 받는다. 값이 작은 건 다섯 막뿐이라서다.
const ACT_RATE := 0.02        # 막 하나당 공격
const ACT_HP_RATE := 0.02     # 막 하나당 체력
const CHRONICLE := [
	"무덤이 먼저 깨어났다. 흙을 밀고 나온 것들은 아직 제 이름을 기억했다.",
	"언덕은 오래 탔다. 재 아래에서 뿔이 자라고, 불은 주인을 골랐다.",
	"얼음은 소리를 삼킨다. 여기서 죽은 것들은 비명을 남기지 못했다.",
	"성은 비어 있지 않았다. 벽이 숨을 쉬고, 계단은 밤마다 수를 바꿨다.",
	"가장 깊은 곳에 앉은 것은 왕이 아니었다. 왕좌가 그를 붙들고 있었다.",
]


static func gear_total() -> int:
	var n := 0
	for slot in GearDefs.SLOTS:
		for r in GearDefs.RARITY:
			n += GearDefs.items_of(str(slot), str(r["key"])).size()
	return n


static func skill_total() -> int:
	return SkillDefs.all_keys().size()


# 모은 종수에 따라 붙는 배율 몫. FoeTiers.codex_bonus 와 같은 꼴이라
# 부르는 쪽이 문법을 새로 배울 게 없다.
static func bonus(marks: Array, got: int, stat: String) -> float:
	var sum := 0.0
	for m in marks:
		if got >= int(m["need"]) and str(m["stat"]) == stat:
			sum += float(m["rate"])
	return sum


# 장비 + 스킬 도감이 그 능력치에 주는 합.
static func total_bonus(gear_got: int, skill_got: int, stat: String) -> float:
	return bonus(GEAR_MARKS, gear_got, stat) + bonus(SKILL_MARKS, skill_got, stat)


# 다음 이정표까지 몇 개 남았나 — 판에 "3종 더"로 적는다. 다 채웠으면 0.
static func to_next(marks: Array, got: int) -> int:
	for m in marks:
		if got < int(m["need"]):
			return int(m["need"]) - got
	return 0


# 밟은 막 수가 주는 몫. reached 는 0-기반 막 번호다(StageDefs.act_of).
static func act_bonus(reached: int, stat: String) -> float:
	var n := clampi(reached + 1, 0, CHRONICLE.size())
	if stat == "damage":
		return ACT_RATE * float(n)
	if stat == "hp":
		return ACT_HP_RATE * float(n)
	return 0.0


static func act_text(index: int) -> String:
	return str(CHRONICLE[index]) if index >= 0 and index < CHRONICLE.size() else ""
