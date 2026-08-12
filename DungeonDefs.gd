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
const KILLS_PER_FLOOR := 5      # 일반 층 = 몹 5마리 (EXPANSION 7장)
# 층당 등가 구간 보폭. 8이면 100층 = 본편 822구간 난이도 — 미궁 끝이 본편
# 끝(1000)보다 약간 앞에 서서, 미궁이 본편을 앞지르는 역전이 안 생긴다.
const EQ_STEP := 8


# 층 -> 본편 등가 구간. 몹 체력·피해·로스터가 전부 이 구간 것이다.
static func eq_stage(floor: int) -> int:
	return mini(StageDefs.total_stages(),
		OPEN_STAGE + (maxi(1, floor) - 1) * EQ_STEP)


# 5층마다 중간보스, 10층마다 보스 — 본편의 주기(MIDBOSS_STEP·보스 10)와 같은
# 문법이라 배우는 것 없이 읽힌다.
static func is_boss_floor(floor: int) -> bool:
	return maxi(1, floor) % 10 == 0


static func is_midboss_floor(floor: int) -> bool:
	return maxi(1, floor) % 10 == 5


static func kills_needed(floor: int) -> int:
	return 1 if is_boss_floor(floor) or is_midboss_floor(floor) \
		else KILLS_PER_FLOOR


# 제한 시간도 본편 문법 그대로: 보스·중간보스 층에만 건다.
static func time_limit(floor: int) -> float:
	if is_boss_floor(floor):
		return StageDefs.TIME_BOSS
	return StageDefs.TIME_MIDBOSS if is_midboss_floor(floor) else 0.0


# 본편 최고 기록이 미궁을 몇 층까지 여는가 (EXPANSION 7장의 교차 잠금).
# 30구간에 5층, 이후 본편 10구간마다 5층씩. 220구간이면 100층 전부.
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


# 깊이 색 — 깊을수록 어둡고 붉게. 몹에 씌운다(modulate). 배경을 새로 뽑지 않고
# "깊어졌다"를 읽히는 가장 싼 수단이다. 끝(100층)도 0.78 까지만 — 더 어두우면
# 체력 바·피해 숫자와 대비가 죽는다.
static func depth_tint(floor: int) -> Color:
	var t := clampf(float(floor) / float(FLOOR_CAP), 0.0, 1.0)
	return Color(1.0, 1.0, 1.0).lerp(Color(0.78, 0.60, 0.64), t)
