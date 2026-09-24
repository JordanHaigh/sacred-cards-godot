extends SceneTree

const REGISTRY_SCRIPT = preload("res://scripts/duel/card_effect_registry.gd")
const EFFECTS_SCRIPT = preload("res://scripts/duel/basic_card_effects.gd")
const ACTION_SCRIPT = preload("res://scripts/duel/duel_action.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")


func _init() -> void:
	var duel = DUEL_STATE_SCRIPT.new(load("res://resources/sacred_cards_rules.tres"), "player_one", "player_two")
	var player_one = duel.get_player("player_one")
	var player_two = duel.get_player("player_two")
	var magic_card = CARD_INSTANCE_SCRIPT.new(301, "player_one")
	player_one.add_to_hand(magic_card)
	if not duel.start() or not duel.set_phase("main"):
		_fail("The activation test duel should start in the main phase.")
		return

	var registry = REGISTRY_SCRIPT.new()
	var effects = EFFECTS_SCRIPT.new()
	if not effects.register_primitives(registry).is_empty() or not registry.map_card_effect(301, "lp_damage"):
		_fail("The damage primitive should register and map to the demo Magic card.")
		return
	var action = ACTION_SCRIPT.activate_effect("player_one", 301, "Magic", "lp_damage", {
		"target_player_id": "player_two",
		"amount": 500,
	})
	if not action.execute(duel, registry):
		_fail("A mapped Magic effect should activate: %s" % action.last_error)
		return
	if player_two.life_points != 7500 or player_one.graveyard_size() != 1 or player_one.hand_size() != 0:
		_fail("Successful activation should apply damage and move the Magic card to the graveyard.")
		return

	var unmapped_card = CARD_INSTANCE_SCRIPT.new(302, "player_one")
	player_one.add_to_hand(unmapped_card)
	var unmapped = ACTION_SCRIPT.activate_effect("player_one", 302, "Magic", "lp_damage", {"amount": 500})
	if unmapped.execute(duel, registry) or "not mapped" not in unmapped.last_error:
		_fail("A registered effect must still be rejected when it is not mapped to the selected card.")
		return
	print("PASS: DuelAction validates effect mappings, applies a reusable effect, and consumes the source card only on success.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
