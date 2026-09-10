extends SceneTree

# Render the production Main impact path; only save/gameplay/shake are muted.
class ReviewMain extends "res://Main.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _shake_combat(_amount: float) -> void:
		pass

const OUTPUT := "res://build/qa/boss-pixel-vfx"
const RADIUS := 140.0 # Comparison cells share a radius; this is not a combat-range test.

func _init() -> void:
	var profile := OS.get_environment("BLOODLORD_CAPTURE_PROFILE")
	if profile.is_empty() or OS.get_environment("APPDATA") != profile \
			or OS.get_environment("LOCALAPPDATA") != profile \
			or not profile.replace("\\", "/").begins_with(ProjectSettings.globalize_path("res://build/qa/")):
		push_error("FoeVfxReview requires one disposable build/qa profile in both APPDATA variables")
		quit(1)
		return
	create_timer(90.0).timeout.connect(func() -> void: quit(1))
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 1000)
	root.content_scale_size = Vector2i(1280, 1000)
	RenderingServer.set_default_clear_color(Color("242834"))
	var stage := ReviewMain.new()
	stage.save_muted = true
	stage.hero_x = -1000.0 # Main's inherited draw keeps its single HUD marker off the grid.
	root.add_child(stage)
	assert(not Foe.pixel_motion_pilot, "VFX review must use the restored original art")
	var keys: Array = FoeTiers.SPECIAL_KIND.keys()
	keys.append("rock")
	assert(keys.size() == 17)
	var effects: Array[AnimatedSprite2D] = []
	var floors: Array[Node2D] = []
	var observations: Array = []
	var boss_art := {"wraith_knight": "boss_1", "gargoyle": "boss_2",
		"frost_golem": "boss_3", "eye_mass": "boss_4", "dark_knight": "boss_5", "rock": "orc"}
	for index in keys.size():
		var key := str(keys[index])
		var cell := Vector2(index % 4 * 320, floori(index / 4.0) * 200)
		var at := cell + Vector2(166, 166)
		var floor_line := Line2D.new()
		floor_line.points = PackedVector2Array([at + Vector2(-150, 2), at + Vector2(150, 2)])
		floor_line.width = 1
		floor_line.default_color = Color("444b57")
		stage.add_child(floor_line)
		var actor := str(boss_art.get(key, key))
		var contact_frame := int(Foe.SPECIAL_CONTACT.get(actor, 0))
		var actor_path := "res://assets/anim/%s_special/%d.png" % [actor, contact_frame]
		if not ResourceLoader.exists(actor_path):
			actor_path = "res://assets/anim/%s_walk/0.png" % actor
		_original_sprite(stage, actor_path, at, false)
		_original_sprite(stage, "res://assets/anim/valentino_1_idle/0.png", at + Vector2(-78, 0), true)
		stage.ground_y = at.y
		var before := stage.get_child_count()
		stage._boss_impact_fx(at.x, RADIUS, key, -1, 0.0)
		var sprite: AnimatedSprite2D
		var floor_fx: Node2D
		for child in stage.get_children().slice(before):
			if child is AnimatedSprite2D:
				sprite = child
			elif child is CombatVfx:
				floor_fx = child
		assert(sprite != null and floor_fx != null, "Missing production pixel impact: " + key)
		assert(sprite.sprite_frames.get_frame_count("play") == 12, "Incomplete effect: " + key)
		assert(sprite.z_index == 4 and sprite.offset == Vector2(0, -16))
		assert(sprite.scale == Vector2(-2, 2) and sprite.position == at)
		assert(floor_fx.get("_kind") == "boss_floor" and floor_fx.z_index == 0)
		assert(is_equal_approx(float(floor_fx.get("_reach")), RADIUS))
		sprite.pause()
		floor_fx.set_process(false)
		effects.append(sprite)
		floors.append(floor_fx)
		var title := Label.new()
		title.text = key
		title.position = cell + Vector2(12, 7)
		title.add_theme_font_size_override("font_size", 17)
		title.z_index = 10
		stage.add_child(title)
		var caption := Label.new()
		caption.text = "%s f%d | original 2x | radius 140" % [actor, contact_frame]
		caption.position = cell + Vector2(12, 179)
		caption.add_theme_font_size_override("font_size", 12)
		caption.modulate = Color("a7a9b5")
		caption.z_index = 10
		stage.add_child(caption)
		observations.append({"key": key, "actor": actor_path, "position": [at.x, at.y],
			"radius": RADIUS, "sprite_z": sprite.z_index, "floor_z": floor_fx.z_index,
			"scale": [sprite.scale.x, sprite.scale.y], "frames": 12})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for age in [0.0, 0.045, 0.11, 0.20, 0.34]:
		for fx in effects:
			fx.set_frame_and_progress(mini(11, floori(age * 30.0)), 0.0)
		for floor_fx in floors:
			floor_fx.set("_age", age)
			floor_fx.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("%s/themes-%03d.png" % [OUTPUT, roundi(age * 1000)]) == OK)
	var report := FileAccess.open(OUTPUT + "/renderer-review.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"path": "Main._boss_impact_fx", "original_art": true,
		"sample_ms": [0, 45, 110, 200, 340], "records": observations}, "\t"))
	report.close()
	for fx in effects:
		fx.frame = 0
		fx.play("play")
	for floor_fx in floors:
		floor_fx.set("_age", 0.0)
		floor_fx.set_process(true)
	await create_timer(0.46).timeout
	await process_frame
	for fx in effects:
		assert(not is_instance_valid(fx), "Pixel impact outlived its 0.40-second animation")
	for floor_fx in floors:
		assert(not is_instance_valid(floor_fx), "Floor impact outlived its 0.40-second limit")
	print("FoeVfxReview OK: 17 production pixel impacts, original sprites, five ages, real 0.40-second lifetime")
	quit(0)

func _original_sprite(parent: Node, texture_path: String, ground: Vector2, flip: bool) -> void:
	var texture := Assets.tex(texture_path)
	assert(texture != null, "Missing original VFX review sprite: " + texture_path)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2, 2)
	sprite.flip_h = flip
	sprite.z_index = 3 if flip else 1
	sprite.position = ground - Vector2(0, (float(texture.get_height()) * 0.5 - Assets.bottom_gap(texture)) * 2.0)
	parent.add_child(sprite)
