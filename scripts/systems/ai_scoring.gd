extends RefCounted
class_name AiScoring

## Typed port of ai_scoring.c's 25 top-level before/after callbacks.
## Effect-specific score tables are explicit injected callables, never ROM addresses.

const LOW_PRIORITY := 0x7EE0ACE9
const U32_MASK := 0xFFFFFFFF
const EXODIA_IDS := [17, 18, 19, 20, 21]
const DESTINY_IDS := [583, 584, 585, 586, 587]

var card_database: CardDatabase
var stat_rules: CardStatRules
var summon_rules: SummonRules
var before_spell_score: Callable
var after_spell_score: Callable
var before_monster_score: Callable
var after_monster_score: Callable

func _init(database: CardDatabase = null, stats: CardStatRules = null, summons: SummonRules = null) -> void:
	card_database = database
	stat_rules = stats if stats != null else CardStatRules.new()
	summon_rules = summons if summons != null else SummonRules.new()

func set_effect_score_handlers(spell_before: Callable, spell_after: Callable, monster_before: Callable, monster_after: Callable) -> void:
	before_spell_score = spell_before
	after_spell_score = spell_after
	before_monster_score = monster_before
	after_monster_score = monster_after

## Evaluates the native before-score callback for one candidate. The supplied
## candidate is a record from AiCandidateDatabase; its operands are packed rows.
func score_before(state: SacredDuelState, acting_side: int, candidate: Dictionary) -> Dictionary:
	if state == null or card_database == null or acting_side < 0 or acting_side > 1 or candidate.is_empty():
		return {"resolved": false, "reason": "invalid_context"}
	var kind := int(candidate.get("kind", -1))
	var operands: Array[int] = _operands(candidate)
	if kind < 0 or kind >= 25 or operands.size() < 1:
		return {"resolved": false, "reason": "invalid_candidate"}
	for packed_operand in operands:
		if _slot(state, acting_side, packed_operand) == null:
			return {"resolved": false, "reason": "invalid_operand"}
	var source := _slot(state, acting_side, operands[0])
	if source == null: return {"resolved": false, "reason": "invalid_operand"}
	var score: int = LOW_PRIORITY
	var card := _card(source.card_id)
	match kind:
		0: score = 0x7EE0ACEA
		1: score = _score_discard(state, acting_side, source)
		2: score = _score_summon_zero(state, acting_side, source, _slot(state, acting_side, operands[1]))
		3: score = _score_summon(state, acting_side, source, operands, 1, 0x7F5DA546)
		4: score = _score_summon(state, acting_side, source, operands, 2, 0x7F7DB066)
		5: score = 0x7EE0ACEC
		6: score = _score_position(state, acting_side, source)
		7, 9: score = _score_direct_attack(state, acting_side, source)
		8, 10: score = _score_attack_target(state, acting_side, _slot(state, acting_side, operands[1]))
		11: score = _score_summon(state, acting_side, source, operands, 3, 0x7F7DB066)
		12, 13:
			var attack := _attack(source, state.terrain)
			score = _u32(attack + 0x7EED7E40) if attack > 0 else LOW_PRIORITY
		14: score = 0x7EEB5B54 if _slot(state, acting_side, operands[1]).is_empty() else LOW_PRIORITY
		15: score = 0x7FFFFFFC if _slot(state, acting_side, operands[1]).is_empty() else LOW_PRIORITY
		16, 17, 19, 20, 22:
			if before_spell_score.is_valid(): return _invoke_effect_score(before_spell_score, state, acting_side, candidate, 0)
			return {"resolved": false, "reason": "spell_score_table_missing", "metadata_index": card.metadata_1a if card != null else -1}
		18: score = 0x7FFFFFFB if _slot(state, acting_side, operands[1]).is_empty() else LOW_PRIORITY
		21: score = 0x7FFFFFFA if _slot(state, acting_side, operands[1]).is_empty() else LOW_PRIORITY
		23:
			if before_monster_score.is_valid(): return _invoke_effect_score(before_monster_score, state, acting_side, candidate, 1)
			return {"resolved": false, "reason": "monster_score_table_missing", "metadata_index": card.metadata_1b if card != null else -1}
		24: score = _score_special_piece(state, acting_side, source, _slot(state, acting_side, operands[1]))
	return {"resolved": true, "score": score, "candidate_id": int(candidate.get("id", -1)), "phase": "before"}

## Applies post-simulation scoring. Pass the state produced by the action model.
func score_after(simulated_state: SacredDuelState, acting_side: int, candidate: Dictionary, current_score: int) -> Dictionary:
	if simulated_state == null or acting_side < 0 or acting_side > 1 or candidate.is_empty():
		return {"resolved": false, "reason": "invalid_context"}
	var kind := int(candidate.get("kind", -1))
	var operands: Array[int] = _operands(candidate)
	if kind < 0 or kind >= 25:
		return {"resolved": false, "reason": "invalid_candidate"}
	for packed_operand in operands:
		if _slot(simulated_state, acting_side, packed_operand) == null:
			return {"resolved": false, "reason": "invalid_operand"}
	var score := current_score & U32_MASK
	match kind:
		2, 3, 4, 11:
			if score != LOW_PRIORITY: score = _u32(score + _monster_stat_sum(simulated_state, acting_side, 2))
		7, 9:
			if simulated_state.has_ended(): score = 0 if simulated_state.auxiliary_flags[acting_side] == 2 else 0x7FFFFFFF
		8, 10:
			if simulated_state.has_ended():
				score = 0 if simulated_state.auxiliary_flags[acting_side] == 2 else 0x7FFFFFFF
			elif operands.size() >= 2:
				var target := _slot(simulated_state, acting_side, operands[1])
				var attacker := _slot(simulated_state, acting_side, operands[0])
				if target != null and target.is_empty():
					if attacker != null and not attacker.is_empty(): score = _u32(score - _attack(attacker, simulated_state.terrain) + 0x7EF0A11E)
				elif attacker == null or attacker.is_empty():
					var own_count := _occupied(_row(simulated_state, acting_side, 2))
					var enemy_count := _occupied(_row(simulated_state, acting_side, 1))
					if own_count > enemy_count: score = _u32(score + 0x7EEE8FB0)
					else: score = LOW_PRIORITY
				else: score = LOW_PRIORITY
		23:
			if after_monster_score.is_valid(): return _invoke_effect_score(after_monster_score, simulated_state, acting_side, candidate, 1, score)
			return {"resolved": false, "reason": "monster_score_table_missing", "metadata_index": _card(_operand_card_id(simulated_state, acting_side, operands[0])).metadata_1b if _card(_operand_card_id(simulated_state, acting_side, operands[0])) != null else -1}
		16, 17, 19, 20, 22:
			if after_spell_score.is_valid(): return _invoke_effect_score(after_spell_score, simulated_state, acting_side, candidate, 0, score)
			return {"resolved": false, "reason": "spell_score_table_missing"}
		24:
			var mask := 0
			for slot in _row(simulated_state, acting_side, 3):
				var piece_index := DESTINY_IDS.find(slot.card_id)
				if piece_index >= 0: mask |= 1 << piece_index
			if mask == 31: score = 0x7FFFFFFF
	return {"resolved": true, "score": score, "candidate_id": int(candidate.get("id", -1)), "phase": "after"}

## Native selection compares unsigned scores strictly, preserving first ties.
func best_candidate(scored_candidates: Array[Dictionary]) -> Dictionary:
	var best_score := 0
	var best: Dictionary = {}
	for entry in scored_candidates:
		var score := int(entry.get("score", 0)) & U32_MASK
		if score > best_score:
			best_score = score
			best = entry.duplicate(true)
	return {} if int(best.get("id", 0)) == 0 else best

func _score_discard(state: SacredDuelState, active: int, slot: DuelCardSlot) -> int:
	var card := _card(slot.card_id)
	if card == null: return LOW_PRIORITY
	if card.metadata_1a != 2: return 0x7EE4F2AF
	match _remaining_tributes(slot.card_id, state):
		0:
			var same_count := 0
			for hand_card in state.side(active).hand:
				if hand_card == slot.card_id: same_count += 1
			var base := 0x7EE2CFCF if slot.card_id not in EXODIA_IDS or same_count > 1 else 0x7EE0ACEE
			return _u32(base - _attack(slot, state.terrain) + 0x1FFFC - _defense(slot, state.terrain))
		1: return 0x7EE4F2B4
		2: return 0x7EE71594
		3: return 0x7EE0ACEF if slot.card_id >= 832 and slot.card_id <= 834 else 0x7EE93874
		_: return LOW_PRIORITY

func _score_summon_zero(state: SacredDuelState, active: int, card_slot: DuelCardSlot, destination: DuelCardSlot) -> int:
	if not _unlocked_monster(card_slot) or _remaining_tributes(card_slot.card_id, state) != 0: return LOW_PRIORITY
	var duplicate_exodia := card_slot.card_id not in EXODIA_IDS
	if not duplicate_exodia:
		var matches := 0
		for hand_card in state.side(active).hand:
			if hand_card == card_slot.card_id: matches += 1
		duplicate_exodia = matches > 1
	return _summon_destination_score(card_slot, destination, 0x7F3D9A26 if duplicate_exodia else 0x7F1D8F06, 0x7F32EBC6 if duplicate_exodia else 0x7F12E0A6, state.terrain)

func _summon(state: SacredDuelState, active: int, card_slot: DuelCardSlot, operands: Array[int], count: int, priority: int) -> int:
	if not _unlocked_monster(card_slot) or _remaining_tributes(card_slot.card_id, state) != count: return LOW_PRIORITY
	var card_attack := _attack(card_slot, state.terrain)
	for index in range(1, count + 1):
		if index >= operands.size(): return LOW_PRIORITY
		var tribute := _slot(state, active, operands[index])
		if tribute == null or (index <= 2 and not _unlocked_monster(tribute)) or _attack(tribute, state.terrain) >= card_attack: return LOW_PRIORITY
	return priority

func _score_summon(state: SacredDuelState, active: int, card_slot: DuelCardSlot, operands: Array[int], count: int, priority: int) -> int:
	return _summon(state, active, card_slot, operands, count, priority)

func _summon_destination_score(card_slot: DuelCardSlot, destination: DuelCardSlot, empty_score: int, upgrade_score: int, terrain: int) -> int:
	if destination == null or destination.is_empty(): return empty_score
	if (destination.persistent_flags & 1) != 0: return LOW_PRIORITY
	if not _monster(destination): return empty_score
	return upgrade_score if _attack(destination, terrain) < _attack(card_slot, terrain) else LOW_PRIORITY

func _score_position(state: SacredDuelState, active: int, slot: DuelCardSlot) -> int:
	var attack := _attack(slot, state.terrain)
	var defense := _defense(slot, state.terrain)
	if attack <= 0: return 0x7EE0ACEB
	var enemy_row := _row(state, active, 1)
	if _occupied(enemy_row) == 0: return 0x7EE0ACEB if attack <= defense else 0x7EE0ACED
	for enemy in enemy_row:
		if enemy.is_empty(): continue
		if (enemy.persistent_flags & 0x10) == 0: return 0x7EE0ACEB
		var enemy_attack := _attack(enemy, state.terrain)
		if attack <= enemy_attack or enemy_attack <= defense: return 0x7EE0ACEB
	return 0x7EE0ACED

func _score_direct_attack(state: SacredDuelState, active: int, slot: DuelCardSlot) -> int:
	var attack := _attack(slot, state.terrain)
	return _u32(attack + 0x7EF1C400) if attack > 0 else LOW_PRIORITY

func _score_attack_target(state: SacredDuelState, active: int, target: DuelCardSlot) -> int:
	return _attack(target, state.terrain) + _defense(target, state.terrain) if target != null else LOW_PRIORITY

func _score_special_piece(state: SacredDuelState, active: int, piece: DuelCardSlot, destination: DuelCardSlot) -> int:
	for slot in _row(state, active, 3):
		if slot.card_id == piece.card_id: return LOW_PRIORITY
	if destination == null or destination.is_empty(): return 0x7EEB5B56
	return LOW_PRIORITY if destination.card_id in DESTINY_IDS else 0x7EEB5B55

func _invoke_effect_score(handler: Callable, state: SacredDuelState, active: int, candidate: Dictionary, metadata_field: int, score: int = 0) -> Dictionary:
	var operands: Array[int] = _operands(candidate)
	var slot := _slot(state, active, operands[0]) if not operands.is_empty() else null
	var card := _card(slot.card_id) if slot != null else null
	return handler.call(state, active, candidate, card, score)

func _operands(candidate: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for packed: Variant in candidate.get("operands", []): result.append(int(packed))
	return result

func _slot(state: SacredDuelState, active: int, packed: int) -> DuelCardSlot:
	var row_id := (packed >> 4) & 15
	var column := packed & 15
	if column >= 5: return null
	if row_id == 4:
		var hand_slot := DuelCardSlot.new()
		if column < state.side(active).hand.size():
			hand_slot.card_id = state.side(active).hand[column]
			if column < state.side(active).hand_flags.size(): hand_slot.persistent_flags = state.side(active).hand_flags[column]
		return hand_slot
	return _row(state, active, row_id)[column] if row_id in [0, 1, 2, 3] else null

func _operand_card_id(state: SacredDuelState, active: int, packed: int) -> int:
	var slot := _slot(state, active, packed)
	return slot.card_id if slot != null else 0

func _row(state: SacredDuelState, active: int, row_id: int) -> Array[DuelCardSlot]:
	var owner := active if row_id >= 2 else 1 - active
	var side := state.side(owner)
	if row_id in [1, 2]: return side.monster_zones
	if row_id in [0, 3]: return side.back_row_zones
	return []

func _monster(slot: DuelCardSlot) -> bool:
	return slot != null and not slot.is_empty() and summon_rules.classify_card(slot.card_id, card_database) == 1

func _unlocked_monster(slot: DuelCardSlot) -> bool:
	return _monster(slot) and (slot.persistent_flags & 1) == 0

func _remaining_tributes(card_id: int, state: SacredDuelState) -> int:
	return summon_rules.remaining_monster_tributes(card_id, state.tributes_committed, card_database)

func _monster_stat_sum(state: SacredDuelState, active: int, row_id: int) -> int:
	var total := 0
	for slot in _row(state, active, row_id):
		if _monster(slot): total = _u32(total + _attack(slot, state.terrain) + _defense(slot, state.terrain))
	return total

func _occupied(row: Array[DuelCardSlot]) -> int:
	var total := 0
	for slot in row:
		if not slot.is_empty(): total += 1
	return total

func _attack(slot: DuelCardSlot, terrain: int) -> int:
	return _stat(slot, terrain, true)

func _defense(slot: DuelCardSlot, terrain: int) -> int:
	return _stat(slot, terrain, false)

func _stat(slot: DuelCardSlot, terrain: int, want_attack: bool) -> int:
	if slot == null: return 0
	var card := _card(slot.card_id)
	if card == null: return 0
	var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, terrain, slot.stage)
	return int(stats.attack if want_attack else stats.defense)

func _card(card_id: int) -> CardDefinition:
	return card_database.get_card(card_id) if card_database != null else null

func _u32(value: int) -> int:
	return value & U32_MASK
