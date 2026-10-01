class_name PreDuelGraphics
extends RefCounted
## Typed list presentation data from pre_duel_graphics.c. Menu row/card IDs are
## resolved by PreDuelMenuState; Godot Controls draw the returned records.

const VISIBLE_ROWS := 5
const CENTER_ROW := 2
const ROW_Y := [37, 53, 70, 93, 109]
const SCROLLBAR_TRAVEL := 124
const CARD_NAME_PATH := "res://decompiled/build/assets/cards/%04d.name.bin"

var database: CardDatabase

func _init(card_database: CardDatabase = null) -> void:
	database = card_database

func build_rows(menu: PreDuelMenuState, deck: Array[int]) -> Array[Dictionary]:
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
			"name": _wager_name_prefix(card),
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

func _wager_name_prefix(card: CardDefinition) -> String:
	# DrawPreDuelGraphics copies exactly twenty bytes from the raw name record
	# before RenderBitmapString selects a language segment. Keep that byte limit
	# separate from Unicode character count so multibyte names follow the C path.
	var path := CARD_NAME_PATH % card.id
	if not FileAccess.file_exists(path):
		return card.name.left(20)
	var raw_name := FileAccess.get_file_as_bytes(path)
	var prefix := raw_name.slice(0, mini(raw_name.size(), 20))
	var selected := SacredTextRules.select_language_segment(prefix, 0)
	var selected_bytes: PackedByteArray = selected.bytes
	var result := ""
	var index := 0
	while index < selected_bytes.size() and selected_bytes[index] != 0 and selected_bytes[index] != 36:
		var value := int(selected_bytes[index])
		if value < 0x80:
			result += char(value)
			index += 1
		else:
			# PixelText's atlas has the native glyph, but this CanvasItem uses
			# Godot's fallback font. Preserve its two-byte boundary as one glyph.
			result += "?"
			index += 2 if index + 1 < selected_bytes.size() else 1
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
