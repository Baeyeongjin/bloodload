class_name Grid
extends RefCounted

# 도트 격자 단일 출처. 모든 크기·좌표는 여기서 나온 값이어야 한다(사장님: 16px 기준).
#
# 이 파일이 있는 이유: arrow-rpg의 UI가 118x44, 406x154 같은 제멋대로 크기라
# 도트가 미세하게 어긋나 보였다. 격자를 코드 한 곳에 박아 두면 새 UI를 만들 때
# "적당히 44"를 못 쓰게 된다.
const UNIT := 16

# 자산 크기(전부 UNIT의 배수). 기존 arrow-rpg 자산이 이미 이 격자에 맞는다.
const SPRITE := UNIT * 2      # 32 — 히어로·몹·아이템·스킬 아이콘
const FX := UNIT * 4          # 64 — VFX 팩 프레임
const BG := Vector2i(576, 896)    # 세로 모바일 (36 x 56 유닛)
# 배경 원본 크기. 2배로 그려 BG를 채운다 — 스프라이트도 2배라 도트 밀도가 같다.
# 배경 원본: 가로로 긴 한 장(화면 폭의 2.6배). 짧으면 같은 그림이 금방 되돌아온다.
# 768 로 생성한 뒤 tools/make_seamless.py 가 오른쪽 24px 을 왼쪽에 겹쳐 섞고
# 잘라내서 744 가 됐다. 그 덕에 옆에 붙여도 이음매가 안 보인다.
const BG_SRC := Vector2i(744, 160)


# 임의 값을 16px 격자에 맞춘다. 배경·패널처럼 큰 덩어리에만 쓴다.
#
# **UI 배치에는 쓰지 않는다.** 16px은 글자 한 줄 높이의 절반이라, 위치를 이걸로
# 반올림하면 아이콘은 8px 밀리고 라벨(반올림 안 함)은 안 밀려서 서로 어긋난다.
# 실제로 그 때문에 버튼·아이콘·글자가 제각각 놀았다.
static func snap(v: float) -> float:
	return roundf(v / float(UNIT)) * float(UNIT)


static func snapv(v: Vector2) -> Vector2:
	return Vector2(snap(v.x), snap(v.y))


# 정수 픽셀로만 맞춘다. 도트가 흐려지는 건 소수점 좌표 때문이지 16px 격자에서
# 벗어나서가 아니다 — UI 배치는 전부 이걸 쓴다.
static func px(v: float) -> float:
	return roundf(v)


static func pxv(v: Vector2) -> Vector2:
	return Vector2(roundf(v.x), roundf(v.y))


# 유닛 개수 -> 픽셀. UI 배치에 숫자를 직접 쓰지 않기 위한 것.
static func u(n: float) -> float:
	return n * float(UNIT)


static func uv(x: float, y: float) -> Vector2:
	return Vector2(x * float(UNIT), y * float(UNIT))
