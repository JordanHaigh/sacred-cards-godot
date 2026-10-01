extends RefCounted
class_name CardDatabase

const DATA_PATH := "res://resources/card_database.json"
const DETAIL_TERMS_PATH := "res://resources/card_detail_terms.json"
const GAME_TABLES_PATH := "res://resources/game_tables.json"
const CARD_NAME_PATH := "res://decompiled/build/assets/cards/%04d.name.bin"
const FONT_MAPPING_PATH := "res://decompiled/build/assets/ui/font-mapping.json"

var _cards: Dictionary[int, CardDefinition] = {}
var _localized_name_bytes: Dictionary[int, PackedByteArray] = {}
var _unicode_by_encoded_glyph: Dictionary[int, String] = {}

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
	if not FileAccess.file_exists(GAME_TABLES_PATH):
		return ERR_FILE_NOT_FOUND
	var game_tables: Variant = JSON.parse_string(FileAccess.get_file_as_string(GAME_TABLES_PATH))
	if not game_tables is Dictionary or not game_tables.get("gMetadata1DBySpellIndex", null) is Array:
		return ERR_PARSE_ERROR
	var metadata_1d_by_spell_index: Array = game_tables.gMetadata1DBySpellIndex
	if metadata_1d_by_spell_index.size() != 132:
		return ERR_INVALID_DATA
	var type_names: Dictionary = terms.types
	var summon_names: Dictionary = terms.summons
	_localized_name_bytes.clear()
	_load_encoded_glyph_names()
	_cards.clear()
	for row: Variant in parsed.cards:
		if not row is Dictionary:
			continue
		var definition := CardDefinition.from_dictionary(row)
		var spell_index := definition.metadata_1a & 0xFF
		if spell_index >= metadata_1d_by_spell_index.size():
			return ERR_INVALID_DATA
		definition.metadata_1a = spell_index
		definition.metadata_1d = int(metadata_1d_by_spell_index[spell_index]) & 0xFF
		definition.type_name = str(type_names.get(str(definition.card_type), ""))
		definition.summon_name = str(summon_names.get(str(definition.attribute), ""))
		if definition.id > 0:
			_cards[definition.id] = definition
	return OK if _cards.size() == 900 else ERR_INVALID_DATA

func get_card(card_id: int) -> CardDefinition:
	# LoadCardMetadata/GetCardNameAddress index their tables with a uint16_t ID.
	return _cards.get(card_id & 0xFFFF) as CardDefinition

func get_card_count() -> int:
	return _cards.size()

## Returns a name decoded from the recovered language-segmented native record.
## The byte format stays inside this loader; callers receive an owned String.
func get_localized_card_name(card_id: int, language: int = 0) -> String:
	var native_card_id := card_id & 0xFFFF
	var definition := get_card(native_card_id)
	if definition == null:
		return ""
	var bytes: PackedByteArray = _localized_name_bytes.get(native_card_id, PackedByteArray())
	if bytes.is_empty():
		var path := CARD_NAME_PATH % native_card_id
		if not FileAccess.file_exists(path):
			return definition.name
		bytes = FileAccess.get_file_as_bytes(path)
		_localized_name_bytes[native_card_id] = bytes
	var segment := SacredTextRules.select_language_segment(bytes, clampi(language, 0, 5))
	var selected: PackedByteArray = segment.bytes
	if selected.is_empty():
		return definition.name
	var decoded := ""
	var index := 0
	while index < selected.size():
		var first := int(selected[index])
		if first == 0 or first == 36:
			break
		if (first & 0x80) == 0:
			decoded += String.chr(first)
			index += 1
			continue
		if index + 1 >= selected.size():
			break
		var encoded := (first << 8) | int(selected[index + 1])
		var glyph: String = _unicode_by_encoded_glyph.get(encoded, "")
		if glyph.is_empty():
			return definition.name
		decoded += glyph
		index += 2
	return decoded if not decoded.is_empty() else definition.name

func _load_encoded_glyph_names() -> void:
	_unicode_by_encoded_glyph.clear()
	if not FileAccess.file_exists(FONT_MAPPING_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FONT_MAPPING_PATH))
	if not parsed is Array:
		return
	for entry: Variant in parsed:
		if not entry is Dictionary:
			continue
		var candidate := str(entry.get("unicode_candidate", ""))
		if candidate.length() != 1:
			continue
		var encoded_text := str(entry.get("encoded", "0x0")).trim_prefix("0x")
		_unicode_by_encoded_glyph[encoded_text.hex_to_int()] = candidate
