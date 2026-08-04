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

var _walk_frames: Array = []
var _attack_frames: Array = []
var _sprite: Texture2D = null
var _anim_t := 0.0
var _flash_t := 0.0
var _hit_t := 0.0
var _visual_frozen := false
var _attack_cd := 0.0
var _attack_anim := -1.0
var _impact_sent := false
var dying := false
var dying_t := 0.0
const DIE_DUR := 0.26
const ATTACK_DUR := 0.42
# 타격 지점을 **프레임 번호가 아니라 모션 길이의 비율**로 잡는다.
# 고정 번호(3)로 두면 프레임 수가 다른 모션에서 지점이 밀린다 — 실제로 새로 들어온
# boss_1~5_attack 이 9프레임이라 타격이 43%가 아니라 33% 지점에서 나가고 있었다.
# 비율로 두면 7·8·9프레임 어디에 붙여도 그린 자세와 타격이 계속 맞는다.
const IMPACT_RATIO := 3.0 / 7.0   # 원래 기준: 7프레임 중 네 번째
const HIT_REACT_DUR := 0.14
const HIT_KNOCKBACK := 7.0


func setup(tier: Dictionary, power: float, stage_gold: float, boss: bool = false) -> void:
	key = str(tier.get("key", "slime"))
	is_boss = boss
	is_midboss = bool(tier.get("midboss", false))
	display_name = "%s%s" % [str(tier.get("name_prefix", "")), str(tier.get("name", key))]
	hp_mult = float(tier.get("hp_mult", 1.0))
	body_scale = float(tier.get("size", 1.0))
	# 보스·중간보스는 한 마리로 단계를 막는다.
	var boss_mult := 12.0 if boss else (3.5 if is_midboss else 1.0)
	max_hp = 10.0 * hp_mult * power * boss_mult
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
	_attack_cd = attack_interval()
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


func _tick_attack(delta: float) -> void:
	if not combat_active:
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
		_attack_anim = 0.0
		_impact_sent = false


# 그림자 반지름. Main 이 발밑에 깔아 준다.
func shadow_r() -> float:
	return _size() * 0.30


func _size() -> float:
	var hero_scale := maxf(2.0, body_scale * 2.0) if is_boss or is_midboss else body_scale
	return float(Grid.SPRITE) * 2.0 * hero_scale


# 맞으면 **온 길 쪽으로** 밀린다. 부호를 고정하면 왼쪽에서 온 몹이 맞을 때
# 영웅 쪽으로 파고들어 때린 게 아니라 달려든 것처럼 보인다.
func hit_offset() -> float:
	return HIT_KNOCKBACK * clampf(_hit_t / HIT_REACT_DUR, 0.0, 1.0) * float(-face)


# 이 몹의 공격이 닿는 거리. 영웅이 이 밖으로 나가면 헛친다 — 대시로 피할 여지가
# 생겨야 "달려가서 팬다"가 전투가 된다.
func reach() -> float:
	return _size() * 0.5 + 44.0


func _draw() -> void:
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
		# 죽음: 발은 붙인 채로 가로로 퍼지고 세로로 눌린다. 파티클 없이 스쿼시만.
		var f := dying_t / DIE_DUR
		wsc = 1.0 + 0.35 * f
		hsc = 1.0 - 0.55 * f
		alpha = 1.0 - f
	var tex: Texture2D = _sprite
	if not dying and _attack_anim >= 0.0 and not _attack_frames.is_empty():
		var attack_i := mini(int(_attack_anim * float(_attack_frames.size()) / ATTACK_DUR),
			_attack_frames.size() - 1)
		tex = _attack_frames[attack_i]
	elif not dying and not _walk_frames.is_empty():
		tex = _walk_frames[int(_anim_t * 8.0) % _walk_frames.size()]
	if tex:
		# 몹은 왼쪽(플레이어)을 본다. 원본이 왼쪽 향함이라 그대로 그린다.
		draw_texture_rect(tex,
			Rect2(Vector2(-w * wsc * 0.5, -w * hsc), Vector2(w * wsc, w * hsc)),
			false, Color(1, 1, 1, alpha))
	else:
		draw_circle(Vector2(0, -w * 0.4), w * 0.4, Color(0.8, 0.35, 0.35, alpha))
	draw_set_transform(Vector2.ZERO)
	if dying or max_hp <= 0.0:
		return
	# 체력 바: 보스만 크게, 잡몹은 얇게. 난전에서 남은 체력이 읽혀야 한다.
	# **반전 밖에서** 그린다 — 안에서 그리면 왼쪽 몹만 체력이 오른쪽부터 준다.
	draw_set_transform(Vector2(hit_offset(), 0.0))
	var bw := w * 0.8
	var bh := 4.0 if is_boss else 2.0
	var by := -w - 8.0
	draw_rect(Rect2(Vector2(-bw * 0.5, by), Vector2(bw, bh)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(Vector2(-bw * 0.5, by), Vector2(bw * clampf(hp / max_hp, 0.0, 1.0), bh)),
		Color(0.9, 0.25, 0.25) if is_boss else Color(0.85, 0.45, 0.35))
	draw_set_transform(Vector2.ZERO)
