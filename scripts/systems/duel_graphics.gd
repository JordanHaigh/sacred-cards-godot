class_name DuelGraphics
extends RefCounted
## Godot-owned replacement for the GBA duel terrain loader.
## Each texture is reconstructed from the recovered tile, map and palette data.

const TERRAIN_COUNT := 7
const VIEW_COUNT := 2
const ARENA_PATH := "res://art/arenas/terrain-%d-view-%d.png"
const VIEWPORT_OFFSETS_PATH := "res://resources/duel_viewport_offsets.json"

# Byte-indexed ROM lookup from 0x08D4C2C1, ported as ordinary Godot data.
var viewport_offsets: Array[int] = []

var terrain_index := 0
var view_index := 0

func _init() -> void:
	_load_viewport_offsets()

func _load_viewport_offsets() -> bool:
	var file := FileAccess.open(VIEWPORT_OFFSETS_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open duel viewport offsets: %s" % VIEWPORT_OFFSETS_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("offsets", []) is Array:
		push_error("Duel viewport offset data has an invalid structure.")
		return false
	var raw_offsets: Array = parsed.offsets
	if raw_offsets.size() != 256:
		push_error("Duel viewport offset table must contain 256 byte-indexed entries.")
		return false
	viewport_offsets.clear()
	for value: Variant in raw_offsets:
		viewport_offsets.append(int(value) & 0xFF)
	return true

## Port of SetDuelViewportOffset(uint8_t): returns the ROM value for any byte view.
func viewport_offset(view: int) -> Dictionary:
	if viewport_offsets.size() != 256:
		return {"ok": false, "error": "viewport offset table must contain 256 entries", "offset": 0}
	var byte_view := view & 0xFF
	return {"ok": true, "view": byte_view, "offset": viewport_offsets[byte_view]}

func select(terrain: int, view: int) -> Dictionary:
	if terrain < 0 or terrain >= TERRAIN_COUNT:
		return {"ok": false, "error": "terrain index out of range", "texture": null}
	if view < 0 or view >= VIEW_COUNT:
		return {"ok": false, "error": "viewport index out of range", "texture": null}
	var path := ARENA_PATH % [terrain, view]
	if not ResourceLoader.exists(path):
		return {"ok": false, "error": "terrain texture missing: %s" % path, "texture": null}
	var viewport: Dictionary = viewport_offset(view)
	if not bool(viewport.get("ok", false)):
		return {"ok": false, "error": String(viewport.get("error", "invalid viewport")), "texture": null}
	terrain_index = terrain
	view_index = view
	return {
		"ok": true,
		"terrain": terrain_index,
		"view": view_index,
		"viewport_offset": int(viewport.offset),
		"texture_path": path,
		"texture": load(path) as Texture2D,
	}

func current_texture_path() -> String:
	return ARENA_PATH % [terrain_index, view_index]
