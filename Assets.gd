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
static var _img_cache := {}


# **텍스처 한 장을 한 번만 편다.** `get_image()` 는 임포트된 텍스처를 그때그때
# 디코드하는 비싼 호출인데, 잉크폭·발밑여백·바닥패드·정점프레임이 각자 새로
# 부르고 있었다 — 프레임 하나당 다섯 번이다. 계산 결과는 저마다 캐시하지만
# **첫 계산에서 다섯 번 디코드하는 것**이 막 하나에 250ms 를 만들었다
# (2026-08-27 --perf 실측).
#
# 캐시는 데우기가 끝나면 Main 이 비운다 — 값은 이미 각 캐시에 들어가 있어서
# 편 이미지를 계속 들고 있을 이유가 없다.
static func image_of(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var key := texture.resource_path
	if key != "" and _img_cache.has(key):
		return _img_cache[key]
	var img := texture.get_image()
	if img != null and key != "":
		_img_cache[key] = img
	return img


# 편 이미지를 버린다(계산 결과 캐시는 그대로 둔다).
static func drop_images() -> void:
	_img_cache.clear()


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
	var image := image_of(texture)
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
	var image := image_of(texture)
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
# **가장 멀리 뻗은 프레임 번호.** 임팩트를 여기에 맞춘다.
#
# 왜 필요한가: 생성 결과가 프롬프트의 프레임 지시를 안 지킨다. "프레임 4 에서 가장
# 멀리 뻗어라"를 명시하고도 attack 은 f2, heavy 는 f1 에 극단이 왔다(2026-08-06 실측:
# 임팩트 24 vs 최대 46). 고정 비율(IMPACT_RATIO)로 잡으면 칼을 뒤로 뺀 순간에 피해가
# 들어가 "안 맞았는데 맞았다"가 된다 — heavy 를 한 번 폐기한 이유가 그것이었다.
#
# 그림을 다시 뽑는 대신 **그림에서 읽는다.** 새 모션이 어떤 타이밍으로 와도 맞는다.
#
# **가로로 뻗는 모션에만 쓴다.** 내려찍기는 아래로 눌리지 옆으로 안 뻗으므로 이 자로
# 재면 잡음에서 최대값을 고른다 — 그쪽은 `slam_peak_frame` 을 쓴다.
# **되감는 프레임 뒤에서만 고른다**(2026-08-10). 연격(attack2·attack3)은 앞 모션의
# 마지막 자세를 0번 프레임으로 물려받는다 — 그건 **직전 스윙의 마무리**지 이번 스윙이
# 아니다. 전체에서 최대를 고르면 attack2 의 임팩트가 f0 으로 잡혀 피해가 그림보다
# 먼저 들어간다(실측: 가로 뻗음 [46,41,32,25,35,37,37,44,45] -> f0).
#
# 휘두르기는 "뒤로 뺐다(최소) → 뻗는다(최대)"라 **최소 이후의 최대**가 곧 임팩트다.
# 이 규칙은 기존 모션의 값을 안 바꾼다(attack f7, heavy f6 그대로) — 그것들은 이미
# 최소가 앞에 있다.
static func reach_peak_frame(dir_path: String, flipped := false) -> int:
	var key := "peak:%s:%s" % [dir_path, str(flipped)]
	if _reach_cache.has(key):
		return int(_reach_cache[key])
	var n := frames(dir_path).size()
	var low := 0
	var low_r := INF
	# f0 을 뺀 전체 극단도 같이 들고 있는다 — 아래 되감기 가드가 쓴다.
	var peak := 0
	var peak_r := -1.0
	for f in n:
		var r := frame_reach(dir_path, f, 1.0, flipped)
		if r < low_r:
			low_r = r
			low = f
		if f > 0 and r > peak_r:
			peak_r = r
			peak = f
	var best := low
	var best_r := -1.0
	for f in range(low, n):
		var r := frame_reach(dir_path, f, 1.0, flipped)
		if r > best_r:
			best_r = r
			best = f
	# **되감는 꼬리에 갇혔으면 되돌린다.** 위 "최소 이후" 규칙은 앞머리에 물려받은
	# 자세(f0)를 건너뛰려고 있는 것인데, 뒤쪽에 더 깊은 골짜기가 있는 모션이면
	# 창이 그 꼬리에 갇혀서 **칼이 이미 되감긴 프레임**이 임팩트가 된다.
	# 실측(2026-08-27): hawaii_attack3·cast = [12,13,13,21,24,23,17,11,12] -> f8(12),
	# 진짜 극단은 f4(24) 다. 사거리가 반토막 나고(48 -> 24) 임팩트가 시전 창
	# 끝(0.94 x 길이)에 붙어서, 그 사이 표적이 죽으면 스킬이 통째로 사라졌다.
	#
	# **고른 값이 극단의 70% 에 못 미칠 때만** 되돌린다 — 규칙을 통째로 바꾸면
	# 평평한 수열(가호 6종 [15,15,...])과 봉우리가 둘인 모션이 같이 흔들린다.
	# 전수 확인: 영웅 모션 120종 중 이 조건에 걸리는 것은 그 둘뿐이다.
	if peak_r > 0.0 and best_r < peak_r * 0.70:
		best = peak
	_reach_cache[key] = best
	return best


# **내려찍기가 바닥에 닿는 프레임.** 잉크 높이가 가장 낮은 프레임이다.
#
# 스프라이트는 발이 지면에 붙어 있어 아래끝이 고정이므로(실측: 슬라임 9프레임 모두
# bottom 29), 높이가 줄어드는 것이 곧 **몸이 아래로 눌렸다**는 뜻이다.
#
# 가로 자(`reach_peak_frame`)로는 못 잡는다. 2026-08-06 실측 — 몹 8종 내려찍기의
# 가로 뻗음은 거의 안 변해서(용암 두꺼비 30~31) 최대값이 사실상 잡음이고, 그걸로
# 고르면 f2 처럼 **아직 들어올리는 중인** 프레임이 임팩트가 된다.
#
#   슬라임 높이 25 27 28 28 26 23 20 22 24  -> f6 (가로 자는 f6, 우연히 일치)
#   두꺼비 높이 24 26 30 30 30 26 23 23 24  -> f6 (가로 자는 f2, 빗나감)
#   임프   높이 31 31 32 30 28 28 29 29 31  -> f4 (가로 자는 f1, 빗나감)
static func slam_peak_frame(dir_path: String) -> int:
	var key := "slam:%s" % dir_path
	if _reach_cache.has(key):
		return int(_reach_cache[key])
	var all_frames := frames(dir_path)
	var best := 0
	var best_h := 1 << 30
	for f in all_frames.size():
		var texture: Texture2D = all_frames[f]
		var used := image_of(texture).get_used_rect()
		if used.size.x <= 0:
			continue
		if used.size.y < best_h:
			best_h = used.size.y
			best = f
	_reach_cache[key] = best
	return best


# 그림 **덩어리**의 아래끝과 캔버스 아래끝 사이의 여백(원본 px). 바닥 이펙트를
# 지면선에 붙일 때 이 값만큼 내려서 붙인다.
#
# **튄 방울 한 점이 아니라 덩어리를 본다.** 잉크가 있는 가장 낮은 줄로 재면
# 갈라진 대지가 캔버스 바닥에 "닿은" 것으로 나오는데(bbox 밑단 48/48), 그건 흩뿌려진
# 핏방울이고 눈에 보이는 덩어리는 5~7px 위에 있다 — 배율 2.24 를 곱하면 화면에서
# 11~16px 떠 보인다. 사장님이 네 번째로 "안 닿아 있다"고 한 것이 이것이다.
# 그래서 **그 프레임에서 가장 넓은 줄의 20% 이상**이 찬 줄을 밑단으로 본다.
#
# 프레임 전체의 **최솟값**을 쓴다: 분출은 중반에 피가 땅을 떠나는 게 정상이라,
# 거기 맞추면 시작 프레임이 파묻힌다. 가장 낮게 닿는 프레임이 지면에 닿으면 된다.
#
# 서는 자리를 상자에서 잉크로 옮긴 것(인계 3장)과 같은 교훈이다 — 캔버스는 상자다.
const _DENSE_ROW := 0.20


static func bottom_pad(dir_path: String) -> float:
	var key := "bpad:%s" % dir_path
	if _reach_cache.has(key):
		return float(_reach_cache[key])
	# **get_pixel 로 훑지 않는다.** 한 픽셀마다 Color 를 하나씩 만들어 내므로
	# 64x64 짜리 9프레임이면 36,864 번이다 — `--perf` 로 재니 이 함수가 든 데우기
	# 구간이 막 하나에 **254ms** 였다(2026-08-27). 알파만 필요하니 바이트를 직접
	# 읽는다: 같은 값이 나오고 비용만 빠진다.
	var pad := 1 << 30
	for texture in frames(dir_path):
		var img := image_of(texture as Texture2D)
		# 임포트 설정에 따라 압축돼 올 수 있다. 바이트를 직접 읽으려면 편다.
		# **사본에 한다** — decompress/convert 는 제자리에서 바꾸는데
		# 이 이미지는 image_of 캐시가 남들과 같이 쓰는 것이다.
		if img.is_compressed() or img.get_format() != Image.FORMAT_RGBA8:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
		var data := img.get_data()
		var w := img.get_width()
		var h := img.get_height()
		var rows: Array[int] = []
		var widest := 0
		for y in h:
			var n := 0
			var base := y * w * 4 + 3      # 알파는 네 번째 바이트
			for x in w:
				if data[base + x * 4] >= 128:
					n += 1
			rows.append(n)
			widest = maxi(widest, n)
		if widest <= 0:
			continue
		var need := maxi(2, int(float(widest) * _DENSE_ROW))
		for y in range(h - 1, -1, -1):
			if rows[y] >= need:
				pad = mini(pad, h - 1 - y)
				break
	var out := float(pad) if pad < (1 << 30) else 0.0
	_reach_cache[key] = out
	return out


static func frame_reach(dir_path: String, frame: int, draw_scale: float = 1.0,
		flipped: bool = false) -> float:
	var key := "%s:%d:%f:%s" % [dir_path, frame, draw_scale, str(flipped)]
	if _reach_cache.has(key):
		return float(_reach_cache[key])
	var all_frames := frames(dir_path)
	if all_frames.is_empty():
		return 0.0
	var texture: Texture2D = all_frames[clampi(frame, 0, all_frames.size() - 1)]
	var image := image_of(texture)
	var used := image.get_used_rect()
	if used.size.x <= 0:
		return 0.0
	var edge := float(image.get_width() - used.position.x) if flipped \
		else float(used.end.x)
	var reach := maxf(0.0, (edge - float(image.get_width()) * 0.5) * draw_scale)
	_reach_cache[key] = reach
	return reach
