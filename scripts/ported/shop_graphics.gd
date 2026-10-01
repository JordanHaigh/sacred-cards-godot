class_name ShopGraphics
extends RefCounted
## Typed shop-thumbnail and selector data recovered from shop_graphics.c.

const ATTRIBUTE_ICON_PATH := "res://art/ui/shop/attribute-%02d.png"
const REQUIREMENT_ICON_PATH := "res://art/ui/shop/requirement-%d.png"
const SELECTOR_X_COORDINATES := [505, 537, 569, 601, 633, 665, 697]
const SELECTOR_Y_COORDINATES := [241, 273, 305, 337, 369]
const SELECTION_PIECE_SPACING := 30
const SCROLLBAR_TRAVEL := 127

var card_database: CardDatabase
var summon_rules: SummonRules

func _init(database: CardDatabase, rules: SummonRules) -> void:
	card_database = database
	summon_rules = rules

func miniature_layers(card_id: int) -> Dictionary:
	var card := card_database.get_card(card_id) if card_database != null else null
	if card == null:
		return {"card_id": card_id, "attribute_path": "", "requirement_path": "", "attack_value": -1, "defense_value": -1}
	var tribute_requirement := summon_rules.card_tribute_requirement(card_id, card_database) if summon_rules != null else 0
	return {
		"card_id": card_id,
		"attribute_path": ATTRIBUTE_ICON_PATH % card.attribute if card.attribute > 0 and card.attribute <= 11 else "",
		"requirement_path": REQUIREMENT_ICON_PATH % tribute_requirement if tribute_requirement > 0 and tribute_requirement <= 3 else "",
		"attack_value": mini(floori(float(card.attack) / 100.0), 99) if card.metadata_1a == 2 else -1,
		"defense_value": mini(floori(float(card.defense) / 100.0), 99) if card.metadata_1a == 2 else -1,
	}

func scrollbar_y(selected_index: int, card_count: int) -> int:
	var row_count := maxi(ceili(float(card_count) / 7.0), 1)
	var selected_row := clampi(selected_index / 7, 0, row_count - 1)
	return floori(float(selected_row * SCROLLBAR_TRAVEL) / float(row_count)) + 1

func selection_origin(row: int, column: int) -> Vector2:
	var x := int(SELECTOR_X_COORDINATES[clampi(column, 0, SELECTOR_X_COORDINATES.size() - 1)]) & 0x1FF
	var y := int(SELECTOR_Y_COORDINATES[clampi(row, 0, SELECTOR_Y_COORDINATES.size() - 1)]) & 0xFF
	if x >= 256:
		x -= 512
	if y >= 128:
		y -= 256
	return Vector2(x, y)

func selection_pieces(at: Vector2) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for index in range(4):
		pieces.append({
			"position": at + Vector2((index % 2) * SELECTION_PIECE_SPACING, (index / 2) * SELECTION_PIECE_SPACING),
			"flip_h": (index & 1) != 0,
			"flip_v": (index & 2) != 0,
		})
	return pieces
