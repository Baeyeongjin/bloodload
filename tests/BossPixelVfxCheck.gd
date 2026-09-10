extends SceneTree

# Real Main effect playback, with UI and save loading disabled.
# APPDATA and LOCALAPPDATA must share a new build/qa/*boss-pixel-vfx* profile.
class Arena extends "res://Main.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _shake_combat(_amount: float) -> void:
		pass
	func play_boss(key: String, at_x: float, radius: float, face: int) -> Array[Node]:
		var before := get_child_count()
		super._boss_impact_fx(at_x, radius, key, face)
		return get_children().slice(before)


var arena: Arena
var effects: Array[Node] = []
var sets := 0
var frames_checked := 0


func _init() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\", "/")
	var qa := ProjectSettings.globalize_path("res://build/qa/").replace("\\", "/")
	if profile.is_empty() or profile != OS.get_environment("LOCALAPPDATA").replace("\\", "/") \
			or not profile.begins_with(qa) or not profile.contains("boss-pixel-vfx"):
		push_error("BossPixelVfxCheck requires one disposable build/qa/*boss-pixel-vfx* profile in both APPDATA variables")
		quit(1)
		return
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("BossPixelVfxCheck timed out")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	arena = Arena.new()
	arena.save_muted = true
	root.add_child(arena)
	arena.ground_y = 320.0
	var keys: Array = FoeTiers.SPECIAL_KIND.keys()
	keys.append("orc") # Uses the default rock sprite set through Main's real fallback key.
	for key in keys:
		var art_key := str(key) if FoeTiers.SPECIAL_KIND.has(key) else "rock"
		if _check_source(art_key) != true or _check_playback(str(key), art_key) != true:
			quit(1)
			return
		sets += 1
	await create_timer(0.5).timeout
	for effect in effects:
		if is_instance_valid(effect):
			push_error("Boss VFX remained alive after 0.5 seconds")
			quit(1)
			return
	arena.queue_free()
	await process_frame
	print("BossPixelVfxCheck OK: %d sets, %d source frames; uniform 30fps, 2x anchored sprites, exact floor ranges, cleanup" % [sets, frames_checked])
	quit(0)


func _check_source(art_key: String) -> bool:
	var path := "res://assets/anim/boss_vfx/" + art_key
	var directory := DirAccess.open(path)
	assert(directory != null, "Missing boss pixel VFX directory: " + art_key)
	var png_count := 0
	for file in directory.get_files():
		if file.get_extension().to_lower() == "png":
			png_count += 1
	assert(png_count == 12, "Boss VFX requires exactly 12 PNG files: " + art_key)
	var visible := 0
	for i in 12:
		var file := "%s/%d.png" % [path, i]
		assert(FileAccess.file_exists(file), "Missing numbered boss VFX frame: " + file)
		var image := (load(file) as Texture2D).get_image()
		assert(image != null and image.get_size() == Vector2i(128, 64), "Wrong boss VFX frame size: " + file)
		var used := image.get_used_rect()
		if used.has_area():
			visible += 1
			assert(used.position.x > 0 and used.position.y > 0 and used.end.x < 128 and used.end.y < 64,
				"Visible ink touches the outermost canvas border: " + file)
		if i == 11:
			assert(not used.has_area(), "Last boss VFX frame must be fully transparent: " + art_key)
		frames_checked += 1
	assert(visible >= 9, "Boss VFX contains fewer than 9 visible frames: " + art_key)
	return true


func _check_playback(key: String, art_key: String) -> bool:
	var face := -1 if sets % 2 == 0 else 1
	var at_x := 240.0 + float(sets)
	var radius := 92.0 + float(sets) * 7.0
	var nodes := arena.play_boss(key, at_x, radius, face)
	assert(nodes.size() == 2, "Boss impact must create one sprite and one floor pulse: " + key)
	var sprite: AnimatedSprite2D
	var floor_effect: CombatVfx
	for node in nodes:
		effects.append(node)
		if node is AnimatedSprite2D:
			sprite = node
		elif node is CombatVfx:
			floor_effect = node
	assert(sprite != null, "Boss impact fell back instead of playing the new sprite: " + key)
	assert(floor_effect != null and floor_effect._kind == "boss_floor", "Boss impact has no dedicated floor pulse: " + key)
	assert(sprite.position == Vector2(at_x, arena.ground_y), "Boss sprite moved away from its real impact center: " + key)
	assert(sprite.offset == Vector2(0, -16) and sprite.centered, "Boss sprite lost its (64,48) source anchor: " + key)
	assert(sprite.scale == Vector2(2 * face, 2) and is_zero_approx(sprite.skew) and is_zero_approx(sprite.rotation),
		"Boss sprite scale, direction or shape was distorted: " + key)
	assert(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and sprite.z_index == 4,
		"Boss sprite filtering or layer changed: " + key)
	assert(sprite.is_in_group(arena.WORLD_FX_GROUP) and floor_effect.is_in_group(arena.WORLD_FX_GROUP),
		"Boss sprite or floor pulse is detached from world scrolling: " + key)
	assert(sprite.animation == "play" and sprite.is_playing(), "Boss sprite animation never started: " + key)
	var animation := sprite.sprite_frames
	assert(animation.get_frame_count("play") == 12 and is_equal_approx(animation.get_animation_speed("play"), 30.0),
		"Boss sprite does not play its 12 frames at 30fps: " + key)
	assert(not animation.get_animation_loop("play"), "Boss sprite incorrectly loops: " + key)
	for i in 12:
		assert(is_equal_approx(animation.get_frame_duration("play", i), 1.0), "Boss VFX frame duration is not uniform: " + key)
		assert(animation.get_frame_texture("play", i).resource_path == "res://assets/anim/boss_vfx/%s/%d.png" % [art_key, i],
			"Boss VFX selected the wrong per-boss palette/frame: " + key)
	assert(floor_effect.position == Vector2(at_x, arena.ground_y) and floor_effect.z_index == 0,
		"Boss floor pulse has the wrong impact center or layer: " + key)
	assert(is_equal_approx(floor_effect._reach, radius), "Boss floor pulse differs from the real damage radius: " + key)
	var theme := FoeTiers.slam_theme(key)
	assert(floor_effect.foe_core == theme[1] and floor_effect.foe_edge == theme[2], "Boss floor pulse lost its individual palette: " + key)
	return true
