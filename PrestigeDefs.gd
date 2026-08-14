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
# static var 인 이유: PaceProbe 가 후보를 훑는다(StageDefs.POWER_STEP 과 같은 자리).
static var MARK_POWER := 0.06


# **이미 받은 몫은 다시 안 준다** (사장님 2026-08-14, 실측 뒤 결정).
#
# 왜: 200일 실측에서 **자주 누를수록 손해**였다 — 벽에 닿을 때마다 눌러 혈흔
# 395개(x24.7)를 모은 쪽이 252구간, 7일씩 참아 131개(x8.9)만 모은 쪽이 300구간.
# 이득(회귀당 혈흔 ~11개)은 매번 같은데 비용(스탯·혈액 리셋 + 되돌아오는 며칠)도
# 매번 같아서, 반복하면 왕복 시간만 버렸다.
#
# 유저가 **참는 게 최선인 버튼**을 화면에 두면 안 되고, 얼마나 참아야 하는지는
# 화면에 안 나왔다. 그래서 같은 자리에서 두 번째로 누르면 0 이 나오게 한다 —
# 잘못 누를 방법이 없어지고, "N구간까지 가면 열린다"로 그대로 적힌다.
static func marks_for(best_stage: int, peak: int = 0) -> int:
	if best_stage < OPEN_STAGE:
		return 0
	return maxi(0, _tier(best_stage) - _tier(peak))


static func can(best_stage: int, peak: int = 0) -> bool:
	return marks_for(best_stage, peak) > 0


# 다음 회귀가 열리는 구간 — 화면에 "N구간까지 가면 열린다"로 적는다.
static func next_stage(peak: int) -> int:
	return maxi(OPEN_STAGE, MARK_BASE + (_tier(peak) + 1) * MARK_STEP)


static func _tier(stage: int) -> int:
	return maxi(0, (stage - MARK_BASE) / MARK_STEP)


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
