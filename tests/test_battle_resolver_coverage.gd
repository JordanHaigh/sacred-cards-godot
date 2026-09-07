extends SceneTree

const CARD_DATABASE_SCRIPT = preload("res://scripts/cards/card_database.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const BATTLE_RESOLVER_SCRIPT = preload("res://scripts/duel/battle_resolver.gd")


func _init() -> void:
	var database = CARD_DATABASE_SCRIPT.new()
	if not database.load_from_directory("res://data/cards_json").is_empty():
		_fail("Could not load card data for battle coverage tests.")
		return
	var rules = load("res://resources/sacred_cards_rules.tres")
	var matchups = load("res://resources/sacred_cards_matchups.tres")

	var equal_duel = _new_duel(rules)
	var equal_attacker = _card(database, 26)
	var equal_defender = _card(database, 1)
	equal_attacker.current_attack = 1800
	equal_defender.current_attack = 1800
	equal_duel.get_player("player_one").place_monster(equal_attacker)
	equal_duel.get_player("player_two").place_monster(equal_defender)
	_enter_battle(equal_duel)
	var equal_result = _resolver(database, matchups, "Sea").resolve(equal_duel, "player_one", 0, "player_two", 0)
	if equal_result.outcome != "draw" or equal_result.attacker_destroyed or equal_result.defender_destroyed or equal_result.life_point_damage != 0:
		_fail("Equal effective attack powers should produce a no-damage draw.")
		return

	var defense_win_duel = _new_duel(rules)
	var defense_win_attacker = _card(database, 26)
	var defense_win_defender = _card(database, 2)
	defense_win_defender.set("battle_position", "defense")
	defense_win_attacker.current_attack = 2400
	defense_win_defender.current_defense = 2000
	defense_win_duel.get_player("player_one").place_monster(defense_win_attacker)
	defense_win_duel.get_player("player_two").place_monster(defense_win_defender)
	_enter_battle(defense_win_duel)
	var defense_win_result = _resolver(database, matchups, "Sea").resolve(defense_win_duel, "player_one", 0, "player_two", 0)
	if defense_win_result.outcome != "attacker_win" or not defense_win_result.defender_destroyed or defense_win_result.life_point_damage != 400:
		_fail("Higher attack power should win against a defense-position monster and report the difference.")
		return

	var blocked_direct_duel = _new_duel(rules)
	var blocked_direct_attacker = _card(database, 1)
	var blocking_monster = _card(database, 26)
	blocked_direct_duel.get_player("player_one").place_monster(blocked_direct_attacker)
	blocked_direct_duel.get_player("player_two").place_monster(blocking_monster)
	_enter_battle(blocked_direct_duel)
	var blocked_direct_result = _resolver(database, matchups, "Sea").resolve(blocked_direct_duel, "player_one", 0, "player_two")
	if blocked_direct_result.success or "empty defending monster field" not in blocked_direct_result.error:
		_fail("Direct attack should be rejected while a defending monster remains.")
		return

	var face_down_duel = _new_duel(rules)
	var face_down_attacker = _card(database, 1)
	face_down_attacker.set("face_state", "face_down")
	face_down_duel.get_player("player_one").place_monster(face_down_attacker)
	_enter_battle(face_down_duel)
	var face_down_result = _resolver(database, matchups, "Sea").resolve(face_down_duel, "player_one", 0, "player_two")
	if face_down_result.success or "face-up attack-position" not in face_down_result.error:
		_fail("Face-down monsters should not be allowed to attack.")
		return

	var disadvantage_duel = _new_duel(rules)
	var fairy_attacker = _card(database, 198)
	var disadvantage_defender = _card(database, 26)
	fairy_attacker.current_attack = 1700
	disadvantage_defender.current_attack = 1700
	disadvantage_duel.get_player("player_one").place_monster(fairy_attacker)
	disadvantage_duel.get_player("player_two").place_monster(disadvantage_defender)
	_enter_battle(disadvantage_duel)
	var disadvantage_result = _resolver(database, matchups, "Dark").resolve(disadvantage_duel, "player_one", 0, "player_two", 0)
	if disadvantage_result.type_environment_outcome != 2 or disadvantage_result.matchup_bonus != -500 or disadvantage_result.outcome != "defender_win":
		_fail("Configured attacker disadvantage should give the defender the matchup edge.")
		return

	var terminal_duel = _new_duel(rules)
	var terminal_attacker = _card(database, 1)
	terminal_attacker.current_attack = 8000
	terminal_duel.get_player("player_one").place_monster(terminal_attacker)
	_enter_battle(terminal_duel)
	var terminal_result = _resolver(database, matchups, "Sea").resolve(terminal_duel, "player_one", 0, "player_two")
	if terminal_duel.status != "finished" or terminal_duel.winner_id != "player_one" or terminal_result.life_point_damage != 8000:
		_fail("Lethal direct damage should finish the duel with the attacker as winner.")
		return
	var result_data: Dictionary = terminal_result.to_dictionary()
	if not result_data.has("attacker_adjusted_power") or terminal_duel.get_battle_history().size() != 1:
		_fail("Battle results and history should expose deterministic structured fields.")
		return

	print("PASS: Battle coverage verifies equal combat, defense outcomes, blocked direct attacks, face state, matchup disadvantage, lethal LP, and result history.")
	quit(0)


func _new_duel(rules: Resource):
	var duel = DUEL_STATE_SCRIPT.new(rules, "player_one", "player_two")
	duel.start()
	return duel


func _enter_battle(duel: Object) -> void:
	duel.advance_phase()
	duel.advance_phase()


func _card(database: Object, card_id: int):
	var card = CARD_INSTANCE_SCRIPT.new(card_id)
	if not card.initialize_from_database(database):
		_fail("Could not initialize test card %d." % card_id)
	return card


func _resolver(database: Object, matchups: Resource, environment: String):
	return BATTLE_RESOLVER_SCRIPT.new(database, matchups, environment, 500)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
