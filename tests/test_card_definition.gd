extends SceneTree

const CARD_DEFINITION_SCRIPT = preload("res://scripts/cards/card_definition.gd")


func _init() -> void:
	var monster = _load_definition("res://data/cards_json/1_Blue-Eyes_White_Dragon.json")
	if monster == null:
		return
	if monster.card_id != 1 or monster.display_name != "Blue-Eyes White Dragon":
		_fail("Monster core fields were not mapped.")
		return
	if monster.attack != 3000 or monster.defense != 2500 or monster.card_type != "Monster":
		_fail("Monster combat fields were not mapped.")
		return

	var magic = _load_definition("res://data/cards_json/301_Legendary_Sword.json")
	if magic == null:
		return
	if magic.card_type != "Magic" or magic.monster_type != null or magic.attack != 0:
		_fail("Magic source sentinels were not preserved.")
		return

	var trap = _load_definition("res://data/cards_json/683_Bear_Trap.json")
	if trap == null:
		return
	if trap.card_type != "Trap" or trap.description.is_empty():
		_fail("Trap fields were not mapped.")
		return

	var source_copy: Dictionary = monster.to_source_record()
	source_copy["atk"] = 1
	source_copy["description"] = "changed outside the definition"
	if monster.attack != 3000 or monster.description == source_copy["description"]:
		_fail("Mutating a source copy changed canonical card data.")
		return

	var metadata_copy: Dictionary = monster.source_metadata
	metadata_copy["dc"] = 999999
	if monster.source_dc == 999999:
		_fail("Mutating metadata changed canonical card data.")
		return

	var invalid_record: Dictionary = monster.to_source_record()
	invalid_record.erase("card")
	var validation_errors: PackedStringArray = CARD_DEFINITION_SCRIPT.validate_source_record(invalid_record)
	if validation_errors.is_empty() or not _contains_error(validation_errors, "card"):
		_fail("Invalid source records need descriptive validation errors.")
		return

	print("PASS: monster, magic, and trap records map to immutable CardDefinitions with defensive metadata copies.")
	quit(0)


func _load_definition(path: String):
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("Could not parse card record: %s" % path)
		return null
	var definition = CARD_DEFINITION_SCRIPT.from_source_record(parsed)
	if definition == null:
		_fail("Could not build CardDefinition: %s" % path)
	return definition


func _contains_error(errors: PackedStringArray, expected_field: String) -> bool:
	for error in errors:
		if expected_field in error:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
