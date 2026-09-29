extends RefCounted
class_name CardDatabase

const DATA_PATH := "res://resources/card_database.json"

var _cards: Dictionary[int, CardDefinition] = {}

func load_recovered_data() -> Error:
	if not FileAccess.file_exists(DATA_PATH):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or not parsed.get("cards", []) is Array:
		return ERR_PARSE_ERROR
	_cards.clear()
	for row: Variant in parsed.cards:
		if not row is Dictionary:
			continue
		var definition := CardDefinition.from_dictionary(row)
		if definition.id > 0:
			_cards[definition.id] = definition
	return OK if _cards.size() == 900 else ERR_INVALID_DATA

func get_card(card_id: int) -> CardDefinition:
	return _cards.get(card_id) as CardDefinition

func get_card_count() -> int:
	return _cards.size()
