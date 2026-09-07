extends SceneTree

const DUEL_ACTION_SCRIPT = preload("res://scripts/duel/duel_action.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")


func _init() -> void:
	var duel = DUEL_STATE_SCRIPT.new(load("res://resources/sacred_cards_rules.tres"), "player_one", "player_two")
	var player_one = duel.get_player("player_one")
	var player_two = duel.get_player("player_two")
	var monster_one = CARD_INSTANCE_SCRIPT.new(1)
	var monster_two = CARD_INSTANCE_SCRIPT.new(2)
	var spell = CARD_INSTANCE_SCRIPT.new(301)
	player_one.load_deck([monster_one, spell])
	player_two.load_deck([monster_two])
	if not duel.start():
		_fail("Duel should start before actions are executed.")
		return

	if not duel.set_phase("main"):
		_fail("Duel should enter main phase for illegal-action validation.")
		return
	var wrong_phase_draw = DUEL_ACTION_SCRIPT.draw("player_one")
	if wrong_phase_draw.execute(duel) or wrong_phase_draw.last_error.is_empty():
		_fail("Illegal draw phase actions should fail with a reason.")
		return
	if not duel.set_phase("draw") or not DUEL_ACTION_SCRIPT.draw("player_one").execute(duel):
		_fail("A draw action should execute during the draw phase.")
		return
	if player_one.hand_size() != 1 or duel.phase != "main":
		_fail("Draw action did not update authoritative state.")
		return

	var bad_summon = DUEL_ACTION_SCRIPT.summon("player_one", 301, "Monster")
	if bad_summon.execute(duel) or "not in the actor's hand" not in bad_summon.last_error:
		_fail("Summoning a missing card should fail explicitly.")
		return
	var summon = DUEL_ACTION_SCRIPT.summon("player_one", 1, "Monster")
	if not summon.execute(duel) or player_one.get_monster_zone(0) != monster_one or player_one.hand_size() != 0:
		_fail("Legal summon should move the card into the authoritative monster zone.")
		return

	player_one.add_to_hand(spell)
	var set_spell = DUEL_ACTION_SCRIPT.set_spell_trap("player_one", 301, "Magic")
	if not set_spell.execute(duel) or player_one.get_spell_trap_zone(0) != spell:
		_fail("Legal spell/trap set should occupy an authoritative zone.")
		return

	if not DUEL_ACTION_SCRIPT.change_position("player_one", 0, "defense").execute(duel) or monster_one.get("battle_position") != "defense":
		_fail("Position change should mutate only the runtime card instance.")
		return
	if DUEL_ACTION_SCRIPT.change_position("player_one", 0, "defense").execute(duel):
		_fail("Repeating the current position should be rejected.")
		return

	player_one.get_monster_zone(0).set("battle_position", "attack")
	player_one.get_monster_zone(0).set("face_state", "face_up")
	player_two.place_monster(monster_two)
	if not duel.set_phase("battle"):
		_fail("Duel should enter the battle phase for attack validation.")
		return
	var attack = DUEL_ACTION_SCRIPT.attack("player_one", 0, "player_two", 0)
	if not attack.execute(duel) or duel.get_pending_actions().size() != 1:
		_fail("Legal attacks should queue an authoritative attack intent.")
		return

	if not DUEL_ACTION_SCRIPT.end_turn("player_one").execute(duel) or duel.active_player_id != "player_two":
		_fail("End-turn should advance authoritative duel state.")
		return
	if DUEL_ACTION_SCRIPT.end_turn("player_one").execute(duel):
		_fail("A non-active player should not be able to end the turn.")
		return

	print("PASS: DuelAction validates legal and illegal draw, summon/set, position, attack-intent, and end-turn paths with explicit errors.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
