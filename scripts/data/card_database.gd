extends RefCounted
class_name CardDatabase

const DATA_PATH := "res://resources/card_database.json"
const DETAIL_TERMS_PATH := "res://resources/card_detail_terms.json"

var _cards: Dictionary[int, CardDefinition] = {}

func load_recovered_data() -> Error:
	if not FileAccess.file_exists(DATA_PATH):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or not parsed.get("cards", []) is Array:
		return ERR_PARSE_ERROR
	if not FileAccess.file_exists(DETAIL_TERMS_PATH):
		return ERR_FILE_NOT_FOUND
	var terms: Variant = JSON.parse_string(FileAccess.get_file_as_string(DETAIL_TERMS_PATH))
	if not terms is Dictionary or not terms.get("types", null) is Dictionary or not terms.get("summons", null) is Dictionary:
		return ERR_PARSE_ERROR
	var type_names: Dictionary = terms.types
	var summon_names: Dictionary = terms.summons
	_cards.clear()
	for row: Variant in parsed.cards:
		if not row is Dictionary:
			continue
		var definition := CardDefinition.from_dictionary(row)
		definition.type_name = str(type_names.get(str(definition.card_type), ""))
		definition.summon_name = str(summon_names.get(str(definition.attribute), ""))
		if definition.id > 0:
			_cards[definition.id] = definition
	return OK if _cards.size() == 900 else ERR_INVALID_DATA

func get_card(card_id: int) -> CardDefinition:
	return _cards.get(card_id) as CardDefinition

func get_card_count() -> int:
	return _cards.size()
