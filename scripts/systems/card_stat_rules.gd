extends RefCounted
class_name CardStatRules

const TABLE_PATH := "res://resources/game_tables.json"
var _terrain_modifiers: Array = []

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if parsed is Dictionary:
		var flat: Array = parsed.get("gTerrainModifiers", [])
		for terrain in range(7):
			_terrain_modifiers.append(flat.slice(terrain * 24, (terrain + 1) * 24))

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
	if terrain_index >= _terrain_modifiers.size() or type_index >= 24:
		return {"attack": attack & 0xFFFF, "defense": defense & 0xFFFF}
	var modifier: int = _terrain_modifiers[terrain_index][type_index]
	return {
		"attack": apply_stage(apply_terrain(attack, modifier), stage),
		"defense": apply_stage(apply_terrain(defense, modifier), stage),
	}
