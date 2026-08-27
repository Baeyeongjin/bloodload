class_name PassDefs

# 성장 패스 (MONETIZATION_PLAN 5장, IapDefs 의 "season_pass").
#
# **이미 하는 행동에 얹는다** — 새 그라인드를 안 만드는 게 이 상품의 설계
# 원칙이다(5-1). 점수는 임무를 채울 때만 들어온다: 패스를 샀다고 따로 할 일이
# 생기지 않고, 안 샀어도 무료 줄은 그대로 받는다.
#
# 줄이 둘인 이유: **무료 줄이 없으면 패스는 그냥 보상 상자**다. 무과금도 같은
# 트랙을 오르되 받는 것이 적어야, 사는 사람은 "더 받는다"를 사고 안 사는
# 사람은 "손해 본다"가 아니라 "덜 받는다"가 된다.
# **시즌제**(2026-08-20, 사장님). 28일이 지나면 트랙이 새로 열린다 — 한 번
# 다 오르면 끝인 패스는 그 뒤로 살 이유가 없고, 안 산 사람에게도 "다음 판이
# 온다"가 복귀 이유가 된다. 시즌 번호는 **날짜에서 계산한다**: 서버가 없으니
# 기준일부터 몇 번째 28일 구간인지로 센다. 시즌이 바뀌면 점수가 0 으로 돌아가고
# 받은 칸도 비워진다(Main._pass_roll_season).
const SEASON_DAYS := 28
const SEASON_EPOCH := "2026-08-25"      # 첫 시즌 시작(월요일)

const STEPS := 30
# 일일 임무 하나 = 10점, 주간 하나 = 40점, 출석도 일일과 같은 10점이다.
#
# **예산은 임무 표에서 나온다 — 여기 숫자를 박으면 표가 늘 때 조용히 갈린다.**
# 옛 주석은 "일일 5종 · 주간 4종 = 2040점" 이었는데 실제 표는 일일 12종 ·
# 주간 9종이고 출석은 아예 빠져 있었다. 다시 세면(2026-08-27 실측):
#
#   일일 12종 x 10점 x 28일 = 3,360
#   주간  9종 x 40점 x  4주 = 1,440
#   출석      28일 x 10점   =   280
#                        합   5,080점
#
# 한 단계 60점이면 만렙이 1,800점 = **9.9일**이었다. 28일 시즌인데 열흘이면
# 트랙이 다 차고 남은 18일은 16,000원짜리 구독이 아무것도 안 줬다.
# 150 이면 4,500점 = 24.8일이고 여유가 1.13배다 — 임무를 11% 흘려도 만렙에
# 닿는다. 170 은 28.1일이라 하루만 빠져도 못 채운다(그래서 안 쓴다).
#
# 임무 표가 늘면 이 값을 다시 잰다 — tests/PassCheck.gd 가 예산과 필요를
# 직접 비교하므로 크게 갈리면 거기서 먼저 걸린다.
const POINT_QUEST := 10
const POINT_WEEKLY := 40
const STEP_POINT := 150


# 오늘이 몇 번째 시즌인가. 기준일 이전이면 0 시즌이다.
static func season_of(date: String) -> int:
	var d := Time.get_unix_time_from_datetime_string(date)
	var e := Time.get_unix_time_from_datetime_string(SEASON_EPOCH)
	if d <= e:
		return 0
	return int((d - e) / (float(SEASON_DAYS) * 86400.0))


# 이번 시즌이 끝나기까지 남은 날. 진열에 "n일 남음"으로 뜬다.
static func season_days_left(date: String) -> int:
	var d := Time.get_unix_time_from_datetime_string(date)
	var e := Time.get_unix_time_from_datetime_string(SEASON_EPOCH)
	var span := float(SEASON_DAYS) * 86400.0
	if d <= e:
		return SEASON_DAYS
	return maxi(1, int(ceil((span - fmod(d - e, span)) / 86400.0)))


static func step_of(points: int) -> int:
	return clampi(points / STEP_POINT, 0, STEPS)


# 다음 단계까지 남은 점수. 만렙이면 0.
static func to_next(points: int) -> int:
	if step_of(points) >= STEPS:
		return 0
	return STEP_POINT - (points % STEP_POINT)


# 무료 줄 — 3단계마다 소환권, 10단계마다 혈정, 나머지는 보석.
# 소환권 주기가 5 였을 때는 30단계에서 세 번(5·15·25)뿐이라 **네 종류를 다
# 못 돌았다**(PassCheck 이 잡았다). 3 이면 여덟 번이라 골고루 간다.
# 종류를 돌리는 이유: 같은 재화만 30번 주면 트랙을 보는 재미가 없다.
static func free_reward(step: int) -> Dictionary:
	if step % 10 == 0:
		return {"kind": "crystal", "amount": 300.0}
	if step % 3 == 0:
		return {"kind": TicketDefs.reward_of(_ticket_at(step)), "amount": 1.0}
	return {"kind": "gem", "amount": 20.0}


# 유료 줄 — 무료의 3~4배. 매 단계 보석이 깔리고 3단계마다 소환권 뭉치,
# 10단계마다 혈정 뭉치가 겹친다.
static func paid_reward(step: int) -> Dictionary:
	if step % 10 == 0:
		return {"kind": "crystal", "amount": 1200.0}
	if step % 3 == 0:
		return {"kind": TicketDefs.reward_of(_ticket_at(step)), "amount": 4.0}
	return {"kind": "gem", "amount": 70.0}


# 소환권 종류를 돌린다 — 한 종류만 주면 나머지 셋의 천장이 안 찬다(TicketDefs).
static func _ticket_at(step: int) -> String:
	return str(TicketDefs.KINDS[(step / 3) % TicketDefs.KINDS.size()])


# 28일을 다 돌았을 때 유료 줄이 주는 보석 총량. 값어치 검사가 이걸 본다.
static func paid_total_gem() -> float:
	var sum := 0.0
	for i in range(1, STEPS + 1):
		var r := paid_reward(i)
		if str(r["kind"]) == "gem":
			sum += float(r["amount"])
	return sum
