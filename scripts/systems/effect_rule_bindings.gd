extends RefCounted
class_name EffectRuleBindings

## Connects recovered effect rules to the existing metadata-index dispatcher.
## The caller owns this binding object for as long as the dispatcher is in use.

var dispatcher: CardEffectDispatcher
var card_effects: CardEffectRules
var effect_families: EffectFamilyRules
var spell_effects: SpellEffectRules
var monster_effects: MonsterEffectRules
var battle_state: SacredBattleState

func install(target: CardEffectDispatcher, card_rules: CardEffectRules, family_rules: EffectFamilyRules, spell_rules: SpellEffectRules, monster_rules: MonsterEffectRules) -> bool:
	dispatcher = target
	card_effects = card_rules
	effect_families = family_rules
	spell_effects = spell_rules
	monster_effects = monster_rules
	if dispatcher == null or card_effects == null or effect_families == null or spell_effects == null or monster_effects == null:
		return false
	battle_state = card_effects.battle_state if card_effects.battle_state != null else SacredBattleState.new()
	card_effects.battle_state = battle_state
	spell_effects.battle_state = battle_state
	monster_effects.battle_state = battle_state
	if card_effects.traps != null: card_effects.traps.battle_state = battle_state
	if spell_effects.trap_rules != null: spell_effects.trap_rules.battle_state = battle_state
	var registered: Dictionary[int, bool] = {}
	for index in card_effects.supported_metadata_1a():
		registered[index] = true
	for index in effect_families.supported_metadata_1a():
		registered[index] = true
	for index in spell_effects.supported_metadata_1a():
		registered[index] = true
	for index in monster_effects.supported_metadata_1b():
		if not dispatcher.register_metadata_1b(index, Callable(self, "_dispatch_monster_effect")):
			return false
	for index: int in registered:
		if not dispatcher.register_metadata_1a(index, Callable(self, "_dispatch_effect")):
			return false
	# Fairy's Gift uses the same typed life-point rule body in the monster table.
	return dispatcher.register_metadata_1b(2, Callable(self, "_dispatch_monster_effect"))

func _dispatch_effect(card: CardDefinition, context: Dictionary) -> Variant:
	var state := context.get("duel_state") as SacredDuelState
	if state == null:
		return {"resolved": false, "reason": "duel_state_missing"}
	var acting_side := int(context.get("acting_side", state.active_side))
	var row := int(context.get("row", -1))
	var column := int(context.get("column", -1))
	var suppressed := bool(context.get("presentation_suppressed", false))
	if effect_families.handles(card.id):
		return effect_families.resolve(
			state,
			acting_side,
			card.id,
			row,
			column,
			int(context.get("source_row", -1)),
			int(context.get("source_column", -1)),
			suppressed
		)
	if spell_effects.handles(card.id):
		return spell_effects.resolve(
			state,
			acting_side,
			card.id,
			row,
			column,
			int(context.get("source_row", -1)),
			int(context.get("source_column", -1)),
			suppressed
		)
	return card_effects.resolve(state, acting_side, card.id, row, column, suppressed)

func _dispatch_monster_effect(card: CardDefinition, context: Dictionary) -> Variant:
	if card.id != 363:
		var state := context.get("duel_state") as SacredDuelState
		if state == null:
			return {"resolved": false, "reason": "duel_state_missing"}
		return monster_effects.resolve(
			state,
			int(context.get("acting_side", state.active_side)),
			card.metadata_1b,
			int(context.get("column", -1)),
			bool(context.get("presentation_suppressed", false)),
			context.get("random_service") as SacredRandom
		)
	var state := context.get("duel_state") as SacredDuelState
	if state == null:
		return {"resolved": false, "reason": "duel_state_missing"}
	return card_effects.resolve(
		state,
		int(context.get("acting_side", state.active_side)),
		card.id,
		int(context.get("row", -1)),
		int(context.get("column", -1)),
		bool(context.get("presentation_suppressed", false))
	)
