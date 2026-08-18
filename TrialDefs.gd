class_name TrialDefs
# 시련 (참고작 "고대 유적지" — REFERENCE_TEARDOWN §7) — 단계 보스와 1:1.
# 이기면 **영구 공격·체력 %** 가 남고, 다음 단계는 미궁 층이 잠근다(엇갈린 잠금).
# 도전은 무제한이다 — 실패에 값을 물리면 도전 자체를 안 한다(재화 던전과 같은
# 규칙). 보상이 단계당 한 번뿐이라 무제한이어도 파밍이 안 된다.


const BONUS_PER := 0.03      # 격파당 공·체 +3%p — 완주(33단계)면 약 x2.0
const TIME_LIMIT := 45.0     # 이 안에 보스를 눕혀야 한다
const FLOOR_PER := 3         # n단계 도전 조건: 미궁 3n층 정복


# 도전 단계의 본편 등가 구간 — 보스의 힘과 생김새(그 막의 보스)가 여기서 나온다.
# ponytail: 첫 감(1단계=40, 완주 360). 사장님 플레이로 조이고, 곡선 재측정
# (PaceProbe)에 BONUS_PER 와 함께 넣는다.
static func eq_stage(n: int) -> int:
	return 30 + n * 10


static func mult(cleared: int) -> float:
	return 1.0 + BONUS_PER * float(cleared)


static func floor_need(n: int) -> int:
	return FLOOR_PER * n


static func max_stage() -> int:
	return 33    # 미궁 100층이 여는 마지막 단계 (3 x 33 = 99)
