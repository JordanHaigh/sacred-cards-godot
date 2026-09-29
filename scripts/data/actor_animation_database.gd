extends RefCounted
class_name ActorAnimationDatabase

## Texture-backed replacement for actor_graphics.c's GBA tile-sheet copy.
const DATA_PATH := "res://resources/actor_frames.json"

var _actors: Dictionary[int, Dictionary] = {}
var _walking_phases: Array[int] = []
var _special_frames: Array[int] = []
var _texture_cache: Dictionary[String, Texture2D] = {}

func load_recovered_data() -> Error:
	if not FileAccess.file_exists(DATA_PATH):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	_actors.clear()
	for value: Variant in parsed.get("actors", []):
		if value is Dictionary:
			_actors[int(value.get("id", -1))] = value
	_walking_phases.clear()
	for phase: Variant in parsed.get("walking_phases", []):
		_walking_phases.append(int(phase))
	_special_frames.clear()
	for frame: Variant in parsed.get("special_orientation_frames", []):
		_special_frames.append(int(frame))
	return OK if _actors.size() == 102 and _walking_phases.size() == 20 else ERR_INVALID_DATA

func walking_frame_index(orientation: int, animation_state: int) -> int:
	if orientation < 0 or orientation > 3 or animation_state < 0 or animation_state >= _walking_phases.size():
		return -1
	return orientation * 3 + _walking_phases[animation_state]

func is_special_orientation_frame(frame_index: int) -> bool:
	return frame_index in _special_frames

func special_frame_index(orientation: int) -> int:
	return _special_frames[orientation] if orientation >= 0 and orientation < _special_frames.size() else -1

func get_frame_texture(actor_id: int, frame_index: int, palette_index: int = 0) -> Texture2D:
	var actor: Dictionary = _actors.get(actor_id, {})
	var frames: Array = actor.get("frames", [])
	if frame_index < 0 or frame_index >= frames.size():
		return null
	var frame: Dictionary = frames[frame_index]
	if bool(frame.get("blank", false)):
		return null
	var images: Array = frame.get("images", [])
	if images.is_empty():
		return null
	var image_index := clampi(palette_index, 0, images.size() - 1)
	var path := str(images[image_index])
	if not _texture_cache.has(path):
		var texture := load(path) as Texture2D
		if texture == null:
			return null
		_texture_cache[path] = texture
	return _texture_cache[path]

func make_sprite(actor_id: int, frame_index: int, palette_index: int = 0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = get_frame_texture(actor_id, frame_index, palette_index)
	return sprite
