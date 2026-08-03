class_name Type
extends RefCounted

# 폰트 단일 출처. 화면마다 load()하지 않아 교체 지점을 한 곳으로 고정한다.
#
# Fantasy Warrior (11x11 픽셀 블랙레터). 한글 완성형 11172자를 전부 담고 있어
# 폴백 없이 이 한 장으로 끝난다 — 처음 받은 DungeonFont는 코드포인트가 188개뿐이라
# 한글이 전부 □로 나왔고, 그때는 Galmuri를 폴백으로 붙여야 했다.
#
# 11x11 도트 폰트라 글자 크기는 11의 배수(11/22/33)일 때 가장 또렷하다.
# 그 외 크기는 픽셀이 어긋나 뭉개진다.
#
# 라이선스: CC BY 4.0 — "Fantasy Warrior Font" by Douglas Vautour (Burpy Fresh).
# 배포 시 크레딧 표기 필요. 원문은 assets/fonts/README-FantasyWarrior.txt.

const PATH := "res://assets/fonts/fantasy_warrior.ttf"
const NATIVE := 11         # 폰트 원본 도트 크기
const SIZE_BODY := NATIVE * 2      # 22 — 본문
const SIZE_SMALL := NATIVE         # 11 — 보조
const SIZE_TITLE := NATIVE * 3     # 33 — 제목
# 배수가 아닌 크기는 픽셀이 살짝 어긋나지만, 칸에 안 들어가는 것보다 낫다.
# 버튼처럼 폭이 정해진 곳에 쓴다.
const SIZE_MID := 16               # 버튼 안 글자

static var _font: FontFile


static func font() -> Font:
	if _font == null:
		_font = load(PATH) as FontFile
	return _font if _font != null else ThemeDB.fallback_font


# 프로젝트 전체에 한 번에 먹이는 테마. Main이 루트에 걸면 모든 Label·Button이 따른다.
static func theme(default_size: int = SIZE_BODY) -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = default_size
	return t
