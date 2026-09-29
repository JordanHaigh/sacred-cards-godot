extends RefCounted
class_name CardEffectRules

## Typed ports of card_effects.c's field, life-point and Fairy's Gift handlers.
## Rendering and audio are returned as presentation events for the duel view.

const FIELD_SPELLS := {
	330: {"terrain": 1, "effect_card": 330},
	331: {"terrain": 2, "effect_card": 331},
	332: {"terrain": 3, "effect_card": 332},
	333: {"terrain": 4, "effect_card": 333},
	334: {"terrain": 5, "effect_card": 334},
	335: {"terrain": 6, "effect_card": 335},
}
const LIFE_POINT_SPELLS := {
	338: {"amount": 200, "effect_card": 338, "damage": false},
	339: {"amount": 500, "effect_card": 339, "damage": false},
	340: {"amount": 1000, "effect_card": 340, "damage": false},
	341: {"amount": 2000, "effect_card": 341, "damage": false},
	342: {"amount": 5000, "effect_card": 342, "damage": false},
	343: {"amount": 50, "effect_card": 343, "damage": true},
	344: {"amount": 100, "effect_card": 344, "damage": true},
	345: {"amount": 200, "effect_card": 345, "damage": true},
	346: {"amount": 500, "effect_card": 346, "damage": true},
	347: {"amount": 1000, "effect_card": 347, "damage": true},
}
const METADATA_1A_BY_CARD := {
	330: 3, 331: 4, 332: 5, 333: 6, 334: 7, 335: 8,
	338: 9, 339: 10, 340: 11, 341: 12, 342: 13,
	343: 14, 344: 15, 345: 16, 346: 17, 347: 18,
}

var traps: TrapEffectRules
var battle_state: SacredBattleState

func _init(trap_rules: TrapEffectRules = null) -> void:
	traps = trap_rules
	battle_state = SacredBattleState.new()

func supported_metadata_1a() -> Array[int]:
	var result: Array[int] = []
	for index: int in METADATA_1A_BY_CARD.values():
		if index not in result:
			result.append(index)
	return result

func handles(card_id: int) -> bool:
	return FIELD_SPELLS.has(card_id) or LIFE_POINT_SPELLS.has(card_id) or card_id == 363

func resolve(state: SacredDuelState, acting_side: int, card_id: int, row: int, column: int, presentation_suppressed: bool = false) -> Dictionary:
	if state == null or acting_side < 0 or acting_side >= 2:
		return {"resolved": false}
	if FIELD_SPELLS.has(card_id):
		var field: Dictionary = FIELD_SPELLS[card_id]
		state.terrain = int(field.terrain)
		state.discard_slot(acting_side, row, column, 0)
		return {"resolved": true, "kind": "field", "terrain": state.terrain, "presentation": [] if presentation_suppressed else [65, int(field.effect_card), 79]}
	if LIFE_POINT_SPELLS.has(card_id):
		var spell: Dictionary = LIFE_POINT_SPELLS[card_id]
		var trigger := _slot(state, acting_side, row, column)
		if traps != null and trigger != null and not trigger.is_empty():
			var found := traps.find_activating_trap(state, 1 - acting_side, acting_side, row, column)
			if bool(found.found) and not presentation_suppressed:
				var trap_result := traps.activate(state, 1 - acting_side, int(found.slot), acting_side, row, column, int(found.kind), int(spell.amount))
				return {"resolved": true, "redirected_by_trap": true, "trap": trap_result}
		var affected_side := acting_side if not bool(spell.damage) else 1 - acting_side
		var battle_result := _apply_life_operation(state, affected_side, int(spell.amount), bool(spell.damage))
		state.discard_slot(acting_side, row, column, 0)
		return {"resolved": true, "kind": "life_points", "affected_side": affected_side, "amount": int(spell.amount), "damage": bool(spell.damage), "battle": battle_result, "presentation": [] if presentation_suppressed else [65, int(spell.effect_card), 77 if bool(spell.damage) else 78]}
	if card_id == 363:
		var battle_result := _apply_life_operation(state, acting_side, 1000, false)
		return {"resolved": true, "kind": "monster_heal", "affected_side": acting_side, "amount": 1000, "battle": battle_result, "presentation": [] if presentation_suppressed else [363, 78]}
	return {"resolved": false}

func _apply_life_operation(state: SacredDuelState, affected_side: int, amount: int, damage: bool) -> Dictionary:
	var side_a := {"owner": 0, "attack": 0}
	var side_b := {"owner": 1, "attack": 0}
	if affected_side == 0:
		side_a.attack = amount
		if damage: battle_state.prepare_damage_side_a(amount)
		else: battle_state.prepare_heal_side_a(amount)
	else:
		side_b.attack = amount
		if damage: battle_state.prepare_damage_side_b(amount)
		else: battle_state.prepare_heal_side_b(amount)
	battle_state.resolve(state, side_a, side_b)
	if (battle_state.last_result_flags & 4) != 0: state.auxiliary_flags[0] = 2
	if (battle_state.last_result_flags & 16) != 0: state.auxiliary_flags[1] = 2
	return {"code": battle_state.last_result_code, "flags": battle_state.last_result_flags}

func _slot(state: SacredDuelState, side_id: int, row: int, column: int) -> DuelCardSlot:
	var side := state.side(side_id)
	if side == null or column < 0 or column >= 5:
		return null
	if row == 2:
		return side.monster_zones[column]
	if row == 3:
		return side.back_row_zones[column]
	return null
