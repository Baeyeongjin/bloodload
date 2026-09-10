class_name CombatVfx
extends Node2D

# Slash/heavy origins: wielder's chest. Impact: target's chest. Slam: ground.
# World scrolling belongs to the caller; add the returned node to world_fx there.
const MAX_ALIVE := 36
const LIFE := {"slash1": 0.30, "slash2": 0.34, "slash3": 0.40,
	"impact": 0.20, "heavy": 0.52, "heavy_tell": 0.34,
	"slam": 0.48, "slam_tell": 0.44, "sweep": 0.36, "wave": 0.48,
	"field": 3.0, "ward": 6.0, "eye": 3.0, "crown": 3.0,
	"rain": 0.44, "eruption": 0.48, "vortex": 0.54, "bounce": 0.26,
	"foe_special": 0.40, "boss_floor": 0.40}
const DARK := Color("581529")
const BLOOD := Color("d62b4e")
const LIGHT := Color("ff6c78")
const IVORY := Color("fff1c9")
const DUST := Color("997c70")
const EARTH := Color("865135")
const AMBER := Color("db8b42")
const ORC_CORE := Color("ffd59b")

var _kind := "slash1"
var _age := 0.0
var _life := 0.30
var _power := 1.0
var _reach := 90.0
# Local forward coordinate: a left-facing effect mirrors this with the whole node.
# The attack range stays centered on the caller; only its club contact is offset.
var impact_x := 0.0
var ice_slam := false
var repeats := 1
var foe_theme := "rock"
var foe_core := Color("dbbd72")
var foe_edge := Color("72563d")


static func spawn(parent: Node, kind: String, at: Vector2, face := 1,
		power := 1.0) -> Node2D:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or not LIFE.has(kind):
		return null
	var live := parent.get_tree().get_nodes_in_group("combat_vfx")
	if live.size() >= MAX_ALIVE:
		# Budget overflow drops the oldest effect, never combat state or a live actor.
		live[0].remove_from_group("combat_vfx")
		live[0].queue_free()
	# Explicit loading also works before an editor import updates the class-name cache.
	var fx = (load("res://CombatVfx.gd") as GDScript).new()
	fx._kind = kind
	fx._life = float(LIFE[kind])
	fx._power = clampf(power, 0.65, 1.65)
	# Slam callers pass their actual combat radius / 90; preserve that reach exactly.
	fx._reach = maxf(1.0, power * 90.0)
	fx.position = at.round()
	fx.scale.x = -1.0 if face < 0 else 1.0
	fx.z_index = 8
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(fx)
	fx.add_to_group("combat_vfx")
	return fx


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	match _kind:
		"slash1", "slash2", "slash3", "heavy":
			_draw_slash()
		"impact":
			_draw_impact()
		"slam", "eruption":
			_draw_slam()
		"slam_tell":
			_draw_slam_tell()
		"heavy_tell":
			_draw_heavy_tell()
		"sweep", "wave", "vortex", "bounce":
			_draw_wave()
		"field":
			_draw_field()
		"ward":
			_draw_ward()
		"eye", "crown":
			_draw_sigil()
		"rain":
			_draw_rain()
		"foe_special":
			_draw_foe_special()
		"boss_floor":
			_draw_boss_floor()


func _draw_boss_floor() -> void:
	# Only the real affected radius; the sprite owns the decorative strike above it.
	var contact := clampf(1.0 - _age / 0.08, 0.0, 1.0)
	draw_line(Vector2(-_reach, 0).round(), Vector2(_reach, 0).round(),
		_ink(IVORY, contact * 0.9), 2, false)
	var travel := 1.0 - pow(1.0 - clampf(_age / 0.13, 0.0, 1.0), 2.0)
	var fade := pow(maxf(0.0, 1.0 - maxf(0.0, _age - 0.075) / (_life - 0.075)), 1.35)
	for side in [-1, 1]:
		var x := float(side) * _reach * travel
		var rear := x - float(side) * minf(14.0, absf(x))
		draw_line(Vector2(rear, 1).round(), Vector2(x, 1).round(), _ink(foe_edge, fade), 2, false)
		draw_line(Vector2(rear, 0).round(), Vector2(x, 0).round(),
			_ink(foe_core.lightened(0.15), fade * 0.8), 1, false)


func _draw_foe_special() -> void:
	# Hold the contact readable, then spend the rest of this short lifetime fading.
	var fade := pow(maxf(0.0, 1.0 - maxf(0.0, _age - 0.075) / (_life - 0.075)), 1.35)
	var travel := 1.0 - pow(1.0 - clampf(_age / 0.13, 0.0, 1.0), 2.0)
	var head := 0.35 + 0.65 * (1.0 - pow(1.0 - clampf(_age / 0.07, 0.0, 1.0), 3.0))
	var tail := clampf((_age - 0.025) / 0.23, 0.0, 1.0)
	var span := minf(_reach, 130.0)
	var core := foe_core.lightened(0.15)
	# The caller creates this on contact. A brief ground glint makes that instant
	# readable even before the travelling strokes unfold; no full-body flash.
	var contact := clampf(1.0 - _age / 0.08, 0.0, 1.0)
	draw_line(Vector2(-_reach, 0).round(), Vector2(_reach, 0).round(),
		_ink(IVORY, contact * 0.9), 2, false)
	_pixel(Vector2(0, -3), 5, _ink(IVORY, contact))
	# Sparse fronts mark the actual two-sided radius, independently of decoration.
	for side in [-1, 1]:
		var x := float(side) * _reach * travel
		var rear := x - float(side) * minf(14.0, absf(x))
		draw_line(Vector2(rear, 1).round(), Vector2(x, 1).round(), _ink(foe_edge, fade), 2, false)
		draw_line(Vector2(rear, 0).round(), Vector2(x, 0).round(), _ink(core, fade * 0.8), 1, false)
	match foe_theme:
		"soul", "arc", "cross", "lash":
			var strokes := 2 if foe_theme in ["soul", "cross"] else 1
			for i in strokes:
				var points: Array[Vector2]
				match foe_theme:
					"soul":
						points = [Vector2(0, -8 - i * 8), Vector2(span * 0.25, -57 - i * 7),
							Vector2(span * 0.64, -48 + i * 11), Vector2(span * 0.94, -3 + i * 3)]
					"lash":
						points = [Vector2(0, -6), Vector2(span * 0.27, -92),
							Vector2(span * 0.78, 15), Vector2(span, -13)]
					"cross":
						points = [Vector2(6, -44 if i == 0 else -3),
							Vector2(span * 0.30, -34 if i == 0 else -15),
							Vector2(span * 0.64, -15 if i == 0 else -34),
							Vector2(span * 0.94, -3 if i == 0 else -44)]
					_:
						points = [Vector2(6, -42), Vector2(span * 0.30, -60),
							Vector2(span * 0.64, -32), Vector2(span * 0.96, -2)]
				_ribbon(points, tail, head, 12.0 if foe_theme == "lash" else 10.0, _ink(foe_edge, fade))
				_ribbon(points, maxf(tail, head - 0.72), head, 5.0, _ink(core, fade))
				_ribbon(points, maxf(tail, head - 0.20), head, 3.0, _ink(IVORY, fade))
		"sonic":
			for i in 2:
				var progress := clampf((_age - i * 0.05) / 0.23, 0.0, 1.0)
				if progress <= 0.0 or progress >= 1.0:
					continue
				var x := progress * _reach
				var h := 8.0 + progress * 19.0
				var arc := PackedVector2Array()
				for j in 9:
					var y := lerpf(-h, h, float(j) / 8.0)
					arc.append(Vector2(x - absf(y) * 0.34, y - 17.0).round())
				draw_polyline(arc, _ink(foe_edge, (1.0 - progress) * fade), 6, false)
				draw_polyline(arc, _ink(core, (1.0 - progress) * fade), 3, false)
		"spray", "boil":
			for i in 6:
				var age := _age - float(i % 3) * 0.025
				if age < 0.0:
					continue
				var t := clampf(age / 0.26, 0.0, 1.0)
				var x := lerpf(8.0, span, float(i) / 5.0) * (0.25 + t * 0.75)
				var y := -sin(t * PI) * (16 + i % 3 * 8)
				if foe_theme == "boil":
					x = (float(i) / 5.0 - 0.5) * minf(_reach * 1.25, 130.0)
					y = -t * (18 + i % 3 * 7)
				_pixel(Vector2(x, y), 6, _ink(foe_edge, fade))
				_pixel(Vector2(x - 1, y - 1), 3, _ink(core, fade))
				_pixel(Vector2(x - 1, y - 2), 1, _ink(IVORY, fade * 0.8))
		"pillar":
			for i in 2:
				var x := float(i * 2 - 1) * 17.0
				var points: Array[Vector2] = [Vector2(x, 1), Vector2(x - 8, -17),
					Vector2(x + 8, -31), Vector2(x + 2, -44)]
				_ribbon(points, tail, head, 10, _ink(foe_edge, fade))
				_ribbon(points, maxf(tail, head - 0.65), head, 5, _ink(core, fade))
				_ribbon(points, maxf(tail, head - 0.20), head, 2, _ink(IVORY, fade))
		"crack":
			# Broken low floor fissures stay separate from upright crystal spikes.
			for side in [-1, 1]:
				var points := PackedVector2Array([Vector2(0, 0),
					Vector2(side * span * 0.24, -5).round(),
					Vector2(side * span * 0.46, 1).round(),
					Vector2(side * span * 0.71, -4).round(),
					Vector2(side * span * 0.92, 0).round()])
				draw_polyline(points, _ink(foe_edge, fade), 3, false)
				draw_polyline(points, _ink(core, fade * 0.8), 1, false)
			for i in 3:
				var x := lerpf(-span * 0.7, span * 0.7, float(i) / 2.0)
				var rise := sin(pow(clampf(_age / 0.28, 0.0, 1.0), 0.55) * PI)
				if rise < 0.02:
					continue
				var tip := Vector2(x + 3, -28.0 * rise).round()
				var shard := PackedVector2Array([Vector2(x - 7, 0).round(), tip,
					Vector2(x + 8, 0).round()])
				draw_colored_polygon(shard, _ink(foe_edge, fade))
				draw_line(tip, Vector2(x + 3, 0).round(), _ink(core, fade), 3, false)
				_pixel(tip, 2, _ink(IVORY, fade))
		_:
			# Rooted crystals, airborne debris and squat rock chips have distinct shapes.
			var count := 5 if foe_theme in ["crystal", "debris"] else 3
			for i in count:
				var x := lerpf(-span * 0.65, span * 0.65, float(i) / float(count - 1))
				var age := _age - absf(x) / maxf(span, 1.0) * 0.10
				if age < 0.0 or age >= 0.25:
					continue
				var rise := sin(pow(age / 0.25, 0.65) * PI)
				var height := (30.0 if foe_theme == "crystal" else 18.0) * rise
				if height < 0.5:
					continue
				if foe_theme == "debris":
					_pixel(Vector2(x, -height), 7, _ink(foe_edge, fade))
					_pixel(Vector2(x - 1, -height - 1), 3, _ink(core, fade))
				elif foe_theme == "rock":
					_pixel(Vector2(x, -height * 0.5), 8, _ink(foe_edge, fade))
					draw_line(Vector2(x - 2, -height * 0.5 - 2).round(),
						Vector2(x + 2, -height * 0.5 - 2).round(), _ink(core, fade), 2, false)
				else:
					var shard := PackedVector2Array([Vector2(x - 4, 1).round(),
						Vector2(x + 1, -height).round(), Vector2(x + 5, 1).round()])
					draw_colored_polygon(shard, _ink(foe_edge, fade))
					draw_line(Vector2(x + 1, -height).round(), Vector2(x + 3, 0).round(), _ink(core, fade), 3, false)
					_pixel(Vector2(x + 1, -height), 2, _ink(IVORY, fade))


func _ink(color: Color, opacity: float) -> Color:
	return Color(color, clampf(opacity, 0.0, 1.0))


func _pixel(at: Vector2, size: float, color: Color) -> void:
	var side := maxf(1.0, roundf(size))
	draw_rect(Rect2((at - Vector2.ONE * side * 0.5).round(), Vector2.ONE * side), color)


func _curve(points: Array[Vector2], t: float) -> Vector2:
	return points[0].bezier_interpolate(points[1], points[2], points[3], t)


# Two tapered edges form a directional curved blade. No circle, blur, or sprite rotation.
func _ribbon(points: Array[Vector2], tail: float, head: float, width: float, color: Color) -> void:
	if head - tail < 0.006 or color.a < 0.015:
		return
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in 19:
		var u := float(i) / 18.0
		var t := lerpf(tail, head, u)
		var p := _curve(points, t)
		var tangent := (_curve(points, minf(1.0, t + 0.008))
			- _curve(points, maxf(0.0, t - 0.008))).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half := width * 0.5 * pow(sin(u * PI), 0.65)
		upper.append((p + normal * half).round())
		lower.append((p - normal * half).round())
	# Pixel snapping can make a fading, narrow ribbon touch itself. A triangle strip
	# keeps those one-pixel tips drawable without asking the polygon tessellator
	# to resolve self-intersections or dropping an entire fading frame.
	for i in 18:
		for triangle in [PackedVector2Array([upper[i], lower[i], upper[i + 1]]),
				PackedVector2Array([lower[i], lower[i + 1], upper[i + 1]])]:
			if absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) >= 1.0:
				draw_primitive(triangle, PackedColorArray([color]), PackedVector2Array())


func _draw_slash() -> void:
	var points: Array[Vector2]
	var width := 8.0
	var sweep_time := 0.11
	match _kind:
		"slash2":
			points = [Vector2(8, 29), Vector2(54, 29), Vector2(91, -15), Vector2(72, -58)]
			width = 9.0
			sweep_time = 0.12
		"slash3":
			points = [Vector2(-10, -53), Vector2(34, -62), Vector2(91, -2), Vector2(106, 28)]
			width = 13.0
			sweep_time = 0.14
		"heavy":
			points = [Vector2(-8, -82), Vector2(71, -83), Vector2(101, -22), Vector2(111, 27)]
			width = 19.0
			sweep_time = 0.13
		_:
			points = [Vector2(-12, -9), Vector2(24, -33), Vector2(78, -20), Vector2(106, 9)]
	var head := 1.0 - pow(1.0 - clampf(_age / sweep_time, 0.0, 1.0), 3.0)
	var tail := pow(clampf((_age - 0.026) / (_life - 0.026), 0.0, 1.0), 1.35)
	var fade := pow(1.0 - _age / _life, 0.65)
	var thickness := width * sqrt(_power) * (0.72 + 0.28 * fade)
	_ribbon(points, tail, head, thickness * 1.45, _ink(DARK, fade * 0.85))
	_ribbon(points, tail, head, thickness, _ink(BLOOD, fade))
	_ribbon(points, maxf(tail, head - 0.70), head, thickness * 0.55, _ink(LIGHT, fade * 0.90))
	var hot := clampf(1.0 - _age / (sweep_time * 1.25), 0.0, 1.0)
	_ribbon(points, maxf(tail, head - 0.48), head, thickness * 0.26, _ink(IVORY, hot))
	for i in 10:
		var t := float(i + 1) / 11.0
		var elapsed := _age - (0.055 + t * sweep_time * 0.50)
		if elapsed < 0.0 or elapsed > 0.20:
			continue
		var tangent := (_curve(points, minf(1.0, t + 0.02)) - _curve(points, t)).normalized()
		var p := _curve(points, t) + tangent * elapsed * (38.0 + float(i) * 5.0)
		p.y += elapsed * elapsed * 135.0
		_pixel(p, 2.0 if i % 3 else 1.0, _ink(LIGHT if i % 3 else IVORY, (1.0 - elapsed / 0.20) * 0.75))
	if _kind == "heavy":
		# A short ground release closes the overhead stroke; this is not a projectile.
		var ground_age := maxf(0.0, _age - 0.060)
		var ground_head := clampf(ground_age / 0.11, 0.0, 1.0)
		var ground_tail := clampf((ground_age - 0.08) / 0.27, 0.0, 1.0)
		var ground: Array[Vector2] = [Vector2(23, 30), Vector2(51, 20), Vector2(107, 25), Vector2(134, 31)]
		_ribbon(ground, ground_tail, ground_head, 5.0, _ink(BLOOD, fade * 0.80))
		_ribbon(ground, ground_tail, ground_head, 1.5, _ink(IVORY, fade * hot))
		_draw_dust(12, 24.0, 109.0, 28.0, 0.10)


func _draw_impact() -> void:
	var progress := _age / _life
	var hot := clampf(1.0 - _age / 0.09, 0.0, 1.0)
	var radius := (11.0 + 8.0 * sqrt(clampf(_age / 0.025, 0.0, 1.0))) * sqrt(_power)
	if hot > 0.0:
		var star := PackedVector2Array([Vector2(-radius, -2), Vector2(-4, -4),
			Vector2(-1, -radius * 0.72), Vector2(3, -4), Vector2(radius * 1.35, 1),
			Vector2(4, 4), Vector2(1, radius * 0.68), Vector2(-3, 4)])
		for i in star.size():
			star[i] = star[i].round()
		draw_colored_polygon(star, _ink(BLOOD, hot))
		for i in star.size():
			star[i] = (star[i] * 0.67).round()
		draw_colored_polygon(star, _ink(IVORY, hot))
	for i in 14:
		var angle := lerpf(-1.10, 1.10, float(i) / 13.0)
		if i % 6 == 0:
			angle += PI
		var velocity := Vector2.from_angle(angle) * (125.0 + float((i * 47) % 190))
		var p := velocity * _age + Vector2(0, _age * _age * 220.0)
		var end := p + velocity.normalized() * lerpf(8.0, 2.0, progress)
		draw_line(p.round(), end.round(), _ink(IVORY if i % 3 else LIGHT, 1.0 - progress), 1.0 if i % 2 else 2.0, false)


func _draw_heavy_tell() -> void:
	var charge := _age / _life
	var points: Array[Vector2] = [Vector2(9, -10), Vector2(-3, -30), Vector2(7, -54), Vector2(32, -63)]
	_ribbon(points, 0.0, maxf(0.02, charge), 2.5, _ink(BLOOD, 0.4 + charge * 0.5))
	_pixel(Vector2(10, -12), 2.0 + charge * 3.0, _ink(IVORY, charge * 0.9))
	for i in 5:
		var p := Vector2(26 + i * 6, -64 + (i % 3) * 8).lerp(Vector2(10, -12), charge)
		_pixel(p, 2, _ink(LIGHT, sin(charge * PI)))


func _draw_slam_tell() -> void:
	var charge := _age / _life
	var opacity := 0.35 + charge * 0.60
	var strike := clampf(impact_x, -_reach, _reach)
	draw_line(Vector2(-_reach, 0), Vector2(_reach, 0), _ink(AMBER, opacity), 2, false)
	for side in [-1, 1]:
		var x := float(side) * _reach
		draw_line(Vector2(x, -6), Vector2(x, 3), _ink(AMBER, opacity), 2, false)
		draw_line(Vector2(x, 3), Vector2(x - float(side) * 11, 3), _ink(AMBER, opacity), 2, false)
		for i in 4:
			var travel := fmod(charge + float(i) * 0.20, 1.0)
			_pixel(Vector2(lerpf(float(side) * (_reach - 9), strike, travel), -2 - (i % 2) * 2), 2, _ink(AMBER, travel * 0.8))
	_pixel(Vector2(strike, -3), 2 + charge * 3, _ink(ORC_CORE, charge * 0.55))


func _draw_slam() -> void:
	var earth := Color("4c7992") if ice_slam else EARTH
	var edge := Color("07cde5") if ice_slam else AMBER
	var core := Color("d1eaf1") if ice_slam else ORC_CORE
	if _kind == "eruption":
		earth = DARK
		edge = BLOOD
		core = LIGHT
	var front := clampf(_age / 0.23, 0.0, 1.0)
	var strike := clampf(impact_x, -_reach, _reach)
	var fade := pow(1.0 - _age / _life, 1.4)
	for side in [-1, 1]:
		var s := float(side)
		var leading := lerpf(strike, s * _reach, 1.0 - pow(1.0 - front, 2.0))
		var wave := PackedVector2Array([Vector2(leading - s * 39, 2),
			Vector2(leading - s * 22, -4), Vector2(leading - s * 10, -12 * (1.0 - front)),
			Vector2(leading, 0), Vector2(leading - s * 12, 4)])
		for i in wave.size():
			wave[i].x = clampf(wave[i].x, -_reach, _reach)
			wave[i] = wave[i].round()
		draw_colored_polygon(wave, _ink(earth, fade))
		draw_line(Vector2(clampf(leading - s * 30, -_reach, _reach), 0).round(), Vector2(leading, 0).round(), _ink(edge, fade), 2, false)
	var spread := minf(_reach, 64.0 * sqrt(_power))
	for i in 8:
		var x := clampf(strike + (float(i) / 7.0 - 0.5) * spread * 2.0, -_reach + 8, _reach - 8)
		var distance := absf(x - strike) / spread
		var elapsed := _age - distance * 0.075
		if elapsed < 0.0 or elapsed > 0.20:
			continue
		var life := elapsed / 0.20
		var rise := sin(pow(life, 0.55) * PI)
		var height := (33.0 - distance * 12.0) * rise * sqrt(_power)
		var shard := PackedVector2Array([Vector2(x - 7, 0), Vector2(x - 3, -height * 0.45),
			Vector2(x + 2, -height), Vector2(x + 5, -height * 0.22), Vector2(x + 8, 1)])
		for j in shard.size():
			shard[j] = shard[j].round()
		draw_colored_polygon(shard, _ink(edge, 1.0 - life))
		if life < 0.33:
			draw_line(Vector2(x, 0).round(), Vector2(x + 2, -height).round(), _ink(core, (0.33 - life) * 2), 2, false)
	_draw_dust(16, -_reach * 0.87, _reach * 1.74, 0, 0.075)


func _draw_dust(count: int, start_x: float, span: float, floor_y: float, delay: float) -> void:
	for i in count:
		var elapsed := _age - delay - float(i % 4) * 0.018
		if elapsed < 0.0 or elapsed > 0.30:
			continue
		var x := start_x + span * float(i) / float(maxi(1, count - 1))
		var speed := 28.0 + float((i * 17) % 38)
		var p := Vector2(x + signf(x) * elapsed * 24.0,
			floor_y - elapsed * speed + elapsed * elapsed * 105.0)
		if _kind in ["slam", "eruption"]:
			p.x = clampf(p.x, -_reach + 2, _reach - 2)
		var tint := Color("7198ac") if ice_slam else (DUST if i % 4 else DARK)
		_pixel(p, 2 + (i % 3), _ink(tint, (1.0 - elapsed / 0.30) * 0.55))


# Skill ribbons stay thin: the effect describes travel while the actor remains visible.
# _reach is supplied from the affected on-screen span, never fed back into combat.
func _draw_wave() -> void:
	for beat in repeats:
		var age := _age - float(beat) * 0.12
		var duration := minf(0.48, _life - float(beat) * 0.12)
		if age < 0.0 or age >= duration:
			continue
		var points: Array[Vector2]
		var width := 10.0
		var rise := float(beat % 3) * 5.0
		match _kind:
			"sweep":
				points = [Vector2(0, 8), Vector2(_reach * 0.28, -21),
					Vector2(_reach * 0.72, -13), Vector2(_reach, 2)]
				width = 8.0
			"bounce":
				points = [Vector2(0, 0), Vector2(_reach * 0.32, -13),
					Vector2(_reach * 0.78, -10), Vector2(_reach, 0)]
				width = 5.0
			"vortex":
				points = [Vector2(-_reach * 0.7, -4), Vector2(_reach * 0.9, -55),
					Vector2(_reach * 0.9, 8), Vector2(-_reach * 0.65, 0)]
				width = 11.0
			_:
				points = [Vector2(0, -3 - rise), Vector2(_reach * 0.25, -42 - rise),
					Vector2(_reach * 0.73, -31 - rise), Vector2(_reach, -2)]
		var head := 1.0 - pow(1.0 - clampf(age / 0.12, 0.0, 1.0), 3.0)
		var tail := pow(clampf((age - 0.045) / (duration - 0.045), 0.0, 1.0), 1.3)
		var fade := pow(1.0 - age / duration, 0.85)
		_ribbon(points, tail, head, width * 1.5, _ink(DARK, fade * 0.55))
		_ribbon(points, tail, head, width, _ink(BLOOD, fade * 0.80))
		_ribbon(points, maxf(tail, head - 0.52), head, width * 0.36, _ink(LIGHT, fade))
		_ribbon(points, maxf(tail, head - 0.28), head, 1.5,
			_ink(IVORY, clampf(1.0 - age / 0.16, 0.0, 1.0)))
		if _kind == "wave" and repeats > 1 and age < 0.24:
			# Four bites keep the serpent skill distinct from the single tidal wave.
			var p := _curve(points, head).round()
			var jaw := PackedVector2Array([p + Vector2(-10, -5), p + Vector2(1, -4),
				p + Vector2(6, -1), p + Vector2(1, 0), p + Vector2(6, 3), p + Vector2(-9, 4)])
			draw_colored_polygon(jaw, _ink(BLOOD, fade))
			_pixel(p + Vector2(-3, -2), 2, _ink(IVORY, fade))
		for i in 7:
			var t := float(i + 1) / 8.0
			if t < tail or t > head:
				continue
			_pixel(_curve(points, t) + Vector2(-age * 24.0, 5 + i % 3 * 3),
				2, _ink(LIGHT, fade * 0.55))


func _held_opacity() -> float:
	return minf(clampf(_age / 0.12, 0.0, 1.0), clampf((_life - _age) / 0.22, 0.0, 1.0))


func _draw_field() -> void:
	var fade := _held_opacity()
	# A shallow broken seal, with the exact combat-radius endpoints on the ground.
	# No large opaque disc: ink collects in narrow fractures below the feet.
	for i in 24:
		var a := TAU * float(i) / 24.0
		var b := a + TAU / 24.0 * 0.72
		var p := Vector2(cos(a) * _reach, sin(a) * 9.0)
		var q := Vector2(cos(b) * _reach, sin(b) * 9.0)
		draw_line(p.round(), q.round(), _ink(BLOOD, fade * 0.65), 2, false)
	for i in 9:
		var x := lerpf(-_reach, _reach, float(i) / 8.0)
		var p := Vector2(x, -2 - i % 3 * 2)
		var q := p + Vector2(minf(15.0, _reach - x), -3 if i % 2 else 3)
		draw_line(p.round(), q.round(), _ink(DARK, fade * 0.8), 4, false)
		draw_line(p.round(), q.round(), _ink(LIGHT, fade * 0.32), 1, false)
		var drift := fmod(_age * 0.55 + float(i) * 0.17, 1.0)
		_pixel(Vector2(x, -3 - drift * 12), 2,
			_ink(BLOOD, fade * sin(drift * PI) * 0.45))


func _draw_ward() -> void:
	var fade := _held_opacity()
	# Split heraldic shield. The clear middle leaves the helmet, hands and sword open.
	for side in [-1, 1]:
		var s := float(side)
		var points := [Vector2(s * 7, -38), Vector2(s * 32, -27),
			Vector2(s * 30, 11), Vector2(s * 13, 32)]
		for i in 3:
			draw_line(points[i], points[i + 1], _ink(DARK, fade * 0.65), 4, false)
			draw_line(points[i], points[i + 1], _ink(BLOOD, fade * 0.62), 2, false)
		var travel := fmod(_age * 0.65 + (0.5 if side < 0 else 0.0), 3.0)
		var index := int(travel)
		var spark: Vector2 = points[index].lerp(points[index + 1], fmod(travel, 1.0))
		_pixel(spark, 3, _ink(LIGHT, fade * 0.8))
		_pixel(spark + Vector2(0, -3), 1, _ink(IVORY, fade * 0.6))


func _draw_sigil() -> void:
	var fade := _held_opacity()
	if _kind == "eye":
		for side in [-1, 1]:
			var lid: Array[Vector2] = [Vector2(-38, 0), Vector2(-14, side * 20),
				Vector2(17, side * 20), Vector2(38, 0)]
			_ribbon(lid, 0, 1, 3, _ink(BLOOD, fade * 0.78))
		_pixel(Vector2.ZERO, 12, _ink(DARK, fade * 0.8))
		draw_line(Vector2(0, -7), Vector2(0, 7), _ink(LIGHT, fade), 3, false)
		_pixel(Vector2(-1, -3), 2, _ink(IVORY, fade * 0.85))
	else:
		var crown := PackedVector2Array([Vector2(-16, -7), Vector2(-8, -2),
			Vector2(0, -12), Vector2(8, -2), Vector2(16, -7),
			Vector2(12, 6), Vector2(-12, 6), Vector2(-16, -7)])
		draw_polyline(crown, _ink(BLOOD, fade * 0.85), 3, false)
		draw_line(Vector2(-11, 3), Vector2(11, 3), _ink(LIGHT, fade), 2, false)
		_pixel(Vector2(0, -9), 2, _ink(IVORY, fade * 0.8))


func _draw_rain() -> void:
	# Short diagonal blood needles end at the floor, not in front of the face.
	for i in 7:
		var age := _age - float(i % 3) * 0.035
		if age < 0.0 or age > 0.26:
			continue
		var progress := clampf(age / 0.13, 0.0, 1.0)
		var x := lerpf(-_reach, _reach, float(i) / 6.0)
		var end := Vector2(x, lerpf(-68, 0, progress))
		var tail := end + Vector2(4, -13 * (1.0 - progress))
		var fade := 1.0 - age / 0.26
		draw_line(tail.round(), end.round(), _ink(BLOOD, fade * 0.8), 3, false)
		draw_line(tail.round(), end.round(), _ink(LIGHT, fade), 1, false)
		if progress >= 1.0:
			_pixel(Vector2(x + (age - 0.13) * 15.0, -(age - 0.13) * 22.0),
				2, _ink(LIGHT, fade))
