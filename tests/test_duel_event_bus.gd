extends SceneTree

const EVENT_BUS_SCRIPT = preload("res://scripts/duel/duel_event_bus.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const DUEL_ACTION_SCRIPT = preload("res://scripts/duel/duel_action.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")

var received_events: Array[Dictionary] = []


func _init() -> void:
	var bus = EVENT_BUS_SCRIPT.new()
	var callback := Callable(self, "_record_event")
	if not bus.subscribe("sample", callback):
		_fail("A valid event listener should subscribe.")
		return
	var first: Dictionary = bus.publish("sample", {"value": 7})
	if received_events.size() != 1 or received_events[0].get("payload", {}).get("value") != 7:
		_fail("Subscribed listeners should receive event payloads synchronously.")
		return
	if first.get("sequence") != 1 or bus.history().size() != 1:
		_fail("Event sequence numbers and history should be deterministic.")
		return
	if not bus.unsubscribe("sample", callback):
		_fail("A subscribed listener should be removable.")
		return
	bus.publish("sample", {"value": 8})
	if received_events.size() != 1:
		_fail("Unsubscribed listeners should no longer receive events.")
		return

	var duel = DUEL_STATE_SCRIPT.new(load("res://resources/sacred_cards_rules.tres"), "one", "two")
	if not bool(duel.get("event_bus").call("subscribe", "phase_changed", callback)):
		_fail("DuelState should expose its event bus to observers.")
		return
	if not duel.start() or not duel.set_phase("main"):
		_fail("A duel should start and enter its first main phase.")
		return
	if received_events.size() != 2 or received_events[1].get("payload", {}).get("to") != "main":
		_fail("DuelState should publish phase changes from authoritative transitions.")
		return

	var action_duel = DUEL_STATE_SCRIPT.new(load("res://resources/sacred_cards_rules.tres"), "one", "two")
	action_duel.get_player("one").load_deck([CARD_INSTANCE_SCRIPT.new(1, "one")])
	var action_events: Array[Dictionary] = []
	var action_listener := Callable(self, "_record_action_event").bind(action_events)
	if not action_duel.event_bus.subscribe("card_drawn", action_listener):
		_fail("The event bus should allow listening for authoritative card draws.")
		return
	if not action_duel.event_bus.subscribe("action_executed", action_listener):
		_fail("The event bus should allow listening for executed action events.")
		return
	if not action_duel.start() or not DUEL_ACTION_SCRIPT.draw("one").execute(action_duel):
		_fail("An authoritative draw action should complete in the draw phase.")
		return
	if action_events.size() != 2 or action_events[0].get("name") != "card_drawn" or action_events[1].get("name") != "action_executed":
		_fail("Draw and action events should publish in deterministic order.")
		return
	print("PASS: DuelEventBus delivers ordered events, supports subscriptions, and receives authoritative DuelState phase changes.")
	quit(0)


func _record_event(event: Dictionary) -> void:
	received_events.append(event)


func _record_action_event(event: Dictionary, event_list: Array[Dictionary]) -> void:
	event_list.append(event)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
