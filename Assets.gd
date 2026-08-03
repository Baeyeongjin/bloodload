class_name Assets
extends RefCounted
# =====================================================================
#  스프라이트/애니메이션 로더
#  - tex(path): 단일 텍스처 (없으면 null → 도형 폴백)
#  - frames(dir): dir/0.png, 1.png ... 연속 프레임 배열 (없으면 빈 배열)
# =====================================================================

static var _cache := {}
static var _fcache := {}
static var _reach_cache := {}

static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_cache[path] = t
	return t

static func frames(dir_path: String) -> Array:
	if _fcache.has(dir_path):
		return _fcache[dir_path]
	var arr: Array = []
	var i := 0
	while i < 32:
		var p := "%s/%d.png" % [dir_path, i]
		# 소스 PNG가 지워지고 .import만 남은 경우 ResourceLoader.exists()가 true를
		# 반환할 수 있다. 원본도 함께 확인해 고아 임포트 로딩 오류를 막는다.
		if FileAccess.file_exists(p) and ResourceLoader.exists(p):
			arr.append(load(p))
			i += 1
		else:
			break
	_fcache[dir_path] = arr
	return arr


# 중심 정렬 스프라이트가 오른쪽을 볼 때, 중심부터 불투명 픽셀 끝까지의 실제 거리.
static func frame_reach(dir_path: String, frame: int, draw_scale: float = 1.0,
		flipped: bool = false) -> float:
	var key := "%s:%d:%f:%s" % [dir_path, frame, draw_scale, str(flipped)]
	if _reach_cache.has(key):
		return float(_reach_cache[key])
	var all_frames := frames(dir_path)
	if all_frames.is_empty():
		return 0.0
	var texture: Texture2D = all_frames[clampi(frame, 0, all_frames.size() - 1)]
	var image := texture.get_image()
	var used := image.get_used_rect()
	if used.size.x <= 0:
		return 0.0
	var edge := float(image.get_width() - used.position.x) if flipped \
		else float(used.end.x)
	var reach := maxf(0.0, (edge - float(image.get_width()) * 0.5) * draw_scale)
	_reach_cache[key] = reach
	return reach
