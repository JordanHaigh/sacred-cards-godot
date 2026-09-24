class_name BattleResolver
extends RefCounted

## UI-independent monster battle resolver.
##
## The resolver reads CardInstance runtime stats, resolves canonical monster
## type/alignment through CardDatabase, and writes only to DuelState/player
## state. Matchup bonus is configurable because exact source scaling remains
## an explicit project assumption.

const BATTLE_RESULT_SCRIPT = preload("res://scripts/duel/battle_result.gd")
const VICTORY_RESOLVER_SCRIPT = preload("res://scripts/duel/victory_resolver.gd")
const DUEL_EVENT_BUS_SCRIPT = preload("res://scripts/duel/duel_event_bus.gd")

var _card_database: Object
var _matchup_rules: Resource
var _environment: String
var _matchup_bonus: int


func _init(
		card_database: Object,
		matchup_rules: Resource,
		environment: String = "Field",
		matchup_bonus: int = 500,
	) -> void:
	_card_database = card_database
	_matchup_rules = matchup_rules
	_environment = environment
	_matchup_bonus = maxi(0, matchup_bonus)


func resolve(
		duel_state: Object,
		attacker_id: String,
		attacker_zone: int,
		defender_id: String,
		defender_zone: int = -1,
	) -> RefCounted:
	var result = BATTLE_RESULT_SCRIPT.new()
	result.attacker_id = attacker_id
	result.defender_id = defender_id
	result.attacker_zone = attacker_zone
	result.defender_zone = defender_zone
	if not _validate_request(duel_state, result):
		return result

	var attacker_player = duel_state.get_player(attacker_id)
	var defender_player = duel_state.get_player(defender_id)
	var attacker = attacker_player.get_monster_zone(attacker_zone)
	var defender = defender_player.get_monster_zone(defender_zone) if defender_zone >= 0 else null
	var attacker_definition = _resolve_definition(attacker)
	if attacker_definition == null:
		return _fail(result, "Attacker definition could not be resolved.")
	if defender != null and _resolve_definition(defender) == null:
		return _fail(result, "Defender definition could not be resolved.")

	result.success = true
	result.direct_attack = defender == null
	result.attacker_base_power = attacker.current_attack
	result.attacker_adjusted_power = attacker.current_attack
	if result.direct_attack:
		result.outcome = "direct_attack"
		result.life_point_damage = defender_player.take_damage(result.attacker_adjusted_power)
	else:
		result.defender_base_power = defender.current_attack if defender.get("battle_position") == "attack" else defender.current_defense
		result.defender_adjusted_power = result.defender_base_power
		_apply_matchups(result, attacker, defender, attacker_definition)
		_resolve_comparison(result, attacker_player, defender_player, attacker, defender)

	duel_state.record_battle(result.to_dictionary())
	duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_BATTLE_RESOLVED, result.to_dictionary())
	VICTORY_RESOLVER_SCRIPT.new().resolve(duel_state)
	return result


func _validate_request(duel_state: Object, result: Object) -> bool:
	if duel_state == null or not duel_state.has_method("get_player"):
		return _reject(result, "A valid DuelState is required.")
	if duel_state.get("status") != "in_progress":
		return _reject(result, "The duel is not in progress.")
	if duel_state.get("phase") != "battle":
		return _reject(result, "Battle resolution requires the battle phase.")
	if duel_state.get("active_player_id") != result.attacker_id:
		return _reject(result, "Only the active player can attack.")
	var attacker_player = duel_state.get_player(result.attacker_id)
	var defender_player = duel_state.get_player(result.defender_id)
	if attacker_player == null or defender_player == null or result.attacker_id == result.defender_id:
		return _reject(result, "Attacker and defender must be different duel players.")
	var attacker = attacker_player.get_monster_zone(result.attacker_zone)
	if attacker == null:
		return _reject(result, "Attacker zone does not contain a monster.")
	if attacker.get("face_state") != "face_up" or attacker.get("battle_position") != "attack":
		return _reject(result, "Only face-up attack-position monsters can attack.")
	if result.defender_zone >= 0:
		var defender = defender_player.get_monster_zone(result.defender_zone)
		if defender == null:
			return _reject(result, "Defender zone does not contain a monster.")
	else:
		for index in range(defender_player.monster_zone_count()):
			if defender_player.get_monster_zone(index) != null:
				return _reject(result, "Direct attack requires an empty defending monster field.")
	return true


func _resolve_comparison(result: Object, attacker_player: Object, defender_player: Object, attacker: Object, defender: Object) -> void:
	if result.attacker_adjusted_power > result.defender_adjusted_power:
		result.outcome = "attacker_win"
		result.defender_destroyed = true
		result.life_point_damage = defender_player.take_damage(result.attacker_adjusted_power - result.defender_adjusted_power)
		defender_player.send_to_graveyard(defender)
	elif result.attacker_adjusted_power < result.defender_adjusted_power:
		result.outcome = "defender_win"
		result.attacker_destroyed = true
		result.life_point_damage = attacker_player.take_damage(result.defender_adjusted_power - result.attacker_adjusted_power)
		attacker_player.send_to_graveyard(attacker)
	else:
		result.outcome = "draw"


func _apply_matchups(result: Object, attacker: Object, defender: Object, attacker_definition: Resource) -> void:
	if _matchup_rules == null:
		return
	var attacker_type := String(attacker_definition.get("monster_type"))
	var defender_definition := _resolve_definition(defender)
	result.type_environment_outcome = int(_matchup_rules.evaluate_type_environment(attacker_type, _environment))
	result.guardian_star_outcome = int(_matchup_rules.resolve_guardian_star_matchup(
		String(attacker.effective_attribute(_card_database)),
		String(defender.effective_attribute(_card_database)),
	))
	var attacker_edges := 0
	var defender_edges := 0
	for outcome in [result.type_environment_outcome, result.guardian_star_outcome]:
		if outcome == 1:
			attacker_edges += 1
		elif outcome == 2:
			defender_edges += 1
	if attacker_edges > defender_edges:
		result.attacker_adjusted_power += _matchup_bonus
		result.matchup_bonus = _matchup_bonus
	elif defender_edges > attacker_edges:
		result.defender_adjusted_power += _matchup_bonus
		result.matchup_bonus = -_matchup_bonus


func _resolve_definition(card: Object) -> Resource:
	if card == null or _card_database == null or not card.has_method("resolve_definition"):
		return null
	return card.resolve_definition(_card_database)


func _fail(result: Object, message: String) -> RefCounted:
	result.error = message
	return result


func _reject(result: Object, message: String) -> bool:
	result.error = message
	return false
