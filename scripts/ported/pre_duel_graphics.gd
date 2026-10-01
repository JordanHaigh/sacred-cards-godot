class_name PreDuelGraphics
extends RefCounted
## Typed list presentation data from pre_duel_graphics.c. Menu row/card IDs are
## resolved by PreDuelMenuState; Godot Controls draw the returned records.

const VISIBLE_ROWS := 5
const CENTER_ROW := 2
const ROW_Y := [37, 53, 70, 93, 109]
const SCROLLBAR_TRAVEL := 124
const CARD_NAME_PATH := "res://decompiled/build/assets/cards/%04d.name.bin"
const ASCII_GLYPH_CODES_PATH := "res://resources/ascii_glyph_codes.json"

var database: CardDatabase
var _ascii_glyph_indices: Array[int] = []

func _init(card_database: CardDatabase = null) -> void:
	database = card_database
	_load_ascii_glyph_indices()

func build_rows(menu: PreDuelMenuState, deck: Array[int], language_id: int = 0) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if menu == null: return rows
	var deck_counts: Dictionary[int, int] = {}
	for card_id in deck: deck_counts[card_id] = int(deck_counts.get(card_id, 0)) + 1
	for row_index in range(VISIBLE_ROWS):
		var card_id := menu.card_at_visible_row(row_index)
		var card := database.get_card(card_id) if database != null else null
		if card == null: continue
		var owned := int(menu.collection_counts.get(card_id, 0))
		var detail := _detail_for(card, menu.view_mode)
		rows.append({
			"row": row_index,
			"card_id": card_id,
			"name_glyphs": _wager_name_glyphs(card, language_id),
			"miniature_path": card.miniature_path,
			"attribute": card.attribute,
			"level": card.level,
			"card_type": card.card_type,
			"owned_count": owned,
			"deck_count": int(deck_counts.get(card_id, 0)),
			"detail": detail,
			"selected": row_index == CENTER_ROW,
			"y": ROW_Y[row_index],
		})
	return rows

func _wager_name_glyphs(card: CardDefinition, language_id: int = 0) -> Array[int]:
	# DrawPreDuelGraphics copies exactly twenty bytes from the raw name record
	# before RenderBitmapString selects a language segment. Keep that byte limit
	# separate from Unicode character count so multibyte names keep their glyphs.
	var path := CARD_NAME_PATH % card.id
	if not FileAccess.file_exists(path):
		return _ascii_glyphs_from_string(card.name.left(20))
	var raw_name := FileAccess.get_file_as_bytes(path)
	var prefix := raw_name.slice(0, mini(raw_name.size(), 20))
	var selected := SacredTextRules.select_language_segment(prefix, clampi(language_id, 0, 5))
	var selected_bytes: PackedByteArray = selected.bytes
	var glyphs: Array[int] = []
	var index := 0
	while index < selected_bytes.size() and selected_bytes[index] != 0 and selected_bytes[index] != 36:
		var value := int(selected_bytes[index])
		if value < 0x80:
			var ascii_index := value - 32
			glyphs.append(_ascii_glyph_indices[ascii_index] if ascii_index >= 0 and ascii_index < _ascii_glyph_indices.size() else 31)
			index += 1
		else:
			var code := value << 8
			if index + 1 < selected_bytes.size():
				code |= int(selected_bytes[index + 1])
			glyphs.append(SacredTextRules.bitmap_glyph_index(code))
			index += 2 if index + 1 < selected_bytes.size() else 1
	return glyphs

func _load_ascii_glyph_indices() -> void:
	_ascii_glyph_indices.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASCII_GLYPH_CODES_PATH)) if FileAccess.file_exists(ASCII_GLYPH_CODES_PATH) else null
	if not parsed is Dictionary or not parsed.get("encoded_codes", []) is Array:
		return
	for encoded: Variant in parsed.encoded_codes:
		if encoded == null:
			_ascii_glyph_indices.append(31)
		else:
			var value := int(encoded) & 0xffff
			_ascii_glyph_indices.append(SacredTextRules.bitmap_glyph_index(((value << 8) | (value >> 8)) & 0xffff))

func _ascii_glyphs_from_string(value: String) -> Array[int]:
	var result: Array[int] = []
	for index in range(value.length()):
		var ascii_index := value.unicode_at(index) - 32
		result.append(_ascii_glyph_indices[ascii_index] if ascii_index >= 0 and ascii_index < _ascii_glyph_indices.size() else 31)
	return result

func _detail_for(card: CardDefinition, view_mode: int) -> Dictionary:
	match view_mode:
		1:
			return {"left_label": "ATK", "left_value": card.attack, "right_label": "DEF", "right_value": card.defense}
		2:
			return {"left_label": "ATTR", "left_value": card.attribute, "right_label": "TYPE", "right_value": card.card_type}
		3:
			return {"left_label": "COST", "left_value": card.cost, "right_label": "LEVEL", "right_value": card.level}
		_:
			return {"left_label": "ATTR", "left_value": card.attribute, "right_label": "TYPE", "right_value": card.card_type}

func scrollbar_offset(selected_index: int, card_count: int = 900) -> int:
	if card_count <= 1: return 0
	return floori(float(clampi(selected_index, 0, card_count - 1) * SCROLLBAR_TRAVEL) / float(card_count - 1))

func source_row_tile(row_index: int) -> int:
	# The selected row takes an extra tile line in the native list map.
	return row_index * 3 + (0 if row_index < 2 else 1 if row_index == 2 else 2) + 2
