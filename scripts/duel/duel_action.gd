class_name DuelAction
extends RefCounted

## A validated command that can be issued by UI, AI, or another duel system.
##
## The action never owns duel state. It validates against and mutates only the
## supplied DuelState, leaving presentation and input concerns outside this
## class.

const ACTION_DRAW := "draw"
const ACTION_SUMMON := "summon"
const ACTION_SET_MONSTER := "set_monster"
const ACTION_SET_SPELL_TRAP := "set_spell_trap"
const ACTION_CHANGE_POSITION := "change_position"
const ACTION_ATTACK := "attack"
const ACTION_END_TURN := "end_turn"

const PHASE_DRAW := "draw"
const PHASE_MAIN := "main"
const PHASE_BATTLE := "battle"
const PHASE_END := "end"

var _action_type: String
var _actor_id: String
var _payload: Dictionary
var _last_error: String = ""

var action_type: String:
	get:
		return _action_type

var actor_id: String:
	get:
		return _actor_id

var last_error: String:
	get:
		return _last_error


func _init(action_kind: String = "", initial_actor_id: String = "", action_payload: Dictionary = {}) -> void:
	_action_type = action_kind
	_actor_id = initial_actor_id
	_payload = action_payload.duplicate(true)


func payload() -> Dictionary:
	return _payload.duplicate(true)


func validate(duel_state: Object) -> bool:
	_last_error = ""
	if duel_state == null or not duel_state.has_method("get_player"):
		return _fail("A valid DuelState is required.")
	if duel_state.get("status") != "in_progress":
		return _fail("The duel is not in progress.")
	if duel_state.get("active_player_id") != _actor_id:
		return _fail("Only the active player can perform this action.")
	var player = duel_state.call("get_player", _actor_id)
	if player == null:
		return _fail("Unknown action actor '%s'." % _actor_id)

	match _action_type:
		ACTION_DRAW:
			if duel_state.get("phase") != PHASE_DRAW:
				return _fail("Draw is only legal during the draw phase.")
			if player.call("deck_size") <= 0:
				return _fail("Cannot draw because the deck is empty.")
			return true
		ACTION_END_TURN:
			if not [PHASE_MAIN, PHASE_BATTLE, PHASE_END].has(duel_state.get("phase")):
				return _fail("End turn is not legal during the current phase.")
			return true
		ACTION_SUMMON, ACTION_SET_MONSTER, ACTION_SET_SPELL_TRAP:
			return _validate_card_play(duel_state, player)
		ACTION_CHANGE_POSITION:
			return _validate_position_change(player)
		ACTION_ATTACK:
			return _validate_attack(duel_state, player)
		_:
			return _fail("Unknown action type '%s'." % _action_type)


func execute(duel_state: Object) -> bool:
	if not validate(duel_state):
		return false
	var player = duel_state.call("get_player", _actor_id)

	match _action_type:
		ACTION_DRAW:
			player.call("draw_card")
			duel_state.set_phase(PHASE_MAIN)
			return true
		ACTION_END_TURN:
			return duel_state.end_turn()
		ACTION_SUMMON:
			var summon_card = _card_in_hand(player)
			var summon_zone := int(_payload.get("zone_index", -1))
			if player.place_monster(summon_card, summon_zone) < 0:
				return _fail("Summon could not place the card in the requested zone.")
			summon_card.set("battle_position", "attack")
			summon_card.set("face_state", "face_up")
			return true
		ACTION_SET_MONSTER:
			var set_monster_card = _card_in_hand(player)
			var set_monster_zone := int(_payload.get("zone_index", -1))
			if player.place_monster(set_monster_card, set_monster_zone) < 0:
				return _fail("Set monster could not place the card in the requested zone.")
			set_monster_card.set("battle_position", "defense")
			set_monster_card.set("face_state", "face_down")
			return true
		ACTION_SET_SPELL_TRAP:
			var set_card = _card_in_hand(player)
			var set_zone := int(_payload.get("zone_index", -1))
			if player.place_spell_trap(set_card, set_zone) < 0:
				return _fail("Set spell/trap could not place the card in the requested zone.")
			set_card.set("face_state", "face_down")
			return true
		ACTION_CHANGE_POSITION:
			var position_card = player.get_monster_zone(int(_payload["zone_index"]))
			position_card.set("battle_position", String(_payload["position"]))
			return true
		ACTION_ATTACK:
			var attack_record := _payload.duplicate(true)
			attack_record["type"] = ACTION_ATTACK
			attack_record["actor_id"] = _actor_id
			duel_state.queue_action(attack_record)
			return true
	return _fail("Action execution was not implemented for '%s'." % _action_type)


static func draw(actor_id: String) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_DRAW, actor_id)


static func summon(actor_id: String, card_id: int, card_type: String, zone_index: int = -1) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_SUMMON, actor_id, {
		"card_id": card_id,
		"card_type": card_type,
		"zone_index": zone_index,
	})


static func set_monster(actor_id: String, card_id: int, card_type: String, zone_index: int = -1) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_SET_MONSTER, actor_id, {
		"card_id": card_id,
		"card_type": card_type,
		"zone_index": zone_index,
	})


static func set_spell_trap(actor_id: String, card_id: int, card_type: String, zone_index: int = -1) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_SET_SPELL_TRAP, actor_id, {
		"card_id": card_id,
		"card_type": card_type,
		"zone_index": zone_index,
	})


static func change_position(actor_id: String, zone_index: int, position: String) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_CHANGE_POSITION, actor_id, {
		"zone_index": zone_index,
		"position": position,
	})


static func attack(actor_id: String, attacker_zone: int, defender_id: String, defender_zone: int = -1) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_ATTACK, actor_id, {
		"attacker_zone": attacker_zone,
		"defender_id": defender_id,
		"defender_zone": defender_zone,
	})


static func end_turn(actor_id: String) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_END_TURN, actor_id)


func _validate_card_play(duel_state: Object, player: Object) -> bool:
	if duel_state.get("phase") != PHASE_MAIN:
		return _fail("Card play is only legal during the main phase.")
	var card_type := String(_payload.get("card_type", ""))
	if _action_type in [ACTION_SUMMON, ACTION_SET_MONSTER] and card_type != "Monster":
		return _fail("Monster actions require card_type 'Monster'.")
	if _action_type == ACTION_SET_SPELL_TRAP and not ["Magic", "Trap"].has(card_type):
		return _fail("Set spell/trap requires card_type 'Magic' or 'Trap'.")
	var card = _card_in_hand(player)
	if card == null:
		return _fail("Card ID %s is not in the actor's hand." % _payload.get("card_id", ""))
	if _action_type in [ACTION_SUMMON, ACTION_SET_MONSTER]:
		if player.get_open_monster_zone_index() < 0 and int(_payload.get("zone_index", -1)) < 0:
			return _fail("No open monster zone is available.")
	else:
		if player.get_open_spell_trap_zone_index() < 0 and int(_payload.get("zone_index", -1)) < 0:
			return _fail("No open spell/trap zone is available.")
	return true


func _validate_position_change(player: Object) -> bool:
	if player == null:
		return _fail("Unknown action actor.")
	var zone_index := int(_payload.get("zone_index", -1))
	if zone_index < 0 or player.get_monster_zone(zone_index) == null:
		return _fail("Position change requires a monster in the requested zone.")
	var position := String(_payload.get("position", ""))
	if not ["attack", "defense"].has(position):
		return _fail("Position must be 'attack' or 'defense'.")
	if _payload.get("position") == player.get_monster_zone(zone_index).get("battle_position"):
		return _fail("Card is already in that battle position.")
	return true


func _validate_attack(duel_state: Object, player: Object) -> bool:
	if duel_state.get("phase") != PHASE_BATTLE:
		return _fail("Attack is only legal during the battle phase.")
	var attacker_zone := int(_payload.get("attacker_zone", -1))
	var attacker = player.get_monster_zone(attacker_zone)
	if attacker == null:
		return _fail("Attack requires a monster in the requested attacker zone.")
	if attacker.get("face_state") != "face_up" or attacker.get("battle_position") != "attack":
		return _fail("Only face-up attack-position monsters can attack.")
	var defender_id := String(_payload.get("defender_id", ""))
	var defender = duel_state.get_player(defender_id)
	if defender == null or defender_id == _actor_id:
		return _fail("Attack requires a different valid defending player.")
	var defender_zone := int(_payload.get("defender_zone", -1))
	if defender_zone >= 0 and defender.get_monster_zone(defender_zone) == null:
		return _fail("The requested defending zone is empty.")
	return true


func _card_in_hand(player: Object) -> RefCounted:
	var requested_id := int(_payload.get("card_id", -1))
	for card in player.get_hand():
		if int(card.get("definition_id")) == requested_id:
			return card
	return null


func _fail(message: String) -> bool:
	_last_error = message
	return false
