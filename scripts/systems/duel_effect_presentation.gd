extends RefCounted
class_name DuelEffectPresentation

## Converts the recovered effect result sequences into explicit Godot events.
## Card IDs and sound IDs remain separate values; no ROM pointers escape rules.

func events_for(result: Variant) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_collect_result(result, events)
	return events

func _collect_result(value: Variant, events: Array[Dictionary]) -> void:
	if not value is Dictionary:
		return
	var presentation: Variant = value.get("presentation", [])
	if presentation is Array and not presentation.is_empty():
		_append_sequence(presentation, events)
	for key: Variant in value:
		var child: Variant = value[key]
		if child is Dictionary:
			_collect_result(child, events)
		elif child is Array:
			for item: Variant in child:
				if item is Dictionary:
					_collect_result(item, events)

func _append_sequence(sequence: Array, events: Array[Dictionary]) -> void:
	if sequence.is_empty():
		return
	if sequence[0] is String and String(sequence[0]) == "load_terrain":
		if sequence.size() > 1:
			events.append({"kind": "terrain", "terrain": int(sequence[1])})
		var terrain_cards := _integer_values(sequence, 2, sequence.size() - 1)
		if not terrain_cards.is_empty():
			events.append({"kind": "cards", "card_ids": terrain_cards})
		_append_sound(sequence[sequence.size() - 1], events)
		return
	if sequence[0] is int and int(sequence[0]) == 65:
		_append_sound(sequence[0], events)
		var wrapped_cards := _integer_values(sequence, 1, sequence.size() - 1)
		if not wrapped_cards.is_empty():
			events.append({"kind": "cards", "card_ids": wrapped_cards})
		if sequence.size() > 2:
			_append_sound(sequence[sequence.size() - 1], events)
		return
	if sequence.size() >= 2 and sequence[sequence.size() - 1] is String:
		var immune_cards := _integer_values(sequence, 0, sequence.size() - 1)
		if not immune_cards.is_empty():
			events.append({"kind": "cards", "card_ids": immune_cards})
		events.append({"kind": "message", "text": String(sequence[sequence.size() - 1])})
		return
	var card_values := _integer_values(sequence, 0, sequence.size() - 1)
	if not card_values.is_empty():
		events.append({"kind": "cards", "card_ids": card_values})
	_append_sound(sequence[sequence.size() - 1], events)

func _integer_values(values: Array, start: int, end_exclusive: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(start, end_exclusive):
		if values[index] is int and int(values[index]) > 0:
			result.append(int(values[index]))
	return result

func _append_sound(value: Variant, events: Array[Dictionary]) -> void:
	if value is int and int(value) >= 0:
		events.append({"kind": "sound", "sound_id": int(value)})
