extends RefCounted
class_name BattleSetupSystem

## Hardware independent port of battle_setup.c combatant preparation.
const STAT_RULES_SCRIPT = preload("res://scripts/systems/card_stat_rules.gd")

var card_database: CardDatabase
var stat_rules: CardStatRules

func _init(database: CardDatabase = null, rules: CardStatRules = null) -> void:
	card_database = database
	stat_rules = rules if rules != null else STAT_RULES_SCRIPT.new()

## Returns calculator side dictionaries plus native-independent source/target locators.
func prepare_direct_attack(duel: SacredDuelState, attacker_column: int) -> Dictionary:
	if not _valid_duel_and_column(duel, attacker_column):
		return {}
	var attacker_side := duel.active_side
	var attacker := _combatant(duel, attacker_side, 2, attacker_column, false)
	var empty_defender := _empty_combatant(1 - attacker_side)
	var side_a: Dictionary = attacker if attacker_side == 0 else empty_defender
	var side_b: Dictionary = empty_defender if attacker_side == 0 else attacker
	return {
		"command": 4 if attacker_side == 0 else 6,
		"side_a": side_a,
		"side_b": side_b,
		"attacker": {"side": attacker_side, "row": 2, "column": attacker_column},
		"target": {"side": 1 - attacker_side, "row": -1, "column": -1},
	}

func prepare_monster_attack(duel: SacredDuelState, attacker_column: int, target_column: int) -> Dictionary:
	if not _valid_duel_and_column(duel, attacker_column) or target_column < 0 or target_column >= 5:
		return {}
	var attacker_side := duel.active_side
	var target_side := 1 - attacker_side
	var target_slot := duel.sides[target_side].monster_zones[target_column]
	if target_slot.is_empty():
		return {}
	var target_defends := target_slot.defense_position
	var attacker := _combatant(duel, attacker_side, 2, attacker_column, true)
	var target := _combatant(duel, target_side, 1, target_column, true)
	var side_a: Dictionary
	var side_b: Dictionary
	var command: int
	if attacker_side == 0:
		side_a = attacker
		side_b = target
		command = 2 if target_defends else 1
	else:
		side_a = target
		side_b = attacker
		command = 5 if target_defends else 1
	return {
		"command": command,
		"side_a": side_a,
		"side_b": side_b,
		"attacker": {"side": attacker_side, "row": 2, "column": attacker_column},
		"target": {"side": target_side, "row": 1, "column": target_column},
	}

func _valid_duel_and_column(duel: SacredDuelState, column: int) -> bool:
	return duel != null and duel.status == SacredDuelState.Status.ACTIVE and duel.active_side >= 0 and duel.active_side < duel.sides.size() and column >= 0 and column < 5 and not duel.sides[duel.active_side].monster_zones[column].is_empty()

func _empty_combatant(owner_id: int) -> Dictionary:
	return {"attack": 0, "defense": 0, "attribute": 0, "owner": owner_id}

func _combatant(duel: SacredDuelState, side_id: int, row: int, column: int, include_attribute: bool) -> Dictionary:
	var side := duel.sides[side_id]
	var slot: DuelCardSlot = side.monster_zones[column]
	var card: CardDefinition = card_database.get_card(slot.card_id) if card_database != null else null
	if card == null:
		return _empty_combatant(side_id)
	var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, duel.terrain, slot.stage)
	return {
		"attack": int(stats.attack),
		"defense": int(stats.defense),
		"attribute": card.attribute if include_attribute else 0,
		"owner": side_id,
	}
