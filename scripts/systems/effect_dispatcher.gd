extends RefCounted
class_name CardEffectDispatcher

## Data-driven replacement for effect_dispatch.c's ROM function-pointer tables.
## Handlers receive (CardDefinition, context Dictionary) and return their result.
signal unsupported_handler(card_id: int, metadata_field: StringName, handler_index: int)

const NOOPS_SCRIPT = preload("res://scripts/systems/effect_noops.gd")
var card_database: CardDatabase
var metadata_1a_handlers: Array[Callable] = []
var metadata_1b_handlers: Array[Callable] = []

func _init(database: CardDatabase = null) -> void:
	card_database = database

func register_metadata_1a(index: int, handler: Callable) -> bool:
	return _register(metadata_1a_handlers, index, 132, handler)

func register_metadata_1b(index: int, handler: Callable) -> bool:
	return _register(metadata_1b_handlers, index, 85, handler)

func dispatch_metadata_1a(card_id: int, context: Dictionary = {}) -> Variant:
	var card := card_database.get_card(card_id) if card_database != null else null
	if card == null:
		return false
	var index := card.metadata_1a
	if index < 0 or index >= 132:
		return false
	if index < metadata_1a_handlers.size() and metadata_1a_handlers[index].is_valid():
		return metadata_1a_handlers[index].call(card, context)
	if NOOPS_SCRIPT.is_empty_metadata_1a_handler(index):
		return NOOPS_SCRIPT.invoke(card, context)
	unsupported_handler.emit(card_id, &"metadata_1a", index)
	return false

func dispatch_metadata_1b(card_id: int, context: Dictionary = {}) -> Variant:
	var card := card_database.get_card(card_id) if card_database != null else null
	if card == null:
		return false
	var index := card.metadata_1b
	if index < 0 or index >= 85:
		return false
	if index < metadata_1b_handlers.size() and metadata_1b_handlers[index].is_valid():
		return metadata_1b_handlers[index].call(card, context)
	unsupported_handler.emit(card_id, &"metadata_1b", index)
	return false

func _register(table: Array[Callable], index: int, limit: int, handler: Callable) -> bool:
	if index < 0 or index >= limit or not handler.is_valid():
		return false
	while table.size() <= index:
		table.append(Callable())
	table[index] = handler
	return true
