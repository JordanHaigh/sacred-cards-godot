class_name DuelEventBus
extends RefCounted

## Delivers ordered, read-only snapshots of duel events to signals and listeners.

signal event_published(event_name: String, event: Dictionary)

const EVENT_DUEL_STARTED := "duel_started"
const EVENT_TURN_STARTED := "turn_started"
const EVENT_TURN_ENDED := "turn_ended"
const EVENT_PHASE_CHANGED := "phase_changed"
const EVENT_ACTION_EXECUTED := "action_executed"
const EVENT_CARD_DRAWN := "card_drawn"
const EVENT_CARD_PLAYED := "card_played"
const EVENT_POSITION_CHANGED := "position_changed"
const EVENT_ATTACK_QUEUED := "attack_queued"
const EVENT_BATTLE_RESOLVED := "battle_resolved"
const EVENT_CARD_DESTROYED := "card_destroyed"
const EVENT_LIFE_POINTS_CHANGED := "life_points_changed"
const EVENT_EFFECT_RESOLVED := "effect_resolved"
const EVENT_TRAP_ACTIVATED := "trap_activated"
const EVENT_DUEL_FINISHED := "duel_finished"

var _listeners: Dictionary = {}
var _history: Array[Dictionary] = []
var _sequence: int = 0
var last_error: String = ""


func subscribe(event_name: String, listener: Callable) -> bool:
	last_error = ""
	if event_name.strip_edges().is_empty():
		return _fail("Event names cannot be empty.")
	if not listener.is_valid():
		return _fail("Event subscribers must be valid callables.")
	var listeners: Array = _listeners.get(event_name, [])
	if listeners.has(listener):
		return _fail("The listener is already subscribed to '%s'." % event_name)
	listeners.append(listener)
	_listeners[event_name] = listeners
	return true


func unsubscribe(event_name: String, listener: Callable) -> bool:
	last_error = ""
	if not _listeners.has(event_name):
		return false
	var listeners: Array = _listeners[event_name].duplicate()
	var listener_index := listeners.find(listener)
	if listener_index < 0:
		return false
	listeners.remove_at(listener_index)
	if listeners.is_empty():
		_listeners.erase(event_name)
	else:
		_listeners[event_name] = listeners
	return true


func publish(event_name: String, payload: Dictionary = {}) -> Dictionary:
	last_error = ""
	if event_name.strip_edges().is_empty():
		last_error = "Event names cannot be empty."
		return {}
	_sequence += 1
	var event := {
		"sequence": _sequence,
		"name": event_name,
		"payload": payload.duplicate(true),
	}
	_history.append(event.duplicate(true))
	event_published.emit(event_name, event.duplicate(true))
	var listeners: Array = _listeners.get(event_name, []).duplicate()
	for listener in listeners:
		listener.call(event.duplicate(true))
	return event.duplicate(true)


func history() -> Array[Dictionary]:
	return _history.duplicate(true)


func _fail(message: String) -> bool:
	last_error = message
	return false
