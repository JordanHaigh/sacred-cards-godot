class_name CardDatabase
extends RefCounted

## Loads canonical CardDefinition resources from the supplied JSON directory.
##
## The database owns one definition per source ID. It does not create mutable
## duel instances and it does not expose a global singleton.

const CARD_DEFINITION_SCRIPT = preload("res://scripts/cards/card_definition.gd")

var _cards_by_id: Dictionary = {}
var _last_diagnostics := PackedStringArray()

var last_diagnostics: PackedStringArray:
	get:
		return _last_diagnostics


func load_from_directory(directory_path: String) -> PackedStringArray:
	var diagnostics := PackedStringArray()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		diagnostics.append("Could not open card directory '%s'." % directory_path)
		_last_diagnostics = diagnostics
		_cards_by_id.clear()
		return diagnostics

	var filenames: Array[String] = []
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.to_lower().ends_with(".json"):
			filenames.append(filename)
		filename = directory.get_next()
	directory.list_dir_end()
	filenames.sort()

	var records: Array = []
	var source_labels: Array[String] = []
	for card_filename in filenames:
		var file_path := directory_path.path_join(card_filename)
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			diagnostics.append("%s: could not open file." % card_filename)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			diagnostics.append("%s: JSON root must be an object." % card_filename)
			continue
		records.append(parsed)
		source_labels.append(card_filename)

	if records.is_empty() and diagnostics.is_empty():
		diagnostics.append("No JSON card records found in '%s'." % directory_path)

	var record_diagnostics := _load_records(records, source_labels)
	diagnostics.append_array(record_diagnostics)
	if not diagnostics.is_empty():
		_cards_by_id.clear()
	_last_diagnostics = diagnostics
	return diagnostics


func load_from_records(records: Array) -> PackedStringArray:
	var source_labels: Array[String] = []
	for index in range(records.size()):
		source_labels.append("record[%d]" % index)
	var diagnostics := _load_records(records, source_labels)
	if not diagnostics.is_empty():
		_cards_by_id.clear()
	_last_diagnostics = diagnostics
	return diagnostics


func get_card(card_id: int) -> Resource:
	return _cards_by_id.get(card_id, null)


func has_card(card_id: int) -> bool:
	return _cards_by_id.has(card_id)


func card_count() -> int:
	return _cards_by_id.size()


func get_all_cards() -> Array[Resource]:
	var cards: Array[Resource] = []
	for card_id in _sorted_ids():
		cards.append(_cards_by_id[card_id])
	return cards


func find_by_name(display_name: String) -> Array[Resource]:
	var matches: Array[Resource] = []
	for card_id in _sorted_ids():
		var definition = _cards_by_id[card_id]
		if String(definition.get("display_name")) == display_name:
			matches.append(definition)
	return matches


func find_by_card_type(card_type: String) -> Array[Resource]:
	var matches: Array[Resource] = []
	for card_id in _sorted_ids():
		var definition = _cards_by_id[card_id]
		if String(definition.get("card_type")) == card_type:
			matches.append(definition)
	return matches


func _load_records(records: Array, source_labels: Array[String]) -> PackedStringArray:
	var diagnostics := PackedStringArray()
	var candidate_cards: Dictionary = {}
	var candidate_sources: Dictionary = {}

	for index in range(records.size()):
		var label := source_labels[index] if index < source_labels.size() else "record[%d]" % index
		var record = records[index]
		if not record is Dictionary:
			diagnostics.append("%s: record must be a JSON object." % label)
			continue

		var validation_errors: PackedStringArray = CARD_DEFINITION_SCRIPT.validate_source_record(record)
		if not validation_errors.is_empty():
			for error in validation_errors:
				diagnostics.append("%s: %s" % [label, error])
			continue

		var card_id := int(record["id"])
		if candidate_cards.has(card_id):
			diagnostics.append("%s: duplicate card ID %d; already defined by %s." % [label, card_id, candidate_sources[card_id]])
			continue

		var definition: Resource = CARD_DEFINITION_SCRIPT.from_source_record(record)
		if definition == null:
			diagnostics.append("%s: CardDefinition could not be created." % label)
			continue
		candidate_cards[card_id] = definition
		candidate_sources[card_id] = label

	if diagnostics.is_empty():
		_cards_by_id = candidate_cards
	return diagnostics


func _sorted_ids() -> Array[int]:
	var card_ids: Array[int] = []
	for raw_id in _cards_by_id.keys():
		card_ids.append(int(raw_id))
	card_ids.sort()
	return card_ids
