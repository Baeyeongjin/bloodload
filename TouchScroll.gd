class_name TouchScroll
extends ScrollContainer

# 손가락으로 끌어서 넘기는 스크롤 (사장님 2026-09-10: "손가락으로 슬라이드해서
# 올릴수있게").
#
# **왜 기본 ScrollContainer 로는 안 되나:** Godot 의 ScrollContainer 도 터치
# 드래그를 처리하지만 그건 `_gui_input` 이라, 목록 칸이 전부 버튼인 이 게임에서는
# **버튼이 터치를 먼저 먹어서** 부모까지 오지 않는다. 그래서 폰에서는 얇은 스크롤
# 바를 정확히 집어야만 움직였다.
#
# 그래서 `_input` 에서 잡는다 — GUI 보다 먼저 오는 자리다. 대신 **누르는 순간은
# 안 삼킨다**: 삼키면 버튼이 아예 안 눌려서 목록을 못 고르게 된다. 손가락이
# THRESHOLD 를 넘게 움직였을 때만 "이건 스크롤이다"로 보고, 그때부터 삼킨다.
# 뗄 때도 삼켜서 클릭이 안 나가게 한다 — 안 그러면 끌어 놓고 손을 뗀 자리의
# 칸이 눌린다.
const THRESHOLD := 8.0

var _touch := false          # 이 판 안에서 시작한 누름인가
var _moved := false          # 스크롤로 판정났는가
var _last := 0.0
var _start := 0.0


# 가로 판이면 x, 아니면 y 를 본다.
func _sideways() -> bool:
	return horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO \
		and vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# **같은 손짓이 두 벌로 온다.** `emulate_mouse_from_touch` 가 기본으로 켜져
	# 있어서 ScreenTouch 뒤에 그것을 흉내낸 MouseButton 이 따라온다. 둘 다
	# 처리하면 앞의 것이 세운 _moved 를 뒤의 것이 지워 버려서, 뗄 때를 못 삼키고
	# **끌어 놓은 자리의 칸이 눌린다**(사장님 2026-09-10: "슬라이드 하다가
	# 버튼이 계속 클릭이 되는데"). 흉내가 켜져 있으면 **마우스 쪽만 본다** —
	# 데스크톱과 같은 길이라 갈래도 안 는다.
	if Input.is_emulating_mouse_from_touch() \
			and (event is InputEventScreenTouch
			or event is InputEventScreenDrag):
		return
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	if touch != null or (click != null
			and click.button_index == MOUSE_BUTTON_LEFT):
		var pressed: bool = touch.pressed if touch != null else click.pressed
		var at: Vector2 = touch.position if touch != null else click.position
		if pressed:
			# 판 밖에서 시작한 누름은 이 판의 일이 아니다.
			_touch = get_global_rect().has_point(at)
			_moved = false
			_last = at.x if _sideways() else at.y
			_start = _last
		else:
			# 끌었으면 뗄 때를 삼킨다 — 손 뗀 자리의 칸이 눌리면 안 된다.
			if _touch and _moved:
				get_viewport().set_input_as_handled()
			_touch = false
			_moved = false
		return
	if not _touch:
		return
	var slide := event as InputEventScreenDrag
	var move := event as InputEventMouseMotion
	if slide == null and (move == null
			or (move.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0):
		return
	var pos: Vector2 = slide.position if slide != null else move.position
	var now: float = pos.x if _sideways() else pos.y
	var step := now - _last
	_last = now
	if absf(now - _start) > THRESHOLD:
		_moved = true
	if not _moved:
		return
	# 손가락을 올리면 목록이 올라온다 — 화면을 잡아 끄는 쪽이다.
	if _sideways():
		scroll_horizontal -= int(step)
	else:
		scroll_vertical -= int(step)
	get_viewport().set_input_as_handled()
