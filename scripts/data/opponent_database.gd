extends RefCounted
class_name OpponentDatabase

const DATA_PATH := "res://resources/opponents.json"
var opponents: Array[Dictionary] = []
var reward_tables: Dictionary = {}
var special_wager_cards: Dictionary[int, bool] = {}

func load_recovered_data() -> Error:
	if not FileAccess.file_exists(DATA_PATH):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	opponents.clear()
	for record: Variant in parsed.get("opponents", []):
		if record is Dictionary:
			opponents.append(record)
	reward_tables = parsed.get("reward_tables", {})
	special_wager_cards.clear()
	for card_id: Variant in parsed.get("special_wager_cards", []):
		if int(card_id) > 0:
			special_wager_cards[int(card_id)] = true
	return OK if opponents.size() == 200 else ERR_INVALID_DATA

func get_opponent(opponent_id: int) -> Dictionary:
	if opponent_id < 0 or opponent_id >= opponents.size():
		return {}
	return opponents[opponent_id]
