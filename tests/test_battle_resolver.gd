extends SceneTree

const CARD_DATABASE_SCRIPT = preload("res://scripts/cards/card_database.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const BATTLE_RESOLVER_SCRIPT = preload("res://scripts/duel/battle_resolver.gd")


func _init() -> void:
	var database = CARD_DATABASE_SCRIPT.new()
	var diagnostics: PackedStringArray = database.load_from_directory("res://data/cards_json")
	if not diagnostics.is_empty():
		_fail("CardDatabase load failed: %s" % "; ".join(diagnostics))
		return
	var matchups = load("res://resources/sacred_cards_matchups.tres")
	var rules = load("res://resources/sacred_cards_rules.tres")

	var higher_attack = _new_duel(rules)
	var blue_eyes = CARD_INSTANCE_SCRIPT.new(1)
	var battle_ox = CARD_INSTANCE_SCRIPT.new(26)
	blue_eyes.initialize_from_database(database)
	battle_ox.initialize_from_database(database)
	higher_attack.get_player("player_one").place_monster(blue_eyes)
	higher_attack.get_player("player_two").place_monster(battle_ox)
	var resolver = BATTLE_RESOLVER_SCRIPT.new(database, matchups, "Field", 500)
	higher_attack.set_phase("battle")
	var result = resolver.resolve(higher_attack, "player_one", 0, "player_two", 0)
	if not result.success or result.outcome != "attacker_win" or not result.defender_destroyed:
		_fail("Higher ATK should destroy the defending monster: success=%s outcome=%s error=%s attacker=%d defender=%d." % [result.success, result.outcome, result.error, result.attacker_adjusted_power, result.defender_adjusted_power])
		return
	if result.life_point_damage != 1300 or higher_attack.get_player("player_two").life_points != 6700:
		_fail("Attack-vs-attack LP damage was not calculated correctly.")
		return

	var defense_duel = _new_duel(rules)
	var weak_attacker = CARD_INSTANCE_SCRIPT.new(26)
	var strong_defender = CARD_INSTANCE_SCRIPT.new(2)
	weak_attacker.initialize_from_database(database)
	strong_defender.initialize_from_database(database)
	strong_defender.set("battle_position", "defense")
	defense_duel.get_player("player_one").place_monster(weak_attacker)
	defense_duel.get_player("player_two").place_monster(strong_defender)
	defense_duel.set_phase("battle")
	var defense_result = BATTLE_RESOLVER_SCRIPT.new(database, matchups, "Sea", 500).resolve(defense_duel, "player_one", 0, "player_two", 0)
	if defense_result.outcome != "defender_win" or not defense_result.attacker_destroyed or defense_result.life_point_damage != 300:
		_fail("Attack-vs-defense should destroy the weaker attacker and apply the difference: outcome=%s attacker=%d defender=%d damage=%d." % [defense_result.outcome, defense_result.attacker_adjusted_power, defense_result.defender_adjusted_power, defense_result.life_point_damage])
		return

	var direct_duel = _new_duel(rules)
	var direct_attacker = CARD_INSTANCE_SCRIPT.new(1)
	direct_attacker.initialize_from_database(database)
	direct_duel.get_player("player_one").place_monster(direct_attacker)
	direct_duel.set_phase("battle")
	var direct_result = resolver.resolve(direct_duel, "player_one", 0, "player_two")
	if not direct_result.direct_attack or direct_result.outcome != "direct_attack" or direct_result.life_point_damage != 3000:
		_fail("Direct attack should apply the attacker's ATK to empty-field LP.")
		return

	var matchup_duel = _new_duel(rules)
	var matchup_attacker = CARD_INSTANCE_SCRIPT.new(1)
	var matchup_defender = CARD_INSTANCE_SCRIPT.new(26)
	matchup_attacker.initialize_from_database(database)
	matchup_defender.initialize_from_database(database)
	matchup_attacker.current_attack = 1700
	matchup_defender.current_attack = 1700
	matchup_duel.get_player("player_one").place_monster(matchup_attacker)
	matchup_duel.get_player("player_two").place_monster(matchup_defender)
	matchup_duel.set_phase("battle")
	var mountain_resolver = BATTLE_RESOLVER_SCRIPT.new(database, matchups, "Mountains", 500)
	var matchup_result = mountain_resolver.resolve(matchup_duel, "player_one", 0, "player_two", 0)
	if matchup_result.type_environment_outcome != 1 or matchup_result.matchup_bonus != 500 or matchup_result.outcome != "attacker_win":
		_fail("Configured type/environment advantage should break an otherwise equal battle.")
		return

	var invalid_duel = _new_duel(rules)
	invalid_duel.set_phase("main")
	var invalid_result = resolver.resolve(invalid_duel, "player_one", 0, "player_two", 0)
	if invalid_result.success or invalid_result.error.is_empty():
		_fail("Invalid battle requests should return explicit errors.")
		return

	print("PASS: BattleResolver handles attack-vs-attack, attack-vs-defense, direct attacks, destruction, LP damage, and matchup advantage.")
	quit(0)


func _new_duel(rules: Resource):
	var duel = DUEL_STATE_SCRIPT.new(rules, "player_one", "player_two")
	duel.start()
	return duel


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
