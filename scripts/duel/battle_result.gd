class_name BattleResult
extends RefCounted

## Serializable result of one resolved attack.

var success: bool = false
var error: String = ""
var outcome: String = ""
var attacker_id: String = ""
var defender_id: String = ""
var attacker_zone: int = -1
var defender_zone: int = -1
var direct_attack: bool = false
var attacker_base_power: int = 0
var defender_base_power: int = 0
var attacker_adjusted_power: int = 0
var defender_adjusted_power: int = 0
var type_environment_outcome: int = 0
var guardian_star_outcome: int = 0
var matchup_bonus: int = 0
var life_point_damage: int = 0
var attacker_destroyed: bool = false
var defender_destroyed: bool = false


func to_dictionary() -> Dictionary:
	return {
		"success": success,
		"error": error,
		"outcome": outcome,
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"attacker_zone": attacker_zone,
		"defender_zone": defender_zone,
		"direct_attack": direct_attack,
		"attacker_base_power": attacker_base_power,
		"defender_base_power": defender_base_power,
		"attacker_adjusted_power": attacker_adjusted_power,
		"defender_adjusted_power": defender_adjusted_power,
		"type_environment_outcome": type_environment_outcome,
		"guardian_star_outcome": guardian_star_outcome,
		"matchup_bonus": matchup_bonus,
		"life_point_damage": life_point_damage,
		"attacker_destroyed": attacker_destroyed,
		"defender_destroyed": defender_destroyed,
	}
