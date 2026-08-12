class_name PactDefs

# 혈맹 (참고작 ⑦ "투혼" 자리 — 사장님 선택 컨셉: 피의 권속과 맺는 계약).
# 4번째 장기 성장 축: 별 10성 x 50레벨 = 500레벨이 상한이다.
#
# 예산 자리: 효과는 **합연산 풀**(damage()/max_hp() 의 수집·도감과 같은 괄호)에
# 더한다 — 곱연산은 혈맥 전담(EXPANSION 8장 예산표)이라 여기 %가 곱으로 들어가면
# 예산이 깨진다. 상한 유한: 만렙 +550% (레벨 500% + 별 50%).
#
# 재화 격리: 전용 재화 "인장"은 계약의 제단(재화 던전 3호)에서만 나온다.
const STAR_EVERY := 50      # 50레벨마다 별 하나
const STAR_MAX := 10
const PER_LEVEL := 0.01     # 레벨당 공격·체력 +1%
const PER_STAR := 0.05      # 별 하나마다 +5% 덩어리 — 별이 이정표가 되게


static func level_cap() -> int:
	return STAR_EVERY * STAR_MAX


static func stars(lv: int) -> int:
	return mini(lv / STAR_EVERY, STAR_MAX)


static func bonus(lv: int) -> float:
	return PER_LEVEL * float(mini(lv, level_cap())) \
		+ PER_STAR * float(stars(lv))


# 인장 비용 — 선형. 500레벨 총합 약 27만: 제단 하루 한 판(단계 따라 커지는
# 뭉치)으로 여러 달 걸리는 장기 시계다. 첫 감이라 느슨하다 — 사장님 체감 후 조정.
static func cost(lv: int) -> float:
	return 20.0 + 2.0 * float(lv)
