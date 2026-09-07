extends SceneTree


func _init() -> void:
	var rules = load("res://resources/sacred_cards_rules.tres")
	if rules == null:
		_fail("Could not load the Sacred Cards DuelRuleSet resource.")
		return

	var validation_errors: PackedStringArray = rules.validate()
	if not validation_errors.is_empty():
		_fail("DuelRuleSet validation failed: %s" % "; ".join(validation_errors))
		return

	if rules.starting_life_points != 8000 or rules.opening_hand_size != 5:
		_fail("Sacred Cards starting rules were not loaded.")
		return
	if rules.draw_count_for_turn(1) != 0 or rules.draw_count_for_turn(2) != 1:
		_fail("Draw rules are incorrect.")
		return
	if rules.required_tributes_for_level(4) != 0:
		_fail("Low-level monsters should not require tributes.")
		return
	if rules.required_tributes_for_level(5) != 1 or rules.required_tributes_for_level(7) != 2:
		_fail("Tribute thresholds are incorrect.")
		return
	if not rules.can_direct_attack(0) or rules.can_direct_attack(1):
		_fail("Direct-attack rule is incorrect.")
		return
	if not rules.is_defeat(0) or rules.is_defeat(1, false):
		_fail("Victory and deck-out rules are incorrect.")
		return

	print("PASS: Sacred Cards DuelRuleSet loaded, validated, and returned expected draw, summon, direct-attack, and defeat rules.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
