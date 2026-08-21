extends Control

# 시작 화면 — 제목과 **진짜** 로딩 막대.
#
# 왜 필요한가: 켜면 곧장 전투가 시작됐다. 실측 부팅이 2.1초(PC 헤드리스, 실기는
# 더)인데 그동안 검은 화면이라 "멈춘 건가"로 읽힌다.
#
# **막대가 거짓말을 하면 안 된다.** 시간에 맞춰 채우는 가짜 막대는 유저가 알아본다
# (다 찼는데 안 넘어가거나, 반쯤에서 갑자기 끝난다). 부팅 2.1초 중 1.1초가
# `Main.tscn` 읽기인데 그 구간은 ResourceLoader 가 실제 진행률을 준다 —
# 스레드 로딩으로 그 숫자를 그대로 그린다.
#
# 자산은 게으르게 읽힌다(Assets.tex 가 필요할 때 읽는다). 그래서 여기서 2293장을
# 미리 읽지 않는다 — 그러면 시작이 되레 느려지고, 몹 한 종 처음 읽기는 29ms 라
# 게임 중 끊김이 문제가 아니다(BootProbe 실측).
#
# 다 읽으면 **막대를 치우고 "아무 곳이나 누르세요"** 로 바꾼다(사장님 2026-08-20).
# 곧장 넘기면 못 본 사이에 전투가 지나간다. 다 찬 막대를 세워 두는 것도 "멈췄나"
# 로 읽히므로 막대는 남기지 않는다.

const MAIN := "res://Main.tscn"
const BG := "res://assets/ui/title_bg.png"

const W := 576.0
const H := 896.0
const BAR_W := 400.0
const BAR_H := 18.0
const BAR_Y := 742.0
const BLOOD := Color(0.72, 0.16, 0.20)      # Main.STAGE_BAR_COL 과 같은 핏빛
const INK := Color(0.08, 0.02, 0.04)
const ART_ZOOM := 2.0                        # 288x448 -> 576x896 (화면과 동일)
const VEIL_MAX := 0.82

# 로딩이 눈 깜짝할 새 끝나면 화면이 번쩍이고 만다 — 제목을 읽을 틈은 준다.
# 개발 플래그(캡처·검수)로 켤 때는 0 이다: 도구가 기다릴 이유가 없다.
const MIN_SHOW := 0.7

var _bar: Control          # 테두리·바탕·채움 세 겹을 한 번에 치우려고 묶는다
var _fill: ColorRect
var _pct: Label
var _t := 0.0
var _done := false
var _tap_on := false
var _entering := false
# 대기 중 미리 데울 자산 목록 — Assets._cache 가 static 이라 여기서 읽어 두면
# Main 이 그대로 쓴다. 클릭 후 멈칫의 몸통이 이 로드였다(사장님 지적).
var _warm: PackedStringArray = []
var _warm_i := 0


func _ready() -> void:
	size = Vector2(W, H)
	_build()
	ResourceLoader.load_threaded_request(MAIN)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-title"):
			_shot(a.ends_with("=tap"))


func _build() -> void:
	var theme_ := Type.theme()
	theme = theme_

	var back := ColorRect.new()
	back.size = Vector2(W, H)
	back.color = Color(0.04, 0.02, 0.03)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	# **288x448 을 정수 2배로 576x896.** 화면과 정확히 같아서 잘리지도 남지도
	# 않는다 — 타이틀 그림을 이 규격으로 뽑은 이유다(PixelLab 은 총 면적이
	# 262144 까지라 576x896 을 통째로는 못 뽑는다). 도트는 정수배가 아니면 뭉갠다.
	var tex := Assets.tex(BG)
	if tex != null:
		var art := TextureRect.new()
		art.texture = tex
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.size = Vector2(tex.get_width() * ART_ZOOM, tex.get_height() * ART_ZOOM)
		art.position = Vector2((W - art.size.x) * 0.5, (H - art.size.y) * 0.5)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)

	# 글자가 앉는 자리만 어둡게 깐다 — 그림 위에 바로 얹으면 하늘색과 겹쳐
	# 획이 묻힌다. 외곽선만으로는 22px 글자가 안 버틴다(실측).
	_veil(0.0, 260.0, true)
	_veil(BAR_Y - 70.0, H - BAR_Y + 70.0, false)

	# **제목은 한글로 쓴다.** 블랙레터 대문자 D 는 O 와 구별이 안 돼서
	# "BLOODLORD" 가 "BLOOOLORO" 로 읽혔다(실측 캡처). 이 폰트의 알려진 함정이고
	# (`Lv.` 가 `LD` 로 읽혀 `N레벨` 로 바꾼 것과 같은 자리), 한글은 또렷하다.
	_label("핏빛 군주", Type.NATIVE * 4, 96.0, Color(0.90, 0.82, 0.76), 6)
	_label("B L O O D L O R D", Type.SIZE_SMALL, 160.0,
		Color(0.60, 0.30, 0.32), 3)

	# 막대 — 테두리·바탕·채움 세 겹. ProgressBar 는 스타일박스를 따로 먹여야
	# 도트 느낌이 나는데, 그 설정이 여기 코드보다 길다.
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)

	var edge := ColorRect.new()
	edge.color = Color(0.30, 0.12, 0.14)
	edge.size = Vector2(BAR_W + 4.0, BAR_H + 4.0)
	edge.position = Vector2((W - BAR_W) * 0.5 - 2.0, BAR_Y - 2.0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(edge)

	var slot := ColorRect.new()
	slot.color = Color(0.10, 0.05, 0.06)
	slot.size = Vector2(BAR_W, BAR_H)
	slot.position = Vector2((W - BAR_W) * 0.5, BAR_Y)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(slot)

	_fill = ColorRect.new()
	_fill.color = BLOOD
	_fill.size = Vector2(0.0, BAR_H)
	_fill.position = slot.position
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_fill)

	_pct = _label("0%", Type.SIZE_SMALL, BAR_Y + 28.0, Color(0.58, 0.44, 0.42), 3)


# 로딩이 끝난 자리. 막대와 % 를 치우고 그 자리에 안내를 놓는다 — 화면이 바뀌는
# 것 자체가 "다 됐다"는 신호라서 따로 완료 표시를 안 붙인다.
func _tap_ready() -> void:
	_tap_on = true
	# 기다리는 동안 무거운 폴더의 그림을 미리 읽는다 — 프레임당 몇 장씩이라
	# 안 끊기고, 1~2초만 서 있어도 수백 장이 데워져 입장이 가벼워진다.
	for d in ["ui", "enemies", "items", "skill_icons", "cards"]:
		var da := DirAccess.open("res://assets/%s" % d)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".png"):
				_warm.append("res://assets/%s/%s" % [d, f])
	_bar.hide()
	_pct.hide()
	var tap := _label("아무 곳이나 누르세요", Type.SIZE_BODY, BAR_Y - 8.0,
		Color(0.96, 0.92, 0.90), 6)
	# 깜빡임 — 멈춘 화면인지 기다리는 화면인지 구분이 돼야 한다. 바닥을 0.45 로
	# 두는 이유: 그림이 어두워서 더 흐려지면 글자가 통째로 사라진다(실측 캡처).
	var tw := tap.create_tween().set_loops()
	tw.tween_property(tap, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tap, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


# 마우스 클릭·키·터치 아무거나. **_unhandled_input 이 아니라 _input 이다** —
# 루트 Control 의 mouse_filter 가 STOP 이라 마우스 버튼은 GUI 에서 먹히고
# unhandled 까지 안 내려온다.
func _input(event: InputEvent) -> void:
	if not _tap_on or _done or _entering:
		return
	if not (event is InputEventMouseButton or event is InputEventKey
			or event is InputEventScreenTouch):
		return
	if not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	# **클릭에는 즉시 반응이 보여야 한다.** 씬 전환의 _ready 가 한 프레임을
	# 통째로 먹어서(UI 조립) 그냥 넘기면 "눌렀는데 멈췄다"로 읽힌다(사장님).
	# 어둠이 먼저 내려오면 그 멈칫은 어둠 뒤에서 지나간다.
	_entering = true
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.01, 0.03, 0.0)
	veil.size = Vector2(W, H)
	add_child(veil)
	var tw2 := veil.create_tween()
	tw2.tween_property(veil, "color:a", 1.0, 0.22)
	tw2.tween_callback(_enter)


# 글자 뒤에 까는 어둠. **GradientTexture2D 를 쓴다** — 알파를 달리한 ColorRect
# 를 여러 장 겹쳐 흉내 냈더니 밝은 달 위에서 줄무늬가 그대로 보였다(실측 캡처).
# 엔진에 진짜 그라데이션이 있는데 손으로 계단을 만들 이유가 없다.
func _veil(y: float, height: float, from_top: bool) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.01, 0.02, VEIL_MAX))
	g.set_color(1, Color(0.03, 0.01, 0.02, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = int(W)
	t.height = int(height)
	t.fill_from = Vector2(0.0, 0.0 if from_top else 1.0)
	t.fill_to = Vector2(0.0, 1.0 if from_top else 0.0)
	var r := TextureRect.new()
	r.texture = t
	r.position = Vector2(0.0, y)
	r.size = Vector2(W, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)


func _label(text: String, font_size: int, y: float, col: Color,
		outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Type.font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(W, float(font_size) + 8.0)
	l.position = Vector2(0.0, y)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _tap_on and not _entering and _warm_i < _warm.size():
		# 프레임당 6장 — 60fps 에서 0.4초면 다 데워진다. 클릭이 먼저 오면
		# 남은 몫은 Main 이 원래대로 게으르게 읽는다.
		for _k in 6:
			if _warm_i >= _warm.size():
				break
			Assets.tex(_warm[_warm_i])
			_warm_i += 1
	if _done or _tap_on:
		return
	_t += delta
	var progress: Array = []
	var st := ResourceLoader.load_threaded_get_status(MAIN, progress)
	var p := float(progress[0]) if not progress.is_empty() else 0.0

	match st:
		ResourceLoader.THREAD_LOAD_LOADED:
			# 다 읽었어도 최소 시간은 지킨다 — 막대가 끝까지 찬 뒤에 바뀐다.
			p = 1.0
			if _t >= _min_show():
				# 검사·캡처 도구는 문 앞에 세워 두지 않는다. 화면이 없는
				# 실행에는 안내 자체가 뜻이 없다(헤드리스 검사가 여기서 멎었다).
				if _auto():
					_enter()
				else:
					_tap_ready()
				return
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# **여기서 멈추면 유저는 영영 못 들어간다.** 스레드 로딩이 안 되면
			# 곧장 씬을 바꾼다 — 그쪽은 동기 로딩이라 느릴 뿐 열리기는 한다.
			push_error("Main.tscn 스레드 로딩 실패 — 동기 전환")
			_done = true
			get_tree().change_scene_to_file(MAIN)
			return
	_fill.size.x = BAR_W * clampf(p, 0.0, 1.0)
	_pct.text = "%d%%" % int(round(clampf(p, 0.0, 1.0) * 100.0))


# 개발 플래그로 켰으면 안 기다린다 — 캡처·검수 도구가 0.7초를 서 있을 이유가 없다.
func _min_show() -> float:
	return 0.0 if _auto() else MIN_SHOW


# 사람이 아니라 도구가 켠 실행인가.
func _auto() -> bool:
	return DisplayServer.get_name() == "headless" \
		or not OS.get_cmdline_user_args().is_empty()


# [개발 도구] --shot-title[=tap] : 이 화면을 찍고 끝낸다. =tap 은 로딩이 끝난
# 뒤(막대 대신 안내)를 찍는다.
#
# Main 의 --autoshot 으로는 못 찍는다 — 그 코드는 씬이 넘어간 **뒤에** 도니까
# 항상 전투 화면이 나온다. 막대는 로딩이 1초 만에 끝나 찍을 때마다 다른 값이
# 걸리므로, 디자인을 보려고 중간값에 세워 둔다.
func _shot(tap: bool) -> void:
	_done = true          # _process 가 씬을 넘기지 못하게 잠근다
	await get_tree().create_timer(0.5).timeout
	if tap:
		_tap_ready()
		_tap_on = false   # _input 이 씬을 넘기지 못하게 — 찍기만 한다
		await get_tree().create_timer(0.4).timeout
	else:
		_fill.size.x = BAR_W * 0.45
		_pct.text = "45%"
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://autoshot.png")
	print("TITLE SHOT: %s" % ProjectSettings.globalize_path("user://autoshot.png"))
	get_tree().quit()


func _enter() -> void:
	_done = true
	var packed := ResourceLoader.load_threaded_get(MAIN)
	if packed == null:
		get_tree().change_scene_to_file(MAIN)
		return
	get_tree().change_scene_to_packed(packed)
