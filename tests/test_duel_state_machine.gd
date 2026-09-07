extends SceneTree

const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const DUEL_ACTION_SCRIPT = preload("res://scripts/duel/duel_action.gd")


func _init() -> void:
	var rules = load("res://resources/sacred_cards_rules.tres")
	var duel = DUEL_STATE_SCRIPT.new(rules, "player_one", "player_two")
	if not duel.start() or duel.phase != "draw" or duel.turn_number != 1:
		_fail("Starting a duel should enter turn one draw phase.")
		return
	if duel.set_phase("battle") or duel.last_transition_error.is_empty():
		_fail("Skipping from draw directly to battle should be rejected.")
		return
	if not duel.advance_phase() or duel.phase != "main":
		_fail("Draw should transition legally to main phase.")
		return
	if not duel.advance_phase() or duel.phase != "battle":
		_fail("Main should transition legally to battle phase.")
		return
	if not duel.advance_phase() or duel.phase != "end":
		_fail("Battle should transition legally to end phase.")
		return
	if not duel.advance_phase() or duel.phase != "draw" or duel.active_player_id != "player_two" or duel.turn_number != 2:
		_fail("End phase should advance to the next player's draw phase.")
		return

	if duel.advance_turn() or "end phase" not in duel.last_transition_error:
		_fail("Direct turn advancement outside end phase should be rejected.")
		return
	if not duel.advance_phase() or duel.phase != "main":
		_fail("The next player's draw phase should advance to main before ending the turn.")
		return
	if not duel.end_turn() or duel.phase != "draw" or duel.active_player_id != "player_one":
		_fail("end_turn should close main phase and advance the active player: phase=%s active=%s turn=%d error=%s." % [duel.phase, duel.active_player_id, duel.turn_number, duel.last_transition_error])
		return

	var terminal_duel = DUEL_STATE_SCRIPT.new(rules, "player_one", "player_two")
	terminal_duel.start()
	if not terminal_duel.finish("player_one"):
		_fail("A live duel should be able to enter a terminal state.")
		return
	if terminal_duel.advance_phase() or terminal_duel.set_phase("main") or terminal_duel.end_turn():
		_fail("Terminal duels should reject all further phase transitions.")
		return

	var action_duel = DUEL_STATE_SCRIPT.new(rules, "player_one", "player_two")
	action_duel.start()
	action_duel.advance_phase()
	if not DUEL_ACTION_SCRIPT.end_turn("player_one").execute(action_duel):
		_fail("End-turn action should use the guarded state-machine transition.")
		return
	if action_duel.active_player_id != "player_two" or action_duel.phase != "draw":
		_fail("End-turn action did not advance to the next draw phase.")
		return

	print("PASS: DuelState guards phase transitions, advances legal turns deterministically, blocks terminal continuation, and integrates end-turn actions.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
