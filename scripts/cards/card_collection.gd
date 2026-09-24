class_name CardCollection
extends Resource

## Tracks owned copy counts by canonical CardDefinition ID.

@export_storage var _quantities: Dictionary = {}
var _card_database: Object
var last_error: String = ""


func _init(card_database: Object = null) -> void:
	_card_database = card_database


func bind_database(card_database: Object) -> bool:
	last_error = ""
	if card_database == null or not card_database.has_method("has_card"):
		return _fail("CardCollection requires a CardDatabase.")
	_card_database = card_database
	return true


func give(card_id: int, quantity: int = 1) -> bool:
	last_error = ""
	if not _is_known_card(card_id):
		return false
	if quantity <= 0:
		return _fail("Quantity to give must be greater than zero.")
	_quantities[card_id] = int(_quantities.get(card_id, 0)) + quantity
	return true


func remove(card_id: int, quantity: int = 1) -> bool:
	last_error = ""
	if not _is_known_card(card_id):
		return false
	if quantity <= 0:
		return _fail("Quantity to remove must be greater than zero.")
	var current_quantity := int(_quantities.get(card_id, 0))
	if quantity > current_quantity:
		return _fail("Cannot remove %d copies of card %d; only %d are owned." % [quantity, card_id, current_quantity])
	var remaining := current_quantity - quantity
	if remaining == 0:
		_quantities.erase(card_id)
	else:
		_quantities[card_id] = remaining
	return true


func owns(card_id: int) -> bool:
	last_error = ""
	if not _is_known_card(card_id):
		return false
	return int(_quantities.get(card_id, 0)) > 0


func get_quantity(card_id: int) -> int:
	last_error = ""
	if not _is_known_card(card_id):
		return -1
	return int(_quantities.get(card_id, 0))


func quantities() -> Dictionary:
	return _quantities.duplicate(true)


func _is_known_card(card_id: int) -> bool:
	if _card_database == null or not _card_database.has_method("has_card"):
		return _fail("A CardDatabase must be bound before using the collection.")
	if card_id <= 0 or not bool(_card_database.call("has_card", card_id)):
		return _fail("Unknown card ID %d." % card_id)
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false
