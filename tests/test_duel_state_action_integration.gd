extends SceneTree

const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")
const DUEL_ACTION_SCRIPT = preload("res://scripts/duel/duel_action.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const VICTORY_RESOLVER_SCRIPT = preload("res://scripts/duel/victory_resolver.gd")


func _init() -> void:
	var rules: Resource = load("res://resources/sacred_cards_rules.tres")
	var duel = DUEL_STATE_SCRIPT.new(rules, "player_one", "player_two")
	var player_one = duel.get_player("player_one")
	var player_two = duel.get_player("player_two")
	var monster_one = CARD_INSTANCE_SCRIPT.new(1)
	var monster_two = CARD_INSTANCE_SCRIPT.new(2)
	var player_two_draw = CARD_INSTANCE_SCRIPT.new(3)
	var spell = CARD_INSTANCE_SCRIPT.new(301)
	player_one.load_deck([monster_one, spell])
	player_two.load_deck([monster_two, player_two_draw])

	if duel.status != "setup" or duel.phase != "draw" or duel.active_player_id != "player_one":
		_fail("A new duel should begin in setup with player one active for draw.")
		return
	if not duel.start() or duel.status != "in_progress" or duel.turn_number != 1:
		_fail("A duel should start exactly once with turn one in progress.")
		return

	var wrong_actor_draw = DUEL_ACTION_SCRIPT.draw("player_two")
	if wrong_actor_draw.execute(duel) or "active player" not in wrong_actor_draw.last_error:
		_fail("A non-active player must not draw during the current turn.")
		return
	if not DUEL_ACTION_SCRIPT.draw("player_one").execute(duel):
		_fail("The active player should draw during the draw phase.")
		return
	if duel.phase != "main" or player_one.hand_size() != 1:
		_fail("A successful draw should move the duel to main and add one card to hand.")
		return

	var wrong_phase_draw = DUEL_ACTION_SCRIPT.draw("player_one")
	if wrong_phase_draw.execute(duel) or "draw phase" not in wrong_phase_draw.last_error:
		_fail("A second draw in main phase must be rejected.")
		return
	var premature_attack = DUEL_ACTION_SCRIPT.attack("player_one", 0, "player_two")
	if premature_attack.execute(duel) or "battle phase" not in premature_attack.last_error:
		_fail("An attack issued during main phase must be rejected.")
		return
	if not DUEL_ACTION_SCRIPT.summon("player_one", 1, "Monster").execute(duel):
		_fail("The active player should be able to summon a monster from hand.")
		return
	player_one.add_to_hand(spell)
	if not DUEL_ACTION_SCRIPT.set_spell_trap("player_one", 301, "Magic").execute(duel):
		_fail("The active player should be able to set a spell from hand.")
		return

	player_two.place_monster(monster_two)
	if not duel.advance_phase() or duel.phase != "battle":
		_fail("Main phase should advance legally to battle phase.")
		return
	var attack = DUEL_ACTION_SCRIPT.attack("player_one", 0, "player_two", 0)
	if not attack.execute(duel) or duel.get_pending_actions().size() != 1:
		_fail("A face-up attack-position monster should queue an attack intent.")
		return
	if not DUEL_ACTION_SCRIPT.end_turn("player_one").execute(duel):
		_fail("End-turn should close the battle phase and advance to player two.")
		return
	if duel.active_player_id != "player_two" or duel.phase != "draw" or duel.turn_number != 2:
		_fail("End-turn should switch the active player and reset to draw phase.")
		return

	var old_actor_end_turn = DUEL_ACTION_SCRIPT.end_turn("player_one")
	if old_actor_end_turn.execute(duel) or "active player" not in old_actor_end_turn.last_error:
		_fail("The previous player must not end the new player's turn.")
		return
	if not DUEL_ACTION_SCRIPT.draw("player_two").execute(duel):
		_fail("Player two should draw at the start of the second turn.")
		return
	if not DUEL_ACTION_SCRIPT.end_turn("player_two").execute(duel):
		_fail("Player two should be able to end the second turn from main phase.")
		return

	player_two.life_points = 0
	var victory = VICTORY_RESOLVER_SCRIPT.new().resolve(duel)
	if not victory.terminal or victory.winner_id != "player_one" or duel.status != "finished":
		_fail("Victory resolution should finish the duel and preserve the surviving winner.")
		return
	if duel.advance_phase() or duel.last_transition_error.is_empty():
		_fail("A finished duel must reject further phase transitions.")
		return
	var terminal_action = DUEL_ACTION_SCRIPT.end_turn("player_one")
	if terminal_action.execute(duel) or "not in progress" not in terminal_action.last_error:
		_fail("A finished duel must reject further actions.")
		return

	print("PASS: Duel state and actions integrate across turns, illegal requests, attack intents, and terminal victory blocking.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
