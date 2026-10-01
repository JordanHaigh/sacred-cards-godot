extends RefCounted
class_name CardStatRules

const TABLE_PATH := "res://resources/game_tables.json"
const TERRAIN_COUNT := 7
const CARD_TYPE_COUNT := 24
var _terrain_modifiers: Array[PackedByteArray] = []

func _init() -> void:
	if not FileAccess.file_exists(TABLE_PATH):
		push_error("Card terrain modifier table is missing: %s" % TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if not parsed is Dictionary or not parsed.get("gTerrainModifiers", null) is Array:
		push_error("Card terrain modifier table has an invalid structure.")
		return
	var flat: Array = parsed.gTerrainModifiers
	if flat.size() != TERRAIN_COUNT * CARD_TYPE_COUNT:
		push_error("Card terrain modifier table must contain 7 rows of 24 byte values.")
		return
	for terrain in range(TERRAIN_COUNT):
		var row := PackedByteArray()
		for card_type in range(CARD_TYPE_COUNT):
			var modifier: Variant = flat[terrain * CARD_TYPE_COUNT + card_type]
			if typeof(modifier) != TYPE_INT or int(modifier) < 0 or int(modifier) > 0xFF:
				_terrain_modifiers.clear()
				push_error("Card terrain modifier at row %d, type %d is not a byte." % [terrain, card_type])
				return
			row.append(int(modifier))
		_terrain_modifiers.append(row)

static func apply_stage(stat_input: int, stage_input: int) -> int:
	var stat := stat_input & 0xFFFF
	var stage := stage_input & 0xFF
	if stage >= 128:
		stage -= 256
	return clampi(stat + stage * 500, 0, 65534)

static func apply_terrain(stat_input: int, modifier_input: int) -> int:
	var stat := stat_input & 0xFFFF
	var result: int = stat
	match modifier_input & 0xFF:
		1: result = int(float(stat) * 0.7) & 0xFFFF
		3:
			result = int(float(stat) * 1.3) & 0xFFFF
			if result > 65533:
				result = 65534
	return result

func apply_card_modifiers(attack: int, defense: int, metadata_1a: int, card_type: int, terrain: int, stage: int) -> Dictionary:
	if (metadata_1a & 0xFF) != 2:
		return {"attack": attack & 0xFFFF, "defense": defense & 0xFFFF}
	var terrain_index := terrain & 0xFF
	var type_index := card_type & 0xFF
	if terrain_index >= _terrain_modifiers.size() or type_index >= CARD_TYPE_COUNT:
		return {"attack": attack & 0xFFFF, "defense": defense & 0xFFFF}
	var modifier: int = _terrain_modifiers[terrain_index][type_index]
	return {
		"attack": apply_stage(apply_terrain(attack, modifier), stage),
		"defense": apply_stage(apply_terrain(defense, modifier), stage),
	}
