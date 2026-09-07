extends SceneTree

const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")
const PLAYER_STATE_SCRIPT = preload("res://scripts/duel/duel_player_state.gd")


func _init() -> void:
	var player = PLAYER_STATE_SCRIPT.new("player_one", 8000, 2, 2)
	var first_card = CARD_INSTANCE_SCRIPT.new(1)
	var second_card = CARD_INSTANCE_SCRIPT.new(2)
	var third_card = CARD_INSTANCE_SCRIPT.new(3)
	var fourth_card = CARD_INSTANCE_SCRIPT.new(4)
	var fifth_card = CARD_INSTANCE_SCRIPT.new(5)
	var sixth_card = CARD_INSTANCE_SCRIPT.new(6)

	if player.load_deck([first_card, second_card, third_card, fourth_card, fifth_card, sixth_card]) != 6:
		_fail("Deck loading should keep each valid card exactly once.")
		return
	if player.deck_size() != 6 or player.hand_size() != 0 or player.graveyard_size() != 0:
		_fail("Initial player zones were not represented correctly.")
		return

	if player.draw_card() != first_card or player.hand_size() != 1 or player.deck_size() != 5:
		_fail("Drawing should move the deck's first card to the hand.")
		return
	if first_card.owner_id != "player_one":
		_fail("Cards moved into player state should receive the owning player ID.")
		return
	var drawn_cards: Array[RefCounted] = player.draw_cards(2)
	if drawn_cards.size() != 2 or drawn_cards[0] != second_card or drawn_cards[1] != third_card:
		_fail("Multi-card drawing should preserve deterministic deck order.")
		return

	if player.take_damage(1200) != 1200 or player.life_points != 6800:
		_fail("Damage should reduce life points and report applied damage.")
		return
	if player.heal(500) != 500 or player.life_points != 7300:
		_fail("Healing should increase life points and report applied healing.")
		return
	if player.take_damage(-10) != 0 or player.heal(-10) != 0:
		_fail("Negative damage or healing should have no effect.")
		return
	if player.take_damage(10000) != 7300 or not player.is_defeated():
		_fail("Lethal damage should clamp life points to zero and mark defeat.")
		return

	var zone_player = PLAYER_STATE_SCRIPT.new("zone_player", 8000, 2, 1)
	if zone_player.get_open_monster_zone_index() != 0 or zone_player.get_open_spell_trap_zone_index() != 0:
		_fail("Open zone lookup should return the first available slot.")
		return
	if zone_player.place_monster(fourth_card) != 0 or zone_player.place_monster(fifth_card) != 1:
		_fail("Monster placement should use available monster zones.")
		return
	if zone_player.get_open_zone_index("monster") != -1 or zone_player.place_monster(sixth_card) != -1:
		_fail("A full monster zone should reject additional monsters.")
		return
	if zone_player.place_spell_trap(sixth_card) != 0 or not zone_player.is_field_zone_open():
		_fail("Spell/trap placement or field availability is incorrect.")
		return
	if not zone_player.place_field(third_card) or zone_player.is_field_zone_open():
		_fail("Field placement should occupy the single field zone.")
		return
	var no_field_player = PLAYER_STATE_SCRIPT.new("no_field", 8000, 1, 1, 0)
	if no_field_player.is_field_zone_open() or no_field_player.place_field(third_card):
		_fail("A player configured without a field zone should reject field cards.")
		return

	if zone_player.send_to_graveyard(fourth_card) != true or zone_player.get_monster_zone(0) != null:
		_fail("Sending a field card to the graveyard should clear its previous zone.")
		return
	if zone_player.graveyard_size() != 1 or zone_player.get_open_monster_zone_index() != 0:
		_fail("Graveyard transfer should reopen the old zone.")
		return
	if zone_player.draw_card() != null:
		_fail("An empty deck should return no card when drawing.")
		return

	var hand_copy: Array[RefCounted] = player.get_hand()
	hand_copy.clear()
	if player.hand_size() != 3:
		_fail("Zone getters should not expose mutable collection internals.")
		return

	print("PASS: DuelPlayerState tracks zones, deterministic draws, LP changes, ownership, and open-zone behavior without UI dependencies.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
