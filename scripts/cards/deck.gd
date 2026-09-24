class_name Deck
extends Resource

## An ordered player deck containing card definition IDs.
## CardDatabase stays separate so the deck can be saved without copying card data.

@export_storage var _card_ids: PackedInt32Array = PackedInt32Array()


func _init(card_ids: PackedInt32Array = PackedInt32Array()) -> void:
	_card_ids = card_ids.duplicate()


func add_card(card_id: int, position: int = -1) -> bool:
	if card_id <= 0:
		return false
	if position < 0:
		_card_ids.append(card_id)
		return true
	if position > _card_ids.size():
		return false
	_card_ids.insert(position, card_id)
	return true


func remove_card(card_id: int) -> bool:
	var card_index := _card_ids.find(card_id)
	if card_index < 0:
		return false
	_card_ids.remove_at(card_index)
	return true


func card_count(card_id: int = 0) -> int:
	if card_id <= 0:
		return _card_ids.size()
	var matching_copies := 0
	for stored_card_id in _card_ids:
		if stored_card_id == card_id:
			matching_copies += 1
	return matching_copies


func card_ids() -> PackedInt32Array:
	return _card_ids.duplicate()


func clear() -> void:
	_card_ids.clear()


func shuffle(seed: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	for index in range(_card_ids.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var stored_card_id := _card_ids[index]
		_card_ids[index] = _card_ids[swap_index]
		_card_ids[swap_index] = stored_card_id


func validate(card_database: Object, require_non_empty: bool = false) -> PackedStringArray:
	var errors := PackedStringArray()
	if card_database == null or not card_database.has_method("has_card"):
		errors.append("A CardDatabase is required to validate deck card IDs.")
		return errors
	if require_non_empty and _card_ids.is_empty():
		errors.append("The deck cannot be empty.")
	for index in range(_card_ids.size()):
		var card_id := int(_card_ids[index])
		if card_id <= 0:
			errors.append("Deck entry %d must have a positive card ID." % index)
		elif not bool(card_database.call("has_card", card_id)):
			errors.append("Deck entry %d references unknown card ID %d." % [index, card_id])
	return errors
