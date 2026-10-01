extends RefCounted
class_name AiActions

## Typed replacement for ai_actions.c's 25 simulation/execution actions.
## Candidate operands are packed row/column values; hand and zones are owned data.

var card_database: CardDatabase
var effect_dispatcher: CardEffectDispatcher
var trap_rules: TrapEffectRules
var battle_setup: BattleSetupSystem
var random_service: SacredRandom
var battle_state := SacredBattleState.new()
var summon_rules := SummonRules.new()

func _init(database: CardDatabase = null, dispatcher: CardEffectDispatcher = null, traps: TrapEffectRules = null, setup: BattleSetupSystem = null) -> void:
	card_database = database
	effect_dispatcher = dispatcher
	trap_rules = traps
	battle_setup = setup if setup != null else BattleSetupSystem.new(database)

func set_random_service(service: SacredRandom) -> void:
	random_service = service

## simulate selects the native simulation table behavior. Simulated spell/trap
## effects suppress display while retaining the rule mutations.
func execute(state: SacredDuelState, acting_side: int, candidate: Dictionary, simulate: bool = false) -> Dictionary:
	if state == null or acting_side < 0 or acting_side > 1 or candidate.is_empty():
		return {"resolved": false, "reason": "invalid_context"}
	var kind := int(candidate.get("kind", -1))
	var operands := _operands(candidate)
	if kind < 0 or kind >= 25 or operands.size() != 6:
		return {"resolved": false, "reason": "invalid_candidate"}
	if acting_side != state.active_side:
		return {"resolved": false, "reason": "acting_side_not_active"}
	for packed in operands:
		if _slot(state, acting_side, packed) == null:
			return {"resolved": false, "reason": "invalid_operand"}
	var result: Dictionary = {"resolved": true, "action_kind": kind, "candidate_id": int(candidate.get("id", -1)), "presentation": [], "audio_id": 0}
	match kind:
		0: pass
		1: _discard_operand(state, acting_side, operands[0])
		2: result = _summon(state, acting_side, operands, 0, result)
		3: result = _summon(state, acting_side, operands, 1, result)
		4: result = _summon(state, acting_side, operands, 2, result)
		5:
			_slot(state, acting_side, operands[0]).persistent_flags |= 3
			_slot(state, acting_side, operands[0]).defense_position = true
		6: _attack_pose(_slot(state, acting_side, operands[0]))
		7: result = _attack(state, acting_side, operands, false, false, result)
		8: result = _attack(state, acting_side, operands, true, false, result)
		9:
			if simulate: result = _attack(state, acting_side, operands, false, false, result)
			else: result = _trapped_attack(state, acting_side, operands, result)
		10:
			if simulate: result = _attack(state, acting_side, operands, true, false, result)
			else: result = _trapped_attack(state, acting_side, operands, result)
		11: result = _summon(state, acting_side, operands, 3, result)
		12: result = _attack(state, acting_side, operands, true, false, result)
		13:
			if simulate: result = _attack(state, acting_side, operands, true, false, result)
			else: result = _trapped_attack(state, acting_side, operands, result)
		14, 15, 18, 21, 24: result = _move_card(state, acting_side, operands[0], operands[1], result)
		16, 17: result = _dispatch_spell(state, acting_side, operands[0], operands[1], true, simulate, result)
		19, 20: result = _dispatch_spell(state, acting_side, operands[0], operands[0], false, simulate, result, kind == 19)
		22: result = _ritual_action(state, acting_side, operands, simulate, result)
		23: result = _dispatch_monster(state, acting_side, operands[0], simulate, result)
	if not bool(result.get("resolved", false)):
		return result
	if simulate:
		result.audio_id = 0
	elif int(result.get("audio_id", 0)) == 0:
		result.audio_id = _action_audio(kind)
	if kind == 23 and not simulate:
		result["before_audio_id"] = 64
	if simulate: result.presentation = []
	return result

func _summon(state: SacredDuelState, active: int, operands: Array[int], tribute_count: int, result: Dictionary) -> Dictionary:
	for index in range(tribute_count, 0, -1): _discard_operand(state, active, operands[index])
	var moved := _move_card(state, active, operands[0], operands[1], result)
	if not bool(moved.get("resolved", false)): return moved
	state.side(active).duel_flags |= 8
	_lock_hand_monsters(state.side(active))
	return moved

func _move_card(state: SacredDuelState, active: int, source_packed: int, destination_packed: int, result: Dictionary) -> Dictionary:
	var source_row := (source_packed >> 4) & 15
	var source_column := source_packed & 15
	var destination := _slot(state, active, destination_packed)
	if destination == null: return {"resolved": false, "reason": "destination_missing"}
	var card_id := 0
	var source_flags := 0
	var source_stage := 0
	var source_zone_mode := 0
	if source_row == 4:
		var side := state.side(active)
		if source_column >= side.hand.size(): return {"resolved": false, "reason": "source_empty"}
		card_id = side.hand[source_column]
		source_flags = side.hand_flags[source_column] if source_column < side.hand_flags.size() else 0
		source_stage = side.hand_stages[source_column] if source_column < side.hand_stages.size() else 0
		source_zone_mode = side.hand_zone_modes[source_column] if source_column < side.hand_zone_modes.size() else 0
		side.remove_hand_at(source_column)
	else:
		var source := _slot(state, active, source_packed)
		if source == null or source.is_empty(): return {"resolved": false, "reason": "source_empty"}
		card_id = source.card_id
		source_flags = source.persistent_flags
		_copy_slot(destination, source, active)
		source.clear()
		return result
	destination.card_id = card_id
	destination.controller = active
	var destination_row := (destination_packed >> 4) & 15
	var set_in_back_row := destination_row in [0, 3] and int(result.get("action_kind", -1)) in [14, 15, 18, 21, 24]
	# CopyDuelCell replaces the low six destination flag bits from the source,
	# while preserving destination-owned high bits. Placement pose is separate.
	destination.persistent_flags = (destination.persistent_flags & 0xC0) | (source_flags & 0x3F)
	destination.stage = source_stage
	destination.zone_mode = source_zone_mode
	destination.face_down = set_in_back_row
	destination.defense_position = false
	destination.has_attacked = false
	return result

func _attack(state: SacredDuelState, active: int, operands: Array[int], monster_target: bool, _trapped: bool, result: Dictionary) -> Dictionary:
	if battle_setup == null: return {"resolved": false, "reason": "battle_setup_missing"}
	battle_state.last_result_code = 0
	battle_state.last_result_flags = 0
	var attacker_column := state.absolute_board_column((operands[0] >> 4) & 15, operands[0] & 15)
	var attacker_slot := _slot(state, active, operands[0])
	var attacker_card_id := attacker_slot.card_id if attacker_slot != null else 0
	var target_card_id := 0
	if monster_target and operands.size() > 1:
		var target_slot := _slot(state, active, operands[1])
		target_card_id = target_slot.card_id if target_slot != null else 0
	var old_life_points: Array[int] = [state.sides[0].life_points, state.sides[1].life_points]
	_attack_pose(_slot(state, active, operands[0]))
	var setup: Dictionary
	if monster_target:
		var target := _slot(state, active, operands[1])
		if target == null or target.is_empty(): return {"resolved": false, "reason": "target_missing"}
		target.persistent_flags |= 0x10
		target.face_down = false
		setup = battle_setup.prepare_monster_attack(state, attacker_column, operands[1] & 15)
	else:
		setup = battle_setup.prepare_direct_attack(state, attacker_column)
	if setup.is_empty(): return {"resolved": false, "reason": "battle_setup_failed"}
	battle_state.resolve_setup(state, setup)
	_apply_battle_destruction(state, setup, battle_state.last_result_flags)
	result["battle"] = {"code": battle_state.last_result_code, "flags": battle_state.last_result_flags}
	result["battle_setup"] = setup
	var combat_owners: Array[int] = [int(setup.side_a.get("owner", 0)), int(setup.side_b.get("owner", 1))]
	var combat_cards: Array[int] = []
	for owner in combat_owners:
		combat_cards.append(attacker_card_id if owner == active else target_card_id)
	result["battle_presentation"] = {
		"result_code": battle_state.last_result_code,
		"card_ids": combat_cards,
		"owners": combat_owners,
		"old_life_points": old_life_points,
		"new_life_points": [state.sides[0].life_points, state.sides[1].life_points],
	}
	return result

func _apply_battle_destruction(state: SacredDuelState, setup: Dictionary, flags: int) -> void:
	var attacker: Dictionary = setup.get("attacker", {})
	var target: Dictionary = setup.get("target", {})
	var side_a: Dictionary = setup.get("side_a", {})
	var side_b: Dictionary = setup.get("side_b", {})
	if int(attacker.get("row", -1)) >= 0:
		var attacker_lost := (int(side_a.owner) == int(attacker.side) and (flags & 1) != 0) or (int(side_b.owner) == int(attacker.side) and (flags & 2) != 0)
		if attacker_lost: state.discard_slot(int(attacker.side), 2, int(attacker.column), true)
	if int(target.get("row", -1)) >= 0:
		var target_lost := (int(side_a.owner) == int(target.side) and (flags & 1) != 0) or (int(side_b.owner) == int(target.side) and (flags & 2) != 0)
		if target_lost: state.discard_slot(int(target.side), 2, int(target.column), true)

func _trapped_attack(state: SacredDuelState, active: int, operands: Array[int], result: Dictionary) -> Dictionary:
	var attacker_column := operands[0] & 15
	_attack_pose(_slot(state, active, operands[0]))
	var found := trap_rules.find_activating_trap(state, 1 - active, active, 2, attacker_column) if trap_rules != null else {"found": false}
	if not bool(found.get("found", false)): return {"resolved": false, "reason": "expected_trap_missing"}
	var activated := trap_rules.activate(state, 1 - active, int(found.slot), active, 2, attacker_column, int(found.kind), 1)
	result["trap"] = activated
	result["presentation"] = activated.get("presentation", [])
	return result

func _dispatch_spell(state: SacredDuelState, active: int, source_packed: int, target_packed: int, targeted: bool, simulate: bool, result: Dictionary, lock_hand_after_effect: bool = false) -> Dictionary:
	if effect_dispatcher == null: return {"resolved": false, "reason": "effect_dispatcher_missing"}
	var source := _slot(state, active, source_packed)
	if source == null or source.is_empty(): return {"resolved": false, "reason": "spell_source_missing"}
	var target_row := (target_packed >> 4) & 15
	var target_column := target_packed & 15
	var context := _context(state, active, target_row, target_column, source_packed, targeted, simulate)
	var dispatched: Variant = effect_dispatcher.dispatch_metadata_1a(source.card_id, context)
	if not dispatched is Dictionary or not bool(dispatched.get("resolved", false)):
		return {"resolved": false, "reason": "spell_effect_not_resolved", "effect": dispatched}
	result["effect"] = dispatched
	if lock_hand_after_effect and (state.side(active).duel_flags & 8) != 0:
		_lock_hand_monsters(state.side(active))
	_clear_action_source(state, active, source_packed)
	result["presentation"] = dispatched.get("presentation", []) if dispatched is Dictionary else []
	return result

func _ritual_action(state: SacredDuelState, active: int, operands: Array[int], simulate: bool, result: Dictionary) -> Dictionary:
	var ritual := _slot(state, active, operands[0])
	if ritual == null or ritual.is_empty(): return {"resolved": false, "reason": "ritual_source_missing"}
	var card := _card(ritual.card_id)
	if card != null and summon_rules.card_category_requirement(card.id, card_database) == 2:
		_discard_operand(state, active, operands[2])
		_discard_operand(state, active, operands[3])
	return _dispatch_spell(state, active, operands[0], operands[0], false, simulate, result)

func _dispatch_monster(state: SacredDuelState, active: int, packed: int, simulate: bool, result: Dictionary) -> Dictionary:
	if effect_dispatcher == null: return {"resolved": false, "reason": "effect_dispatcher_missing"}
	var slot := _slot(state, active, packed)
	if slot == null or slot.is_empty(): return {"resolved": false, "reason": "monster_source_missing"}
	_attack_pose(slot)
	var row := (packed >> 4) & 15
	var column := packed & 15
	var dispatched: Variant = effect_dispatcher.dispatch_metadata_1b(slot.card_id, _context(state, active, row, column, packed, false, simulate))
	if not dispatched is Dictionary or not bool(dispatched.get("resolved", false)):
		return {"resolved": false, "reason": "monster_effect_not_resolved", "effect": dispatched}
	result["effect"] = dispatched
	result["presentation"] = dispatched.get("presentation", []) if dispatched is Dictionary else []
	if (state.side(active).duel_flags & 8) != 0: _lock_hand_monsters(state.side(active))
	return result

func _context(state: SacredDuelState, active: int, row: int, column: int, source_packed: int, set_source: bool, simulate: bool) -> Dictionary:
	var context := {
		"duel_state": state,
		"acting_side": active,
		"row": row,
		"column": column,
		"presentation_suppressed": simulate,
		"random_service": random_service,
	}
	if set_source:
		context["source_row"] = (source_packed >> 4) & 15
		context["source_column"] = source_packed & 15
	return context

func _discard_operand(state: SacredDuelState, active: int, packed: int) -> int:
	var row_id := (packed >> 4) & 15
	var column := packed & 15
	if row_id == 4:
		var side := state.side(active)
		if column >= side.hand.size(): return 0
		var card_id := side.remove_hand_at(column)
		if summon_rules.classify_card(card_id, card_database) == 1: state.remember_grave_card(active, card_id, true)
		return card_id
	var owner := active if row_id >= 2 else 1 - active
	var zone_row := 2 if row_id in [1, 2] else 3
	var slot := _slot(state, active, packed)
	if slot == null: return 0
	var is_monster := row_id in [1, 2] and summon_rules.classify_card(slot.card_id, card_database) == 1
	return state.discard_slot(owner, zone_row, state.absolute_board_column(row_id, column), is_monster)

func _clear_action_source(state: SacredDuelState, active: int, packed: int) -> void:
	var row_id := (packed >> 4) & 15
	var column := packed & 15
	if row_id == 4:
		state.side(active).remove_hand_at(column)
		return
	var source := _slot(state, active, packed)
	if source != null:
		source.clear()

func _lock_hand_monsters(side: DuelSideState) -> void:
	for index in range(side.hand.size()):
		if side.hand[index] != 0 and summon_rules.classify_card(side.hand[index], card_database) == 1:
			side.hand_flags[index] |= 1

func _copy_slot(destination: DuelCardSlot, source: DuelCardSlot, active: int) -> void:
	destination.card_id = source.card_id
	destination.controller = active
	destination.face_down = source.face_down
	destination.defense_position = source.defense_position
	destination.has_attacked = source.has_attacked
	destination.stage = source.stage
	destination.zone_mode = source.zone_mode
	destination.persistent_flags = (destination.persistent_flags & 0xC0) | (source.persistent_flags & 0x3F)

func _attack_pose(slot: DuelCardSlot) -> void:
	slot.persistent_flags = (slot.persistent_flags & 0xFD) | 0x11
	slot.face_down = false
	slot.defense_position = false
	slot.has_attacked = true

func _slot(state: SacredDuelState, active: int, packed: int) -> DuelCardSlot:
	var row_id := (packed >> 4) & 15
	var column := packed & 15
	if column >= 5: return null
	if row_id == 4:
		var slot := DuelCardSlot.new()
		var hand_side := state.side(active)
		if column < hand_side.hand.size():
			slot.card_id = hand_side.hand[column]
			if column < hand_side.hand_flags.size(): slot.persistent_flags = hand_side.hand_flags[column]
			if column < hand_side.hand_stages.size(): slot.stage = hand_side.hand_stages[column]
			if column < hand_side.hand_zone_modes.size(): slot.zone_mode = hand_side.hand_zone_modes[column]
		return slot
	return state.relative_board_slot(active, row_id, column)

func _operands(candidate: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for packed: Variant in candidate.get("operands", []): result.append(int(packed))
	return result

func _action_audio(kind: int) -> int:
	if kind == 1: return 62
	if kind in [2, 3, 4, 11, 14, 15, 18, 21]: return 58
	if kind in [5, 6]: return 60
	return 0

func _card(card_id: int) -> CardDefinition:
	return card_database.get_card(card_id) if card_database != null else null
