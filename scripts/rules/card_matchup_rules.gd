class_name CardMatchupRules
extends Resource

## Editable Sacred Cards matchup tables.
##
## The tables are kept in a Resource so battle code can query them without
## embedding matchup constants or a large conditional statement.

enum Outcome {
	NEUTRAL,
	ATTACKER_ADVANTAGE,
	DEFENDER_ADVANTAGE,
}

const VALID_MONSTER_TYPES: PackedStringArray = [
	"Aqua",
	"Beast",
	"Beast-Warrior",
	"Dinosaur",
	"Dragon",
	"Fairy",
	"Fiend",
	"Fish",
	"Insect",
	"Machine",
	"Plant",
	"Pyro",
	"Reptile",
	"Rock",
	"Sea Serpent",
	"Spellcaster",
	"Thunder",
	"Warrior",
	"Winged Beast",
	"Zombie",
]

const VALID_ENVIRONMENTS: PackedStringArray = [
	"Mountains",
	"Dark",
	"Wasteland",
	"Field",
	"Forest",
	"Sea",
]

const VALID_GUARDIAN_STARS: PackedStringArray = [
	"Fire",
	"Forest",
	"Wind",
	"Earth",
	"Thunder",
	"Water",
	"Dark",
	"Light",
	"Fiend",
	"Dreams",
	"Divine",
]

@export_category("Type and Environment")
@export var type_environment_advantages: Dictionary = {}
@export var type_environment_disadvantages: Dictionary = {}

@export_category("Guardian Stars")
@export var guardian_star_superiority: Dictionary = {}


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(_validate_mapping(
		type_environment_advantages,
		VALID_MONSTER_TYPES,
		VALID_ENVIRONMENTS,
		"type_environment_advantages",
	))
	errors.append_array(_validate_mapping(
		type_environment_disadvantages,
		VALID_MONSTER_TYPES,
		VALID_ENVIRONMENTS,
		"type_environment_disadvantages",
	))
	errors.append_array(_validate_mapping(
		guardian_star_superiority,
		VALID_GUARDIAN_STARS,
		VALID_GUARDIAN_STARS,
		"guardian_star_superiority",
	))

	for monster_type in type_environment_advantages.keys():
		var advantages = type_environment_advantages[monster_type]
		var disadvantages = type_environment_disadvantages.get(monster_type, [])
		if advantages is Array and disadvantages is Array:
			for environment in advantages:
				if disadvantages.has(environment):
					errors.append("%s cannot both advantage and disadvantage %s." % [monster_type, environment])

	for guardian_star in guardian_star_superiority.keys():
		var superior_to = guardian_star_superiority[guardian_star]
		if not superior_to is Array:
			continue
		for other_star in superior_to:
			if _contains(guardian_star_superiority, str(other_star), str(guardian_star)):
				errors.append("guardian_star_superiority contains a contradictory two-way rule for %s and %s." % [guardian_star, other_star])

	return errors


func evaluate_type_environment(monster_type: String, environment: String) -> Outcome:
	if _contains(type_environment_advantages, monster_type, environment):
		return Outcome.ATTACKER_ADVANTAGE
	if _contains(type_environment_disadvantages, monster_type, environment):
		return Outcome.DEFENDER_ADVANTAGE
	return Outcome.NEUTRAL


func resolve_guardian_star_matchup(attacker_star: String, defender_star: String) -> Outcome:
	if _contains(guardian_star_superiority, attacker_star, defender_star):
		return Outcome.ATTACKER_ADVANTAGE
	if _contains(guardian_star_superiority, defender_star, attacker_star):
		return Outcome.DEFENDER_ADVANTAGE
	return Outcome.NEUTRAL


func _validate_mapping(mapping: Dictionary, valid_keys: PackedStringArray, valid_values: PackedStringArray, label: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for raw_key in mapping.keys():
		var key := str(raw_key)
		if not valid_keys.has(key):
			errors.append("%s has invalid key '%s'." % [label, key])
		var values = mapping[raw_key]
		if not values is Array:
			errors.append("%s.%s must contain an array of identifiers." % [label, key])
			continue
		for raw_value in values:
			var value := str(raw_value)
			if not valid_values.has(value):
				errors.append("%s.%s has invalid value '%s'." % [label, key, value])
	return errors


func _contains(mapping: Dictionary, key: String, value: String) -> bool:
	var values = mapping.get(key, [])
	return values is Array and values.has(value)
