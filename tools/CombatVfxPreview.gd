extends SceneTree

const FX = preload("res://CombatVfx.gd")
const KINDS := ["slash1", "slash2", "slash3", "impact", "heavy_tell", "heavy", "slam_tell", "slam"]
var stage: Node2D
var label: Label


func _init() -> void:
	var profile := OS.get_environment("BLOODLORD_CAPTURE_PROFILE")
	if profile.is_empty() or OS.get_environment("APPDATA") != profile \
			or OS.get_environment("LOCALAPPDATA") != profile:
		push_error("An isolated capture profile is required.")
		quit(1)
		return
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(576, 360)
	root.content_scale_size = Vector2i(576, 360)
	stage = Node2D.new()
	root.add_child(stage)
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/bg/wide_ruins.png")
	bg.centered = false
	bg.scale = Vector2(2, 2)
	stage.add_child(bg)
	for actor in [["valentino_1_idle", Vector2(169, 260)], ["orc_walk", Vector2(230, 260)]]:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/anim/%s/0.png" % actor[0])
		sprite.position = actor[1]
		sprite.scale = Vector2(2, 2)
		sprite.flip_h = actor[0] == "valentino_1_idle"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stage.add_child(sprite)
	label = Label.new()
	label.position = Vector2(16, 14)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	stage.add_child(label)
	var folder := "res://build/qa/combat-vfx"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for kind in KINDS:
		var origin := Vector2(169, 260)
		var facing := 1
		var strength := 1.0
		if kind == "impact":
			origin = Vector2(230, 262)
		elif kind.begins_with("slam"):
			origin = Vector2(230, 290)
			facing = -1
			strength = 200.0 / 90.0
		var effect: Node2D = FX.spawn(stage, kind, origin, facing, strength)
		if kind.begins_with("slam"):
			effect.impact_x = 50.0
			assert(is_equal_approx(effect._reach, 200.0))
			assert(effect.to_global(Vector2(effect.impact_x, 0)).x == 180.0)
		effect.set_process(false)
		for frame in 36:
			effect._age = float(frame) / 60.0
			effect.visible = effect._age < effect._life
			effect.queue_redraw()
			label.text = "%s   %.3fs / %.2fs   |   60 FPS PIXEL VFX" % [kind.to_upper(), effect._age, effect._life]
			await process_frame
			await RenderingServer.frame_post_draw
			var error := root.get_texture().get_image().save_png("%s/%s-%02d.png" % [folder, kind, frame])
			assert(error == OK)
		effect.queue_free()
		await process_frame
	# Every kind releases itself; overflow caps effects without deleting actors.
	for i in 72:
		FX.spawn(stage, "impact", Vector2.ZERO)
	assert(get_nodes_in_group("combat_vfx").size() == FX.MAX_ALIVE)
	await create_timer(0.60).timeout
	assert(get_nodes_in_group("combat_vfx").is_empty())
	assert(FX.spawn(stage, "unknown", Vector2.ZERO) == null)
	print("COMBAT VFX PASS: 8 kinds / 288 real frames / budget36 / TTL / unknown guard")
	quit()
