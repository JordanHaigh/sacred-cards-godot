extends RefCounted
class_name AiAttackTagDatabase

## Value-based port of FindAiAttackTag from ai_turn.c.

const DATA_PATH := "res://resources/ai_attack_tags.json"

var _tags_by_pair: Dictionary = {}

func load_recovered_data() -> Error:
	if not FileAccess.file_exists(DATA_PATH):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or not parsed.get("attack_tags", []) is Array:
		return ERR_PARSE_ERROR
	var records: Dictionary = {}
	for row: Variant in parsed.attack_tags:
		if not row is Dictionary:
			return ERR_PARSE_ERROR
		var opponent_id := int(row.get("opponent", 0))
		var card_id := int(row.get("card", 0))
		var tag_id := int(row.get("tag", 0))
		if opponent_id <= 0 or card_id <= 0 or tag_id <= 0:
			return ERR_INVALID_DATA
		var key := _pair_key(opponent_id, card_id)
		if records.has(key):
			return ERR_INVALID_DATA
		records[key] = tag_id
	_tags_by_pair = records
	return OK

## Returns zero when the recovered C lookup would clear its output tag.
func find_attack_tag(opponent_id: int, card_id: int) -> int:
	return int(_tags_by_pair.get(_pair_key(opponent_id, card_id), 0))

func _pair_key(opponent_id: int, card_id: int) -> String:
	return "%d:%d" % [opponent_id & 0xFFFF, card_id & 0xFFFF]
