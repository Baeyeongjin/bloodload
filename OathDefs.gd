class_name OathDefs
# 핏빛 계약 — 운빨 돌파 시스템 (docs/OATH_DESIGN.md, 사장님 확정 2026-08-18).
# 탭 한 번에 룰렛 세 번(등급→계약→각인), 천장 100/30, 피의 서약, 공명, 진혈.
# 이름이 PactDefs(혈맹)와 다른 이유: 같은 "계약"이라도 축이 완전히 다르다.


const CHARGE_MIN := 40.0     # 자연 충전 — 40분에 1장
const CARD_CAP := 3          # 보관 상한(멤버십 +2 는 IapDefs 쪽에서)
const PITY_LEGEND := 100     # 일반 천장 — 만월은 드물어야 극적이다(사장님)
const PITY_GOLD := 30        # 황금 계약서 천장 (제안값)
const TRUEBLOOD := 0.001     # 진혈 0.1% — 무과금도 같은 확률(잭팟 목격담이 광고다)
const VOW_RATE := 0.10       # 피의 서약 — 혈액 보유량의 10%를 건다
const RESONANCE_MULT := 1.5  # 공명 — 같은 등급 연속 2회
const LV_MAX := 5            # 계약 레벨(중복 수집) 상한
const LV_STEP := 0.15        # 레벨당 주효과 +15%p (계수)
const RECHARGE_GEM := 30.0   # 즉시 충전
const REROLL_GEM := 10.0     # 다시 굴리기
const GOLD_GEM := 60.0       # 황금 계약서 1장

# 계약 12종 — effects 의 키가 Main 의 훅과 1:1 이다:
#   attack 공격배수+ · speed 공속+ · armor 받는피해- · regen 회복배수+ ·
#   regen_max 초당 최대체력% 회복 · leech 흡혈량(혈액)+ · crit 치명확률 레벨+ ·
#   cleave 평타 광역 · time 제한시간+초 · exec 처형 문턱+ ·
#   devour 보스 체력 % 즉시 흡수(즉발)
const CONTRACTS := [
	{"id": "thirst", "name": "갈증의 피", "rarity": "common",
		"effects": {"attack": 0.30}, "dur": 60.0},
	{"id": "stride", "name": "밤의 보폭", "rarity": "common",
		"effects": {"speed": 0.25}, "dur": 60.0},
	{"id": "hide", "name": "여물지 않은 갑피", "rarity": "common",
		"effects": {"armor": 0.25}, "dur": 60.0},
	{"id": "skin", "name": "굳은 살가죽", "rarity": "uncommon",
		"effects": {"armor": 0.35, "regen": 1.0}, "dur": 60.0},
	{"id": "redthirst", "name": "붉은 갈증", "rarity": "uncommon",
		"effects": {"leech": 1.0}, "dur": 60.0},
	{"id": "instinct", "name": "사냥꾼의 직감", "rarity": "uncommon",
		"effects": {"crit": 25.0}, "dur": 60.0},
	{"id": "frenzy", "name": "피의 광란", "rarity": "rare",
		"effects": {"attack": 0.60, "speed": 0.30}, "dur": 45.0},
	{"id": "batstorm", "name": "박쥐 폭풍", "rarity": "rare",
		"effects": {"cleave": 1.0}, "dur": 45.0},
	{"id": "veil", "name": "핏빛 장막", "rarity": "rare",
		"effects": {"armor": 0.60, "regen_max": 0.05}, "dur": 45.0},
	{"id": "clot", "name": "응혈의 시간", "rarity": "epic",
		"effects": {"time": 20.0, "attack": 0.40}, "dur": 45.0},
	{"id": "throne", "name": "왕좌의 명령", "rarity": "epic",
		"effects": {"exec": 0.20}, "dur": 60.0},
	{"id": "lord", "name": "군주의 갈증", "rarity": "legend",
		"effects": {"devour": 0.40}, "dur": 0.0},
]

# 진혈 — 표 밖의 숨은 등급. 즉시 처형 + 카드 3장 환급.
const TRUEBLOOD_CONTRACT := {"id": "trueblood", "name": "진혈 계약",
	"rarity": "trueblood", "effects": {"devour": 1.0}, "dur": 0.0,
	"refund": 3}

# 각인 6종 — kind 를 Main 이 해석한다.
const ENGRAVES := [
	{"id": "long", "name": "오래 가는 피", "kind": "dur", "v": 0.20},
	{"id": "thick", "name": "짙은 피", "kind": "amp", "v": 0.15},
	{"id": "return", "name": "되돌아오는 피", "kind": "refund", "v": 0.10},
	{"id": "vowguard", "name": "서약의 가호", "kind": "vow_back", "v": 0.50},
	{"id": "echo", "name": "공명하는 피", "kind": "resonance", "v": 0.20},
	{"id": "knock", "name": "천장을 두드리는 피", "kind": "pity2", "v": 1.0},
]


# ── 계약의 서 (미니 패스, 과금 6접점) ─────────────────────────────────────
# **카드를 쓴 횟수**로 찬다 — 굴릴수록 차오르니 굴릴 이유가 하나 더 는다.
# 무료 줄은 카드·보석, 유료 줄은 황금·카드 뭉치. 성장 패스와 같은 30칸.
const BOOK_STEPS := 30
const BOOK_PER_STEP := 3     # 3번 굴리면 한 칸


static func book_step(used: int) -> int:
	return clampi(used / BOOK_PER_STEP, 0, BOOK_STEPS)


static func book_free(step: int) -> Dictionary:
	if step % 10 == 0:
		return {"kind": "oath_gold", "amount": 1.0}
	if step % 3 == 0:
		return {"kind": "oath_card", "amount": 1.0}
	return {"kind": "gem", "amount": 20.0}


static func book_paid(step: int) -> Dictionary:
	if step % 10 == 0:
		return {"kind": "oath_gold", "amount": 4.0}
	if step % 3 == 0:
		return {"kind": "oath_card", "amount": 3.0}
	return {"kind": "gem", "amount": 70.0}


# ── 멤버십(혈세) 연동 — 값을 아는 곳은 여기 하나다 ────────────────────────
static func charge_min(member: bool) -> float:
	return 30.0 if member else CHARGE_MIN


static func card_cap(member: bool) -> int:
	return CARD_CAP + (2 if member else 0)


const MEMBER_WEEKLY_GOLD := 3


# 카드 앞면 — 계약마다 한 장(2026-08-18 사장님: "카드 디자인도 다 하나씩").
# 파일명 규약이라 표가 아니라 디스크가 진실이다(OathCheck 이 실존을 본다).
static func card_face(id: String) -> String:
	return "res://assets/cards/oc_%s.png" % id


static func of(id: String) -> Dictionary:
	if id == "trueblood":
		return TRUEBLOOD_CONTRACT
	for c in CONTRACTS:
		if str(c["id"]) == id:
			return c
	return {}


static func of_rarity(rarity: String) -> Array:
	var out := []
	for c in CONTRACTS:
		if str(c["rarity"]) == rarity:
			out.append(c)
	return out


static func engrave(id: String) -> Dictionary:
	for e in ENGRAVES:
		if str(e["id"]) == id:
			return e
	return {}


# 계약 레벨 배수 — 중복 수집이 카드를 키운다. **쓸 때만** 적용되므로 영구
# 전투력(곡선)을 오염시키지 않는다.
static func lv_mult(lv: int) -> float:
	return 1.0 + LV_STEP * float(clampi(lv, 1, LV_MAX) - 1)
