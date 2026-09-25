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
const ACTION_ACTIVATE_EFFECT := "activate_effect"

const PHASE_DRAW := "draw"
const PHASE_MAIN := "main"
const PHASE_BATTLE := "battle"
const PHASE_END := "end"
const DUEL_EVENT_BUS_SCRIPT = preload("res://scripts/duel/duel_event_bus.gd")

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


func validate(duel_state: Object, effect_registry: Object = null) -> bool:
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
		ACTION_ACTIVATE_EFFECT:
			return _validate_effect_activation(duel_state, player, effect_registry)
		_:
			return _fail("Unknown action type '%s'." % _action_type)


func execute(duel_state: Object, effect_registry: Object = null) -> bool:
	if not validate(duel_state, effect_registry):
		return false
	var player = duel_state.call("get_player", _actor_id)

	match _action_type:
		ACTION_DRAW:
			var drawn_card = player.call("draw_card")
			duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_CARD_DRAWN, {
				"player_id": _actor_id,
				"card_id": int(drawn_card.get("definition_id")),
			})
			duel_state.set_phase(PHASE_MAIN)
			_publish_action(duel_state)
			return true
		ACTION_END_TURN:
			if not bool(duel_state.call("end_turn")):
				return _fail(String(duel_state.get("last_transition_error")))
			_publish_action(duel_state)
			return true
		ACTION_SUMMON:
			var summon_card = _card_in_hand(player)
			var summon_zone := int(_payload.get("zone_index", -1))
			if player.place_monster(summon_card, summon_zone) < 0:
				return _fail("Summon could not place the card in the requested zone.")
			summon_card.set("battle_position", "attack")
			summon_card.set("face_state", "face_up")
			duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_CARD_PLAYED, _card_event_payload(summon_card, summon_zone, "summon"))
			_publish_action(duel_state)
			return true
		ACTION_SET_MONSTER:
			var set_monster_card = _card_in_hand(player)
			var set_monster_zone := int(_payload.get("zone_index", -1))
			if player.place_monster(set_monster_card, set_monster_zone) < 0:
				return _fail("Set monster could not place the card in the requested zone.")
			set_monster_card.set("battle_position", "defense")
			set_monster_card.set("face_state", "face_down")
			duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_CARD_PLAYED, _card_event_payload(set_monster_card, set_monster_zone, "set_monster"))
			_publish_action(duel_state)
			return true
		ACTION_SET_SPELL_TRAP:
			var set_card = _card_in_hand(player)
			var set_zone := int(_payload.get("zone_index", -1))
			if player.place_spell_trap(set_card, set_zone) < 0:
				return _fail("Set spell/trap could not place the card in the requested zone.")
			set_card.set("face_state", "face_down")
			duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_CARD_PLAYED, _card_event_payload(set_card, set_zone, "set_spell_trap"))
			_publish_action(duel_state)
			return true
		ACTION_CHANGE_POSITION:
			var position_card = player.get_monster_zone(int(_payload["zone_index"]))
			position_card.set("battle_position", String(_payload["position"]))
			duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_POSITION_CHANGED, {
				"player_id": _actor_id,
				"card_id": int(position_card.get("definition_id")),
				"zone_index": int(_payload["zone_index"]),
				"position": String(_payload["position"]),
			})
			_publish_action(duel_state)
			return true
		ACTION_ATTACK:
			var attack_record := _payload.duplicate(true)
			attack_record["type"] = ACTION_ATTACK
			attack_record["actor_id"] = _actor_id
			duel_state.queue_action(attack_record)
			duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_ATTACK_QUEUED, attack_record)
			_publish_action(duel_state)
			return true
		ACTION_ACTIVATE_EFFECT:
			var effect_card = _find_effect_card(player)
			var effect_parameters: Dictionary = _payload.get("parameters", {}).duplicate(true)
			effect_parameters["duel_state"] = duel_state
			effect_parameters["actor_id"] = _actor_id
			effect_parameters["source_card_id"] = int(effect_card.get("definition_id"))
			if not effect_parameters.has("target_player_id"):
				effect_parameters["target_player_id"] = _actor_id
			var effect_result: Dictionary = effect_registry.call("execute", String(_payload["effect_id"]), effect_parameters)
			if not bool(effect_result.get("success", false)):
				return _fail(String(effect_result.get("error", "Card effect did not complete.")))
			player.call("send_to_graveyard", effect_card)
			var resolved_payload := {
				"effect_id": String(_payload["effect_id"]),
				"actor_id": _actor_id,
				"source_card_id": int(effect_card.get("definition_id")),
				"details": effect_result.get("details", {}),
			}
			duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_EFFECT_RESOLVED, resolved_payload)
			_publish_action(duel_state)
			return true
	return _fail("Action execution was not implemented for '%s'." % _action_type)


static func draw(actor_id: String) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_DRAW, actor_id)


static func summon(actor_id: String, card_id: int, card_type: String, zone_index: int = -1, instance_id: int = 0) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_SUMMON, actor_id, {
		"card_id": card_id,
		"card_type": card_type,
		"zone_index": zone_index,
		"instance_id": instance_id,
	})


static func set_monster(actor_id: String, card_id: int, card_type: String, zone_index: int = -1, instance_id: int = 0) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_SET_MONSTER, actor_id, {
		"card_id": card_id,
		"card_type": card_type,
		"zone_index": zone_index,
		"instance_id": instance_id,
	})


static func set_spell_trap(actor_id: String, card_id: int, card_type: String, zone_index: int = -1, instance_id: int = 0) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_SET_SPELL_TRAP, actor_id, {
		"card_id": card_id,
		"card_type": card_type,
		"zone_index": zone_index,
		"instance_id": instance_id,
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


static func activate_effect(actor_id: String, card_id: int, card_type: String, effect_id: String, parameters: Dictionary = {}) -> RefCounted:
	return load("res://scripts/duel/duel_action.gd").new(ACTION_ACTIVATE_EFFECT, actor_id, {
		"card_id": card_id,
		"card_type": card_type,
		"effect_id": effect_id,
		"parameters": parameters,
	})


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
	var zone_index := int(_payload.get("zone_index", -1))
	if _action_type in [ACTION_SUMMON, ACTION_SET_MONSTER]:
		if zone_index == -1 and player.get_open_monster_zone_index() < 0:
			return _fail("No open monster zone is available.")
		if zone_index != -1 and (zone_index < 0 or zone_index >= player.monster_zone_count() or player.get_monster_zone(zone_index) != null):
			return _fail("The requested monster zone is unavailable.")
	else:
		if zone_index == -1 and player.get_open_spell_trap_zone_index() < 0:
			return _fail("No open spell/trap zone is available.")
		if zone_index != -1 and (zone_index < 0 or zone_index >= player.spell_trap_zone_count() or player.get_spell_trap_zone(zone_index) != null):
			return _fail("The requested spell/trap zone is unavailable.")
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


func _validate_effect_activation(duel_state: Object, player: Object, effect_registry: Object) -> bool:
	if duel_state.get("phase") != PHASE_MAIN:
		return _fail("Card effects can only be activated during the main phase.")
	if effect_registry == null or not effect_registry.has_method("has_effect"):
		return _fail("A CardEffectRegistry is required to activate an effect.")
	var card_type := String(_payload.get("card_type", ""))
	if not ["Magic", "Trap"].has(card_type):
		return _fail("Only Magic or Trap cards can activate a card effect.")
	if _find_effect_card(player) == null:
		return _fail("The effect card must be in hand or set in a spell/trap zone.")
	var effect_id := String(_payload.get("effect_id", ""))
	if effect_id.is_empty() or not bool(effect_registry.call("has_effect", effect_id)):
		return _fail("Effect '%s' is not registered." % effect_id)
	if effect_registry.has_method("effects_for_card"):
		var mapped_effects: PackedStringArray = effect_registry.call("effects_for_card", int(_payload.get("card_id", -1)))
		if not mapped_effects.has(effect_id):
			return _fail("Effect '%s' is not mapped to card ID %s." % [effect_id, _payload.get("card_id", "")])
	return true


func _card_in_hand(player: Object) -> RefCounted:
	var requested_id := int(_payload.get("card_id", -1))
	var requested_instance_id := int(_payload.get("instance_id", 0))
	for card in player.get_hand():
		if int(card.get("definition_id")) == requested_id and (requested_instance_id == 0 or int(card.get_instance_id()) == requested_instance_id):
			return card
	return null


func _find_effect_card(player: Object) -> RefCounted:
	var card_in_hand := _card_in_hand(player)
	if card_in_hand != null:
		return card_in_hand
	var requested_id := int(_payload.get("card_id", -1))
	for zone_index in range(player.call("spell_trap_zone_count")):
		var card = player.call("get_spell_trap_zone", zone_index)
		if card != null and int(card.get("definition_id")) == requested_id:
			return card
	return null


func _fail(message: String) -> bool:
	_last_error = message
	return false


func _card_event_payload(card: Object, zone_index: int, play_type: String) -> Dictionary:
	return {
		"player_id": _actor_id,
		"card_id": int(card.get("definition_id")),
		"zone_index": zone_index,
		"play_type": play_type,
	}


func _publish_action(duel_state: Object) -> void:
	duel_state.call("emit_event", DUEL_EVENT_BUS_SCRIPT.EVENT_ACTION_EXECUTED, {
		"actor_id": _actor_id,
		"action_type": _action_type,
		"payload": _payload.duplicate(true),
	})
