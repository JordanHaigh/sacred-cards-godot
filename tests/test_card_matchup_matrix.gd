extends SceneTree


func _init() -> void:
	var rules = load("res://resources/sacred_cards_matchups.tres")
	if rules == null:
		_fail("Could not load the Sacred Cards matchup resource.")
		return
	var validation_errors: PackedStringArray = rules.validate()
	if not validation_errors.is_empty():
		_fail("Configured matchup matrix is invalid: %s" % "; ".join(validation_errors))
		return

	var configured_advantages := 0
	for monster_type in rules.type_environment_advantages.keys():
		for environment in rules.type_environment_advantages[monster_type]:
			configured_advantages += 1
			if rules.evaluate_type_environment(str(monster_type), str(environment)) != 1:
				_fail("Configured advantage did not resolve for %s/%s." % [monster_type, environment])
				return
			if rules.evaluate_type_environment(str(monster_type), "Not an environment") != 0:
				_fail("Unknown environments should resolve neutrally.")
				return

	var configured_disadvantages := 0
	for monster_type in rules.type_environment_disadvantages.keys():
		for environment in rules.type_environment_disadvantages[monster_type]:
			configured_disadvantages += 1
			if rules.evaluate_type_environment(str(monster_type), str(environment)) != 2:
				_fail("Configured disadvantage did not resolve for %s/%s." % [monster_type, environment])
				return
	if configured_advantages != 17 or configured_disadvantages != 3:
		_fail("Expected 17 type/environment advantages and 3 disadvantages, got %d/%d." % [configured_advantages, configured_disadvantages])
		return

	var configured_guardian_edges := 0
	for guardian_star in rules.guardian_star_superiority.keys():
		for superior_star in rules.guardian_star_superiority[guardian_star]:
			configured_guardian_edges += 1
			if rules.resolve_guardian_star_matchup(str(guardian_star), str(superior_star)) != 1:
				_fail("Configured guardian-star edge did not resolve for %s/%s." % [guardian_star, superior_star])
				return
			if rules.resolve_guardian_star_matchup(str(superior_star), str(guardian_star)) != 2:
				_fail("Reverse guardian-star edge should favor the defender.")
				return
			if str(guardian_star) == str(superior_star):
				_fail("Configured guardian-star matrix must not contain self-advantage.")
				return
	if configured_guardian_edges != 10:
		_fail("Expected 10 configured guardian-star edges, got %d." % configured_guardian_edges)
		return

	var invalid_identifier = rules.duplicate(true)
	invalid_identifier.type_environment_advantages["Unknown Type"] = ["Sea"]
	invalid_identifier.type_environment_disadvantages["Fairy"] = ["Unknown Environment"]
	if invalid_identifier.validate().is_empty():
		_fail("Invalid matchup identifiers should produce diagnostics.")
		return

	var invalid_shape = rules.duplicate(true)
	invalid_shape.guardian_star_superiority["Fire"] = "Forest"
	if invalid_shape.validate().is_empty():
		_fail("Non-array matchup entries should produce diagnostics.")
		return

	var self_advantage = rules.duplicate(true)
	self_advantage.guardian_star_superiority["Fire"].append("Fire")
	if not _contains_error(self_advantage.validate(), "itself"):
		_fail("Guardian-star self-advantage should produce a targeted diagnostic.")
		return

	var contradiction = rules.duplicate(true)
	contradiction.guardian_star_superiority["Forest"] = ["Fire"]
	if not _contains_error(contradiction.validate(), "contradictory two-way"):
		_fail("Contradictory guardian-star edges should produce a targeted diagnostic.")
		return

	var overlap = rules.duplicate(true)
	overlap.type_environment_advantages["Fairy"] = ["Dark"]
	overlap.type_environment_disadvantages["Fairy"] = ["Dark"]
	if not _contains_error(overlap.validate(), "both advantage and disadvantage"):
		_fail("Overlapping type/environment edges should produce a targeted diagnostic.")
		return

	print("PASS: all configured type/environment and guardian-star matchup pairs resolve, and invalid matrix shapes, references, self-edges, overlaps, and contradictions are diagnosed.")
	quit(0)


func _contains_error(errors: PackedStringArray, expected_text: String) -> bool:
	for error in errors:
		if expected_text in error:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
