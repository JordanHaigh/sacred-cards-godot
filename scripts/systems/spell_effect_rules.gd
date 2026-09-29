extends RefCounted
class_name SpellEffectRules

## Port of the remaining 37 nonempty metadata-1A spell handlers in
## spell_effects.c. Relative C rows become explicit side/zone lookups here.

const RITUAL_PATH := "res://resources/spell_ritual_recipes.json"
const SUMMON_RULES_SCRIPT := preload("res://scripts/systems/summon_rules.gd")
const CARD_METADATA_1A := {
	336: 19, 337: 20, 318: 53, 320: 48, 329: 49, 348: 50, 350: 51, 349: 52,
	669: 82, 658: 99, 672: 76, 661: 81, 653: 95, 656: 97, 655: 96,
	660: 101, 662: 102, 663: 103, 664: 104, 787: 109, 786: 110, 790: 105,
	789: 107, 788: 108, 785: 111, 784: 112, 781: 115, 895: 116, 898: 119,
	896: 121, 894: 122, 893: 123, 891: 124, 892: 125, 675: 69, 667: 94,
	722: 106,
}
const ELIMINATION_SPELLS := {
	653: {"type": 4, "check_immunity": true},
	656: {"type": 3, "check_immunity": false},
	660: {"type": 15, "check_immunity": true},
	662: {"type": 10, "check_immunity": false},
	663: {"type": 19, "check_immunity": false},
	664: {"type": 13, "check_immunity": false},
	787: {"type": 2, "check_immunity": false},
	786: {"type": 8, "check_immunity": false},
}

var card_database: CardDatabase
var stat_rules: CardStatRules
var trap_rules: TrapEffectRules
var battle_state: SacredBattleState
var summon_rules: SummonRules
var _ritual_recipes: Array = []

func _init(database: CardDatabase = null, traps: TrapEffectRules = null, stats: CardStatRules = null) -> void:
	card_database = database
	trap_rules = traps
	stat_rules = stats if stats != null else CardStatRules.new()
	battle_state = SacredBattleState.new()
	summon_rules = SUMMON_RULES_SCRIPT.new()
	_load_rituals()

func supported_metadata_1a() -> Array[int]:
	var indices: Array[int] = []
	for value: Variant in CARD_METADATA_1A.values():
		var index := int(value)
		if index not in indices:
			indices.append(index)
	return indices

func handles(card_id: int) -> bool:
	return CARD_METADATA_1A.has(card_id)

func resolve(state: SacredDuelState, acting_side: int, card_id: int, row: int, column: int, source_row: int = -1, source_column: int = -1, presentation_suppressed: bool = false) -> Dictionary:
	if state == null or acting_side < 0 or acting_side >= state.sides.size():
		return {"resolved": false, "reason": "invalid_context"}
	if card_id not in [893, 894] and (column < 0 or column >= 5):
		return {"resolved": false, "reason": "invalid_context"}
	var target: DuelCardSlot = _relative_slot(state, acting_side, row, column) if column >= 0 and column < 5 else null
	if target == null and card_id not in [893, 894]:
		return {"resolved": false, "reason": "target_slot_missing"}
	var source: DuelCardSlot = _relative_slot(state, acting_side, source_row, source_column) if source_row >= 0 and source_column >= 0 else null
	var result: Dictionary
	match card_id:
		336: result = _clear_field_spell(state, acting_side, target, card_id, [1, 2], 75, presentation_suppressed)
		337:
			var redirect := _check_trap(state, acting_side, row, column, card_id, 0, presentation_suppressed)
			if not redirect.is_empty(): return redirect
			result = _clear_field_spell(state, acting_side, target, card_id, [1], 75, presentation_suppressed)
		320: result = _stop_defense(state, acting_side, target, card_id, presentation_suppressed)
		329: result = _dragon_capture_jar(state, acting_side, target, card_id, presentation_suppressed)
		348: result = _reveal_spell(state, acting_side, target, card_id, true, presentation_suppressed)
		350: result = _reveal_spell(state, acting_side, target, card_id, false, presentation_suppressed)
		349: result = _lower_row_spell(state, acting_side, target, card_id, 1, 74, presentation_suppressed)
		669: result = _lower_row_spell(state, acting_side, target, card_id, 2, 74, presentation_suppressed)
		318: result = _elegant_egotist(state, acting_side, target, source, card_id, presentation_suppressed)
		658: result = _metalmorph(state, acting_side, target, source, card_id, presentation_suppressed)
		672: result = _clear_field_spell(state, acting_side, target, card_id, [0], 89, presentation_suppressed)
		661: result = _crush_card(state, acting_side, target, card_id, presentation_suppressed)
		653, 656, 660, 662, 663, 664, 787, 786: result = _eliminate_type(state, acting_side, target, card_id, presentation_suppressed)
		655: result = _cursebreaker(state, acting_side, target, card_id, presentation_suppressed)
		790: result = _spy(state, acting_side, target, card_id, presentation_suppressed)
		789: result = _draw_two(state, acting_side, target, card_id, presentation_suppressed)
		788: result = _restructer_revolution(state, acting_side, target, card_id, presentation_suppressed)
		785: result = _multiply(state, acting_side, target, card_id, presentation_suppressed)
		784: result = _take_control(state, acting_side, target, card_id, false, presentation_suppressed)
		781: result = _take_control(state, acting_side, target, card_id, true, presentation_suppressed)
		895: result = _monster_reborn(state, acting_side, target, card_id, presentation_suppressed)
		898: result = _beckon(state, acting_side, target, card_id, presentation_suppressed)
		896: result = _gravedigger_ghoul(state, acting_side, target, card_id, presentation_suppressed)
		894: result = _clear_all_fields(state, acting_side, card_id, false, presentation_suppressed)
		893: result = _clear_all_fields(state, acting_side, card_id, true, presentation_suppressed)
		891: result = _messenger_of_peace(state, acting_side, target, card_id, presentation_suppressed)
		892: result = _darkness_approaches(state, acting_side, target, card_id, presentation_suppressed)
		675: result = _ultimate_dragon(state, acting_side, target, card_id, presentation_suppressed)
		667: result = _gate_guardian_ritual(state, acting_side, target, card_id, presentation_suppressed)
		722: result = _dark_magic_ritual(state, acting_side, target, card_id, presentation_suppressed)
		_: return {"resolved": false, "reason": "unsupported_spell"}
	return result

func _clear_field_spell(state: SacredDuelState, acting_side: int, target: DuelCardSlot, card_id: int, relative_rows: Array, sound: int, suppressed: bool) -> Dictionary:
	for relative_row: int in relative_rows:
		_clear_relative_row(state, acting_side, relative_row, card_id != 672)
	var presentation := []
	if card_id in [894, 893]:
		presentation = _present(card_id, sound, suppressed)
	else:
		if target != null:
			_discard_relative(state, acting_side, target, _relative_row_for_slot(state, acting_side, target), _is_monster(target.card_id))
		presentation = _present(card_id, sound, suppressed)
	return {"resolved": true, "kind": "field_clear", "presentation": presentation}

func _check_trap(state: SacredDuelState, acting_side: int, row: int, column: int, card_id: int, amount: int, suppressed: bool) -> Dictionary:
	if trap_rules == null:
		return {}
	var found := trap_rules.find_activating_trap(state, 1 - acting_side, acting_side, row, column)
	if not bool(found.found) or suppressed:
		return {}
	var activated := trap_rules.activate(state, 1 - acting_side, int(found.slot), acting_side, row, column, int(found.kind), amount)
	return {"resolved": true, "redirected_by_trap": true, "trap": activated}

func _stop_defense(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var opponent := state.side(1 - active)
	opponent.duel_flags |= 4
	for slot in _row(state, active, 1):
		if not slot.is_empty():
			slot.defense_position = false
			slot.face_down = false
			slot.persistent_flags = (slot.persistent_flags & 0xFD) | 0x10
	return _consume(state, active, target, card_id, 60, suppressed)

func _dragon_capture_jar(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	for column in range(5):
		var slot := _relative_slot(state, active, 1, column)
		var card := _card(slot.card_id)
		if card != null and not state.is_effect_immune(card.id) and card.card_type == 1:
			_discard_relative(state, active, slot, 1, true)
	return _consume(state, active, target, card_id, 76, suppressed)

func _reveal_spell(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, restrict_attack: bool, suppressed: bool) -> Dictionary:
	if restrict_attack:
		state.side(1 - active).attack_restriction_turns |= 3
	for slot in _row(state, active, 1):
		if not slot.is_empty():
			slot.face_down = false
			slot.persistent_flags |= 0x10
	return _consume(state, active, target, card_id, 80 if restrict_attack else 60, suppressed)

func _lower_row_spell(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, stages: int, sound: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, 1):
		if not slot.is_empty():
			for _step in range(stages):
				slot.stage = maxi(-128, slot.stage - 1)
	return _consume(state, active, target, card_id, sound, suppressed)

func _elegant_egotist(state: SacredDuelState, active: int, target: DuelCardSlot, source: DuelCardSlot, _card_id: int, suppressed: bool) -> Dictionary:
	if source == null:
		return {"resolved": false, "reason": "source_missing"}
	var matched := 0
	for material in [62, 875]:
		if target.card_id == material:
			target.card_id = 63
			_discard_relative(state, active, source, 3, false)
			matched = material
	if matched == 0:
		return {"resolved": false, "reason": "material_missing"}
	return {"resolved": true, "kind": "transformation", "result_card_id": 63, "presentation": _present_pair(318, matched, 90, suppressed)}

func _metalmorph(state: SacredDuelState, active: int, target: DuelCardSlot, source: DuelCardSlot, _card_id: int, suppressed: bool) -> Dictionary:
	if source == null:
		return {"resolved": false, "reason": "source_missing"}
	var results := {391: 392, 82: 742, 885: 884}
	if not results.has(target.card_id):
		return {"resolved": false, "reason": "material_missing"}
	target.card_id = int(results[target.card_id])
	_discard_relative(state, active, source, 3, false)
	return {"resolved": true, "kind": "transformation", "result_card_id": target.card_id, "presentation": _present(658, 90, suppressed)}

func _crush_card(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, 1):
		if slot.is_empty() or state.is_effect_immune(slot.card_id):
			continue
		if _attack(slot, state.terrain) > 1499:
			_discard_relative(state, active, slot, 1, true)
	return _consume(state, active, target, card_id, 76, suppressed)

func _eliminate_type(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var rule: Dictionary = ELIMINATION_SPELLS[card_id]
	for slot in _row(state, active, 1):
		if bool(rule.check_immunity) and state.is_effect_immune(slot.card_id):
			continue
		var card := _card(slot.card_id)
		if card != null and card.card_type == int(rule.type):
			_discard_relative(state, active, slot, 1, true)
	return _consume(state, active, target, card_id, 76, suppressed)

func _cursebreaker(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, 2):
		if not slot.is_empty() and slot.stage < 0:
			slot.stage = 0
	return _consume(state, active, target, card_id, 73, suppressed)

func _spy(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	state.side(1 - active).hand_revealed = true
	return _consume(state, active, target, card_id, 60, suppressed)

func _draw_two(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var drawn: Array[int] = []
	for _draw in range(2):
		var card_id_drawn := DuelDeck.draw_card(state.side(active), state)
		if card_id_drawn != 0:
			drawn.append(card_id_drawn)
	var consumed := _consume(state, active, target, card_id, 59, suppressed)
	consumed["drawn_card_ids"] = drawn
	return consumed

func _restructer_revolution(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var damage := maxi(0, 5 - mini(5, state.side(1 - active).hand_count())) * 200
	var battle_result := _damage(state, 1 - active, damage)
	var consumed := _consume(state, active, target, card_id, 77, suppressed)
	consumed["damage"] = damage
	consumed["battle"] = battle_result
	return consumed

func _multiply(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, 2)
	var has_material := false
	for slot in row:
		has_material = has_material or slot.card_id == 58
	if has_material:
		for slot in row:
			if slot.is_empty():
				slot.card_id = 58
				slot.stage = 0
				slot.zone_mode = 0
				slot.persistent_flags = (slot.persistent_flags | 0x11) & 0xF9 & 0xDF
			else:
				if slot.card_id == 58:
					slot.persistent_flags = (slot.persistent_flags | 0x11) & 0xFD
	return _consume(state, active, target, card_id, 83, suppressed)

func _take_control(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, temporary: bool, suppressed: bool) -> Dictionary:
	var own := _row(state, active, 2)
	var enemy := _row(state, active, 1)
	var destination := -1
	for index in range(own.size()):
		if own[index].is_empty():
			destination = index
			break
	var source_index := _strongest_vulnerable(state, active)
	if destination >= 0 and source_index >= 0:
		var destination_slot: DuelCardSlot = own[destination]
		var source_slot: DuelCardSlot = enemy[source_index]
		destination_slot.card_id = source_slot.card_id
		destination_slot.controller = active
		destination_slot.stage = source_slot.stage
		destination_slot.zone_mode = 2
		destination_slot.face_down = false
		destination_slot.defense_position = (source_slot.persistent_flags & 4) != 0
		destination_slot.has_attacked = false
		destination_slot.persistent_flags = ((source_slot.persistent_flags | 0x10) & 0xFC & 0xFB) | (source_slot.persistent_flags & 4)
		if temporary:
			destination_slot.persistent_flags |= 0x20
		else:
			destination_slot.persistent_flags &= 0xDF
		source_slot.clear()
	var consumed := _consume(state, active, target, card_id, 85, suppressed)
	consumed["stolen_card_id"] = own[destination].card_id if destination >= 0 and source_index >= 0 else 0
	return consumed

func _monster_reborn(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var own := _row(state, active, 2)
	var destination := -1
	for index in range(own.size()):
		if own[index].is_empty():
			destination = index
			break
	var revived := 0
	if destination >= 0:
		var enemy := 1 - active
		revived = state.take_grave_card(enemy)
		if revived != 0:
			var slot: DuelCardSlot = own[destination]
			slot.card_id = revived
			slot.controller = active
			slot.stage = 0
			slot.zone_mode = 2
			slot.face_down = false
			slot.persistent_flags = (slot.persistent_flags | 0x10) & 0xF8 & 0xDF
	var consumed := _consume(state, active, target, card_id, 84, suppressed)
	consumed["revived_card_id"] = revived
	return consumed

func _beckon(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var source_index := _strongest_vulnerable(state, active)
	var destroyed := 0
	if source_index >= 0:
		var source: DuelCardSlot = _row(state, active, 1)[source_index]
		destroyed = source.card_id
		_discard_relative(state, active, source, 1, true)
	var consumed := _consume(state, active, target, card_id, 76, suppressed)
	consumed["destroyed_card_id"] = destroyed
	return consumed

func _gravedigger_ghoul(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var removed := [state.take_grave_card(0, true), state.take_grave_card(1, true)]
	var consumed := _consume(state, active, target, card_id, 76, suppressed)
	consumed["removed_grave_card_ids"] = removed
	return consumed

func _clear_all_fields(state: SacredDuelState, active: int, card_id: int, clear_hands: bool, suppressed: bool) -> Dictionary:
	for relative_row in range(4):
		_clear_relative_row(state, active, relative_row, true)
	if clear_hands:
		var removed: Array[int] = []
		for side_id in range(2):
			var side := state.side(side_id)
			for hand_index in range(side.hand.size()):
				var hand_card_id: int = side.hand[hand_index]
				if hand_card_id == 0 or state.is_effect_immune(hand_card_id):
					continue
				if _is_monster(hand_card_id):
					state.remember_grave_card(side_id, hand_card_id, true)
				removed.append(hand_card_id)
				side.remove_hand_at(hand_index)
		return {"resolved": true, "kind": "field_and_hand_clear", "removed_hand_card_ids": removed, "presentation": _present(card_id, 75, suppressed)}
	return {"resolved": true, "kind": "field_clear", "presentation": _present(card_id, 75, suppressed)}

func _messenger_of_peace(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, 1):
		if not slot.is_empty() and _attack(slot, state.terrain) > 1499:
			slot.persistent_flags |= 1
	return _consume(state, active, target, card_id, 80, suppressed)

func _darkness_approaches(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, 2):
		if not slot.is_empty():
			slot.face_down = true
			slot.persistent_flags &= 0xEF
	return _consume(state, active, target, card_id, 60, suppressed)

func _ultimate_dragon(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var chosen_recipe: Dictionary = {}
	var chosen_slots: Array[int] = []
	for recipe_index in [29, 28, 27, 5]:
		if recipe_index < _ritual_recipes.size():
			var recipe: Dictionary = _ritual_recipes[recipe_index]
			var slots := _find_three_materials(state, active, recipe)
			if slots.size() == 3:
				chosen_recipe = recipe
				chosen_slots = slots
				break
	if chosen_slots.size() != 3:
		return {"resolved": false, "reason": "materials_missing"}
	_discard_relative(state, active, target, _relative_row_for_slot(state, active, target), false)
	var row := _row(state, active, 2)
	_replace_slot_card(row[chosen_slots[0]], int(chosen_recipe.result))
	row[chosen_slots[1]].clear()
	row[chosen_slots[2]].clear()
	state.tributes_committed = 0
	return {"resolved": true, "kind": "ritual", "result_card_id": int(chosen_recipe.result), "reset_tributes": true, "presentation": _present_pair(card_id, int(chosen_recipe.result), 83, suppressed)}

func _gate_guardian_ritual(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, 2)
	var columns: Array[int] = []
	for material in [371, 372, 373]:
		var column := _find_card(row, material)
		if column < 0:
			return {"resolved": false, "reason": "materials_missing"}
		columns.append(column)
	_discard_relative(state, active, target, _relative_row_for_slot(state, active, target), false)
	_replace_slot_card(row[columns[0]], 374)
	row[columns[1]].clear()
	row[columns[2]].clear()
	state.tributes_committed = 0
	return {"resolved": true, "kind": "ritual", "result_card_id": 374, "reset_tributes": true, "presentation": _present_pair(card_id, 374, 83, suppressed)}

func _dark_magic_ritual(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, 2)
	var recipe_index := 26 if _contains_card(row, 865) else 24 if _contains_card(row, 35) else -1
	if recipe_index < 0 or recipe_index >= _ritual_recipes.size():
		return {"resolved": false, "reason": "materials_missing"}
	var recipe: Dictionary = _ritual_recipes[recipe_index]
	var material_column := _find_card(row, int(recipe.material))
	if material_column < 0:
		return {"resolved": false, "reason": "materials_missing"}
	_discard_relative(state, active, target, _relative_row_for_slot(state, active, target), false)
	_replace_slot_card(row[material_column], int(recipe.result))
	state.tributes_committed = 0
	return {"resolved": true, "kind": "ritual", "result_card_id": int(recipe.result), "reset_tributes": true, "presentation": _present_pair(card_id, int(recipe.result), 83, suppressed)}

func _find_three_materials(state: SacredDuelState, active: int, recipe: Dictionary) -> Array[int]:
	var cards := [int(recipe.material), int(recipe.raw_words[2]), int(recipe.raw_words[3])]
	var columns: Array[int] = []
	var row := _row(state, active, 2)
	for card_id in cards:
		var found := -1
		for column in range(row.size()):
			if column in columns:
				continue
			if row[column].card_id == card_id:
				found = column
				break
		if found < 0:
			return []
		columns.append(found)
	return columns

func _consume(state: SacredDuelState, active: int, target: DuelCardSlot, card_id: int, sound: int, suppressed: bool) -> Dictionary:
	_discard_relative(state, active, target, _relative_row_for_slot(state, active, target), false)
	return {"resolved": true, "kind": "spell", "presentation": _present(card_id, sound, suppressed)}

func _discard_relative(state: SacredDuelState, active: int, slot: DuelCardSlot, relative_row: int, is_monster: bool) -> void:
	if slot == null:
		return
	var owner := active if relative_row >= 2 else 1 - active
	var actual_row := 2 if relative_row in [1, 2] else 3
	var column := _find_slot_column(state, owner, actual_row, slot)
	if column >= 0:
		state.discard_slot(owner, actual_row, column, is_monster)

func _clear_relative_row(state: SacredDuelState, active: int, relative_row: int, check_immunity: bool) -> void:
	for slot in _row(state, active, relative_row):
		if not check_immunity or not state.is_effect_immune(slot.card_id):
			_discard_relative(state, active, slot, relative_row, _is_monster(slot.card_id))

func _relative_slot(state: SacredDuelState, active: int, relative_row: int, column: int) -> DuelCardSlot:
	if column < 0 or column >= 5:
		return null
	var slots := _row(state, active, relative_row)
	return slots[column] if column < slots.size() else null

func _row(state: SacredDuelState, active: int, relative_row: int) -> Array[DuelCardSlot]:
	var owner := active if relative_row >= 2 else 1 - active
	var side := state.side(owner)
	if side == null:
		return []
	return side.monster_zones if relative_row in [1, 2] else side.back_row_zones if relative_row in [0, 3] else []

func _relative_row_for_slot(state: SacredDuelState, active: int, slot: DuelCardSlot) -> int:
	if slot == null:
		return 3
	for relative_row in range(4):
		for candidate in _row(state, active, relative_row):
			if candidate == slot:
				return relative_row
	return 3

func _find_slot_column(state: SacredDuelState, side_id: int, row: int, slot: DuelCardSlot) -> int:
	var side := state.side(side_id)
	if side == null:
		return -1
	var slots: Array[DuelCardSlot] = side.monster_zones if row == 2 else side.back_row_zones
	for index in range(slots.size()):
		if slots[index] == slot:
			return index
	return -1

func _find_card(row: Array[DuelCardSlot], card_id: int) -> int:
	for index in range(row.size()):
		if row[index].card_id == card_id:
			return index
	return -1

func _contains_card(row: Array[DuelCardSlot], card_id: int) -> bool:
	return _find_card(row, card_id) >= 0

func _strongest_vulnerable(state: SacredDuelState, active: int) -> int:
	var best := 0
	var result := -1
	var row := _row(state, active, 1)
	for index in range(row.size()):
		var slot: DuelCardSlot = row[index]
		if slot.is_empty() or state.is_effect_immune(slot.card_id):
			continue
		var attack := _attack(slot, state.terrain)
		if attack >= best:
			best = attack
			result = index
	return result

func _attack(slot: DuelCardSlot, terrain: int) -> int:
	var card := _card(slot.card_id)
	if card == null:
		return 0
	var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, terrain, slot.stage)
	return int(stats.attack)

func _is_monster(card_id: int) -> bool:
	return summon_rules.classify_card(card_id, card_database) == 1

func _card(card_id: int) -> CardDefinition:
	return card_database.get_card(card_id) if card_database != null and card_id > 0 else null

func _replace_slot_card(slot: DuelCardSlot, card_id: int) -> void:
	slot.card_id = card_id
	slot.stage = 0
	slot.zone_mode = 0
	slot.persistent_flags &= 0xC8

func _damage(state: SacredDuelState, side_id: int, amount: int) -> Dictionary:
	if side_id < 0 or side_id >= state.sides.size():
		return {"resolved": false}
	var side_a := {"owner": 0, "attack": amount if side_id == 0 else 0}
	var side_b := {"owner": 1, "attack": amount if side_id == 1 else 0}
	if side_id == 0: battle_state.prepare_damage_side_a(amount)
	else: battle_state.prepare_damage_side_b(amount)
	battle_state.resolve(state, side_a, side_b)
	if (battle_state.last_result_flags & 4) != 0: state.auxiliary_flags[0] = 2
	if (battle_state.last_result_flags & 16) != 0: state.auxiliary_flags[1] = 2
	return {"resolved": true, "code": battle_state.last_result_code, "flags": battle_state.last_result_flags}

func _present(card_id: int, sound: int, suppressed: bool) -> Array:
	return [] if suppressed else [65, card_id, sound]

func _present_pair(card_id: int, other_card_id: int, sound: int, suppressed: bool) -> Array:
	return [] if suppressed else [65, card_id, other_card_id, sound]

func _load_rituals() -> void:
	if not FileAccess.file_exists(RITUAL_PATH):
		push_error("Missing recovered spell ritual table: %s" % RITUAL_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RITUAL_PATH))
	if parsed is Array:
		_ritual_recipes = parsed
