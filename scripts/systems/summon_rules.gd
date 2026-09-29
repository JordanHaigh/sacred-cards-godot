extends RefCounted
class_name SummonRules

const TABLE_PATH := "res://resources/game_tables.json"
const TYPE_CLASSES := [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 4]
var _tributes_by_level: Array = []
var _category_requirements: Array = []

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if parsed is Dictionary:
		_tributes_by_level = parsed.get("gTributesByLevel", [])
		_category_requirements = parsed.get("gCategoryRequirements", [])

func classify_card(card_id: int, database: CardDatabase) -> int:
	if card_id == 0:
		return 0
	var card := database.get_card(card_id)
	if card == null or card.card_type < 0 or card.card_type >= TYPE_CLASSES.size():
		return 0
	return TYPE_CLASSES[card.card_type]

func card_tribute_requirement(card_id: int, database: CardDatabase) -> int:
	var card := database.get_card(card_id)
	if card == null or card.level < 0 or card.level >= _tributes_by_level.size():
		return 0
	return int(_tributes_by_level[card.level])

func remaining_monster_tributes(card_id: int, committed: int, database: CardDatabase) -> int:
	if classify_card(card_id, database) != 1:
		return 0
	return maxi(0, card_tribute_requirement(card_id, database) - committed)

func card_category_requirement(card_id: int, database: CardDatabase) -> int:
	var card := database.get_card(card_id)
	if card == null or card.metadata_1d < 0 or card.metadata_1d >= _category_requirements.size():
		return 0
	return int(_category_requirements[card.metadata_1d])

func remaining_category_four_requirement(card_id: int, committed: int, database: CardDatabase) -> int:
	if classify_card(card_id, database) != 4:
		return 0
	return maxi(0, card_category_requirement(card_id, database) - committed)
