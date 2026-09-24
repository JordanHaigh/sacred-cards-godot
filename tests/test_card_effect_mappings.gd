extends SceneTree

const DATABASE_SCRIPT = preload("res://scripts/cards/card_database.gd")
const REGISTRY_SCRIPT = preload("res://scripts/duel/card_effect_registry.gd")
const EFFECTS_SCRIPT = preload("res://scripts/duel/basic_card_effects.gd")


func _init() -> void:
	var database = DATABASE_SCRIPT.new()
	if not database.load_from_directory("res://data/cards_json").is_empty():
		_fail("The supplied card dataset should load before validating mappings.")
		return
	var records = JSON.parse_string(FileAccess.get_file_as_string("res://resources/card_effect_mappings.json"))
	if not records is Array:
		_fail("Card effect mappings should be a JSON array.")
		return
	var registry = REGISTRY_SCRIPT.new()
	var effects = EFFECTS_SCRIPT.new()
	if not effects.register_primitives(registry).is_empty():
		_fail("Every mapped primitive should register successfully.")
		return
	var diagnostics: PackedStringArray = registry.load_mapping_records(records)
	if not diagnostics.is_empty():
		_fail("Card effect mapping data is invalid: %s" % diagnostics[0])
		return
	var mapped_card_count := 0
	for record in records:
		var card_id := int(record.get("card_id", 0))
		if not database.has_card(card_id):
			_fail("Mapping references missing card ID %d." % card_id)
			return
		var card = database.get_card(card_id)
		if not ["Magic", "Trap"].has(card.get("card_type")):
			_fail("Effect mapping card %d is not a Magic or Trap card." % card_id)
			return
		mapped_card_count += 1
	if mapped_card_count != 11:
		_fail("Expected 11 explicitly mapped simple effects, found %d." % mapped_card_count)
		return
	print("PASS: Every documented effect mapping points to a supplied Magic card and a registered primitive.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
