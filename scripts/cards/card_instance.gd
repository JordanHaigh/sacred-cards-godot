class_name CardInstance
extends RefCounted

## Mutable duel state for one use of a canonical CardDefinition.
##
## The instance stores the definition ID rather than copying card data. A
## CardDatabase is supplied when a system needs to resolve that ID.

const SERIAL_VERSION: int = 1

const BATTLE_POSITION_ATTACK := "attack"
const BATTLE_POSITION_DEFENSE := "defense"
const FACE_STATE_FACE_UP := "face_up"
const FACE_STATE_FACE_DOWN := "face_down"

var _definition_id: int
var _owner_id: String
var _current_attack: int = 0
var _current_defense: int = 0
var _battle_position: String = BATTLE_POSITION_ATTACK
var _face_state: String = FACE_STATE_FACE_UP
var _temporary_card_type: Variant = null
var _temporary_attribute: Variant = null
var _buffs: Array[Dictionary] = []
var _debuffs: Array[Dictionary] = []
var _statuses: Array[String] = []
var _turn_flags: Dictionary = {}
var _initialized_from_definition: bool = false

var definition_id: int:
	get:
		return _definition_id

var owner_id: String:
	get:
		return _owner_id
	set(value):
		_owner_id = value

var current_attack: int:
	get:
		return _current_attack
	set(value):
		_current_attack = maxi(0, value)

var current_defense: int:
	get:
		return _current_defense
	set(value):
		_current_defense = maxi(0, value)

var battle_position: String:
	get:
		return _battle_position
	set(value):
		if value == BATTLE_POSITION_ATTACK or value == BATTLE_POSITION_DEFENSE:
			_battle_position = value

var face_state: String:
	get:
		return _face_state
	set(value):
		if value == FACE_STATE_FACE_UP or value == FACE_STATE_FACE_DOWN:
			_face_state = value

var temporary_card_type: Variant:
	get:
		return _temporary_card_type
	set(value):
		if value == null or typeof(value) == TYPE_STRING:
			_temporary_card_type = value

var temporary_attribute: Variant:
	get:
		return _temporary_attribute
	set(value):
		if value == null or typeof(value) == TYPE_STRING:
			_temporary_attribute = value


func _init(card_id: int = 0, initial_owner_id: String = "") -> void:
	_definition_id = card_id
	_owner_id = initial_owner_id


func resolve_definition(database: Object) -> Resource:
	if database == null or not database.has_method("get_card"):
		return null
	var definition = database.call("get_card", _definition_id)
	if definition == null or not definition is Resource:
		return null
	return definition


func initialize_from_database(database: Object) -> bool:
	var definition := resolve_definition(database)
	if definition == null:
		return false
	_current_attack = int(definition.get("attack"))
	_current_defense = int(definition.get("defense"))
	_initialized_from_definition = true
	return true


func is_initialized() -> bool:
	return _initialized_from_definition


func set_temporary_card_type(card_type: Variant) -> bool:
	if card_type != null and typeof(card_type) != TYPE_STRING:
		return false
	_temporary_card_type = card_type
	return true


func set_temporary_attribute(attribute: Variant) -> bool:
	if attribute != null and typeof(attribute) != TYPE_STRING:
		return false
	_temporary_attribute = attribute
	return true


func effective_card_type(database: Object) -> Variant:
	if _temporary_card_type != null:
		return _temporary_card_type
	var definition := resolve_definition(database)
	return null if definition == null else definition.get("card_type")


func effective_attribute(database: Object) -> Variant:
	if _temporary_attribute != null:
		return _temporary_attribute
	var definition := resolve_definition(database)
	return null if definition == null else definition.get("alignment")


func add_buff(effect_id: String, attack_delta: int = 0, defense_delta: int = 0, duration_turns: int = -1) -> void:
	_buffs.append({
		"id": effect_id,
		"attack_delta": maxi(0, attack_delta),
		"defense_delta": maxi(0, defense_delta),
		"duration_turns": duration_turns,
	})


func add_debuff(effect_id: String, attack_delta: int = 0, defense_delta: int = 0, duration_turns: int = -1) -> void:
	_debuffs.append({
		"id": effect_id,
		"attack_delta": maxi(0, attack_delta),
		"defense_delta": maxi(0, defense_delta),
		"duration_turns": duration_turns,
	})


func buffs() -> Array[Dictionary]:
	return _buffs.duplicate(true)


func debuffs() -> Array[Dictionary]:
	return _debuffs.duplicate(true)


func add_status(status_id: String) -> void:
	if not _statuses.has(status_id):
		_statuses.append(status_id)


func remove_status(status_id: String) -> void:
	_statuses.erase(status_id)


func has_status(status_id: String) -> bool:
	return _statuses.has(status_id)


func statuses() -> Array[String]:
	return _statuses.duplicate()


func set_turn_flag(flag_id: String, enabled: bool = true) -> void:
	_turn_flags[flag_id] = enabled


func has_turn_flag(flag_id: String) -> bool:
	return bool(_turn_flags.get(flag_id, false))


func turn_flags() -> Dictionary:
	return _turn_flags.duplicate(true)


func to_serialized() -> Dictionary:
	return {
		"version": SERIAL_VERSION,
		"definition_id": _definition_id,
		"owner_id": _owner_id,
		"current_attack": _current_attack,
		"current_defense": _current_defense,
		"battle_position": _battle_position,
		"face_state": _face_state,
		"temporary_card_type": _temporary_card_type,
		"temporary_attribute": _temporary_attribute,
		"buffs": _buffs.duplicate(true),
		"debuffs": _debuffs.duplicate(true),
		"statuses": _statuses.duplicate(),
		"turn_flags": _turn_flags.duplicate(true),
	}


static func from_serialized(data: Dictionary) -> RefCounted:
	var instance = load("res://scripts/cards/card_instance.gd").new(
		int(data.get("definition_id", 0)),
		String(data.get("owner_id", "")),
	)
	instance._current_attack = maxi(0, int(data.get("current_attack", 0)))
	instance._current_defense = maxi(0, int(data.get("current_defense", 0)))
	instance.battle_position = String(data.get("battle_position", BATTLE_POSITION_ATTACK))
	instance.face_state = String(data.get("face_state", FACE_STATE_FACE_UP))
	instance.set_temporary_card_type(data.get("temporary_card_type"))
	instance.set_temporary_attribute(data.get("temporary_attribute"))
	instance._copy_dictionary_array(data.get("buffs", []), instance._buffs)
	instance._copy_dictionary_array(data.get("debuffs", []), instance._debuffs)
	instance._copy_string_array(data.get("statuses", []), instance._statuses)
	if data.get("turn_flags", {}) is Dictionary:
		instance._turn_flags = data["turn_flags"].duplicate(true)
	return instance


func _copy_dictionary_array(source: Variant, destination: Array[Dictionary]) -> void:
	if not source is Array:
		return
	for entry in source:
		if entry is Dictionary:
			destination.append(entry.duplicate(true))


func _copy_string_array(source: Variant, destination: Array[String]) -> void:
	if not source is Array:
		return
	for entry in source:
		if typeof(entry) == TYPE_STRING:
			destination.append(String(entry))
