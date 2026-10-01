extends RefCounted
class_name AiValidation

## Typed port of the 25 recovered candidate validators in ai_validation.c.
## Action operands are packed row/column integers; board state stays Godot-owned.

const TARGET_CLASS_PATH := "res://resources/ai_spell_target_classes.json"
const RITUAL_PATH := "res://resources/spell_ritual_recipes.json"
const SPECIAL_PIECES := [583, 584, 585, 586, 587]

var card_database: CardDatabase
var summon_rules: SummonRules
var trap_rules: TrapEffectRules
var target_classes: Array = []
var ritual_recipes: Array = []

func _init(database: CardDatabase = null, summons: SummonRules = null, traps: TrapEffectRules = null) -> void:
	card_database = database
	summon_rules = summons if summons != null else SummonRules.new()
	trap_rules = traps
	var targets: Variant = JSON.parse_string(FileAccess.get_file_as_string(TARGET_CLASS_PATH))
	if targets is Dictionary:
		target_classes = targets.get("metadata_1a_target_classes", [])
	var recipes: Variant = JSON.parse_string(FileAccess.get_file_as_string(RITUAL_PATH))
	if recipes is Array:
		ritual_recipes = recipes

## action_kind follows the recovered 0..24 native action table.
## Returns a reason with invalid results to make candidate filtering inspectable.
func validate(state: SacredDuelState, acting_side: int, action_kind: int, operands: Array[int]) -> Dictionary:
	if state == null or card_database == null or summon_rules == null or acting_side < 0 or acting_side > 1 or action_kind < 0 or action_kind >= 25:
		return {"valid": false, "reason": "invalid_context"}
	if operands.size() < _required_operands(action_kind):
		return {"valid": false, "reason": "missing_operand"}
	var slots: Array[DuelCardSlot] = []
	for operand in operands:
		var slot := _operand_slot(state, acting_side, operand)
		if slot == null:
			return {"valid": false, "reason": "invalid_operand"}
		slots.append(slot)
	var valid := false
	match action_kind:
		0: valid = true
		1: valid = _occupied(_operand_row(state, acting_side, operands[0])) > 4 and not slots[0].is_empty() and _unlocked(slots[0])
		2: valid = _is_unlocked_monster(slots[0]) and _remaining_tributes(slots[0].card_id, state) == 0 and (slots[1].is_empty() or _unlocked(slots[1]))
		3: valid = _summon_tributes(slots, state, 1)
		4: valid = _summon_tributes(slots, state, 2)
		5: valid = (state.side(acting_side).duel_flags & 4) == 0 and _is_unlocked_monster(slots[0])
		6: valid = _is_unlocked_monster(slots[0])
		7, 9: valid = _attack_valid(state, acting_side, operands, slots, action_kind == 9, 0)
		8, 10: valid = _attack_valid(state, acting_side, operands, slots, action_kind == 10, 1)
		11: valid = _summon_tributes(slots, state, 3)
		12, 13: valid = _attack_valid(state, acting_side, operands, slots, action_kind == 13, 2)
		14: valid = _is_class(slots[0], 3) and not _is_special_piece(slots[0].card_id)
		15: valid = _spell_class(slots[0], 1)
		16, 17: valid = _targeted_spell_valid(state, acting_side, operands, slots, action_kind == 17)
		18: valid = _spell_class(slots[0], 0)
		19, 20: valid = _spell_valid(state, acting_side, operands, slots, action_kind == 20)
		21: valid = _is_class(slots[0], 4)
		22: valid = _ritual_valid(slots, operands, state, acting_side)
		23: valid = _hidden_monster_effect(slots[0])
		24: valid = _is_class(slots[0], 3) and _is_special_piece(slots[0].card_id)
	return {"valid": valid, "reason": "ok" if valid else "conditions_not_met", "action_kind": action_kind}

func validate_candidate(state: SacredDuelState, acting_side: int, candidate: Dictionary) -> Dictionary:
	if candidate.is_empty(): return {"valid": false, "reason": "candidate_missing"}
	var operands: Array[int] = []
	for packed: Variant in candidate.get("operands", []): operands.append(int(packed))
	var result := validate(state, acting_side, int(candidate.get("kind", -1)), operands)
	result["candidate_id"] = int(candidate.get("id", -1))
	return result

func _required_operands(kind: int) -> int:
	if kind in [0]: return 0
	if kind in [1, 5, 6, 7, 9, 12, 13, 14, 15, 18, 19, 20, 21, 23, 24]: return 1
	if kind in [2, 3, 8, 10, 16, 17]: return 2
	if kind == 11: return 4
	if kind == 4: return 3
	if kind == 22: return 4
	return 0

func _operand_slot(state: SacredDuelState, acting_side: int, packed: int) -> DuelCardSlot:
	var row_id := (packed >> 4) & 0xF
	var column := packed & 0xF
	if column >= 5: return null
	if row_id == 4: return _hand_slot(state.side(acting_side), column)
	return state.relative_board_slot(acting_side, row_id, column)

func _operand_row(state: SacredDuelState, acting_side: int, packed: int) -> Array[DuelCardSlot]:
	var row_id := (packed >> 4) & 0xF
	if row_id == 4:
		var hand_slots: Array[DuelCardSlot] = []
		for column in range(5):
			hand_slots.append(_hand_slot(state.side(acting_side), column))
		return hand_slots
	return state.relative_board_row(acting_side, row_id)

func _hand_slot(side: DuelSideState, column: int) -> DuelCardSlot:
	var slot := DuelCardSlot.new()
	if side != null and column >= 0 and column < side.hand.size():
		slot.card_id = side.hand[column]
		slot.controller = side.side_id
		if column < side.hand_flags.size(): slot.persistent_flags = side.hand_flags[column]
		if column < side.hand_stages.size(): slot.stage = side.hand_stages[column]
		if column < side.hand_zone_modes.size(): slot.zone_mode = side.hand_zone_modes[column]
	return slot

func _unlocked(slot: DuelCardSlot) -> bool:
	return (slot.persistent_flags & 1) == 0

func _is_unlocked_monster(slot: DuelCardSlot) -> bool:
	return not slot.is_empty() and _is_class(slot, 1) and _unlocked(slot)

func _is_class(slot: DuelCardSlot, category: int) -> bool:
	return not slot.is_empty() and summon_rules.classify_card(slot.card_id, card_database) == category

func _remaining_tributes(card_id: int, state: SacredDuelState) -> int:
	return summon_rules.remaining_monster_tributes(card_id, state.tributes_committed, card_database)

func _summon_tributes(slots: Array[DuelCardSlot], state: SacredDuelState, count: int) -> bool:
	if not _is_unlocked_monster(slots[0]) or _remaining_tributes(slots[0].card_id, state) != count: return false
	for index in range(1, count + 1):
		if not _is_unlocked_monster(slots[index]): return false
	return true

func _attack_valid(state: SacredDuelState, acting_side: int, operands: Array[int], slots: Array[DuelCardSlot], trapped: bool, target_kind: int) -> bool:
	if state.auxiliary_flags[acting_side] == 0 or (state.side(acting_side).duel_flags & 3) != 0: return false
	var trap_found := _find_trap(state, acting_side, operands[0])
	if bool(trap_found.found) != trapped or not _is_unlocked_monster(slots[0]): return false
	if target_kind == 0: return _occupied(state.relative_board_row(acting_side, 1)) == 0
	if slots.size() < 2 or not _is_class(slots[1], 1): return false
	var hidden := (slots[1].persistent_flags & 0x10) != 0
	return hidden == (target_kind == 2)

func _find_trap(state: SacredDuelState, acting_side: int, packed: int) -> Dictionary:
	var row_id := (packed >> 4) & 0xF
	var column := packed & 0xF
	return {"found": false} if trap_rules == null else trap_rules.find_activating_trap(state, 1 - acting_side, acting_side, row_id, column)

func _spell_class(slot: DuelCardSlot, target_class: int) -> bool:
	if not _is_class(slot, 2): return false
	var card := _card(slot.card_id)
	return card != null and card.metadata_1a >= 0 and card.metadata_1a < target_classes.size() and int(target_classes[card.metadata_1a]) == target_class

func _targeted_spell_valid(state: SacredDuelState, acting_side: int, operands: Array[int], slots: Array[DuelCardSlot], trapped: bool) -> bool:
	if not _spell_class(slots[0], 1) or not _is_unlocked_monster(slots[1]): return false
	return bool(_find_trap(state, acting_side, operands[0]).found) == trapped

func _spell_valid(state: SacredDuelState, acting_side: int, operands: Array[int], slots: Array[DuelCardSlot], trapped: bool) -> bool:
	if not _spell_class(slots[0], 0): return false
	return bool(_find_trap(state, acting_side, operands[0]).found) == trapped

func _hidden_monster_effect(slot: DuelCardSlot) -> bool:
	if slot.is_empty(): return false
	var card := _card(slot.card_id)
	return card != null and card.metadata_1b != 0 and _unlocked(slot) and (slot.persistent_flags & 0x10) == 0

func _ritual_valid(slots: Array[DuelCardSlot], operands: Array[int], state: SacredDuelState, acting_side: int) -> bool:
	if not _is_class(slots[0], 4): return false
	for index in range(1, 4):
		if not _is_unlocked_monster(slots[index]): return false
	var ritual := _card(slots[0].card_id)
	if ritual == null: return false
	var recipe_index := ritual.metadata_1d
	var candidates := [29, 28, 27, 5] if recipe_index == 5 else [26, 24] if recipe_index == 24 else [recipe_index]
	var required_column := operands[1] & 0xF
	for index in candidates:
		if index < 0 or index >= ritual_recipes.size(): continue
		var recipe: Dictionary = ritual_recipes[index]
		var additional_materials: Array = recipe.get("other_materials", [0, 0])
		var materials: Array[int] = [int(recipe.get("material", 0)), int(additional_materials[0]), int(additional_materials[1])]
		var column_matches := recipe_index == 5 or _first_card(state.side(acting_side).monster_zones, materials[0]) == required_column
		if _has_materials(state.side(acting_side).monster_zones, materials) and column_matches:
			return true
	return false

func _has_materials(row: Array[DuelCardSlot], materials: Array[int]) -> bool:
	var remaining := materials.duplicate()
	for slot in row:
		var material_index := remaining.find(slot.card_id)
		if material_index >= 0: remaining.remove_at(material_index)
	return remaining.is_empty()

func _first_card(row: Array[DuelCardSlot], card_id: int) -> int:
	for index in range(row.size()):
		if row[index].card_id == card_id: return index
	return -1

func _is_special_piece(card_id: int) -> bool:
	return card_id in SPECIAL_PIECES

func _occupied(row: Array[DuelCardSlot]) -> int:
	var count := 0
	for slot in row:
		if not slot.is_empty(): count += 1
	return count

func _card(card_id: int) -> CardDefinition:
	return card_database.get_card(card_id) if card_database != null else null
