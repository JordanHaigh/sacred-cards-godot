class_name VictoryResolver
extends RefCounted

## Resolves confirmed terminal conditions without depending on UI or battle FX.
##
## LP defeat is always checked. Deck-out is checked only when the supplied
## DuelRuleSet explicitly enables it, keeping uncertain behavior configurable.

const VICTORY_RESULT_SCRIPT = preload("res://scripts/duel/victory_result.gd")


func resolve(duel_state: Object, draw_succeeded: bool = true) -> RefCounted:
	var result = VICTORY_RESULT_SCRIPT.new()
	if duel_state == null or not duel_state.has_method("get_player"):
		return _fail(result, "A valid DuelState is required.")
	if duel_state.get("status") == "finished":
		result.success = true
		result.terminal = true
		result.winner_id = duel_state.get("winner_id")
		result.reason = "already_finished"
		return result
	if duel_state.get("status") != "in_progress":
		return _fail(result, "Victory checks require an in-progress duel.")

	var player_ids: Array[String] = duel_state.player_ids()
	if player_ids.size() != 2:
		return _fail(result, "Victory checks require exactly two duel players.")
	var first_player = duel_state.get_player(player_ids[0])
	var second_player = duel_state.get_player(player_ids[1])
	var first_defeated := _is_defeated(duel_state, first_player, draw_succeeded if duel_state.active_player_id == player_ids[0] else true)
	var second_defeated := _is_defeated(duel_state, second_player, draw_succeeded if duel_state.active_player_id == player_ids[1] else true)

	result.success = true
	if first_defeated and second_defeated:
		duel_state.finish()
		result.terminal = true
		result.reason = "simultaneous_defeat"
		return result
	if first_defeated:
		duel_state.finish(player_ids[1])
		result.terminal = true
		result.winner_id = player_ids[1]
		result.loser_id = player_ids[0]
		result.reason = _loss_reason(first_player, duel_state, draw_succeeded if duel_state.active_player_id == player_ids[0] else true)
		return result
	if second_defeated:
		duel_state.finish(player_ids[0])
		result.terminal = true
		result.winner_id = player_ids[0]
		result.loser_id = player_ids[1]
		result.reason = _loss_reason(second_player, duel_state, draw_succeeded if duel_state.active_player_id == player_ids[1] else true)
		return result
	result.reason = "no_loss"
	return result


func _is_defeated(duel_state: Object, player: Object, player_draw_succeeded: bool) -> bool:
	var ruleset = duel_state.get("ruleset")
	if ruleset != null and ruleset.has_method("is_defeat"):
		return ruleset.is_defeat(player.life_points, player_draw_succeeded)
	return player.is_defeated()


func _loss_reason(player: Object, duel_state: Object, player_draw_succeeded: bool) -> String:
	if player.life_points <= 0:
		return "life_points_zero"
	var ruleset = duel_state.get("ruleset")
	if ruleset != null and ruleset.get("deck_out_causes_defeat") and not player_draw_succeeded:
		return "deck_out"
	return "defeat"


func _fail(result: Object, message: String) -> RefCounted:
	result.error = message
	return result
