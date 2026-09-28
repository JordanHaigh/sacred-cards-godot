class_name PreDuelGraphics
extends RefCounted
## Typed list presentation data from pre_duel_graphics.c. Menu row/card IDs are
## resolved by PreDuelMenuState; Godot Controls draw the returned records.

const VISIBLE_ROWS := 5
const CENTER_ROW := 2
const ROW_Y := [37, 53, 70, 93, 109]
const SCROLLBAR_TRAVEL := 124

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
			"name": card.name,
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
