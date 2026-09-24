class_name TrapTriggerSystem
extends RefCounted

## Evaluates configured set traps when authoritative duel events are published.
## The first eligible trap resolves in player order, then spell/trap-zone order.

const EVENT_BUS_SCRIPT = preload("res://scripts/duel/duel_event_bus.gd")

var _duel_state: Object
var _effect_registry: Object
var _triggers_by_card_id: Dictionary = {}
var _subscribed_events: Array[String] = []
var last_error: String = ""


func load_trigger_mappings(records: Array) -> PackedStringArray:
	var diagnostics := PackedStringArray()
	for record_index in range(records.size()):
		var record = records[record_index]
		if not record is Dictionary:
			diagnostics.append("trap_mapping[%d] must be an object." % record_index)
			continue
		var card_id := int(record.get("card_id", 0))
		var event_name := String(record.get("event", ""))
		var effect_id := String(record.get("effect_id", ""))
		var parameters = record.get("parameters", {})
		if card_id <= 0 or event_name.strip_edges().is_empty() or effect_id.is_empty():
			diagnostics.append("trap_mapping[%d] requires a card_id, event name, and effect_id." % record_index)
			continue
		if not parameters is Dictionary:
			diagnostics.append("trap_mapping[%d].parameters must be an object." % record_index)
			continue
		var mappings: Array = _triggers_by_card_id.get(card_id, [])
		mappings.append({
			"event": event_name,
			"effect_id": effect_id,
			"parameters": parameters.duplicate(true),
		})
		_triggers_by_card_id[card_id] = mappings
		if not _subscribed_events.has(event_name):
			_subscribed_events.append(event_name)
	return diagnostics


func bind(duel_state: Object, effect_registry: Object) -> bool:
	last_error = ""
	if duel_state == null or not duel_state.has_method("get_player"):
		return _fail("Trap triggers require a valid DuelState.")
	if effect_registry == null or not effect_registry.has_method("execute"):
		return _fail("Trap triggers require a CardEffectRegistry.")
	unbind()
	_duel_state = duel_state
	_effect_registry = effect_registry
	var event_bus = duel_state.get("event_bus")
	if event_bus == null:
		_duel_state = null
		_effect_registry = null
		return _fail("Trap triggers could not access the duel event bus.")
	for event_name in _subscribed_events:
		if not bool(event_bus.call("subscribe", event_name, Callable(self, "_on_trigger_event"))):
			unbind()
			return _fail("Trap triggers could not subscribe to '%s'." % event_name)
	return true


func unbind() -> void:
	if _duel_state != null:
		var event_bus = _duel_state.get("event_bus")
		if event_bus != null:
			for event_name in _subscribed_events:
				event_bus.call("unsubscribe", event_name, Callable(self, "_on_trigger_event"))
	_duel_state = null
	_effect_registry = null


func _on_trigger_event(event: Dictionary) -> void:
	if _duel_state == null or _effect_registry == null or _duel_state.get("status") != "in_progress":
		return
	var payload: Dictionary = event.get("payload", {})
	var actor_id := String(payload.get("actor_id", payload.get("player_id", "")))
	for owner_id in _duel_state.call("player_ids"):
		if String(owner_id) == actor_id:
			continue
		var trap_owner = _duel_state.call("get_player", String(owner_id))
		for zone_index in range(trap_owner.call("spell_trap_zone_count")):
			var trap_card = trap_owner.call("get_spell_trap_zone", zone_index)
			if trap_card == null or trap_card.get("face_state") != "face_down":
				continue
			var card_mappings: Array = _triggers_by_card_id.get(int(trap_card.get("definition_id")), [])
			for mapping in card_mappings:
				if mapping.get("event") != event.get("name"):
					continue
				var parameters: Dictionary = mapping.get("parameters", {})
				var target_player_id := String(parameters.get("target_player_id", actor_id))
				var target_zone := int(parameters.get("zone_index", payload.get("attacker_zone", payload.get("zone_index", -1))))
				if String(event.get("name")) == EVENT_BUS_SCRIPT.EVENT_ATTACK_QUEUED:
					var attacker_player = _duel_state.call("get_player", actor_id)
					if attacker_player == null:
						continue
					var attacker = attacker_player.call("get_monster_zone", target_zone)
					if attacker == null or not _attack_meets_condition(attacker, parameters):
						continue
				var target_player = _duel_state.call("get_player", target_player_id)
				if target_player == null or target_zone < 0:
					continue
				var target_card = target_player.call("get_monster_zone", target_zone)
				if target_card == null:
					continue
				var target_card_id := int(target_card.get("definition_id"))
				var context := {
					"duel_state": _duel_state,
					"actor_id": String(owner_id),
					"target_player_id": target_player_id,
					"zone_index": target_zone,
					"source_card_id": int(trap_card.get("definition_id")),
				}
				var effect_result: Dictionary = _effect_registry.call("execute", String(mapping.get("effect_id")), context)
				if not bool(effect_result.get("success", false)):
					last_error = String(effect_result.get("error", "Trap effect failed."))
					return
				trap_card.set("face_state", "face_up")
				trap_owner.call("send_to_graveyard", trap_card)
				_duel_state.call("emit_event", EVENT_BUS_SCRIPT.EVENT_TRAP_ACTIVATED, {
					"owner_id": String(owner_id),
					"card_id": int(trap_card.get("definition_id")),
					"trigger_event": String(event.get("name")),
					"target_card_id": target_card_id,
					"effect_id": String(mapping.get("effect_id")),
				})
				return


func _attack_meets_condition(attacker: Object, parameters: Dictionary) -> bool:
	var max_attack := int(parameters.get("max_attack", -1))
	return max_attack < 0 or int(attacker.get("current_attack")) <= max_attack


func _fail(message: String) -> bool:
	last_error = message
	return false
