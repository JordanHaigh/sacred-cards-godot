class_name DuelState
extends RefCounted

## Authoritative, UI-independent state for one duel.
##
## Player collections remain owned by DuelPlayerState. This object owns the
## turn lifecycle and records events that later systems can resolve or display.

const SERIAL_VERSION: int = 1

const STATUS_SETUP := "setup"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_FINISHED := "finished"

const PHASE_DRAW := "draw"
const PHASE_MAIN := "main"
const PHASE_BATTLE := "battle"
const PHASE_END := "end"

const PLAYER_STATE_SCRIPT = preload("res://scripts/duel/duel_player_state.gd")
const DEFAULT_RULESET_PATH := "res://resources/sacred_cards_rules.tres"

var _ruleset: Resource
var _players: Dictionary = {}
var _player_order: Array[String] = []
var _active_player_id: String = ""
var _turn_number: int = 0
var _status: String = STATUS_SETUP
var _phase: String = PHASE_DRAW
var _winner_id: String = ""
var _pending_actions: Array[Dictionary] = []
var _pending_effects: Array[Dictionary] = []
var _battle_history: Array[Dictionary] = []

var ruleset: Resource:
	get:
		return _ruleset

var active_player_id: String:
	get:
		return _active_player_id

var turn_number: int:
	get:
		return _turn_number

var status: String:
	get:
		return _status

var phase: String:
	get:
		return _phase

var winner_id: String:
	get:
		return _winner_id


func _init(
		initial_ruleset: Resource = null,
		first_player_id: String = "player_one",
		second_player_id: String = "player_two",
	) -> void:
	_ruleset = initial_ruleset
	if _ruleset == null:
		_ruleset = load(DEFAULT_RULESET_PATH)
	_add_player(first_player_id)
	_add_player(second_player_id)
	if not _player_order.is_empty():
		_active_player_id = _player_order[0]


func start() -> bool:
	if _status != STATUS_SETUP or _player_order.size() != 2:
		return false
	_status = STATUS_IN_PROGRESS
	_turn_number = 1
	_phase = PHASE_DRAW
	_winner_id = ""
	return true


func set_phase(next_phase: String) -> bool:
	if _status != STATUS_IN_PROGRESS or not _is_valid_phase(next_phase):
		return false
	_phase = next_phase
	return true


func advance_turn() -> bool:
	if _status != STATUS_IN_PROGRESS or _player_order.size() != 2:
		return false
	var active_index := _player_order.find(_active_player_id)
	if active_index < 0:
		return false
	_active_player_id = _player_order[(active_index + 1) % _player_order.size()]
	_turn_number += 1
	_phase = PHASE_DRAW
	return true


func finish(next_winner_id: String = "") -> bool:
	if _status != STATUS_IN_PROGRESS:
		return false
	if not next_winner_id.is_empty() and not _players.has(next_winner_id):
		return false
	_status = STATUS_FINISHED
	_phase = PHASE_END
	_winner_id = next_winner_id
	return true


func forfeit(player_id: String) -> bool:
	if _status != STATUS_IN_PROGRESS or not _players.has(player_id):
		return false
	for candidate_id in _player_order:
		if candidate_id != player_id:
			return finish(candidate_id)
	return finish()


func get_player(player_id: String) -> RefCounted:
	return _players.get(player_id, null)


func has_player(player_id: String) -> bool:
	return _players.has(player_id)


func get_players() -> Array[RefCounted]:
	var players: Array[RefCounted] = []
	for player_id in _player_order:
		players.append(_players[player_id])
	return players


func player_ids() -> Array[String]:
	return _player_order.duplicate()


func queue_action(action: Dictionary) -> int:
	_pending_actions.append(action.duplicate(true))
	return _pending_actions.size() - 1


func queue_effect(effect: Dictionary) -> int:
	_pending_effects.append(effect.duplicate(true))
	return _pending_effects.size() - 1


func get_pending_actions() -> Array[Dictionary]:
	return _pending_actions.duplicate(true)


func get_pending_effects() -> Array[Dictionary]:
	return _pending_effects.duplicate(true)


func pop_pending_action() -> Dictionary:
	if _pending_actions.is_empty():
		return {}
	return _pending_actions.pop_front()


func pop_pending_effect() -> Dictionary:
	if _pending_effects.is_empty():
		return {}
	return _pending_effects.pop_front()


func record_battle(result: Dictionary) -> int:
	_battle_history.append(result.duplicate(true))
	return _battle_history.size() - 1


func get_battle_history() -> Array[Dictionary]:
	return _battle_history.duplicate(true)


func to_serialized() -> Dictionary:
	var serialized_players: Array[Dictionary] = []
	for player_id in _player_order:
		serialized_players.append(_serialize_player(_players[player_id]))
	return {
		"version": SERIAL_VERSION,
		"status": _status,
		"phase": _phase,
		"turn_number": _turn_number,
		"active_player_id": _active_player_id,
		"winner_id": _winner_id,
		"ruleset": _serialize_ruleset(),
		"players": serialized_players,
		"pending_actions": _pending_actions.duplicate(true),
		"pending_effects": _pending_effects.duplicate(true),
		"battle_history": _battle_history.duplicate(true),
	}


func to_debug_string() -> String:
	return JSON.stringify(to_serialized())


func _add_player(player_id: String) -> bool:
	if player_id.is_empty() or _players.has(player_id):
		return false
	var player = PLAYER_STATE_SCRIPT.new(
		player_id,
		_rule_value("starting_life_points", 8000),
		_rule_value("monster_zone_count", 5),
		_rule_value("spell_trap_zone_count", 5),
		_rule_value("field_zone_count", 1),
	)
	_players[player_id] = player
	_player_order.append(player_id)
	return true


func _rule_value(property_name: String, fallback: int) -> int:
	if _ruleset == null:
		return fallback
	return int(_ruleset.get(property_name))


func _is_valid_phase(candidate_phase: String) -> bool:
	return candidate_phase in [PHASE_DRAW, PHASE_MAIN, PHASE_BATTLE, PHASE_END]


func _serialize_ruleset() -> Dictionary:
	return {
		"starting_life_points": _rule_value("starting_life_points", 8000),
		"opening_hand_size": _rule_value("opening_hand_size", 5),
		"starting_deck_size": _rule_value("starting_deck_size", 40),
		"monster_zone_count": _rule_value("monster_zone_count", 5),
		"spell_trap_zone_count": _rule_value("spell_trap_zone_count", 5),
		"field_zone_count": _rule_value("field_zone_count", 1),
	}


func _serialize_player(player: RefCounted) -> Dictionary:
	var monster_zones: Array = []
	for index in range(player.monster_zone_count()):
		monster_zones.append(_card_definition_id(player.get_monster_zone(index)))
	var spell_trap_zones: Array = []
	for index in range(player.spell_trap_zone_count()):
		spell_trap_zones.append(_card_definition_id(player.get_spell_trap_zone(index)))
	return {
		"player_id": player.player_id,
		"life_points": player.life_points,
		"deck_size": player.deck_size(),
		"hand_size": player.hand_size(),
		"graveyard_size": player.graveyard_size(),
		"monster_zones": monster_zones,
		"spell_trap_zones": spell_trap_zones,
		"field_zone": _card_definition_id(player.get_field_zone()),
	}


func _card_definition_id(card: RefCounted) -> Variant:
	if card == null:
		return null
	if not card.has_method("to_serialized"):
		return null
	return card.get("definition_id")
