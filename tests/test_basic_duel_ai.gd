extends SceneTree

const AI_SCRIPT = preload("res://scripts/duel/basic_duel_ai.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const CARD_DATABASE_SCRIPT = preload("res://scripts/cards/card_database.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")


func _init() -> void:
	var database = CARD_DATABASE_SCRIPT.new()
	if not database.load_from_directory("res://data/cards_json").is_empty():
		_fail("The supplied card database should load for the AI smoke test.")
		return
	var duel = DUEL_STATE_SCRIPT.new(load("res://resources/sacred_cards_rules.tres"), "player_one", "player_two")
	var human_player = duel.get_player("player_one")
	var ai_player = duel.get_player("player_two")
	human_player.load_deck([CARD_INSTANCE_SCRIPT.new(3)])
	var player_monster = CARD_INSTANCE_SCRIPT.new(1)
	ai_player.load_deck([player_monster])
	if not duel.start():
		_fail("The duel should start before the AI turn.")
		return
	if not load("res://scripts/duel/duel_action.gd").draw("player_one").execute(duel):
		_fail("The human should draw during the opening turn.")
		return
	if not duel.end_turn():
		_fail("The human's empty opening turn should advance to the AI.")
		return
	var ai = AI_SCRIPT.new()
	if not ai.take_turn(duel, database):
		_fail("AI turn failed: %s" % ai.last_error)
		return
	if duel.active_player_id != "player_one" or duel.turn_number != 3 or duel.phase != "draw":
		_fail("AI should complete its turn and hand control back to player one.")
		return
	if ai_player.hand_size() != 0 or ai_player.get_monster_zone(0) != player_monster:
		_fail("AI should draw and summon its strongest available monster.")
		return
	var pending_actions: Array[Dictionary] = duel.get_pending_actions()
	if pending_actions.size() != 1 or pending_actions[0].get("actor_id") != "player_two":
		_fail("AI should queue its attack using the shared validated action API.")
		return
	print("PASS: BasicDuelAI completes a deterministic draw, summon, attack, and end-turn sequence.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
