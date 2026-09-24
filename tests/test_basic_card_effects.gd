extends SceneTree

const EFFECTS_SCRIPT = preload("res://scripts/duel/basic_card_effects.gd")
const REGISTRY_SCRIPT = preload("res://scripts/duel/card_effect_registry.gd")
const CARD_DATABASE_SCRIPT = preload("res://scripts/cards/card_database.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")


func _init() -> void:
	var database = CARD_DATABASE_SCRIPT.new()
	if not database.load_from_directory("res://data/cards_json").is_empty():
		_fail("CardDatabase should load for effect tests.")
		return
	var duel = DUEL_STATE_SCRIPT.new(load("res://resources/sacred_cards_rules.tres"), "player_one", "player_two")
	var player_one = duel.get_player("player_one")
	var player_two = duel.get_player("player_two")
	var draw_one = CARD_INSTANCE_SCRIPT.new(3, "player_one")
	var draw_two = CARD_INSTANCE_SCRIPT.new(4, "player_one")
	player_one.load_deck([draw_one, draw_two])
	var monster = CARD_INSTANCE_SCRIPT.new(1, "player_two")
	monster.initialize_from_database(database)
	player_two.place_monster(monster, 0)
	if not duel.start() or not duel.set_phase("main"):
		_fail("The effect test duel should start in its main phase.")
		return

	var registry = REGISTRY_SCRIPT.new()
	var primitives = EFFECTS_SCRIPT.new()
	if not primitives.register_primitives(registry).is_empty():
		_fail("Basic spell primitives should register without duplicate IDs.")
		return
	var base_context := {
		"duel_state": duel,
		"card_database": database,
		"actor_id": "player_one",
		"target_player_id": "player_two",
	}

	var damage := _execute(registry, "lp_damage", base_context, {"amount": 500})
	if not damage.get("success") or player_two.life_points != 7500:
		_fail("LP damage should update the target player's authoritative life points.")
		return
	var healing := _execute(registry, "lp_heal", base_context, {"target_player_id": "player_one", "amount": 200})
	if not healing.get("success") or player_one.life_points != 8200:
		_fail("LP healing should update the target player's authoritative life points.")
		return
	var drawing := _execute(registry, "draw_cards", base_context, {"target_player_id": "player_one", "count": 2})
	if not drawing.get("success") or player_one.hand_size() != 2:
		_fail("The draw primitive should move cards from deck to hand.")
		return

	var stat_change := _execute(registry, "modify_monster_stats", base_context, {
		"zone_index": 0,
		"attack_delta": 200,
		"defense_delta": -100,
	})
	if not stat_change.get("success") or monster.current_attack != 3200 or monster.current_defense != 2400:
		_fail("Stat effects should change only the selected monster's runtime stats.")
		return
	var position_change := _execute(registry, "change_monster_position", base_context, {"zone_index": 0, "position": "defense"})
	if not position_change.get("success") or monster.battle_position != "defense":
		_fail("Position effects should update the selected monster.")
		return
	var destruction := _execute(registry, "destroy_monster", base_context, {"zone_index": 0})
	if not destruction.get("success") or player_two.get_monster_zone(0) != null or player_two.graveyard_size() != 1:
		_fail("Destruction should move a monster from the field to its graveyard.")
		return
	var revival := _execute(registry, "revive_monster", base_context, {"graveyard_index": 0, "zone_index": 0})
	if not revival.get("success") or player_two.get_monster_zone(0) != monster or player_two.graveyard_size() != 0:
		_fail("Revival should return a monster to an open field zone.")
		return
	var invalid_target := _execute(registry, "destroy_monster", base_context, {"zone_index": 4})
	if invalid_target.get("success") or invalid_target.get("error", "").is_empty():
		_fail("Invalid effect targets should fail with an explicit reason.")
		return
	print("PASS: BasicCardEffects covers LP, draw, stat, position, destroy, and revive primitives with explicit target checks.")
	quit(0)


func _execute(registry: Object, effect_id: String, base_context: Dictionary, options: Dictionary) -> Dictionary:
	var context := base_context.duplicate()
	context.merge(options, true)
	return registry.call("execute", effect_id, context)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
