extends SceneTree

const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")


func _init() -> void:
	var rules = load("res://resources/sacred_cards_rules.tres")
	if rules == null:
		_fail("Could not load the duel ruleset.")
		return

	var duel = DUEL_STATE_SCRIPT.new(rules, "player_one", "player_two")
	if duel.ruleset != rules or duel.player_ids() != ["player_one", "player_two"]:
		_fail("DuelState did not expose its ruleset and ordered players.")
		return
	if duel.status != "setup" or duel.turn_number != 0 or duel.active_player_id != "player_one":
		_fail("DuelState should begin in deterministic setup state.")
		return

	var player_one_card = CARD_INSTANCE_SCRIPT.new(1)
	var player_two_card = CARD_INSTANCE_SCRIPT.new(2)
	duel.get_player("player_one").load_deck([player_one_card])
	duel.get_player("player_two").load_deck([player_two_card])
	if not duel.start() or duel.status != "in_progress" or duel.turn_number != 1 or duel.phase != "draw":
		_fail("DuelState should enter turn one in the draw phase.")
		return
	if not duel.set_phase("main") or duel.phase != "main" or duel.set_phase("invalid"):
		_fail("DuelState phase validation is incorrect.")
		return

	var action := {"kind": "draw", "player_id": "player_one"}
	var effect := {"kind": "field_modifier", "amount": 500}
	duel.queue_action(action)
	duel.queue_effect(effect)
	duel.record_battle({"attacker": 1, "defender": 2, "outcome": "neutral"})
	action["kind"] = "changed_outside_state"
	if duel.get_pending_actions()[0]["kind"] != "draw":
		_fail("Pending actions should be stored as defensive copies.")
		return
	if duel.get_pending_effects().size() != 1 or duel.get_battle_history().size() != 1:
		_fail("Pending effects and battle history were not recorded.")
		return

	if not duel.advance_turn() or duel.active_player_id != "player_two" or duel.turn_number != 2 or duel.phase != "draw":
		_fail("Turn advancement should switch players and return to draw phase.")
		return
	if duel.pop_pending_action()["kind"] != "draw" or duel.pop_pending_effect()["kind"] != "field_modifier":
		_fail("Pending queues should pop entries in insertion order.")
		return

	var snapshot: Dictionary = duel.to_serialized()
	if snapshot["status"] != "in_progress" or snapshot["players"].size() != 2:
		_fail("In-progress serialization is missing authoritative state.")
		return
	if snapshot["players"][0]["deck_size"] != 1 or snapshot["players"][1]["deck_size"] != 1:
		_fail("Player zone summaries were not serialized deterministically.")
		return
	if duel.to_debug_string() != JSON.stringify(snapshot):
		_fail("Debug serialization should use the same deterministic snapshot.")
		return

	if not duel.forfeit("player_two") or duel.status != "finished" or duel.phase != "end" or duel.winner_id != "player_one":
		_fail("Forfeit should produce a terminal result for the remaining player.")
		return
	if duel.advance_turn() or duel.finish("player_two"):
		_fail("Terminal DuelState should reject further lifecycle changes.")
		return
	if duel.to_serialized()["winner_id"] != "player_one":
		_fail("Terminal winner should remain in serialized state.")
		return

	print("PASS: DuelState tracks players, lifecycle, pending queues, battle history, rules, and deterministic terminal snapshots.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
