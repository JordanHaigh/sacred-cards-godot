class_name BasicDuelAI
extends RefCounted

## A small deterministic opponent that only issues validated DuelAction commands.
## It draws, summons its strongest monster, queues attacks, then ends its turn.

const DUEL_ACTION_SCRIPT = preload("res://scripts/duel/duel_action.gd")

var last_error: String = ""


func take_turn(duel_state: Object, card_database: Object, battle_resolver: Object = null) -> bool:
	last_error = ""
	if duel_state == null or card_database == null:
		return _fail("A DuelState and CardDatabase are required.")
	if duel_state.get("status") != "in_progress":
		return _fail("The duel is not in progress.")
	var actor_id := String(duel_state.get("active_player_id"))
	var opponent_id := _opponent_id(duel_state, actor_id)
	if actor_id.is_empty() or opponent_id.is_empty():
		return _fail("The active player and an opponent must exist.")
	var actor = duel_state.call("get_player", actor_id)
	var opponent = duel_state.call("get_player", opponent_id)
	_initialize_field_cards(duel_state, card_database)

	if duel_state.get("phase") == "draw":
		if not _execute(DUEL_ACTION_SCRIPT.draw(actor_id), duel_state):
			return false
	if duel_state.get("phase") != "main":
		return _fail("The AI turn must begin in the draw phase.")

	var monster := _strongest_monster(actor.call("get_hand"), card_database)
	if monster != null and actor.call("get_open_monster_zone_index") >= 0:
		var definition = monster.call("resolve_definition", card_database)
		var summon := DUEL_ACTION_SCRIPT.summon(actor_id, int(monster.get("definition_id")), String(definition.get("card_type")))
		if not _execute(summon, duel_state):
			return false

	if not duel_state.call("set_phase", "battle"):
		return _fail("The duel could not enter its battle phase.")
	for zone_index in range(actor.call("monster_zone_count")):
		var attacker = actor.call("get_monster_zone", zone_index)
		if attacker == null or attacker.get("face_state") != "face_up" or attacker.get("battle_position") != "attack":
			continue
		var defender_zone := _first_monster_zone(opponent)
		var attack := DUEL_ACTION_SCRIPT.attack(actor_id, zone_index, opponent_id, defender_zone)
		if not _execute(attack, duel_state):
			return false
		if battle_resolver != null:
			duel_state.call("pop_pending_action")
			var result = battle_resolver.call("resolve", duel_state, actor_id, zone_index, opponent_id, defender_zone)
			if not result.get("success"):
				return _fail(result.get("error"))
			if duel_state.get("status") == "finished":
				return true

	if not _execute(DUEL_ACTION_SCRIPT.end_turn(actor_id), duel_state):
		return false
	return true


func _strongest_monster(hand: Array, card_database: Object) -> Object:
	var best: Object = null
	var best_attack := -1
	for card in hand:
		var definition = card.resolve_definition(card_database)
		if definition == null or definition.get("card_type") != "Monster":
			continue
		if not card.is_initialized() and not card.initialize_from_database(card_database):
			continue
		var attack := int(definition.get("attack"))
		if attack > best_attack:
			best = card
			best_attack = attack
	return best


func _initialize_field_cards(duel_state: Object, card_database: Object) -> void:
	for player in duel_state.call("get_players"):
		for zone_index in range(player.monster_zone_count()):
			var card = player.get_monster_zone(zone_index)
			if card != null and not card.is_initialized():
				card.initialize_from_database(card_database)


func _first_monster_zone(player: Object) -> int:
	for zone_index in range(player.call("monster_zone_count")):
		if player.call("get_monster_zone", zone_index) != null:
			return zone_index
	return -1


func _opponent_id(duel_state: Object, actor_id: String) -> String:
	for player_id in duel_state.call("player_ids"):
		if String(player_id) != actor_id:
			return String(player_id)
	return ""


func _execute(action: Object, duel_state: Object) -> bool:
	if bool(action.call("execute", duel_state)):
		return true
	return _fail(String(action.get("last_error")))


func _fail(message: String) -> bool:
	last_error = message
	return false
