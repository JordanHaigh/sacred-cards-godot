extends SceneTree


func _init() -> void:
	var rules = load("res://resources/sacred_cards_matchups.tres")
	if rules == null:
		_fail("Could not load the Sacred Cards matchup resource.")
		return

	var validation_errors: PackedStringArray = rules.validate()
	if not validation_errors.is_empty():
		_fail("Matchup validation failed: %s" % "; ".join(validation_errors))
		return

	if rules.evaluate_type_environment("Dragon", "Mountains") != 1:
		_fail("Dragon should have an advantage in Mountains.")
		return
	if rules.evaluate_type_environment("Fairy", "Dark") != 2:
		_fail("Fairy should have a disadvantage in Dark.")
		return
	if rules.evaluate_type_environment("Beast", "Mountains") != 0:
		_fail("Unconfigured type/environment pairs should be neutral.")
		return
	if rules.resolve_guardian_star_matchup("Fire", "Forest") != 1:
		_fail("Fire should be superior to Forest.")
		return
	if rules.resolve_guardian_star_matchup("Forest", "Fire") != 2:
		_fail("Forest versus Fire should favor the defender.")
		return
	if rules.resolve_guardian_star_matchup("Divine", "Fire") != 0:
		_fail("Unconfigured Divine matchups should be neutral.")
		return

	var invalid_rules = rules.duplicate(true)
	invalid_rules.type_environment_advantages["Not a monster type"] = ["Sea"]
	var invalid_errors: PackedStringArray = invalid_rules.validate()
	if invalid_errors.is_empty():
		_fail("Invalid matchup identifiers should produce diagnostics.")
		return

	print("PASS: type/environment and guardian-star matchups resolve deterministically and invalid entries are diagnosed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
