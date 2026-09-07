extends SceneTree

const CARD_DATABASE_SCRIPT = preload("res://scripts/cards/card_database.gd")


func _init() -> void:
	var database = CARD_DATABASE_SCRIPT.new()
	var diagnostics: PackedStringArray = database.load_from_directory("res://data/cards_json")
	if not diagnostics.is_empty():
		_fail("CardDatabase load failed: %s" % "; ".join(diagnostics))
		return
	if database.card_count() != 900:
		_fail("Expected 900 cards, got %d." % database.card_count())
		return

	var blue_eyes = database.get_card(1)
	if blue_eyes == null or blue_eyes.get("display_name") != "Blue-Eyes White Dragon":
		_fail("Lookup by card ID failed.")
		return
	if database.get_card(1) != blue_eyes or not database.has_card(900) or database.has_card(901):
		_fail("Card ID indexing is not stable.")
		return

	var duplicate_names: Array[Resource] = database.find_by_name("Blue-Eyes White Dragon")
	if duplicate_names.size() != 2:
		_fail("Duplicate display names should remain addressable by ID.")
		return
	if database.find_by_card_type("Monster").size() != 773:
		_fail("Card type lookup returned the wrong number of monsters.")
		return

	var records: Array = [blue_eyes.to_source_record(), blue_eyes.to_source_record()]
	var duplicate_diagnostics: PackedStringArray = database.load_from_records(records)
	if duplicate_diagnostics.is_empty() or database.card_count() != 0:
		_fail("Duplicate IDs should produce diagnostics and an atomic failed load.")
		return
	if not _contains_text(duplicate_diagnostics, "duplicate card ID 1"):
		_fail("Duplicate-ID diagnostic was not descriptive.")
		return

	var malformed_record: Dictionary = blue_eyes.to_source_record()
	malformed_record.erase("description")
	var malformed_diagnostics: PackedStringArray = database.load_from_records([malformed_record])
	if malformed_diagnostics.is_empty() or not _contains_text(malformed_diagnostics, "description"):
		_fail("Malformed records should identify the invalid field.")
		return

	print("PASS: 900 CardDefinitions load once, ID/name/type lookups work, and duplicate or malformed records fail with diagnostics.")
	quit(0)


func _contains_text(messages: PackedStringArray, expected: String) -> bool:
	for message in messages:
		if expected in message:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
