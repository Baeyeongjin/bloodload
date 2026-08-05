class_name Ui
extends RefCounted

# UI 조립 헬퍼. 생성한 도트 패널을 9-slice로 늘려 쓴다.
#
# 패널을 크기마다 새로 생성하지 않는 이유: 방치형은 창이 여러 개고 크기가 제각각이라
# 크기별로 뽑으면 자산이 무한히 는다. 테두리만 고정하고 가운데를 늘리는 9-slice면
# 한 장으로 모든 창을 덮는다.

const PANEL := "res://assets/ui/panel.png"
const PANEL_ART := Rect2(6, 6, 148, 84)
# 생성된 패널(160x96)의 테두리 두께. 이 값보다 크게 잡으면 모서리 무늬가 겹치고
# 작게 잡으면 테두리가 늘어나 뭉개진다 — 실측해서 정한다.
const PANEL_MARGIN := 12


# 늘어나는 도트 패널. size는 16px 격자에 맞춰 들어와야 한다.
static func panel(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = Assets.tex(PANEL)
	n.region_rect = PANEL_ART
	n.position = Grid.pxv(pos)
	n.size = Grid.pxv(size)
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for side in ["left", "top", "right", "bottom"]:
		n.set("patch_margin_" + side, PANEL_MARGIN)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


# 아이콘. 기본 64px(32px 원본의 2배)이고, 틀 안에 넣을 때는 크기를 줄여 준다.
# 원본 크기가 32~96px로 제각각이라 KEEP_ASPECT_CENTERED 로 상자 안에 맞춘다.
static func icon(path: String, pos: Vector2, box := 0.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.tex(path)
	t.position = Grid.pxv(pos)
	var s := box if box > 0.0 else float(Grid.SPRITE * 2)
	t.size = Vector2(s, s)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# 직사각형 UI 원화를 정확한 크기로 표시한다. 카드 프레임처럼 정사각형이 아닌 자산용.
static func image(path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.tex(path)
	t.position = Grid.pxv(pos)
	t.size = Grid.pxv(size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# 도트 버튼. 9-slice라 가로 길이를 마음대로 바꿔도 테두리가 안 뭉개진다.
static func button(text: String, pos: Vector2, size: Vector2,
		font_size := Type.SIZE_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Grid.pxv(pos)
	b.size = Grid.pxv(size)
	# 포커스를 안 받게 한다 — 안 그러면 마지막에 누른 버튼 하나가 계속 눌린 것처럼 보인다.
	b.focus_mode = Control.FOCUS_NONE
	# 글자는 칸 한가운데. 넘치면 늘어나는 대신 잘라낸다 — 버튼 밖으로 삐져나오면
	# 어느 버튼의 글자인지 안 읽힌다.
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.add_theme_font_size_override("font_size", font_size)
	# 외곽선은 글자 크기에 맞춘다. 작은 글자에 5px을 두르면 획이 다 메워진다.
	b.add_theme_constant_override("outline_size", 5 if font_size >= Type.SIZE_BODY else 3)
	b.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 1.0))
	b.add_theme_color_override("font_color", Color(0.92, 0.86, 0.86))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.42))
	for state in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, _nine("res://assets/ui/btn.png", BTN_ART, 10, 5))
	for state in ["hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state,
			_nine("res://assets/ui/btn_hover.png", BTN_ART, 10, 5))
	return b


static func cost_icon(button: Button, path: String, width := 20) -> void:
	button.icon = Assets.tex(path)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", width)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT


# 생성된 버튼(96x32)에서 **실제 알약은 y 0~23 뿐**이고 아래 8px은 별개의 어두운
# 받침이다. 32 전체를 버튼으로 쓰면 글자가 32의 가운데(15.5)에 놓이는데 알약의
# 가운데는 11.5라 4px 아래로 보인다 — 알약만 잘라 쓴다.
# (가로도 마찬가지로 가운데 44px에만 그림이 있다.)
const BTN_ART := Rect2(26, 0, 44, 24)
# 버튼 글자 위아래 여백. 이 폰트는 위아래로 여유가 없어 0이면 테두리에 닿는다.
const TEXT_PAD := 4
# 세로 중앙 보정. Button 은 폰트가 보고하는 높이(ascent+descent)로 가운데를 잡는데,
# 그 높이에는 이 폰트가 실제로 안 쓰는 여백이 들어 있어 글자가 한쪽으로 쏠린다.
# 양수면 아래로, 음수면 위로 민다.
#
# **눈대중 금지.** tools/measure_text.py 로 스크린샷에서 잉크 중심과 칸 중심의
# 차이를 재서 넣는다 — 처음에 눈으로 3을 넣었다가 반대로 아래로 넘쳤다.
const TEXT_NUDGE := 0


# 스크롤바 원화는 세로용(무늬가 위아래 끝에만 있다)이다. 가로 바에 그대로 쓰면
# 가운데를 옆으로 늘여서 무늬가 뭉개진다 — 그림을 90도 돌려 쓴다.
# 한 번 돌린 건 들고 있는다(스크롤바는 창마다 새로 만든다).
static var _rot_cache := {}


static func _rot90(path: String) -> Texture2D:
	if _rot_cache.has(path):
		return _rot_cache[path]
	var src := Assets.tex(path)
	if src == null:
		return null
	var img := src.get_image()
	img.rotate_90(CLOCKWISE)
	var t := ImageTexture.create_from_image(img)
	_rot_cache[path] = t
	return t


static func _nine(path: String, region := Rect2(), side := 14, cap := 8,
		rotate := false) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = _rot90(path) if rotate else Assets.tex(path)
	if region.size.x > 0.0:
		s.region_rect = region
	# 좌우/상하 테두리 두께. 이보다 크면 모서리 무늬가 겹치고 작으면 늘어나 뭉개진다.
	s.texture_margin_left = side
	s.texture_margin_right = side
	s.texture_margin_top = cap
	s.texture_margin_bottom = cap
	# 글자가 놓이는 안쪽 여백. 좌우는 테두리에 붙지 않게 띄우고,
	# 상하는 **반드시 같아야** 한다 — 다르면 Button 의 세로 중앙정렬이 그만큼 밀린다.
	# +6 까지 줬더니 152px 버튼에서 "강화 1848" 이 잘렸다. 여백과 글자 자리는
	# 같은 폭을 나눠 쓰므로 둘 중 하나만 넉넉할 수 있다.
	s.content_margin_left = side + 2
	s.content_margin_right = side + 2
	s.content_margin_top = TEXT_PAD + maxf(0.0, float(TEXT_NUDGE))
	s.content_margin_bottom = TEXT_PAD + maxf(0.0, float(-TEXT_NUDGE))
	return s


# 진행바. 틀은 생성한 도트, 채움은 코드다 —
# 단색 블록을 PixelLab에 시켰더니 깨진 글자를 그렸다(단색은 코드가 항상 정확하다).
#
# bar_frame.png(울퉁불퉁한 돌)은 512px로 늘리면 무늬가 뭉개져서 안 쓴다.
# bar_hp.png 는 192x32 중 실제 그림이 y 7~24 에만 있고 안쪽 구멍이 y 11~20 이다.
# 그 18px 을 2배(36px)로 그려야 도트가 안 어긋난다.
# bar_frame.png(128x32) 의 실제 그림은 y 3~28. 그 26px 을 2배(52px)로 그린다.
#
# 예전에 이 그림이 뭉개져 보였던 진짜 이유는 그림이 나빠서가 아니라 **9-slice 가
# 가운데를 가로로 4배 이상 늘여서** 였다. 무늬가 있는 그림은 늘리면 안 되고
# **반복(TILE)** 시켜야 도트가 산다.
const BAR_ART := Rect2(0, 3, 128, 26)
const BAR_H := 52.0                     # 26 x2. 정확히 2배라야 도트가 안 어긋난다
const BAR_CAP := 8                      # 좌우 끝 두께(원본 기준)
const BAR_INSET := Vector2(14, 12)      # 채움을 틀 안쪽으로 들이는 양(화면 px)


static func bar(pos: Vector2, width: float, fill_col: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.position = Grid.pxv(pos)
	p.size = Vector2(width, BAR_H)
	p.show_percentage = false
	p.max_value = 1.0
	var back := _nine("res://assets/ui/bar_frame.png", BAR_ART, BAR_CAP, 5)
	# 반복(TILE)도 해 봤는데 조각 경계가 세로줄로 드러나 더 나빴다. 늘리는 쪽이 낫다 —
	# 가운데가 거의 균일한 어두운 색이라 늘려도 티가 안 난다(무늬는 좌우 끝에만 있다).
	# 배경은 여백을 안 쓴다 — 여백은 글자용이고 바에는 글자가 없다.
	for side in ["left", "right", "top", "bottom"]:
		back.set("content_margin_" + side, 0)
	p.add_theme_stylebox_override("background", back)
	var fill := StyleBoxTexture.new()
	fill.texture = _bar_fill_tex(fill_col)
	for side in ["left", "right", "top", "bottom"]:
		fill.set("texture_margin_" + side, 0)
		fill.set("content_margin_" + side, 0)
	fill.expand_margin_left = -BAR_INSET.x
	fill.expand_margin_right = -BAR_INSET.x
	fill.expand_margin_top = -BAR_INSET.y
	fill.expand_margin_bottom = -BAR_INSET.y
	p.add_theme_stylebox_override("fill", fill)
	# 채움 텍스처가 뭉개지면 도트가 아니라 그라데이션으로 보인다.
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# 채움을 단색 사각형으로 두면 틀만 도트고 안은 매끈해서 따로 논다.
# 위 밝게 / 가운데 본색 / 아래 어둡게 — 도트 바의 기본 3톤을 세로 10px 로 만들어
# 가로로만 늘린다(가로는 균일하니 늘어나도 도트가 안 깨진다).
static func _bar_fill_tex(col: Color) -> ImageTexture:
	var h := 10
	var img := Image.create(1, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var c := col
		if y < 2:
			c = col.lightened(0.38)      # 윗면 하이라이트
		elif y < 4:
			c = col.lightened(0.14)
		elif y >= h - 2:
			c = col.darkened(0.42)       # 아랫면 그림자
		elif y >= h - 4:
			c = col.darkened(0.20)
		img.set_pixel(0, y, c)
	return ImageTexture.create_from_image(img)


# 도트 폰트가 없으므로 외곽선을 두껍게 줘서 배경 위에서 읽히게 한다.
static func label(text: String, pos: Vector2, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Grid.pxv(pos)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 1.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# 도트 스크롤 목록. 기본 스크롤바는 매끈한 사각형이라 도트 UI 안에서 혼자 논다.
#
# 스크롤을 쓰는 이유: 스탯이 7개로 늘면 한 화면에 안 들어간다. 크기를 줄여 억지로
# 넣으면 글자가 안 읽히고, 두 줄로 나누면 "뭘 올릴까"를 한눈에 못 본다.
const SCROLL_W := 24.0
# 손잡이(scroll_grab.png 32x64) 는 위아래 끝에만 무늬가 있어 가운데만 늘린다.
const GRAB_CAP := 14
const TRACK_CAP := 10


static func scroll(pos: Vector2, size: Vector2, horizontal := false) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.position = Grid.pxv(pos)
	s.size = Grid.pxv(size)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal \
		else ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if horizontal \
		else ScrollContainer.SCROLL_MODE_AUTO
	s.follow_focus = false
	var bar: ScrollBar = s.get_h_scroll_bar() if horizontal else s.get_v_scroll_bar()
	if horizontal:
		bar.custom_minimum_size.y = SCROLL_W
	else:
		bar.custom_minimum_size.x = SCROLL_W
	# 가로 바는 돌린 그림 + 두께도 뒤바꾼 값(무늬가 위아래 → 좌우로 옮겨간다).
	bar.add_theme_stylebox_override("scroll",
		_nine("res://assets/ui/scroll_track.png", Rect2(),
			TRACK_CAP if horizontal else 6, 6 if horizontal else TRACK_CAP, horizontal))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state,
			_nine("res://assets/ui/scroll_grab.png", Rect2(),
				GRAB_CAP if horizontal else 6, 6 if horizontal else GRAB_CAP, horizontal))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s



# ── 사장님이 고른 신규 UI 자산 (2026-08-05) ────────────────────────────────
# 큰 판(panel.png) 하나로 다 덮던 걸 용도별 조각으로 나눴다. 상단을 떠 있는
# 소형 위젯식으로 바꾸면서 "판"이 아니라 "알약/띠/원형 버튼"이 필요해졌다.
#
# 여백은 **실측**이다. pill 은 양끝 붉은 보석이 x 0~30 / 66~96 이고 그 사이가
# 늘어나도 되는 가운데다. widget_bar 는 원본 가운데에 리벳 기둥이 있어서 잘라내고
# (기둥이 9-slice 가운데에 있으면 늘어나 뭉개진다) 찢어진 왼쪽 + 오른쪽 기둥만 남겼다.
const PILL := "res://assets/ui/pill.png"
const PILL_SIDE := 30
const PILL_CAP := 6
const WIDGET_BAR := "res://assets/ui/widget_bar.png"
const WIDGET_SIDE := 16
const WIDGET_CAP := 8


static func _slice(path: String, side: int, cap: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = Assets.tex(path)
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.set("patch_margin_left", side)
	n.set("patch_margin_right", side)
	n.set("patch_margin_top", cap)
	n.set("patch_margin_bottom", cap)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


# 재화 알약. 양끝 보석은 native 크기로 남고 가운데만 늘어난다.
static func pill(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(PILL, PILL_SIDE, PILL_CAP)
	n.position = pos
	n.size = size
	return n


# 가로로 긴 띠(가이드 위젯). 가죽 무늬가 균일해서 가로로 많이 늘려도 안 뭉개진다.
static func widget_bar(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(WIDGET_BAR, WIDGET_SIDE, WIDGET_CAP)
	n.position = pos
	n.size = size
	return n
