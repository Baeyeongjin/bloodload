class_name Foe
extends Node2D

# 방치형 몹. arrow-rpg의 Enemy(600줄)에서 방치형에 필요한 것만 남겼다 —
# 추격 AI·행동 타입·특수공격·실제 좌표 넉백이 전부 빠진다. 몹은 왼쪽으로 걸어오다 멈춰 서서
# 맞는 게 전부다. 플레이어가 조작하지 않으므로 회피할 수단도, 피할 이유도 없다.

# 배경 스크롤과 공유하는 속도. 640에서 전열 300까지 약 2.8초 — 이보다 느리면
# 무리 하나 만나는 데 7초가 걸려 걷는 구간이 지루해진다.
const WALK_SPEED := 120.0

var key := "slime"
var hp := 10.0
var max_hp := 10.0
var gold := 1.0
var is_boss := false
var is_midboss := false
var display_name := ""
var stop_x := 0.0          # 이 x까지 걸어와서 멈춘다 (자리)
# 진행 방향. -1 = 오른쪽에서 나와 왼쪽으로, +1 = 왼쪽에서 나와 오른쪽으로.
# 그림 원본이 왼쪽을 보므로 +1 일 때만 뒤집는다.
var face := -1
var hp_mult := 1.0
var body_scale := 1.0      # 영웅 표시 크기 대비 종별 크기
var combat_active := false # Main이 교전 중이며 영웅이 살아 있을 때만 true
var hero_x := 0.0          # Main 이 매 프레임 넘겨 준다. 닿을 때만 휘두르는 근거

var _walk_frames: Array = []
var _attack_frames: Array = []
var _special_frames: Array = []   # 특수 패턴 전용 모션. 없으면 평타로 떨어진다
var _sprite: Texture2D = null
var _anim_t := 0.0
var _flash_t := 0.0
var _hit_t := 0.0
var _visual_frozen := false
var _attack_cd := 0.0
var _swing_n := 0          # 몇 번째 스윙인가 — 특수 패턴 주기를 센다
var _tell_t := -1.0        # 특수 패턴 예고 남은 시간 (-1 = 예고 중 아님)
var special_swing := false # 지금 나가는 스윙이 특수 패턴인가
var _attack_anim := -1.0
var _impact_sent := false
var dying := false
var dying_t := 0.0
# 죽는 연출. 0.26 은 스쿼시만 할 때 값이라 날아가는 걸 보기엔 짧다.
const DIE_DUR := 0.42
const DIE_FLY := 46.0     # 맞은 쪽 반대로 밀리는 거리
const DIE_HOP := 22.0     # 떠오르는 높이 (포물선)
const DIE_DROP := 14.0    # 마지막에 가라앉는 깊이
const DIE_SPIN := 62.0    # 기우는 각도
const ATTACK_DUR := 0.42
# 타격 지점을 **프레임 번호가 아니라 모션 길이의 비율**로 잡는다.
# 고정 번호(3)로 두면 프레임 수가 다른 모션에서 지점이 밀린다 — 실제로 새로 들어온
# boss_1~5_attack 이 9프레임이라 타격이 43%가 아니라 33% 지점에서 나가고 있었다.
# 비율로 두면 7·8·9프레임 어디에 붙여도 그린 자세와 타격이 계속 맞는다.
const IMPACT_RATIO := 3.0 / 7.0   # 원래 기준: 7프레임 중 네 번째
const HIT_REACT_DUR := 0.14
const HIT_KNOCKBACK := 7.0
const FIRST_SWING := 0.35   # 칸에 도착하고 첫 공격까지. 주기와 별개다


func setup(tier: Dictionary, power: float, stage_gold: float, boss: bool = false) -> void:
	key = str(tier.get("key", "slime"))
	is_boss = boss
	is_midboss = bool(tier.get("midboss", false))
	display_name = "%s%s" % [str(tier.get("name_prefix", "")), str(tier.get("name", key))]
	hp_mult = float(tier.get("hp_mult", 1.0))
	body_scale = float(tier.get("size", 1.0))
	# 보스·중간보스는 한 마리로 단계를 막는다.
	max_hp = FoeTiers.foe_hp(hp_mult, power, boss, is_midboss)
	hp = max_hp
	gold = stage_gold * (10.0 if boss else 1.0)
	_sprite = Assets.tex(str(tier.get("sprite", "")))
	_walk_frames = Assets.frames("res://assets/anim/%s_walk" % str(tier.get("anim_key", key)))
	# walk 과 **같은 키**를 쓴다. 보스는 anim_key(boss_1~5)로 전용 자산이 따로 있고,
	# 없으면 Assets.frames 가 빈 배열을 주므로 원본 몹 attack 으로 떨어진다.
	var anim_key := str(tier.get("anim_key", key))
	_attack_frames = Assets.frames("res://assets/anim/%s_attack" % anim_key)
	if _attack_frames.is_empty():
		_attack_frames = Assets.frames("res://assets/anim/%s_attack" % key)
	# 특수 패턴 전용 모션은 보스·중간보스만 쓴다. 아직 없는 보스는 빈 배열이라
	# _draw 가 평타로 떨어진다 — 하나씩 붙여 나갈 수 있다.
	_special_frames = Assets.frames("res://assets/anim/%s_special" % anim_key)
	# **첫 타는 빨리 나간다.** 예전엔 여기에 주기 전체(1.5~2.3초)를 넣었는데,
	# 이 카운트다운은 **제 칸에 도착한 뒤에야** 돌기 시작한다. 그래서 붙고 나서
	# 2초를 서 있다가 쳤고, 영웅 처치시간이 1.9초라 대부분 때려보지도 못하고 죽었다.
	# 도착하면 바로 휘두르고, 그 다음부터 제 주기를 탄다.
	_attack_cd = FIRST_SWING
	z_index = 2 if boss else 1


func _ready() -> void:
	add_to_group("foes")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func take_damage(d: float) -> void:
	if dying:
		return
	hp -= d
	_flash_t = 0.10
	_hit_t = HIT_REACT_DUR
	self_modulate = Color(7, 7, 8)
	var main := get_parent()
	if main and main.has_method("on_foe_hit"):
		main.on_foe_hit(self, d)
	if hp <= 0.0:
		_die()


func attack_interval() -> float:
	return Balance.foe_attack_interval(hp_mult)


func set_combat_active(active: bool) -> void:
	combat_active = active
	if not active:
		# 사망·부활 중에는 공격 프레임도 멈춘다. 쿨다운은 보존해 부활 직후
		# 전원이 동시에 첫 프레임부터 치는 현상을 막는다.
		_attack_anim = -1.0
		_impact_sent = false


func set_visual_frozen(frozen: bool) -> void:
	_visual_frozen = frozen


func _die() -> void:
	dying = true
	remove_from_group("foes")
	var main := get_parent()
	if main and main.has_method("on_foe_killed"):
		main.on_foe_killed(self)


func _process(delta: float) -> void:
	if not _visual_frozen:
		_anim_t += delta
		_hit_t = maxf(0.0, _hit_t - delta)
		if _flash_t > 0.0:
			_flash_t -= delta
			if _flash_t <= 0.0:
				self_modulate = Color(1, 1, 1)
	if dying:
		dying_t += delta
		if dying_t >= DIE_DUR:
			queue_free()
		queue_redraw()
		return
	# 제 자리까지 걸어와 멈춘다. 방치형이라 그 뒤로는 자리를 지킨다 —
	# 움직이는 건 영웅 쪽이다. 좌우 어느 쪽에서 나와도 같은 식이 되도록
	# 부호를 따지지 않고 move_toward 로 민다.
	if absf(position.x - stop_x) > 0.5:
		position.x = move_toward(position.x, stop_x, WALK_SPEED * delta)
	else:
		_tick_attack(delta)
	queue_redraw()


# 보스·중간보스만 쓰는 특수 패턴. 몇 번에 한 번, **멈춰서 발밑에 착탄 범위를 그리고**
# 넓게 내려찍는다. 예고 중에는 걸음도 스윙도 멈춘다 — 서 있는 것 자체가 신호다.
#
# **잡몹에는 안 붙인다.** 여섯 마리가 동시에 예고하면 바닥이 원으로 덮여서 정작
# 전투가 안 보인다. 예고는 "지금 피해야 한다"를 말하는 것이고, 그게 매 순간이면
# 아무 말도 아니다.
const SPECIAL_EVERY := 3       # 세 번째 스윙마다
const SPECIAL_TELL := 0.85     # 멈춰서 예고하는 시간
const SPECIAL_REACH := 1.7     # 착탄 범위 배수 — 원 크기가 그대로 이 값이다
const SPECIAL_DMG := 2.4       # 피해 배수. 대신 원 밖으로 나가면 통째로 빗나간다


func attack_mult() -> float:
	return SPECIAL_DMG if special_swing else 1.0


# **오프라인 판정이 쓰는 평균 피해 배수.** 실시간은 세 번에 한 번만 SPECIAL_DMG 를
# 쓰지만, 오프라인은 스윙을 하나씩 세지 않고 DPS 로 계산한다. 평타 기준으로만 계산하면
# 오프라인은 "깼다"는데 실제로 돌리면 죽는다 — 조용히 갈라지는 종류라 여기서 맞춘다.
#
#   (평타 (n-1)번 + 특수 1번) / n
static func avg_attack_mult(boss: bool, midboss: bool) -> float:
	if not (boss or midboss):
		return 1.0
	var n := float(SPECIAL_EVERY)
	return ((n - 1.0) + SPECIAL_DMG) / n


# 지금 특수 패턴을 예고하는 중인가. 그리는 쪽(_draw_attack_tell)과 멈추는 쪽이
# 같은 값을 봐야 그림과 움직임이 어긋나지 않는다.
func telling() -> bool:
	return _tell_t >= 0.0


func _tick_attack(delta: float) -> void:
	if not combat_active:
		return
	# **사거리 검사보다 먼저** 돌린다. 아래 검사에 걸려 빠져나가면 예고가 멈춘 채로
	# 굳어서 보스가 영영 안 친다.
	if _tell_t >= 0.0:
		_tell_t -= delta
		if _tell_t <= 0.0:
			_tell_t = -1.0
			_attack_anim = 0.0
			_impact_sent = false
		return
	# **닿지 않으면 아예 안 휘두른다.** 스윙을 시작해 놓고 임팩트 때 빠지면 모션은
	# 나가는데 피해가 0이라, 화면에서는 공격이 나갔다 안 나갔다 하는 것으로 보인다.
	# 시작할 때 재고, 임팩트 때 또 잰다 — 그 사이에 영웅이 대시로 빠져나갔으면
	# 그때는 진짜로 피한 것이고, 그건 남겨 둬야 대시가 회피 수단이 된다.
	if _attack_anim < 0.0 and absf(hero_x - position.x) > reach():
		return
	if _attack_anim >= 0.0:
		_attack_anim += delta
		if not _impact_sent and _attack_anim >= ATTACK_DUR * IMPACT_RATIO:
			_impact_sent = true
			var main := get_parent()
			if main and main.has_method("on_foe_attack"):
				main.on_foe_attack(self)
		if _attack_anim >= ATTACK_DUR:
			_attack_anim = -1.0
		return
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_attack_cd += attack_interval()
		_swing_n += 1
		special_swing = (is_boss or is_midboss) and _swing_n % SPECIAL_EVERY == 0
		if special_swing:
			_tell_t = SPECIAL_TELL   # 멈춰서 예고부터. 스윙은 그 뒤에 나간다
			return
		_attack_anim = 0.0
		_impact_sent = false


# 그림자 반지름. Main 이 발밑에 깔아 준다.
func shadow_r() -> float:
	return _size() * 0.30


# 이 몹의 몸이 실제로 차지하는 가로 절반(화면 픽셀).
#
# `_size() * 0.5` 은 **상자** 절반이라 잉크보다 넓다. 겹침을 잴 때 상자를 쓰면
# 화면에서는 안 닿는데 지표는 겹쳤다고 한다 — 자가 틀린 채로 칸을 옮기면 과보정된다.
# 걸어 들어오는 중에는 프레임이 바뀌므로 지금 그려지는 프레임으로 잰다.
func body_half() -> float:
	var tex: Texture2D = _sprite
	if not _walk_frames.is_empty():
		tex = _walk_frames[int(_anim_t * 8.0) % _walk_frames.size()]
	if tex == null:
		return _size() * 0.5
	return Assets.ink_half_width(tex) * (_size() / float(maxi(1, tex.get_width())))


func _size() -> float:
	var hero_scale := maxf(2.0, body_scale * 2.0) if is_boss or is_midboss else body_scale
	return float(Grid.SPRITE) * 2.0 * hero_scale


# 맞으면 **온 길 쪽으로** 밀린다. 부호를 고정하면 왼쪽에서 온 몹이 맞을 때
# 영웅 쪽으로 파고들어 때린 게 아니라 달려든 것처럼 보인다.
func hit_offset() -> float:
	return HIT_KNOCKBACK * clampf(_hit_t / HIT_REACT_DUR, 0.0, 1.0) * float(-face)


# 이 몹의 공격이 닿는 거리. 영웅이 이 밖으로 나가면 헛친다 — 대시로 피할 여지가
# 생겨야 "달려가서 팬다"가 전투가 된다.
#
# **44 는 너무 짧았다.** 영웅이 한 칸에 붙으면 옆 칸 몹까지 112px 이라, 붙어 있는
# 한 마리 말고는 전부 매번 헛쳤다 — 모션은 나가는데 피해가 안 들어가니 화면에서는
# "공격이 안 나간다"로 보인다. 80 이면 **두 칸까지** 닿아 난전이 된다.
# 세 칸(176px)은 여전히 못 닿으므로 대시로 빠져나갈 여지는 남는다.
func reach() -> float:
	var base := _size() * 0.5 + 80.0
	# 특수 패턴은 넓게 내려찍는다. **예고 중에도 같은 값을 쓴다** — 발밑에 그리는
	# 원이 곧 이 값이라, 다르면 "원 밖인데 맞았다"가 된다.
	return base * SPECIAL_REACH if special_swing else base


# 특수 패턴 착탄 예고. **보스·중간보스가 멈춰 있는 동안에만** 발밑에 납작한 고리가
# 차오른다. 고리 크기는 reach() 그대로라 "여기 서 있으면 맞는다"가 그대로 읽히고,
# 안이 차는 속도가 곧 남은 시간이다.
#
# 바닥에만 그린다 — 몸 위에 표식을 얹으면 정작 몹이 안 보이고, 위쪽에 띄우면
# 전투 화면을 가린다.
# **원이 아니라 바닥에 누운 판이다.** 옆에서 보는 화면이라 원을 눌러 타원으로 그리면
# 공중에 뜬 고리처럼 보인다 — 위아래 변을 어긋나게 민 사각형이 바닥에 깔린 것으로
# 읽힌다(사장님이 보낸 레퍼런스가 그 모양이다).
const TELL_BAND := 18.0        # 바닥에 깔리는 띠의 두께
const TELL_SKEW := 12.0        # 윗변을 옆으로 미는 양 = 바닥 기울기


func _draw_attack_tell() -> void:
	if dying or _tell_t < 0.0:
		return
	var t := clampf(1.0 - _tell_t / SPECIAL_TELL, 0.0, 1.0)
	var r := reach()
	# 채움은 **가운데에서 좌우로** 벌어진다. 그게 곧 남은 시간이다.
	_tell_quad(r * t, Color(0.95, 0.22, 0.18, 0.30))
	_tell_outline(r, Color(1.0, 0.40, 0.30, 0.75))


func _tell_points(half: float) -> PackedVector2Array:
	var y0 := -TELL_BAND
	return PackedVector2Array([
		Vector2(-half + TELL_SKEW, y0), Vector2(half + TELL_SKEW, y0),
		Vector2(half, 0.0), Vector2(-half, 0.0)])


func _tell_quad(half: float, col: Color) -> void:
	if half <= 1.0:
		return
	draw_colored_polygon(_tell_points(half), col)


func _tell_outline(half: float, col: Color) -> void:
	var p := _tell_points(half)
	p.append(p[0])
	draw_polyline(p, col, 2.0)


func _draw() -> void:
	_draw_attack_tell()
	# 원점이 발밑이다. 가운데 정렬로 그리면 크기가 다른 몹끼리 발 높이가 어긋나
	# 다 같이 떠 있는 것처럼 보인다.
	var w := _size()
	var wsc := 1.0
	var hsc := 1.0
	var alpha := 1.0
	var hit_f := clampf(_hit_t / HIT_REACT_DUR, 0.0, 1.0)
	wsc *= 1.0 + 0.12 * hit_f
	hsc *= 1.0 - 0.10 * hit_f
	# 왼쪽에서 나온 몹은 오른쪽을 보므로 통째로 뒤집는다. 그림을 따로 뽑지 않고
	# 좌우 반전으로 끝낸다 — 도트라 반전해도 어색한 곳이 없다.
	draw_set_transform(Vector2(hit_offset(), 0.0), 0.0, Vector2(float(-face), 1.0))
	if dying:
		# 죽음. 예전엔 제자리 스쿼시뿐이라 "사라졌다"에 가까웠다 — 맞아서 죽었다는
		# 인과가 안 보였다. **맞은 쪽으로 날아가면서 무너진다.**
		#
		# 종류를 둘로 가른다: 단단한 놈(hp_mult 큰 쪽)은 뒤로 **날아가고**, 무른 놈은
		# 제자리에서 **녹아내린다**. 같은 연출로 다 죽으면 몹이 다 같아 보인다.
		var f := dying_t / DIE_DUR
		var ease_out := 1.0 - (1.0 - f) * (1.0 - f)
		if hp_mult >= 1.5:
			# 날아감: 온 길 반대로 밀리며 살짝 떠올랐다 떨어지고, 기울어진다.
			draw_set_transform(
				Vector2(float(-face) * DIE_FLY * ease_out,
					-DIE_HOP * sin(f * PI) + DIE_DROP * f * f),
				deg_to_rad(float(-face) * DIE_SPIN * ease_out),
				Vector2(float(-face), 1.0))
			wsc = 1.0 + 0.10 * f
			hsc = 1.0 - 0.15 * f
		else:
			# 녹아내림: 아래로 흘러 퍼진다. 발밑은 그대로 두고 세로만 무너뜨린다.
			wsc = 1.0 + 0.55 * f
			hsc = 1.0 - 0.80 * f
		alpha = 1.0 - ease_out
	var tex: Texture2D = _sprite
	if not dying and _attack_anim >= 0.0 and not _attack_frames.is_empty():
		# 특수 스윙은 전용 모션이 있으면 그걸 쓴다. **없으면 평타로 조용히 떨어진다** —
		# 보스 5종 중 일부만 전용 모션이 붙어 있어도 나머지가 안 깨진다.
		var frames := _special_frames if special_swing and not _special_frames.is_empty() \
			else _attack_frames
		var attack_i := mini(int(_attack_anim * float(frames.size()) / ATTACK_DUR),
			frames.size() - 1)
		tex = frames[attack_i]
	elif not dying and not _walk_frames.is_empty():
		tex = _walk_frames[int(_anim_t * 8.0) % _walk_frames.size()]
	if tex:
		# **발밑은 캔버스가 아니라 그림의 아래끝이다.** 캔버스 아래끝을 지면에 붙이면
		# 그림이 캔버스 안에서 떠 있는 만큼 몹이 공중에 뜬다 — 거미가 그랬다.
		# 게다가 그 여백은 프레임마다 달라서(서리 거미 1~6px) 걸을 때 위아래로
		# 흔들린다. 재서 그만큼 내린다.
		var drop := Assets.bottom_gap(tex) \
			* (w * hsc / float(maxi(1, tex.get_height())))
		# 몹은 왼쪽(플레이어)을 본다. 원본이 왼쪽 향함이라 그대로 그린다.
		draw_texture_rect(tex,
			Rect2(Vector2(-w * wsc * 0.5, -w * hsc + drop), Vector2(w * wsc, w * hsc)),
			false, Color(1, 1, 1, alpha))
	else:
		draw_circle(Vector2(0, -w * 0.4), w * 0.4, Color(0.8, 0.35, 0.35, alpha))
	draw_set_transform(Vector2.ZERO)
	if dying or max_hp <= 0.0:
		return
	# 체력 바: 보스만 크게, 잡몹은 얇게. 난전에서 남은 체력이 읽혀야 한다.
	# **반전 밖에서** 그린다 — 안에서 그리면 왼쪽 몹만 체력이 오른쪽부터 준다.
	#
	# 영웅 바와 **같은 방식**으로 그린다: 어두운 판을 깔고 채움을 1px 안쪽에.
	# 예전엔 채움을 판과 같은 사각형에 그려서 가득 찼을 때 판이 통째로 덮였다 —
	# 테두리가 없어 영웅 바와 이질감이 났다.
	draw_set_transform(Vector2(hit_offset(), 0.0))
	var bw := w * 0.8
	var bh := 7.0 if is_boss else 5.0
	var by := -w - 8.0
	draw_rect(Rect2(Vector2(-bw * 0.5, by), Vector2(bw, bh)), Color(0.03, 0.03, 0.04, 0.85))
	draw_rect(Rect2(Vector2(-bw * 0.5 + 1.0, by + 1.0),
		Vector2((bw - 2.0) * clampf(hp / max_hp, 0.0, 1.0), bh - 2.0)),
		Color(0.9, 0.25, 0.25) if is_boss else Color(0.85, 0.45, 0.35))
	draw_set_transform(Vector2.ZERO)
