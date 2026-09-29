class_name SceneGraphics
extends RefCounted
## Godot resource/composition replacement for scene_graphics.c. Backgrounds
## and portrait frames are textures; actors are ordered typed draw records.

const SCENE_DATA_PATH := "res://resources/scene_graphics.json"
const PORTRAIT_DATA_PATH := "res://resources/scene_portraits.json"
const SCREEN_RECT := Rect2(0, 0, 240, 160)

signal scene_background_changed(scene_id: int, variant: int, texture_path: String)
signal portrait_layer_requested(portrait_id: int, flags: int)
signal dialogue_window_changed(visible: bool)

var scenes: Dictionary = {}
var portraits: Dictionary[int, Dictionary] = {}
var texture_cache: Dictionary[String, Texture2D] = {}
var dialogue_visible := false

func load_recovered_data() -> Error:
	var scene_error := _load_json(SCENE_DATA_PATH, "scenes", scenes)
	if scene_error != OK: return scene_error
	var portrait_file := FileAccess.open(PORTRAIT_DATA_PATH, FileAccess.READ)
	if portrait_file == null: return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(portrait_file.get_as_text())
	if not parsed is Dictionary or not parsed.get("portraits", []) is Array: return ERR_PARSE_ERROR
	portraits.clear()
	for item: Variant in parsed.portraits:
		if item is Dictionary: portraits[int(item.get("id", -1))] = item
	return OK if scenes.size() == 58 and portraits.size() == 33 else ERR_INVALID_DATA

func scene_background(scene_id: int, variant: int = 0) -> Dictionary:
	var record: Dictionary = scenes.get(str(scene_id), {})
	if record.is_empty(): return {"ok": false, "error": "scene_id_out_of_range", "scene_id": scene_id}
	var variant_name := "alternate" if variant != 0 else "normal"
	var path := str(record.get(variant_name, record.get("normal", "")))
	var texture := _texture(path)
	if texture == null: return {"ok": false, "error": "scene_texture_missing", "path": path}
	scene_background_changed.emit(scene_id, variant, path)
	return {"ok": true, "scene_id": scene_id, "variant": variant, "texture_path": path, "texture": _screen_atlas(texture)}

## Stable descending-Y insertion order recovered from SortSceneActors.
func sort_actors(actors: Array[SceneActor]) -> Array[SceneActor]:
	var result: Array[SceneActor] = []
	for actor in actors:
		if actor == null: continue
		var insert_at := result.size()
		for index in range(result.size()):
			if actor.position.y > result[index].position.y:
				insert_at = index
				break
		result.insert(insert_at, actor)
	return result.slice(0, mini(result.size(), 15))

## Updates the actor's height from a typed scene cell when the native bounds
## predicate accepts its coordinates. Returns the resolved height offset.
func actor_height(actor: SceneActor, grid: SceneGrid) -> int:
	if actor == null or grid == null: return 0
	var x := actor.position.x
	var y := actor.position.y
	if x > 0 and x <= 119 and y > 0 and y <= 79:
		var cell := grid.cell_at(x, y)
		if (cell & 0xFE00) == 0: return (cell & 255) >> 1
	return 0

## Godot draw descriptors replace the packed OAM attributes and clipping tests.
func actor_draw_record(actor: SceneActor, height_offset: int, scene_cell: int) -> Dictionary:
	if actor == null: return {}
	var x := actor.position.x
	var y := actor.position.y
	return {
		"actor_id": actor.actor_id,
		"sprite_id": actor.sprite_id,
		"orientation": actor.orientation,
		"animation_state": actor.animation_state,
		"palette_index": actor.palette_index,
		"sprite_position": Vector2i(x * 2 - 16, y * 2 - height_offset - 24),
		"shadow_position": Vector2i(x * 2 - 8, y * 2 - height_offset),
		"sprite_visible": actor.sprite_id >= 0 and y > -32 and y < 104 and x > -16 and x < 136,
		"shadow_visible": actor.sprite_id >= 0 and (actor.flags & 1) != 0 and y > -32 and y < 104 and x > -16 and x < 136,
		"foreground_priority": (scene_cell & 0x100) == 0,
		"scene_cell": scene_cell,
	}

func portrait_frame_paths(portrait_id: int, portrait_flags: int = 0, frame_indices: Array[int] = []) -> Array[String]:
	var result: Array[String] = []
	if portrait_id <= 0: return result
	var portrait: Dictionary = portraits.get(portrait_id, {})
	var groups: Array = portrait.get("groups", [])
	var part_count := mini(3 + (1 if (portrait_flags & 1) != 0 else 0), groups.size())
	for part in range(part_count):
		var frames: Array = groups[part]
		if frames.is_empty(): continue
		var frame_index := int(frame_indices[part]) if part < frame_indices.size() else 0
		var frame: Dictionary = frames[clampi(frame_index, 0, frames.size() - 1)]
		result.append(str(frame.get("image", "")))
	return result

func create_portrait_layer(parent: Control, portrait_id: int, portrait_flags: int = 0, frame_indices: Array[int] = []) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 2
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in portrait_frame_paths(portrait_id, portrait_flags, frame_indices):
		var texture := _texture(path)
		if texture == null: continue
		var part := TextureRect.new()
		part.texture = texture
		part.position = Vector2.ZERO
		part.size = Vector2(240, 160)
		part.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		part.stretch_mode = TextureRect.STRETCH_SCALE
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(part)
	parent.add_child(layer)
	portrait_layer_requested.emit(portrait_id, portrait_flags)
	return layer

func set_dialogue_window_visible(visible: bool) -> Dictionary:
	dialogue_visible = visible
	dialogue_window_changed.emit(visible)
	return {"visible": visible, "rect": Rect2(0, 105, 240, 55) if visible else Rect2(), "blend_alpha": 0.86 if visible else 0.0}

func _load_json(path: String, key: String, destination: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get(key, {}) is Dictionary: return ERR_PARSE_ERROR
	destination.clear()
	destination.merge(parsed[key], true)
	return OK

func _texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	if not texture_cache.has(path):
		var loaded := load(path) as Texture2D
		if loaded == null: return null
		texture_cache[path] = loaded
	return texture_cache[path]

func _screen_atlas(texture: Texture2D) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 240, 160)
	return atlas
