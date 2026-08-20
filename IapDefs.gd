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
		"art": "gem_chest",
		"desc": "매일 보석 100 · 소환권 3\n방치 +4시간 · 던전 +1판 · 광고 제거",
		"instant": {"gem": 1000.0},
		"daily": {"gem": 100.0, "ticket_weapon": 1.0, "ticket_armor": 1.0,
			"ticket_skill": 1.0}},
	# 소환 정기권 (2026-08-20, 사장님). 혈세는 보석 위주라 **소환권을 직접 파는
	# 자리가 없었다** — 보석은 상점으로도 새므로 "소환을 더 돌고 싶다"는 욕구에
	# 정확히 대응하는 상품이 아니다. 여섯 갈래 각 1장이라 어느 갈래도 안 굶는다.
	# 확률을 안 판다는 원칙(5-1의 2)은 그대로다 — 파는 것은 **장수**다.
	{"id": "summon_pass", "name": "소환 정기권", "days": 30, "price": 8800,
		"value": 500,
		"art": "gem_pouch",
		"desc": "매일 소환권 6장 (여섯 갈래 각 1)\n첫 구매에 20장 즉시",
		"instant": {"ticket_weapon": 5.0, "ticket_armor": 5.0,
			"ticket_trinket": 5.0, "ticket_skill": 5.0},
		"daily": {"ticket_weapon": 1.0, "ticket_armor": 1.0,
			"ticket_trinket": 1.0, "ticket_skill": 1.0,
			"ticket_pet": 1.0, "ticket_petgear": 1.0}},
	{"id": "season_pass", "name": "성장 패스", "days": 28, "price": 16000,
		"value": 400, "art": "badge_star",
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
	# 핏빛 계약 팩 3종 (2026-08-18) — 파는 것은 **운을 굴릴 기회**다.
	{"id": "oath_s", "name": "계약 입문", "open": 10, "price": 3300, "value": 180,
		"reward": {"oath_card": 5.0}},
	{"id": "oath_m", "name": "계약 도약", "open": 30, "price": 11000, "value": 200,
		"reward": {"oath_card": 10.0, "oath_gold": 3.0}},
	{"id": "oath_l", "name": "군주의 계약", "open": 60, "price": 33000, "value": 220,
		"reward": {"oath_gold": 10.0, "oath_card": 20.0}},
]

# ── 한정 특가 (2026-08-20, 사장님) ─────────────────────────────────────────
# 성장팩은 **구간 도달**로만 열려서 "지금 사야 할 이유"가 없었다 — 어제 살 수
# 있던 것을 내일도 살 수 있으면 그건 진열이지 특가가 아니다.
#
# **하루에 하나만 돌린다.** 상시 세일로 보이면 정가가 거짓말이 되므로, 날짜로
# 하나를 골라 그날 자정까지만 판다. 고르는 자가 날짜라 서버가 필요 없다.
# 파는 것은 여전히 시간이다 — 여기 어느 줄에도 무과금이 못 얻는 물건은 없다.
const LIMITED := [
	{"id": "ltd_summon", "name": "오늘의 소환 특가", "price": 3300, "value": 320,
		"desc": "소환권 16장",
		"reward": {"ticket_weapon": 4.0, "ticket_armor": 4.0,
			"ticket_trinket": 4.0, "ticket_skill": 4.0}},
	{"id": "ltd_pet", "name": "오늘의 동행 특가", "price": 3300, "value": 320,
		"desc": "펫 소환권 8장 · 먹이 400",
		"reward": {"ticket_pet": 4.0, "ticket_petgear": 4.0, "feed": 400.0}},
	{"id": "ltd_gem", "name": "오늘의 보석 특가", "price": 3300, "value": 350,
		"desc": "보석 500 · 소환권 6장",
		"reward": {"gem": 500.0, "ticket_skill": 6.0}},
	{"id": "ltd_maze", "name": "오늘의 미궁 특가", "price": 3300, "value": 320,
		"desc": "혈정 1500 · 정수 300",
		"reward": {"crystal": 1500.0, "essence": 300.0}},
	{"id": "ltd_oath", "name": "오늘의 계약 특가", "price": 3300, "value": 320,
		"desc": "계약 카드 6장 · 황금 계약 2장",
		"reward": {"oath_card": 6.0, "oath_gold": 2.0}},
]


# 오늘의 특가. 날짜 문자열을 열쇠로 쓴다 — 다른 하루 판정(상점 한도·던전 표)이
# 전부 날짜 문자열이라 규칙을 맞춘다. 하루가 넘어가면 저절로 다음 것이 온다.
static func limited_today(date: String) -> Dictionary:
	if LIMITED.is_empty():
		return {}
	var n := 0
	for c in date:
		n += c.unicode_at(0)
	return LIMITED[n % LIMITED.size()]


static func limited_of(id: String) -> Dictionary:
	for x in LIMITED:
		if str(x["id"]) == id:
			return x
	return {}


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


# ── 구독 상태 ───────────────────────────────────────────────────────────────
# 만료일은 **날짜 문자열**로 둔다(Time.get_date_string_from_system 과 같은 꼴).
# 초 단위 타임스탬프를 쓰면 기기 시계 오차로 하루가 들쭉날쭉해진다 — 다른 하루
# 판정(무료 뽑기·상점 한도·던전 표)이 전부 날짜 문자열이라 규칙을 맞춘다.
static func expiry_date(days: int) -> String:
	var t := Time.get_unix_time_from_system() + float(days) * 86400.0
	return Time.get_date_string_from_unix_time(int(t))


# 오늘이 만료일 **이전**이면 살아 있다. 문자열 비교로 충분하다(ISO 꼴이라
# 사전순 = 시간순). 만료일 당일까지 준다 — 산 날부터 days 일이 온전히 남는다.
static func sub_active(subs: Dictionary, id: String) -> bool:
	var until := str(subs.get(id, ""))
	return until != "" and Time.get_date_string_from_system() <= until


# 상시 효과 셋(설계서 5-2). 어느 구독이 주는지는 여기 한 곳만 안다.
static func idle_bonus_hours(subs: Dictionary) -> float:
	return 4.0 if sub_active(subs, "blood_tax") else 0.0


static func raid_bonus_tries(subs: Dictionary) -> int:
	return 1 if sub_active(subs, "blood_tax") else 0


static func ads_removed(subs: Dictionary) -> bool:
	return sub_active(subs, "blood_tax")


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
