extends SceneTree

const CARD_DATABASE_SCRIPT = preload("res://scripts/cards/card_database.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")


func _init() -> void:
	var database = CARD_DATABASE_SCRIPT.new()
	var diagnostics: PackedStringArray = database.load_from_directory("res://data/cards_json")
	if not diagnostics.is_empty():
		_fail("CardDatabase load failed: %s" % "; ".join(diagnostics))
		return

	var first_instance = CARD_INSTANCE_SCRIPT.new(1, "player_one")
	var second_instance = CARD_INSTANCE_SCRIPT.new(1, "player_two")
	if not first_instance.initialize_from_database(database) or not second_instance.initialize_from_database(database):
		_fail("CardInstances should resolve their canonical CardDefinition.")
		return
	if first_instance.resolve_definition(database) != database.get_card(1):
		_fail("CardInstance did not resolve the canonical definition resource.")
		return
	if first_instance.current_attack != 3000 or first_instance.current_defense != 2500:
		_fail("Runtime combat stats were not initialized from the definition.")
		return

	first_instance.current_attack = 2500
	first_instance.current_defense = 2200
	first_instance.battle_position = "defense"
	first_instance.face_state = "face_down"
	if not first_instance.set_temporary_card_type("Magic") or not first_instance.set_temporary_attribute("Dark"):
		_fail("Temporary type and attribute changes should accept strings.")
		return
	first_instance.add_buff("field_power", 300, 100, 2)
	first_instance.add_debuff("curse", 500, 200, 1)
	first_instance.add_status("immobilized")
	first_instance.set_turn_flag("has_attacked")

	if second_instance.current_attack != 3000 or second_instance.current_defense != 2500:
		_fail("Mutating one instance changed another instance of the same card.")
		return
	if first_instance.effective_card_type(database) != "Magic" or first_instance.effective_attribute(database) != "Dark":
		_fail("Temporary type and attribute overrides did not resolve.")
		return
	if not first_instance.has_status("immobilized") or not first_instance.has_turn_flag("has_attacked"):
		_fail("Runtime statuses or turn flags were not stored.")
		return

	var serialized: Dictionary = first_instance.to_serialized()
	serialized["statuses"].append("outside_mutation")
	if first_instance.has_status("outside_mutation"):
		_fail("Serialized state must be a defensive copy.")
		return
	var restored = CARD_INSTANCE_SCRIPT.from_serialized(first_instance.to_serialized())
	if restored.get("definition_id") != 1 or restored.get("owner_id") != "player_one":
		_fail("Serialized identity was not restored.")
		return
	if restored.get("current_attack") != 2500 or restored.get("battle_position") != "defense":
		_fail("Serialized combat state was not restored.")
		return
	if not restored.call("has_status", "immobilized") or not restored.call("has_turn_flag", "has_attacked"):
		_fail("Serialized statuses or turn flags were not restored.")
		return

	var canonical_definition = database.get_card(1)
	if canonical_definition.get("attack") != 3000 or canonical_definition.get("defense") != 2500:
		_fail("Mutating runtime state changed CardDefinition data.")
		return

	print("PASS: CardInstances resolve canonical definitions, isolate mutable duel state, and round-trip serialized runtime state.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
