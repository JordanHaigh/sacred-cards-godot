extends RefCounted
class_name SacredBattleState

## Typed replacement for battle_state.c's packed calculation/display buffers.

const CALCULATOR_SCRIPT = preload("res://scripts/systems/battle_calculator.gd")

signal battle_resolved(result_code: int, result_flags: int, old_life_points: Array[int], new_life_points: Array[int])

var command: int = 0
var amount_a: int = 0
var amount_b: int = 0
var owner_a: int = 0
var owner_b: int = 1
var last_result_code: int = 0
var last_result_flags: int = 0

func prepare_heal_side_a(amount: int) -> void:
	command = 7
	amount_a = amount & 0xFFFF

func prepare_damage_side_a(amount: int) -> void:
	command = 8
	amount_a = amount & 0xFFFF

func prepare_damage_side_b(amount: int) -> void:
	command = 9
	amount_b = amount & 0xFFFF

func prepare_heal_side_b(amount: int) -> void:
	command = 10
	amount_b = amount & 0xFFFF

func resolve(duel: SacredDuelState, a: Dictionary, b: Dictionary) -> void:
	var old_life_points: Array[int] = [duel.sides[0].life_points, duel.sides[1].life_points]
	var side_a = CALCULATOR_SCRIPT.BattleSide.new()
	var side_b = CALCULATOR_SCRIPT.BattleSide.new()
	_apply_input(side_a, a, duel.sides[0].life_points, owner_a)
	_apply_input(side_b, b, duel.sides[1].life_points, owner_b)
	if command == 7 or command == 8:
		side_a.attack = amount_a
	elif command == 9 or command == 10:
		side_b.attack = amount_b
	var result = CALCULATOR_SCRIPT.resolve(side_a, side_b, command, last_result_code)
	duel.sides[0].life_points = result.side_a.life_points
	duel.sides[1].life_points = result.side_b.life_points
	last_result_code = result.code
	last_result_flags = result.flags
	duel.check_victory()
	var new_life_points: Array[int] = [duel.sides[0].life_points, duel.sides[1].life_points]
	battle_resolved.emit(last_result_code, last_result_flags, old_life_points, new_life_points)

func resolve_setup(duel: SacredDuelState, setup: Dictionary) -> void:
	if setup.is_empty():
		return
	command = int(setup.get("command", 0))
	var side_a: Dictionary = setup.get("side_a", {})
	var side_b: Dictionary = setup.get("side_b", {})
	owner_a = int(side_a.get("owner", 0))
	owner_b = int(side_b.get("owner", 1))
	resolve(duel, side_a, side_b)

func _apply_input(target, values: Dictionary, life_points: int, owner_id: int) -> void:
	target.attack = int(values.get("attack", 0)) & 0xFFFF
	target.defense = int(values.get("defense", 0)) & 0xFFFF
	target.life_points = life_points
	target.attribute = int(values.get("attribute", 0)) & 0xFF
	target.owner = owner_id
