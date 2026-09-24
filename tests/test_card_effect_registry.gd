extends SceneTree

const REGISTRY_SCRIPT = preload("res://scripts/duel/card_effect_registry.gd")


func _init() -> void:
	var registry = REGISTRY_SCRIPT.new()
	if not registry.register_effect("add_points", Callable(self, "_add_points")):
		_fail("A valid reusable effect handler should register.")
		return
	if not registry.map_card_effect(42, "add_points", {"amount": 5}) or not registry.effects_for_card(42).has("add_points"):
		_fail("Registered effect IDs should map to card data without a card-specific switch.")
		return
	if registry.parameters_for_card_effect(42, "add_points").get("amount") != 5:
		_fail("Mapped effect parameters should be returned as reusable card data.")
		return
	var loaded_mappings: PackedStringArray = registry.load_mapping_records([
		{"card_id": 43, "effects": [{"id": "add_points", "parameters": {"amount": 2}}]},
	])
	if not loaded_mappings.is_empty() or not registry.effects_for_card(43).has("add_points"):
		_fail("External card mapping records should load through the registry.")
		return
	var project_mappings = JSON.parse_string(FileAccess.get_file_as_string("res://resources/card_effect_mappings.json"))
	if not project_mappings is Array or not registry.load_mapping_records(project_mappings).is_empty():
		_fail("Project card effect mappings should load from their sidecar data file.")
		return
	if not registry.effects_for_card(343).has("lp_damage") or registry.parameters_for_card_effect(342, "lp_heal").get("amount") != 5000:
		_fail("Real card mappings should retain their effect IDs and parameters.")
		return
	var context := {"value": 3}
	var result: Dictionary = registry.execute("add_points", context)
	if not result.get("success") or result.get("details", {}).get("value") != 13:
		_fail("The registry should route context to the registered effect handler.")
		return
	if registry.execute("missing_effect", {}).get("error", "").is_empty():
		_fail("Unknown effect IDs should return a diagnostic error.")
		return
	if registry.register_effect("add_points", Callable(self, "_add_points")) or registry.last_error.is_empty():
		_fail("Duplicate effect IDs should be rejected with a diagnostic error.")
		return
	print("PASS: CardEffectRegistry registers reusable handlers, routes context, and diagnoses unknown or duplicate IDs.")
	quit(0)


func _add_points(context: Dictionary) -> Dictionary:
	return {"success": true, "details": {"value": int(context.get("value", 0)) + 10}}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
