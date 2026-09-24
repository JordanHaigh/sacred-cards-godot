class_name CardEffectRegistry
extends RefCounted

## Routes reusable effect IDs to handlers. Each handler receives a context
## dictionary and returns {"success": bool, "error": String}.

var _handlers: Dictionary = {}
var _effects_by_card_id: Dictionary = {}
var _parameters_by_card_id: Dictionary = {}
var last_error: String = ""


func register_effect(effect_id: String, handler: Callable) -> bool:
	last_error = ""
	var normalized_id := effect_id.strip_edges()
	if normalized_id.is_empty():
		return _fail("Effect IDs cannot be empty.")
	if not handler.is_valid():
		return _fail("Effect '%s' requires a valid handler." % normalized_id)
	if _handlers.has(normalized_id):
		return _fail("Effect '%s' is already registered." % normalized_id)
	_handlers[normalized_id] = handler
	return true


func has_effect(effect_id: String) -> bool:
	return _handlers.has(effect_id)


func map_card_effect(card_id: int, effect_id: String, parameters: Dictionary = {}) -> bool:
	last_error = ""
	if card_id <= 0:
		return _fail("Card IDs must be positive integers.")
	if not _handlers.has(effect_id):
		return _fail("Cannot map card %d to unknown effect '%s'." % [card_id, effect_id])
	var effects: PackedStringArray = _effects_by_card_id.get(card_id, PackedStringArray())
	if effects.has(effect_id):
		return _fail("Card %d is already mapped to effect '%s'." % [card_id, effect_id])
	effects.append(effect_id)
	_effects_by_card_id[card_id] = effects
	var card_parameters: Dictionary = _parameters_by_card_id.get(card_id, {})
	card_parameters[effect_id] = parameters.duplicate(true)
	_parameters_by_card_id[card_id] = card_parameters
	return true


func effects_for_card(card_id: int) -> PackedStringArray:
	return _effects_by_card_id.get(card_id, PackedStringArray()).duplicate()


func parameters_for_card_effect(card_id: int, effect_id: String) -> Dictionary:
	var card_parameters: Dictionary = _parameters_by_card_id.get(card_id, {})
	return card_parameters.get(effect_id, {}).duplicate(true)


func load_mapping_records(records: Array) -> PackedStringArray:
	var diagnostics := PackedStringArray()
	for record_index in range(records.size()):
		var record = records[record_index]
		if not record is Dictionary:
			diagnostics.append("mapping[%d] must be an object." % record_index)
			continue
		var card_id := int(record.get("card_id", 0))
		var effect_list = record.get("effects", [])
		if card_id <= 0 or not effect_list is Array:
			diagnostics.append("mapping[%d] requires a positive card_id and an effects array." % record_index)
			continue
		for effect_index in range(effect_list.size()):
			var effect_record = effect_list[effect_index]
			if not effect_record is Dictionary:
				diagnostics.append("mapping[%d].effects[%d] must be an object." % [record_index, effect_index])
				continue
			var effect_id := String(effect_record.get("id", ""))
			var raw_parameters = effect_record.get("parameters", {})
			if not raw_parameters is Dictionary:
				diagnostics.append("mapping[%d].effects[%d].parameters must be an object." % [record_index, effect_index])
				continue
			var parameters: Dictionary = raw_parameters
			if not bool(map_card_effect(card_id, effect_id, parameters)):
				diagnostics.append("mapping[%d].effects[%d]: %s" % [record_index, effect_index, last_error])
	return diagnostics


func effect_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for effect_id in _handlers.keys():
		ids.append(String(effect_id))
	ids.sort()
	return ids


func execute(effect_id: String, context: Dictionary) -> Dictionary:
	last_error = ""
	if not _handlers.has(effect_id):
		return _result(false, effect_id, "Unknown card effect '%s'." % effect_id)
	var handler: Callable = _handlers[effect_id]
	var handler_result: Variant = handler.call(context.duplicate(true))
	if not handler_result is Dictionary:
		return _result(false, effect_id, "Effect '%s' returned an invalid result." % effect_id)
	var succeeded := bool(handler_result.get("success", false))
	var error_message := String(handler_result.get("error", ""))
	if not succeeded and error_message.is_empty():
		error_message = "Effect '%s' did not complete." % effect_id
	last_error = error_message
	return {
		"success": succeeded,
		"effect_id": effect_id,
		"error": error_message,
		"details": handler_result.get("details", {}),
	}


func _result(succeeded: bool, effect_id: String, error_message: String) -> Dictionary:
	last_error = error_message
	return {
		"success": succeeded,
		"effect_id": effect_id,
		"error": error_message,
		"details": {},
	}


func _fail(message: String) -> bool:
	last_error = message
	return false
