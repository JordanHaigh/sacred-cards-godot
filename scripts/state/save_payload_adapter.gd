extends RefCounted
class_name SavePayloadAdapter

## Maps the named Godot save model to the recovered native payload regions.
## Unknown bytes can be preserved in extensions.raw_payload_regions.
const CODEC := preload("res://scripts/state/save_payload_codec.gd")

static func regions_for_save(save: PlayerSaveData) -> Dictionary:
	var preserved: Variant = save.extensions.get("raw_payload_regions", {})
	var regions: Dictionary = preserved.duplicate(true) if preserved is Dictionary else {}
	regions["player_name_17_bytes"] = _name_region(save, regions)
	regions["unknown_02020770"] = _byte_region(save.collection_counts, 901)
	regions["player_deck_40_u16"] = _word_region(save.deck, 40)
	regions["deck_capacity_u32"] = _integer_bytes(save.deck_capacity, 4)
	regions["duelist_level_u32"] = _integer_bytes(save.duelist_level, 4)
	regions["unknown_02020CB0"] = _word_region(_as_array(save.extensions.get("duel_record_header", [0, 0])), 2)
	regions["unknown_02020CB4"] = _matrix_word_region(save.extensions.get("duel_records", []), 25, 2)
	regions["unknown_02020DA8"] = PackedByteArray([int(save.extensions.get("progress_rank", 1)) & 0xFF])
	regions["unknown_02020DB0"] = _byte_region(save.shop_stock, 901)
	regions["money_u64"] = _integer_bytes(save.money, 8)
	regions["event_flags_first_32_bytes"] = _byte_region(save.event_flags, 32)
	regions["unknown_020237CC"] = _integer_bytes(save.random_state, 4)
	regions["unknown_020237C4"] = _byte_region(_as_array(save.extensions.get("scene_persistent_flags", [0, 0])), 2)
	return regions

static func pack_save(save: PlayerSaveData) -> PackedByteArray:
	return CODEC.pack_regions(regions_for_save(save))

static func _name_region(save: PlayerSaveData, preserved: Dictionary) -> PackedByteArray:
	var raw: Variant = preserved.get("player_name_17_bytes", PackedByteArray())
	if raw is PackedByteArray and raw.size() == 17:
		return raw.duplicate()
	var bytes := save.player_name.to_utf8_buffer()
	bytes.resize(17)
	return bytes

static func _byte_region(values: Variant, count: int) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(count)
	for index in range(count):
		if values is Array and index < values.size():
			output[index] = int(values[index]) & 0xFF
		elif values is PackedByteArray and index < values.size():
			output[index] = values[index]
	return output

static func _word_region(values: Array, count: int) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(count * 2)
	for index in range(count):
		var value := int(values[index]) & 0xFFFF if index < values.size() else 0
		output[index * 2] = value & 0xFF
		output[index * 2 + 1] = (value >> 8) & 0xFF
	return output

static func _matrix_word_region(value: Variant, rows: int, columns: int) -> PackedByteArray:
	var flattened: Array[int] = []
	if value is Array:
		for row in range(rows):
			var row_values: Variant = value[row] if row < value.size() else []
			for column in range(columns):
				flattened.append(int(row_values[column]) if row_values is Array and column < row_values.size() else 0)
	return _word_region(flattened, rows * columns)

static func _integer_bytes(value: int, count: int) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(count)
	var unsigned_value := value
	for index in range(count):
		output[index] = unsigned_value & 0xFF
		unsigned_value >>= 8
	return output

static func _as_array(value: Variant) -> Array:
	return value if value is Array else []
