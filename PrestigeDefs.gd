class_name PrestigeDefs

# 프레스티지 "핏빛 회귀" (MONETIZATION_PLAN 8-2, 사장님 승인 2026-08-14).
#
# **왜 필요한가**: 200일차 실측에서 게임이 멈췄다 — 90일 245구간에서 200일
# 250구간, 110일 동안 다섯 구간이다. 혈액이 2조 남았는데도 못 쓴다: 공격력
# 189레벨 다음 한 칸이 2.5조라, 수입 지수(구간당 3.8%)가 비용 지수(레벨당 15%)를
# 못 따라간다. 합연산 축이 지수 비용에 먹히는 자리다.
#
# 리셋 배율은 **곱연산**이라 그 싸움을 우회한다. 비용 지수를 낮추는 안도 있었지만
# 그건 초반까지 같이 빨라져 방금 맞춘 곡선(POWER_CURVE 0.97)이 다시 깨진다.
const OPEN_STAGE := 200        # 벽 직전 — "막힐 때쯤 하나씩"(8장 원칙)
# 혈흔 = (도달구간 - BASE) / STEP. 150 부터 세는 건 200 에서 첫 회귀가 5개가
# 되게 하려는 것이다 — 첫 판이 0 이면 누를 이유가 없고, 너무 많으면 한 번에
# 벽이 사라진다.
const MARK_BASE := 150
const MARK_STEP := 10
# 혈흔 하나가 주는 공격력. 실측 역산(구간당 요구 +3.79%)으로:
#   혈흔 5(첫 회귀)  x1.30 -> +7구간
#   혈흔 20(3회차)   x2.20 -> +23구간
#   혈흔 60(10회차)  x4.60 -> +41구간
# 한 번으로는 조금, 반복하면 크게 — 그게 2차 루프의 모양이다.
const MARK_POWER := 0.06


static func can(best_stage: int) -> bool:
	return best_stage >= OPEN_STAGE


# 지금 회귀하면 받는 혈흔. 조건 미달이면 0.
static func marks_for(best_stage: int) -> int:
	if not can(best_stage):
		return 0
	return maxi(0, (best_stage - MARK_BASE) / MARK_STEP)


static func power_mult(marks: int) -> float:
	return 1.0 + MARK_POWER * float(maxi(0, marks))


# 그 배율이 몇 구간어치인가 — 화면에 "얼마나 더 갈 수 있나"를 적으려고 둔다.
# 구간당 요구는 POWER_STEP^(1/10) 이다.
static func stages_worth(marks: int) -> int:
	var m := power_mult(marks)
	if m <= 1.0:
		return 0
	var per: float = pow(StageDefs.POWER_STEP, 0.1)
	return int(log(m) / log(per))
