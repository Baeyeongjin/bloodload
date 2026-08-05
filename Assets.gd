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
static var _gap_cache := {}


# 그림이 캔버스 **아래끝에서 몇 칸 떠 있는가**(원본 픽셀 단위).
#
# 발밑 정렬에 쓴다. 도트 그림은 32x32 안에서 차지하는 위치가 제각각이고,
# **애니메이션은 프레임마다도 다르다**(frost_spider_walk 는 1~6px 로 흔들린다).
# 캔버스 아래끝을 지면에 붙이면 그 차이만큼 몹이 떴다 가라앉았다 한다.
# 그림이 **중심에서 좌우로 가장 멀리 뻗은 거리**(원본 픽셀).
#
# 겹침을 상자 폭으로 재면 안 된다. 32px 캔버스에 26px 만 차 있으면 한쪽당 3px,
# 양쪽 6px 이 과장된다 — 실제로 그 오차 때문에 "겹친다"는 지표가 나왔는데 화면에는
# 안 겹쳐 보였다. 자가 틀리면 벽을 잘못 옮긴다.
static func ink_half_width(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var key := "w:" + texture.resource_path
	if _gap_cache.has(key):
		return float(_gap_cache[key])
	var image := texture.get_image()
	var used := image.get_used_rect()
	var half := 0.0
	if used.size.x > 0:
		var center := float(image.get_width()) * 0.5
		half = maxf(center - float(used.position.x),
			float(used.position.x + used.size.x) - center)
	_gap_cache[key] = half
	return half


static func bottom_gap(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var key := texture.resource_path
	if _gap_cache.has(key):
		return float(_gap_cache[key])
	var image := texture.get_image()
	var used := image.get_used_rect()
	var gap := 0.0 if used.size.y <= 0 \
		else float(image.get_height() - (used.position.y + used.size.y))
	_gap_cache[key] = gap
	return gap

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
