class_name DungeonDefs
extends RefCounted
# =====================================================================
#  핏빛 미궁 — 타워형 던전 (EXPANSION.md 7장, 1단계)
#
#  본편(스테이지)과 분리된 층 등반. 전투·몹·보스는 전부 본편 것을 빌린다 —
#  층을 본편의 등가 구간으로 사상(eq_stage)하고, 몹 곡선·로스터·이름을 그
#  구간에서 그대로 읽는다. **미궁 전용 곡선을 따로 적지 않는 이유**: 본편
#  곡선을 고칠 때(EXPANSION 8장의 조정이 예정돼 있다) 여기가 조용히 낡는다.
#
#  보상(혈정)은 2단계에서 붙는다. 지금 층 클리어가 남기는 것은 기록(dungeon_best)
#  하나이고, 그 기록이 3단계 혈맥의 열쇠가 된다.
# =====================================================================

const FLOOR_CAP := 100
# 30 -> 35 (2026-08-12). 해금 계단의 두 번째 칸이다: 25 에 열린 혈액의 동굴로
# 첫 벽(30 부근)을 한 번 밀고 나서야 미궁이 보인다 — 한꺼번에 열리면 어디부터
# 손대야 할지 못 고른다(RaidDefs.OPEN_STAGE 주석의 그 계단).
const OPEN_STAGE := 35          # 본편 35구간을 넘어야 미궁이 열린다
const KILLS_PER_FLOOR := 5      # (옛 규칙 — 지금은 층마다 보스 하나다)
# 미궁 보스 체력 배수 보정. FoeTiers.BOSS_HP_MULT(35) x 이 값이 실제 무게다:
# 35 x 0.25 = 8.75 = 옛 일반 층(잡몹 5마리)의 1.75배. 층이 보스전이 됐으니
# 조금 더 무겁되, 그대로 두면 일곱 배라 벽이 된다(2026-08-25).
const BOSS_HP_SCALE := 0.25
# 층당 등가 구간 보폭. **총 구간이 500 이 되면서 8 은 역전을 만들었다** —
# 30층이 이미 267구간 난이도라 본편(256)보다 어려워서 미궁이 안 올라가고,
# 미궁이 여는 훈련 상한도 같이 멈춘다. 그러면 혈액이 쓸 곳을 잃는다
# (실측: 90일차 잉여 891경). 5 면 100층 = 본편 530 -> 끝과 나란히 선다.
const EQ_STEP := 5


# 층 -> 본편 등가 구간. 몹 체력·피해·로스터가 전부 이 구간 것이다.
static func eq_stage(floor: int) -> int:
	return mini(StageDefs.total_stages(),
		OPEN_STAGE + (maxi(1, floor) - 1) * EQ_STEP)


# **미궁은 층마다 보스다** (사장님 2026-08-25: "미궁 6마리만 잡으면 끝인데
# 보스 돌아가면서 잡는거면 좋겠어"). 잡몹 다섯을 치우는 층은 본편과 구별이
# 안 됐다 — 한 층 = 한 보스여야 "탑을 오른다"가 된다. 얼굴은 막을 돌아가며
# 바뀐다(Main._c_act_data 가 층으로 막을 고른다).
static func is_boss_floor(_floor: int) -> bool:
	return true


static func is_midboss_floor(_floor: int) -> bool:
	return false


static func kills_needed(_floor: int) -> int:
	return 1


# 층마다 보스전이니 제한 시간도 늘 걸린다.
static func time_limit(_floor: int) -> float:
	return StageDefs.TIME_BOSS


# 본편 최고 기록이 미궁을 몇 층까지 여는가 (EXPANSION 7장의 교차 잠금).
# OPEN_STAGE(35)에 5층, 이후 본편 10구간마다 5층씩. **225구간**이면 100층 전부
# (220 은 95층이다 — 옛 주석이 OPEN_STAGE 30 시절 값을 들고 있었다).
# 다만 층이 열리는 것과 뚫는 것은 다르다: 100층의 등가 구간은 본편 끝(500)이고
# 보스 체력이 일반몹의 8.75배라, 실제 게이트는 개방이 아니라 화력이다.
static func open_floors(best_stage: int) -> int:
	if best_stage < OPEN_STAGE:
		return 0
	return mini(FLOOR_CAP, 5 + (best_stage - OPEN_STAGE) / 10 * 5)


static func label(floor: int) -> String:
	return "미궁 %d층" % maxi(1, floor)


# ── 혈정 수급 (EXPANSION 6장 초안 그대로) ──────────────────────────────────
# 첫 돌파: 10 x 층수 — 100층 전부 돌면 누적 50,500. 혈맥(3단계) 완주 비용을
# 이 값의 1.5배로 잡아 "첫 돌파로 절반, 나머지는 방치 며칠"이 나오게 한다.
static func first_clear_reward(floor: int) -> float:
	return 10.0 * float(maxi(1, floor))


# 소탕: 시간당 최고층 x 0.2 — 50층이면 10/h, 하루 240. 어디에 있든 쌓인다
# (미궁 최고 기록이 곧 광산이다). 값을 바꾸면 위 완주 기간 계산도 다시 한다.
static func sweep_per_hour(best_floor: int) -> float:
	return 0.2 * float(maxi(0, best_floor))


# ── 미궁 보스 얼굴 (사장님 2026-08-26: "미궁 6층부터 얼굴이 반복된다") ────
# 예전엔 **막(ACT) 5개를 돌렸다** — 100층이면 같은 다섯을 20바퀴다.
# 새 아트는 한 장도 안 뽑았다: `_special`(보스 예고 동작)이 있는 몹이 이미
# 서른 종인데 미궁이 그중 다섯만 쓰고 있었다. 나머지는 잡몹으로만 나왔다.
# 보스로 세우면 Foe._size() 가 알아서 2배로 키운다(BOSS_BODY) — 크기 문제 없음.
#
# 뺀 것: 성소의 수호자(제련의 성소 전용) · 역병의 산파·뼈의 합창단·피의 여왕·
# 잊힌 도살자(주간 보스 4종) · 유적의 파수꾼(시련). 콘텐츠마다 얼굴이 갈려야
# "저기 가면 저 놈"이 성립한다.
#
# **5층마다 막 보스(boss_1~5)를 세운다.** 전용 대형 아트라 그 층이 사건으로
# 읽힌다 — 나머지는 잡몹 승격이라 결이 한 단계 낮다.
const MAZE_BOSSES := [
	["slime", "삼킨 늪", "slime"],
	["goblin", "고블린 두목", "goblin"],
	["bat", "밤의 무리", "bat"],
	["mushroom", "홀씨 어미", "mushroom"],
	["wraith_knight", "망령 기사", "boss_1"],
	["zombie", "썩지 않는 자", "zombie"],
	["skeleton", "뼈무덤 지기", "skeleton"],
	["ghoul", "굶주린 구울", "ghoul"],
	["fire_imp", "잿불 임프", "fire_imp"],
	["gargoyle", "가고일 군주", "boss_2"],
	["lava_toad", "용암의 아가리", "lava_toad"],
	["orc", "오크 대장", "orc"],
	["hellhound", "지옥의 사냥개", "hellhound"],
	["frost_spider", "서리 여왕거미", "frost_spider"],
	["frost_golem", "프로스트 골렘", "boss_3"],
	["ice_wisp", "얼어붙은 혼불", "ice_wisp"],
	["demon", "데몬 장군", "demon"],
	["cultist", "광신도 사제", "cultist"],
	["void_wraith", "공허의 망령", "void_wraith"],
	["eye_mass", "눈알 덩어리", "boss_4"],
	["dark_knight", "다크 나이트", "boss_5"],
]

# **얼굴은 장식이고 세기는 층이 정한다.** 몹마다 hp_mult 가 1.0~3.8 이라
# 그대로 쓰면 층마다 체력이 3.8배씩 널뛴다 — 슬라임 층 다음에 다크 나이트 층이
# 오면 그건 난이도가 아니라 제비뽑기다. 값은 옛 막 보스 다섯의 평균
# (3.4+2.6+3.2+3.0+3.8)/5 = 3.2 라 이번 변경으로 난이도가 안 움직인다.
const MAZE_BOSS_HP := 3.2


static func boss_of(floor: int) -> Dictionary:
	var row: Array = MAZE_BOSSES[(maxi(1, floor) - 1) % MAZE_BOSSES.size()]
	return {"key": str(row[0]), "name": str(row[1]), "anim": str(row[2])}


# 깊이 색 — 깊을수록 어둡고 붉게. 몹에 씌운다(modulate). 배경을 새로 뽑지 않고
# "깊어졌다"를 읽히는 가장 싼 수단이다. 끝(100층)도 0.78 까지만 — 더 어두우면
# 체력 바·피해 숫자와 대비가 죽는다.
static func depth_tint(floor: int) -> Color:
	var t := clampf(float(floor) / float(FLOOR_CAP), 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(Color(0.78, 0.60, 0.64), t)
