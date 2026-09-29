extends RefCounted
class_name NewGameState

const TABLE_PATH := "res://resources/game_tables.json"

static func initialize() -> PlayerSaveData:
	var save := PlayerSaveData.new()
	var tables: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if not tables is Dictionary:
		push_error("Recovered initial game tables could not be loaded.")
		return save
	save.player_name = ""
	save.collection_counts = _int_array(tables.get("gInitialCardCollection", []), 901)
	save.deck = _int_array(tables.get("gInitialDeck", []), 40)
	save.deck_capacity = 1600
	save.duelist_level = 72
	save.shop_stock = _int_array(tables.get("gInitialShopStock", []), 901)
	save.money = 500
	save.random_state = 1
	save.event_flags.fill(0)
	save.extensions = {
		"duel_records": _zero_matrix(25, 2),
		"duel_record_header": [0, 0],
		"progress_rank": 1,
		"scene_persistent_flags": [0, 0],
	}
	return save

static func add_collection_card(save: PlayerSaveData, card_id: int, count: int) -> void:
	if card_id <= 0 or card_id >= save.collection_counts.size():
		return
	save.collection_counts[card_id] = mini(250, save.collection_counts[card_id] + count)

static func _int_array(values: Variant, size: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(size):
		result.append(int(values[index]) if values is Array and index < values.size() else 0)
	return result

static func _zero_matrix(rows: int, columns: int) -> Array:
	var result: Array = []
	for _row in range(rows):
		var row: Array[int] = []
		row.resize(columns)
		result.append(row)
	return result
