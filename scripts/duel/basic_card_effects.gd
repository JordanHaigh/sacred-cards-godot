class_name BasicCardEffects
extends RefCounted

## Registers reusable spell primitives. Card IDs are resolved by data mappings,
## while handlers operate only on their supplied target context.

const EVENT_BUS_SCRIPT = preload("res://scripts/duel/duel_event_bus.gd")
const VICTORY_RESOLVER_SCRIPT = preload("res://scripts/duel/victory_resolver.gd")

const EFFECT_LP_DAMAGE := "lp_damage"
const EFFECT_LP_HEAL := "lp_heal"
const EFFECT_DRAW_CARDS := "draw_cards"
const EFFECT_MODIFY_MONSTER_STATS := "modify_monster_stats"
const EFFECT_DESTROY_MONSTER := "destroy_monster"
const EFFECT_REVIVE_MONSTER := "revive_monster"
const EFFECT_CHANGE_MONSTER_POSITION := "change_monster_position"


func register_primitives(registry: Object) -> PackedStringArray:
	var diagnostics := PackedStringArray()
	var registrations: Array[Dictionary] = [
		{"id": EFFECT_LP_DAMAGE, "handler": Callable(self, "_damage_life_points")},
		{"id": EFFECT_LP_HEAL, "handler": Callable(self, "_heal_life_points")},
		{"id": EFFECT_DRAW_CARDS, "handler": Callable(self, "_draw_cards")},
		{"id": EFFECT_MODIFY_MONSTER_STATS, "handler": Callable(self, "_modify_monster_stats")},
		{"id": EFFECT_DESTROY_MONSTER, "handler": Callable(self, "_destroy_monster")},
		{"id": EFFECT_REVIVE_MONSTER, "handler": Callable(self, "_revive_monster")},
		{"id": EFFECT_CHANGE_MONSTER_POSITION, "handler": Callable(self, "_change_monster_position")},
	]
	for registration in registrations:
		if not bool(registry.call("register_effect", registration["id"], registration["handler"])):
			diagnostics.append(String(registry.get("last_error")))
	return diagnostics


func _damage_life_points(context: Dictionary) -> Dictionary:
	var target = _target_player(context)
	if target == null:
		return _fail("LP damage requires a valid target player.")
	var amount := int(context.get("amount", 0))
	if amount <= 0:
		return _fail("LP damage amount must be greater than zero.")
	var old_points := int(target.get("life_points"))
	var actual_damage: int = target.call("take_damage", amount)
	_publish_life_points(context, target, old_points, "damage", actual_damage)
	VICTORY_RESOLVER_SCRIPT.new().resolve(context["duel_state"])
	return _success({"target_player_id": target.get("player_id"), "amount": actual_damage})


func _heal_life_points(context: Dictionary) -> Dictionary:
	var target = _target_player(context)
	if target == null:
		return _fail("LP healing requires a valid target player.")
	var amount := int(context.get("amount", 0))
	if amount <= 0:
		return _fail("LP healing amount must be greater than zero.")
	var old_points := int(target.get("life_points"))
	var actual_healing: int = target.call("heal", amount)
	_publish_life_points(context, target, old_points, "heal", actual_healing)
	return _success({"target_player_id": target.get("player_id"), "amount": actual_healing})


func _draw_cards(context: Dictionary) -> Dictionary:
	var target = _target_player(context)
	if target == null:
		return _fail("Drawing cards requires a valid target player.")
	var count := int(context.get("count", 1))
	if count <= 0:
		return _fail("Draw count must be greater than zero.")
	var drawn: Array = target.call("draw_cards", count)
	var duel_state = context["duel_state"]
	for card in drawn:
		duel_state.call("emit_event", EVENT_BUS_SCRIPT.EVENT_CARD_DRAWN, {
			"player_id": target.get("player_id"),
			"card_id": int(card.get("definition_id")),
			"source": "effect",
		})
	if drawn.is_empty():
		return _fail("No cards could be drawn from the target player's deck.")
	return _success({"target_player_id": target.get("player_id"), "count": drawn.size()})


func _modify_monster_stats(context: Dictionary) -> Dictionary:
	var target_and_card := _target_monster(context)
	if target_and_card.is_empty():
		return _fail("Stat changes require a monster in the requested zone.")
	var card = target_and_card["card"]
	var attack_delta := int(context.get("attack_delta", 0))
	var defense_delta := int(context.get("defense_delta", 0))
	if attack_delta == 0 and defense_delta == 0:
		return _fail("At least one stat change must be non-zero.")
	card.set("current_attack", maxi(0, int(card.get("current_attack")) + attack_delta))
	card.set("current_defense", maxi(0, int(card.get("current_defense")) + defense_delta))
	if attack_delta > 0 or defense_delta > 0:
		card.call("add_buff", "card_effect", maxi(0, attack_delta), maxi(0, defense_delta))
	if attack_delta < 0 or defense_delta < 0:
		card.call("add_debuff", "card_effect", absi(mini(0, attack_delta)), absi(mini(0, defense_delta)))
	var details := {
		"target_player_id": target_and_card["player"].get("player_id"),
		"zone_index": int(context.get("zone_index", -1)),
		"attack": card.get("current_attack"),
		"defense": card.get("current_defense"),
	}
	_publish_effect(context, EFFECT_MODIFY_MONSTER_STATS, details)
	return _success(details)


func _destroy_monster(context: Dictionary) -> Dictionary:
	var target_and_card := _target_monster(context)
	if target_and_card.is_empty():
		return _fail("Destruction requires a monster in the requested zone.")
	var card = target_and_card["card"]
	var target = target_and_card["player"]
	var zone_index := int(context.get("zone_index", -1))
	if not bool(target.call("send_to_graveyard", card)):
		return _fail("The target monster could not be sent to the graveyard.")
	context["duel_state"].call("emit_event", EVENT_BUS_SCRIPT.EVENT_CARD_DESTROYED, {
		"player_id": target.get("player_id"),
		"card_id": int(card.get("definition_id")),
		"zone_index": zone_index,
		"source": "effect",
	})
	return _success({"target_player_id": target.get("player_id"), "card_id": int(card.get("definition_id"))})


func _revive_monster(context: Dictionary) -> Dictionary:
	var target = _target_player(context)
	if target == null:
		return _fail("Revival requires a valid target player.")
	var graveyard_index := int(context.get("graveyard_index", -1))
	var card: RefCounted = _graveyard_card(target, graveyard_index)
	if card == null:
		return _fail("Revival requires a card at the requested graveyard index.")
	var card_database = context.get("card_database")
	if card_database == null:
		return _fail("Revival requires a CardDatabase to check the card type.")
	var definition = card.call("resolve_definition", card_database)
	if definition == null or definition.get("card_type") != "Monster":
		return _fail("Only monster cards can be revived to a monster zone.")
	var requested_zone := int(context.get("zone_index", -1))
	var open_zone: int = target.call("get_open_zone_index", "monster") if requested_zone < 0 else requested_zone
	if open_zone < 0 or target.call("get_monster_zone", open_zone) != null:
		return _fail("Revival requires an open monster zone.")
	if not bool(target.call("remove_from_graveyard", card)):
		return _fail("The card could not be removed from the graveyard.")
	if int(target.call("place_monster", card, open_zone)) < 0:
		target.call("send_to_graveyard", card)
		return _fail("The revived monster could not be placed in the requested zone.")
	card.set("face_state", "face_up")
	card.set("battle_position", "attack")
	var details := {
		"target_player_id": target.get("player_id"),
		"card_id": int(card.get("definition_id")),
		"zone_index": open_zone,
	}
	_publish_effect(context, EFFECT_REVIVE_MONSTER, details)
	return _success(details)


func _change_monster_position(context: Dictionary) -> Dictionary:
	var target_and_card := _target_monster(context)
	if target_and_card.is_empty():
		return _fail("Position changes require a monster in the requested zone.")
	var next_position := String(context.get("position", ""))
	if not ["attack", "defense"].has(next_position):
		return _fail("Position must be 'attack' or 'defense'.")
	var card = target_and_card["card"]
	if card.get("battle_position") == next_position:
		return _fail("The monster is already in that position.")
	card.set("battle_position", next_position)
	var details := {
		"target_player_id": target_and_card["player"].get("player_id"),
		"zone_index": int(context.get("zone_index", -1)),
		"position": next_position,
	}
	_publish_effect(context, EFFECT_CHANGE_MONSTER_POSITION, details)
	return _success(details)


func _target_player(context: Dictionary) -> Object:
	var duel_state = context.get("duel_state")
	if duel_state == null or not duel_state.has_method("get_player"):
		return null
	var player_id := String(context.get("target_player_id", context.get("actor_id", "")))
	return duel_state.call("get_player", player_id)


func _target_monster(context: Dictionary) -> Dictionary:
	var player = _target_player(context)
	if player == null:
		return {}
	var zone_index := int(context.get("zone_index", -1))
	var card = player.call("get_monster_zone", zone_index)
	if card == null:
		return {}
	return {"player": player, "card": card}


func _graveyard_card(player: Object, index: int) -> RefCounted:
	var graveyard: Array = player.call("get_graveyard")
	if index < 0 or index >= graveyard.size():
		return null
	return graveyard[index]


func _publish_life_points(context: Dictionary, player: Object, old_value: int, change_type: String, amount: int) -> void:
	context["duel_state"].call("emit_event", EVENT_BUS_SCRIPT.EVENT_LIFE_POINTS_CHANGED, {
		"player_id": player.get("player_id"),
		"change_type": change_type,
		"amount": amount,
		"previous": old_value,
		"current": player.get("life_points"),
		"source": "effect",
	})


func _publish_effect(context: Dictionary, effect_id: String, details: Dictionary) -> void:
	context["duel_state"].call("emit_event", EVENT_BUS_SCRIPT.EVENT_EFFECT_RESOLVED, {
		"effect_id": effect_id,
		"actor_id": context.get("actor_id", ""),
		"source_card_id": context.get("source_card_id", -1),
		"details": details,
	})


func _success(details: Dictionary) -> Dictionary:
	return {"success": true, "error": "", "details": details}


func _fail(message: String) -> Dictionary:
	return {"success": false, "error": message, "details": {}}
