class_name DuelRuleSet
extends Resource

## Configurable rules shared by duel systems.
##
## This resource owns rules that would otherwise become magic numbers in
## battle, draw, and victory code. Mutable duel state belongs elsewhere.

@export_category("Starting State")
@export_range(1, 99999, 1) var starting_life_points: int = 8000
@export_range(1, 60, 1) var opening_hand_size: int = 5
@export_range(1, 60, 1) var starting_deck_size: int = 40

@export_category("Zones")
@export_range(1, 10, 1) var monster_zone_count: int = 5
@export_range(1, 10, 1) var spell_trap_zone_count: int = 5
@export_range(0, 1, 1) var field_zone_count: int = 1

@export_category("Draw")
@export_range(0, 10, 1) var draws_per_turn: int = 1
@export var first_player_draws_on_first_turn: bool = false

@export_category("Summoning")
@export_range(1, 10, 1) var normal_summons_per_turn: int = 1
@export var tribute_summons_enabled: bool = true
@export_range(1, 12, 1) var one_tribute_minimum_level: int = 5
@export_range(1, 12, 1) var two_tribute_minimum_level: int = 7

@export_category("Combat")
@export var direct_attack_requires_empty_field: bool = true
@export var direct_attack_uses_attacker_attack: bool = true

@export_category("Victory")
@export var zero_life_points_is_defeat: bool = true
@export var deck_out_causes_defeat: bool = false


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if starting_life_points <= 0:
		errors.append("starting_life_points must be greater than zero.")
	if opening_hand_size <= 0:
		errors.append("opening_hand_size must be greater than zero.")
	if starting_deck_size < opening_hand_size:
		errors.append("starting_deck_size must hold the opening hand.")
	if monster_zone_count <= 0:
		errors.append("monster_zone_count must be greater than zero.")
	if spell_trap_zone_count <= 0:
		errors.append("spell_trap_zone_count must be greater than zero.")
	if field_zone_count < 0:
		errors.append("field_zone_count cannot be negative.")
	if draws_per_turn < 0:
		errors.append("draws_per_turn cannot be negative.")
	if normal_summons_per_turn <= 0:
		errors.append("normal_summons_per_turn must be greater than zero.")
	if one_tribute_minimum_level >= two_tribute_minimum_level:
		errors.append("two_tribute_minimum_level must be higher than one_tribute_minimum_level.")

	return errors


func draw_count_for_turn(turn_number: int) -> int:
	if turn_number <= 0:
		return 0
	if turn_number == 1 and not first_player_draws_on_first_turn:
		return 0
	return draws_per_turn


func required_tributes_for_level(level: int) -> int:
	if not tribute_summons_enabled or level < one_tribute_minimum_level:
		return 0
	if level >= two_tribute_minimum_level:
		return 2
	return 1


func can_direct_attack(defending_monster_count: int) -> bool:
	if not direct_attack_requires_empty_field:
		return true
	return defending_monster_count == 0


func is_defeat(life_points: int, draw_succeeded: bool = true) -> bool:
	if zero_life_points_is_defeat and life_points <= 0:
		return true
	return deck_out_causes_defeat and not draw_succeeded
