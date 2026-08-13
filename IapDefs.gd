class_name IapDefs

# 과금 상품 (MONETIZATION_PLAN 5장). **결제 SDK 는 아직 없다** — 표와 진열
# 화면까지 만들고 구매 버튼은 잠가 둔다(사장님 결정). SDK 가 붙으면 _buy 훅
# 하나만 이어면 되도록, 지급 내용을 여기 데이터로 적어 둔다.
#
# 원칙 셋(설계서 5-1)이 이 표를 지배한다:
#   1. **시간을 판다, 힘을 팔지 않는다** — 무과금이 못 하는 것은 안 판다
#   2. **확률을 팔지 않는다** — 소환 확률표는 결제로 안 바뀐다. 파는 건 장수다
#   3. **격리를 깨지 않는다** — 재화는 상점 한도 안에서만 바뀐다
#
# 값은 한국 모바일 표준 가격대다. reward 는 Main._grant_reward 가 아는 이름이고
# 소환권은 TicketDefs 의 "ticket_<종류>" 를 쓴다.

# ── 정기(구독) ──────────────────────────────────────────────────────────────
# 혈세: 이 게임의 기둥 상품. 매일 접속해야 받는 구조라 "돌아올 이유"가 붙는다.
# 패스: 이미 하는 행동(임무)에 얹으므로 새 그라인드를 안 만든다.
#
# value 는 진열용 "가치 %" 배지(레퍼런스 문법). 보석 1 ≈ 10원(11000원=1100)과
# 소환 1회 = 보석 30 으로 어림한 값이다 — 정밀 환산이 아니라 **상대 순서**가
# 목적이다: 구독 > 후반 팩 > 초반 팩.
const SUBS := [
	{"id": "blood_tax", "name": "혈세", "days": 30, "price": 11000, "value": 600,
		"desc": "매일 보석 100 · 소환권 3\n방치 +4시간 · 던전 +1판 · 광고 제거",
		"instant": {"gem": 1000.0},
		"daily": {"gem": 100.0, "ticket_weapon": 1.0, "ticket_armor": 1.0,
			"ticket_skill": 1.0}},
	{"id": "season_pass", "name": "성장 패스", "days": 28, "price": 16000,
		"value": 400,
		"desc": "임무를 채우면 30단계까지\n단계마다 소환권 · 혈정 · 보석",
		"instant": {"gem": 300.0},
		"daily": {}},
]

# ── 성장 패키지 (1회성) ─────────────────────────────────────────────────────
# **벽 직전에 열린다** — 못 넘는 자리에서 파는 건 구제가 아니라 통행료로 읽힌다.
# open 은 그 구간을 넘긴 적이 있어야 보인다는 뜻이다(best_stage 기준).
const PACKS := [
	{"id": "first_step", "name": "첫 걸음", "open": 1, "price": 3300, "value": 180,
		"reward": {"gem": 300.0, "ticket_weapon": 5.0, "ticket_armor": 5.0}},
	{"id": "cave", "name": "동굴 개방", "open": 25, "price": 3300, "value": 180,
		"reward": {"gold": 0.0, "gem": 300.0, "ticket_trinket": 10.0}},
	{"id": "maze", "name": "미궁 개방", "open": 35, "price": 11000, "value": 200,
		"reward": {"crystal": 2000.0, "ticket_skill": 20.0}},
	{"id": "sanctum", "name": "성소 개방", "open": 50, "price": 11000, "value": 200,
		"reward": {"essence": 800.0, "ticket_weapon": 20.0}},
	{"id": "altar", "name": "제단 개방", "open": 80, "price": 33000, "value": 220,
		"reward": {"sigil": 1200.0, "ticket_armor": 20.0, "ticket_trinket": 20.0}},
]

# ── 보석 충전 ───────────────────────────────────────────────────────────────
# 첫 구매 x2 는 **한 번뿐**이다 — 상시 배수는 정가를 거짓말로 만든다.
const GEMS := [
	{"id": "gem_s", "price": 3300, "gem": 300},
	{"id": "gem_m", "price": 11000, "gem": 1100},
	{"id": "gem_l", "price": 33000, "gem": 3500},
	{"id": "gem_xl", "price": 99000, "gem": 11000},
]

const FIRST_BUY_MULT := 2.0


static func sub_of(id: String) -> Dictionary:
	for x in SUBS:
		if str(x["id"]) == id:
			return x
	return {}


static func pack_of(id: String) -> Dictionary:
	for x in PACKS:
		if str(x["id"]) == id:
			return x
	return {}


# 그 구간에서 살 수 있는 패키지들. 벽 직전에 하나씩 열린다.
static func open_packs(best_stage: int) -> Array:
	var out: Array = []
	for x in PACKS:
		if best_stage >= int(x["open"]):
			out.append(x)
	return out


static func price_text(won: int) -> String:
	return "%s원" % _comma(won)


static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
