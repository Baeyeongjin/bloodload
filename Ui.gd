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
	# **expand_mode 를 맨 먼저 준다.** 기본값(KEEP_SIZE)에서는 최소 크기가 원본 크기고,
	# Control.update_minimum_size() 는 **트리 밖 노드에서 그냥 되돌아간다** — 그래서
	# position 을 먼저 주면 그때 최소 32 가 캐시되고, 뒤늦게 expand_mode 를 바꿔도
	# 캐시가 안 깨진다. 결과가 "size 에 12 를 넣었는데 32 로 그려진다"였고, 화면에서는
	# 그냥 "이 아이콘만 왜 크지"로만 보였다(전투력 교차검·알림 점이 전부 그랬다).
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = Assets.tex(path)
	t.position = Grid.pxv(pos)
	var s := box if box > 0.0 else float(Grid.SPRITE * 2)
	t.size = Vector2(s, s)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# 직사각형 UI 원화를 정확한 크기로 표시한다. 카드 프레임처럼 정사각형이 아닌 자산용.
static func image(path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	# expand_mode 를 size 보다 **먼저** — icon() 과 같은 이유다. set_size 는 그 자리에서
	# 최소 크기로 클램프하므로, KEEP_SIZE 상태로 원본보다 작은 size 를 주면 원본
	# 크기로 커진다(수집 격자 미니 카드가 96×128 로 터져 나온 실측, 2026-08-18).
	# 지금까지 안 보였던 건 모든 호출이 원본보다 크게 그려 왔기 때문이다.
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture = Assets.tex(path)
	t.position = Grid.pxv(pos)
	t.size = Grid.pxv(size)
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
	# 눌림 반응 — 누르는 동안 살짝 움츠린다. 스타일박스 색만 바뀌면 "눌렸나?"가
	# 애매하다(사장님: 밋밋함). 트윈 없이 스냅으로 — 픽셀 게임은 스냅이 어울린다.
	b.pivot_offset = Grid.pxv(size) * 0.5
	b.button_down.connect(func() -> void: b.scale = Vector2(0.93, 0.93))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	hover_pop(b)
	return b


# 마우스가 올라가면 **살짝 부푼다** (사장님 2026-08-14: 전 버튼에 호버 반응).
# 눌림(0.93)과 반대 방향이라 둘이 안 싸운다: 올라감 1.04 -> 누름 0.93 -> 뗌 1.04.
# 트윈은 **한 번에 하나만** 돈다 — 빠르게 들락거리면 트윈이 겹쳐 크기가 튄다.
const HOVER_SCALE := 1.04
const HOVER_TIME := 0.07
static func hover_pop(c: Control) -> void:
	if c.pivot_offset == Vector2.ZERO:
		c.pivot_offset = c.size * 0.5
	c.mouse_entered.connect(func() -> void:
		if c is BaseButton and (c as BaseButton).disabled:
			return
		_pop_to(c, HOVER_SCALE))
	c.mouse_exited.connect(func() -> void: _pop_to(c, 1.0))


static func _pop_to(c: Control, to: float) -> void:
	# **has_meta 로 먼저 묻는다.** get_meta 의 기본값이 null 이면 Godot 은 그걸
	# "기본값 없음"으로 읽고 그 자리에서 오류를 낸다(object.cpp 의 ERR_FAIL_V_MSG).
	# 그래서 호버가 처음 벗어나는 순간마다 콘솔에 빨간 줄이 찍혔다 — 화면은
	# 멀쩡해서 캡처를 뜨기 전에는 안 보였다.
	if c.has_meta("hover_tw"):
		var old: Variant = c.get_meta("hover_tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := c.create_tween()
	c.set_meta("hover_tw", tw)
	tw.tween_property(c, "scale", Vector2(to, to), HOVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# 버튼 왼쪽 비용 아이콘. 20px 이 기본인데 **소환 버튼처럼 큰 버튼에서는 작다** —
# 버튼이 크면 아이콘도 같이 키워 넘긴다(사장님: "소환칸 보석 너무 작다").
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
# 늘어나도 되는 가운데다. widget_bar 는 원본 가운데에 리벳 기둥이 있어서 잘라냈고,
# **오른쪽 기둥을 좌우 반전해 왼쪽에도 붙였다** — 처음엔 왼쪽이 원본의 찢어진
# 단면이라 "카드가 잘렸다"로 보였다. 지금은 [기둥 20 | 가죽 40 | 기둥 20] 대칭이다.
# (기둥이 9-slice 가운데에 있으면 늘어나 뭉개진다) 찢어진 왼쪽 + 오른쪽 기둥만 남겼다.
const WIDGET_BAR := "res://assets/ui/widget_bar.png"
const WIDGET_SIDE := 20
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


# 가로로 긴 띠(가이드 위젯). 가죽 무늬가 균일해서 가로로 많이 늘려도 안 뭉개진다.
static func widget_bar(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(WIDGET_BAR, WIDGET_SIDE, WIDGET_CAP)
	n.position = pos
	n.size = size
	return n


# 레퍼런스형 얇은 진행바. 좌우 **화살촉 캡**이 달려 있고 가운데 홈통만 늘어난다.
#
# 실측(assets/ui/bar_slim.png, 128x32, 행 15 / 열 64):
#   화살촉 + 금기둥  좌 0~25 / 우 102~127  -> 9-slice 좌우 여백 26
#   홈통(진짜 파인 자리) y 13~18. 그 위아래 y11·y20 은 금 베벨이라 채움이 거기까지
#   올라가면 테두리를 덮는다.
# **세로는 안 늘린다.** 원본이 32px 인데 22px 로 줄이면 금테가 뭉갠다 — 바 높이를
# 원본에 맞추고(32) 가로만 늘린다.
#
# **채움은 틀 위에 그린다.** 홈통이 불투명(실측 alpha 255)이라 밑에 깔면 통째로
# 가려져 진행도가 영영 안 보인다 — bar_mini 와 같은 함정이고 실제로 그 상태였다.
const BAR_SLIM := "res://assets/ui/bar_slim.png"
const BAR_SLIM_H := 32.0
const BAR_SLIM_SIDE := 26        # 화살촉 + 금기둥
const BAR_SLIM_INNER_Y := 13.0   # 홈통 위끝
const BAR_SLIM_INNER_H := 6.0    # 홈통 높이


# 제한 시간 바. 실측(assets/ui/bar_timer.png, 128x32, 행 16 / 열 64):
#   왼쪽 캡(모래시계) x 0~20  ·  오른쪽 캡 x 121~127  -> 여백이 **좌우가 다르다**
#   홈통 y 14~19 (6줄). 위아래 베벨(y10~13 · y20~23)은 덮으면 안 된다.
# 모래시계가 왼쪽에만 있어서 좌우를 같은 값으로 자르면 그게 늘어나 뭉갠다.
const BAR_TIMER := "res://assets/ui/bar_timer.png"
const BAR_TIMER_H := 32.0
const BAR_TIMER_L := 21          # 모래시계 캡
const BAR_TIMER_R := 8
const BAR_TIMER_INNER_Y := 14.0
const BAR_TIMER_INNER_H := 6.0


# 재화 알약. **자산이 아니라 코드로 그린다.** 도트 원화로 뽑으면 등근 끝이 9-slice 로
# 늘어나면서 뭉개지는데(재화 바가 그랬다), 여기 필요한 건 무늬 없는 검은 판 하나뿐이라
# StyleBoxFlat 이면 끝난다 — 길이가 얼마든 모서리가 정확히 둥글다.
#
# anti_aliasing 은 **끈다.** 켜 두면 모서리가 흐려져 도트 화면에서 저것만 붕 뜬다.
static func pill(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.05, 0.66)
	sb.border_color = Color(0.62, 0.55, 0.40, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(size.y * 0.5))
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	p.position = Grid.pxv(pos)
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func timer_bar(pos: Vector2, width: float) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = Assets.tex(BAR_TIMER)
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.position = pos
	n.size = Vector2(width, BAR_TIMER_H)
	n.set("patch_margin_left", BAR_TIMER_L)
	n.set("patch_margin_right", BAR_TIMER_R)
	n.set("patch_margin_top", 4)
	n.set("patch_margin_bottom", 4)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


static func slim_bar(pos: Vector2, width: float) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = Assets.tex(BAR_SLIM)
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.position = pos
	n.size = Vector2(width, BAR_SLIM_H)
	n.set("patch_margin_left", BAR_SLIM_SIDE)
	n.set("patch_margin_right", BAR_SLIM_SIDE)
	n.set("patch_margin_top", 4)
	n.set("patch_margin_bottom", 4)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


# 가이드 카드 전용. 공용 panel(돌 창)이 아니라 **작은 정보 카드**용 자산이다 —
# 큰 창 무늬를 200px 카드에 쓰면 테두리가 카드를 다 먹는다.
#
# 여백 실측(card_panel 96x48, 가운데 행/열):
#   가로  투명 0~9   · 틀 10~18 · 안쪽 19~75 · 틀 76~82 · 투명 83~95
#   세로  투명 0~3   · 틀 4~12  · 안쪽 13~34 · 틀 35~43 · 투명 44~47
# 9-slice 여백은 **틀 바깥끝까지** 잡아야 한다. 12/4 로 두었을 때 세로 틀(4~12)이
# 통째로 늘리는 구역에 들어가 아래 금테가 실처럼 늘어나 있었다.
const CARD_PANEL := "res://assets/ui/card_panel.png"
const CARD_TAB := "res://assets/ui/card_tab.png"
const CARD_PAD_X := 20.0    # 안쪽 평평한 면이 시작되는 자리
const CARD_PAD_Y := 13.0


static func card(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(CARD_PANEL, int(CARD_PAD_X), int(CARD_PAD_Y))
	n.position = pos
	n.size = size
	return n


static func card_tab(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(CARD_TAB, 6, 7)
	n.position = pos
	n.size = size
	return n


# ── 레퍼런스 대조로 새로 뽑은 조각들 (2026-08-05) ─────────────────────────
# 여백은 전부 **실측**이다(안쪽 평평한 면이 시작되는 열/행을 읽었다).
# 통짜로 쓰는 것(아이콘·알림점)은 여기 없다 — Ui.icon 으로 그냥 그린다.
const LV_BADGE := "res://assets/ui/lv_badge.png"        # 64x32  여백 5/7,9
const CURRENCY_BAR := "res://assets/ui/currency_bar.png" # 128x32 여백 5/2
const SLOT_REWARD := "res://assets/ui/slot_reward.png"   # 40x40  여백 3/2,3
const BAR_MINI := "res://assets/ui/bar_mini.png"         # 96x32
# 실측(row 15 / col 48). 좌우 캡은 x0~7·x88~95 이고 그 안이 홈통이다. 9-slice 여백을
# 4로 두면 금기둥(x7)이 늘어나는 쪽에 걸려 가로로 번진다 — 8이어야 캡이 고정된다.
const BAR_MINI_SIDE := 8
# 홈통(진짜 파인 자리)은 y13~18 뿐이다. 그 위아래 y9~12 · y19~22 는 금·은 베벨이라
# 채움이 거기까지 올라가면 테두리를 덮는다.
const BAR_MINI_INNER_Y := 13.0
const BAR_MINI_INNER_H := 6.0
const TAG_STATUS := "res://assets/ui/tag_status.png"
const PLATE_NAME := "res://assets/ui/plate_name.png"


static func lv_badge(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(LV_BADGE, 6, 8)
	n.position = pos
	n.size = size
	return n


# 재화 바. 여백이 좌우 5뿐이라 **안쪽이 넓다** — 알약(pill)은 양끝 보석이 30씩
# 먹어서 숫자 세 개를 한 줄에 못 넣었다.
static func currency_bar(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(CURRENCY_BAR, 6, 3)
	n.position = pos
	n.size = size
	return n


static func slot_reward(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(SLOT_REWARD, 4, 4)
	n.position = pos
	n.size = size
	return n


static func bar_mini(pos: Vector2, width: float) -> NinePatchRect:
	var n := _slice(BAR_MINI, BAR_MINI_SIDE, 10)
	n.position = pos
	n.size = Vector2(width, 32.0)
	return n


static func tag(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(TAG_STATUS, 10, 8)
	n.position = pos
	n.size = size
	return n


static func name_plate(pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(PLATE_NAME, 10, 11)
	n.position = pos
	n.size = size
	return n


# 창이 뜰 때의 반응. **`visible` 을 켜는 자리는 34곳인데 여기 한 곳만 등록하면
# 전부 걸린다** — 켜지는 순간을 시그널로 잡으므로 호출부는 손대지 않는다
# (사장님: "모든 창들 띄울 때 애니메이션").
#
# 살짝 작게 시작해 튕기며 커진다(TRANS_BACK) — 도트 게임에서 창이 "튀어나오는"
# 그 반응이고, 0.14초라 연타를 막지 않는다. 닫힘은 안 건드린다: 닫는 건 이미
# 결과를 본 뒤라 기다릴 이유가 없다.
static func pop_in(node: Control) -> void:
	if node == null or node.has_meta("pop_in"):
		return
	node.set_meta("pop_in", true)
	node.visibility_changed.connect(func() -> void:
		if not node.visible or not node.is_inside_tree():
			return
		node.pivot_offset = node.size * 0.5
		node.modulate.a = 0.0
		node.scale = Vector2(0.92, 0.92)
		var tw := node.create_tween().set_parallel()
		tw.tween_property(node, "modulate:a", 1.0, 0.10)
		tw.tween_property(node, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


# ── 임무판(duty, 양피지) · 도감(tome, 가죽책) 세트 ─────────────────────────
#
# 조각을 NinePatch 로 늘린다. **TextureRect 로 늘리면 안 된다** — 밀랍 인장과
# 금박 모서리가 같이 늘어나 뭉개진다(판이 528x560 인데 조각은 481x161 이다).
# 여백은 조각마다 실측했다: 장식이 차지하는 만큼을 잘라 줘야 가운데만 늘어난다.
const SET_DIR := "res://assets/ui/sets/"


static func set_body(prefix: String, pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(SET_DIR + prefix + "_body.png", 26, 24)
	n.position = pos
	n.size = size
	return n


# 긴 띠 — 판 안에서 한 덩어리를 묶는 자리.
static func set_card(prefix: String, pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(SET_DIR + prefix + "_band.png", 22, 16)
	n.position = pos
	n.size = size
	return n


# 줄 하나. **버튼도 같은 조각을 쓴다** — 시트에 버튼 전용이 따로 없고, 줄과
# 버튼은 어차피 같은 액자다(눌리는 느낌은 글자 색과 판정이 만든다).
static func set_row(prefix: String, pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(SET_DIR + prefix + "_card.png", 18, 14)
	n.position = pos
	n.size = size
	return n


static func set_button(prefix: String, pos: Vector2, size: Vector2) -> NinePatchRect:
	return set_row(prefix, pos, size)


static func set_tab(prefix: String, on: bool, pos: Vector2,
		size: Vector2) -> NinePatchRect:
	var n := _slice(SET_DIR + prefix + ("_tab_on.png" if on else "_tab_off.png"),
		16, 14)
	n.position = pos
	n.size = size
	return n


static func set_pill(prefix: String, pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := _slice(SET_DIR + prefix + "_pill.png", 16, 10)
	n.position = pos
	n.size = size
	return n
