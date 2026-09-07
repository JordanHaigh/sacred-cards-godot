extends SceneTree

const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const VICTORY_RESOLVER_SCRIPT = preload("res://scripts/duel/victory_resolver.gd")


func _init() -> void:
	var rules = load("res://resources/sacred_cards_rules.tres")
	var resolver = VICTORY_RESOLVER_SCRIPT.new()

	var no_loss_duel = _new_duel(rules)
	var no_loss = resolver.resolve(no_loss_duel)
	if not no_loss.success or no_loss.terminal or no_loss.reason != "no_loss":
		_fail("A healthy duel should remain in progress after victory evaluation.")
		return

	var player_win_duel = _new_duel(rules)
	player_win_duel.get_player("player_two").life_points = 0
	var player_win = resolver.resolve(player_win_duel)
	if not player_win.terminal or player_win.winner_id != "player_one" or player_win.loser_id != "player_two" or player_win.reason != "life_points_zero":
		_fail("LP defeat should record the surviving player as winner.")
		return
	var winner_before_repeat: String = player_win_duel.winner_id
	var repeat_result = resolver.resolve(player_win_duel)
	if not repeat_result.terminal or player_win_duel.winner_id != winner_before_repeat or repeat_result.reason != "already_finished":
		_fail("Terminal resolution should be idempotent and preserve the original winner.")
		return

	var simultaneous_duel = _new_duel(rules)
	simultaneous_duel.get_player("player_one").life_points = 0
	simultaneous_duel.get_player("player_two").life_points = 0
	var simultaneous = resolver.resolve(simultaneous_duel)
	if not simultaneous.terminal or not simultaneous.winner_id.is_empty() or simultaneous.reason != "simultaneous_defeat":
		_fail("Simultaneous LP defeat should terminate as a draw.")
		return

	var disabled_deck_out_duel = _new_duel(rules)
	var disabled_deck_out = resolver.resolve(disabled_deck_out_duel, false)
	if disabled_deck_out.terminal or disabled_deck_out_duel.status != "in_progress":
		_fail("Deck-out should remain disabled by the baseline ruleset.")
		return

	var enabled_rules = rules.duplicate(true)
	enabled_rules.deck_out_causes_defeat = true
	var enabled_deck_out_duel = _new_duel(enabled_rules)
	var enabled_deck_out = resolver.resolve(enabled_deck_out_duel, false)
	if not enabled_deck_out.terminal or enabled_deck_out.winner_id != "player_two" or enabled_deck_out.reason != "deck_out":
		_fail("Enabled deck-out should defeat the active player after a failed draw.")
		return

	var result_data: Dictionary = player_win.to_dictionary()
	if not result_data.has("winner_id") or result_data["reason"] != "life_points_zero":
		_fail("Victory results should expose deterministic serializable fields.")
		return

	print("PASS: VictoryResolver handles LP wins, simultaneous defeat, configurable deck-out, idempotent winners, and structured results.")
	quit(0)


func _new_duel(rules: Resource):
	var duel = DUEL_STATE_SCRIPT.new(rules, "player_one", "player_two")
	duel.start()
	return duel


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
