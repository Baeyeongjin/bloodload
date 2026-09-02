class_name RushDefs
# 혈전 회랑 — 보스 러시 (사장님 픽 2026-09-02). **잡았던 본편 막 보스 10종이
# 줄지어 재도전한다.** 하루 한 판, 층마다 보스 하나(45초), 보상은 층마다 즉시 —
# 죽어도 받은 것은 그대로다. 판은 1층 격파에 쓴다: 들어갔다 그냥 나오면 안 쓴
# 것("실패에 값을 물리면 도전 자체를 안 한다", 재화 던전 규칙).
#
# 90일 이후 일일 루프에 "오늘 할 일"을 하나 얹는 자리다(daily 08-18 C표 추천).
# 얼굴·배경·애님 전부 StageDefs.ACTS 재사용 — 새 그림 0장.

const TIME_LIMIT := 45.0     # 보스당 (시련과 같은 결)
const OPEN_STAGE := 100      # 열 보스를 전부 만난 뒤 (10막 x 10구간)
const START_BACK := 30       # 1층 = 최고 구간 -30 등가 — 재화 던전 -15 전례의 러시판
const STEP := 5              # 층마다 +5구간. 7층쯤 본편 최고를 넘어 벽이 선다
const MILESTONE := 5         # 이 배수 층마다 보석·소환권
const MILESTONE_GEM := 10.0
# 층 혈액 = 등가 시세 40킬 분량 — 벽(~10층)까지 돌면 혈액 던전 한 판(400킬)과
# 비슷하다. 재화 격리(EXPANSION 6장)를 안 깨는 크기다.
const GOLD_KILLS := 40.0


static func eq_stage(fl: int, best: int) -> int:
	return maxi(1, best - START_BACK) + (maxi(1, fl) - 1) * STEP


static func is_milestone(fl: int) -> bool:
	return fl > 0 and fl % MILESTONE == 0


# 이정표 소환권 — 보스 첫 격파 보상과 같은 회전(무기→방어구→장신구→스킬).
# 소환 곡선이 굶고 있어서(신화 장비 해금 누적 1000회/판, 수급 ~4회/일) 여기가
# 그 굶주림을 먹이는 자리다 — 사장님 픽 2026-09-02.
static func milestone_ticket(fl: int) -> String:
	var i := int(round(float(fl) / float(MILESTONE))) - 1
	return TicketDefs.reward_of(TicketDefs.KINDS[i % TicketDefs.KINDS.size()])


static func gold_reward(fl: int, best: int) -> float:
	return StageDefs.gold_per_kill(eq_stage(fl, best)) * GOLD_KILLS \
		/ StageDefs.KILL_WORTH
