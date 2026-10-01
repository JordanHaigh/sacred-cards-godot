extends RefCounted
class_name MonsterEffectRules

## Typed port of the metadata-1B handlers in monster_effects.c. Relative rows
## are resolved from the active duelist instead of dereferencing the ROM grid.

const TABLE_PATH := "res://resources/monster_effect_tables.json"
const ACTIVE_MONSTERS := 2
const OPPONENT_MONSTERS := 1
const OPPONENT_BACK_ROW := 0
const LOCK_FLAG := 0x01
const USED_METADATA_INDICES := [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 59, 60, 61, 62, 63, 64, 65, 66, 67, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84]
const UNREFERENCED_HANDLERS := ["MonsterUnusedBlueEyesFusion", "MonsterUnusedGateGuardianFusion", "MonsterUnusedMixedFusion", "MonsterUnusedNoEffect"]

var card_database: CardDatabase
var stat_rules: CardStatRules
var battle_state: SacredBattleState
var _guardian_pairs: Array = []

func _init(database: CardDatabase = null, stats: CardStatRules = null) -> void:
	card_database = database
	stat_rules = stats if stats != null else CardStatRules.new()
	battle_state = SacredBattleState.new()
	_load_tables()

func supported_metadata_1b() -> Array[int]:
	var indices: Array[int] = []
	for index: int in USED_METADATA_INDICES:
		indices.append(index)
	return indices

func resolve(state: SacredDuelState, acting_side: int, handler_index: int, selected_column: int, presentation_suppressed: bool = false, random_service: SacredRandom = null) -> Dictionary:
	if state == null or acting_side < 0 or acting_side >= state.sides.size() or selected_column < 0 or selected_column >= 5:
		return {"resolved": false, "reason": "invalid_context"}
	if handler_index == 0:
		return {"resolved": true, "kind": "no_effect", "presentation": []}
	var selected := _row(state, acting_side, ACTIVE_MONSTERS)[selected_column]
	var result: Dictionary
	match handler_index:
		1: result = _reaper(state, acting_side, presentation_suppressed)
		3: result = _absorb(state, acting_side, selected, 731, 0, presentation_suppressed)
		4: result = _absorb(state, acting_side, selected, 734, 2, presentation_suppressed)
		5:
			var drawn := DuelDeck.draw_card(state.side(acting_side), state)
			result = _shown(540, 59, presentation_suppressed)
			result["drawn_card_id"] = drawn
		6: result = _boost_card(state, acting_side, 386, 1, 62, 386, 73, presentation_suppressed)
		7: result = _boost_card(state, acting_side, 386, 2, 63, 386, 73, presentation_suppressed)
		8: result = _time_wizard(state, acting_side, presentation_suppressed)
		9: result = _castle_of_dark_illusions(state, acting_side, presentation_suppressed)
		10: result = _raise_matching(state, acting_side, 2, [1, 887], 2, 1, 73, presentation_suppressed)
		11: result = _terrain_effect(state, 2, 39, true, presentation_suppressed)
		12: result = _discard_matching_type(state, acting_side, 11, 15, 76, false, presentation_suppressed)
		13: result = _terrain_effect(state, 0, 74, true, presentation_suppressed)
		14: result = _discard_matching_attribute(state, acting_side, 5, 26, 76, presentation_suppressed)
		15: result = _boost_card(state, acting_side, 375, 1, 376, 375, 73, presentation_suppressed)
		16: result = _pumpking(state, acting_side, presentation_suppressed)
		17: result = _lower_opponent_row(state, acting_side, 59, 59, 74, presentation_suppressed)
		18: result = _catapult_turtle(state, acting_side, selected_column, selected, presentation_suppressed)
		19:
			var drawn := DuelDeck.draw_card(state.side(acting_side), state)
			_discard_slot(state, acting_side, selected, ACTIVE_MONSTERS, true)
			result = _shown(429, 59, presentation_suppressed)
			result["drawn_card_id"] = drawn
		20: result = _terrain_effect(state, 3, 525, false, presentation_suppressed)
		21: result = _dragon_seeker(state, acting_side, presentation_suppressed)
		22: result = _trap_master(state, acting_side, presentation_suppressed)
		23: result = _fiends_hand(state, acting_side, selected, presentation_suppressed)
		24: result = _lock_rows(state, acting_side, [1], 42, 42, 80, presentation_suppressed)
		25: result = _lock_strongest_unlocked(state, acting_side, 610, 80, presentation_suppressed)
		26: result = _magician_girl(state, acting_side, selected, 760, presentation_suppressed)
		27: result = _wodan(state, acting_side, selected_column, presentation_suppressed)
		28: result = _boost_card(state, acting_side, 161, 1, 160, 161, 73, presentation_suppressed)
		29: result = _boost_card(state, acting_side, 160, 1, 161, 160, 73, presentation_suppressed)
		30: result = _red_archery_girl(state, acting_side, presentation_suppressed)
		31:
			_heal_self(state, acting_side, 500)
			result = _shown(612, 78, presentation_suppressed)
		32:
			_damage_opponent(state, acting_side, 50)
			result = _shown_pair(154, 154, 77, presentation_suppressed)
		33: result = _terrain_effect(state, 5, 73, true, presentation_suppressed)
		34: result = _raise_weak_monsters(state, acting_side, presentation_suppressed)
		35: result = _reveal_opponent_hand(state, acting_side, presentation_suppressed)
		36: result = _duplicate_selected(state, acting_side, selected, 195, 195, 58, presentation_suppressed)
		37: result = _boost_card(state, acting_side, 554, 1, 12, 554, 73, presentation_suppressed)
		38: result = _boost_card(state, acting_side, 12, 1, 554, 12, 73, presentation_suppressed)
		39: result = _terrain_effect(state, 1, 637, false, presentation_suppressed)
		40: result = _raise_for_card(state, acting_side, 366, selected, 370, 366, 73, presentation_suppressed)
		41: result = _summon_token(state, acting_side, 486, 117, 486, presentation_suppressed)
		42: result = _hourglass(state, acting_side, presentation_suppressed)
		43: result = _beastking(state, acting_side, presentation_suppressed)
		44: result = _lock_rows(state, acting_side, [1, 2], 129, 129, 80, presentation_suppressed)
		45: result = _summon_token(state, acting_side, 549, 140, 549, presentation_suppressed)
		46: result = _attribute_stages(state, acting_side, 1, 2, 492, 73, presentation_suppressed)
		47: result = _lock_rows(state, acting_side, [1], 740, 0, 80, presentation_suppressed)
		48: result = _attribute_stages(state, acting_side, 2, 1, 628, 73, presentation_suppressed)
		49: result = _direct_damage_from_selected(state, acting_side, selected, 387, presentation_suppressed)
		50: result = _direct_damage_from_selected(state, acting_side, selected, 397, presentation_suppressed)
		51: result = _insect_queen(state, acting_side, selected_column, presentation_suppressed)
		52: result = _obelisk(state, acting_side, presentation_suppressed)
		53: result = _slifer(state, acting_side, selected, presentation_suppressed)
		54: result = _ra(state, acting_side, presentation_suppressed)
		59: result = _boost_card(state, acting_side, 386, 1, 875, 386, 73, presentation_suppressed)
		60: result = _magician_girl(state, acting_side, selected, 872, presentation_suppressed)
		61: result = _magnet_fusion(state, acting_side, selected, 738, 757, 850, presentation_suppressed)
		62: result = _magnet_fusion(state, acting_side, selected, 757, 738, 850, presentation_suppressed)
		63: result = _magnet_fusion(state, acting_side, selected, 850, 738, 757, presentation_suppressed)
		64: result = _valkyrion(state, acting_side, selected, presentation_suppressed)
		65: result = _beast_of_gilfer(state, acting_side, selected, presentation_suppressed)
		66: result = _dark_necrofear(state, acting_side, selected, presentation_suppressed)
		67: result = _zombyra(state, acting_side, selected, presentation_suppressed)
		69: result = _gilford(state, acting_side, presentation_suppressed)
		70: result = _serket(state, acting_side, selected, presentation_suppressed)
		71: result = _jinzo(state, acting_side, presentation_suppressed)
		72: result = _buster_blader(state, acting_side, selected_column, presentation_suppressed)
		73: result = _barrel_dragon(state, acting_side, presentation_suppressed, random_service)
		74: result = _reflect_bounder(state, acting_side, selected_column, presentation_suppressed)
		75: result = _parasite_paracide(state, acting_side, selected, presentation_suppressed)
		76:
			_heal_self(state, acting_side, 500)
			_discard_slot(state, acting_side, selected, ACTIVE_MONSTERS, true)
			result = _shown(764, 78, presentation_suppressed)
		77: result = _pinch_hopper(state, acting_side, selected, presentation_suppressed)
		78: result = _rocket_warrior(state, acting_side, presentation_suppressed)
		79: result = _duplicate_selected(state, acting_side, selected, 810, 0, 58, presentation_suppressed)
		80: result = _boost_for_type(state, acting_side, 2, 1, selected_column, presentation_suppressed)
		81:
			_raise(selected)
			result = _shown(878, 73, presentation_suppressed)
		82: result = _summon_token(state, acting_side, 379, 861, 379, presentation_suppressed)
		83: result = _des_volstgalph(state, acting_side, presentation_suppressed)
		84: result = _exarion(state, acting_side, selected, presentation_suppressed)
		_: return {"resolved": false, "reason": "unsupported_monster_handler"}
	return result

func resolve_unreferenced(handler_name: String, state: SacredDuelState, acting_side: int, selected_column: int, presentation_suppressed: bool = false) -> Dictionary:
	if state == null or selected_column < 0 or selected_column >= 5:
		return {"resolved": false, "reason": "invalid_context"}
	var selected := _row(state, acting_side, ACTIVE_MONSTERS)[selected_column]
	match handler_name:
		"MonsterUnusedBlueEyesFusion":
			if _count(_row(state, acting_side, ACTIVE_MONSTERS), 1) > 2:
				selected.clear()
				_fusion_card(selected, 380)
				_clear_material(state, acting_side, 1)
				_clear_material(state, acting_side, 1)
			return _shown_pair(1, 380, 83, presentation_suppressed)
		"MonsterUnusedGateGuardianFusion":
			var previous := selected.card_id
			if _guardian_present(state, acting_side):
				var pair_index := 0 if previous == 371 else 1 if previous == 372 else 2
				selected.clear()
				_fusion_card(selected, 374)
				_clear_material(state, acting_side, int(_guardian_pairs[pair_index][0]))
				_clear_material(state, acting_side, int(_guardian_pairs[pair_index][1]))
			return _shown_pair(previous, 374, 83, presentation_suppressed)
		"MonsterUnusedMixedFusion":
			if _guardian_present(state, acting_side):
				selected.clear()
				_fusion_card(selected, 374)
				_clear_material(state, acting_side, 1)
				_clear_material(state, acting_side, 1)
			return _shown_pair(1, 380, 83, presentation_suppressed)
		"MonsterUnusedNoEffect":
			return {"resolved": true, "kind": "no_effect", "presentation": []}
	return {"resolved": false, "reason": "unknown_unreferenced_handler"}

func _reaper(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, OPPONENT_BACK_ROW)
	if _count(row, 0) < 5:
		for slot in row:
			var card := _card(slot.card_id)
			if card != null and card.metadata_1c != 0:
				_discard_slot(state, active, slot, OPPONENT_BACK_ROW, false)
				break
	return _shown_pair(84, 84, 89, suppressed)

func _absorb(state: SacredDuelState, active: int, selected: DuelCardSlot, effect_card: int, stages: int, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count_empty_or_immune(state, enemy) != 5:
		var source: DuelCardSlot = enemy[_strongest(state, active, OPPONENT_MONSTERS, 1)]
		_copy_slot(selected, source, active)
		_ready(selected)
		for _step in range(stages):
			_raise(selected)
		source.clear()
	return _shown(effect_card, 85, suppressed)

func _time_wizard(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, ACTIVE_MONSTERS):
		if slot.card_id == 4: slot.card_id = 69
		if slot.card_id == 35 or slot.card_id == 865: slot.card_id = 888
	return _shown_pair(16, 16, 90, suppressed)

func _castle_of_dark_illusions(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	state.terrain = 6
	for slot in _row(state, active, ACTIVE_MONSTERS):
		if not slot.is_empty(): slot.persistent_flags &= 0xEF
	for slot in _row(state, active, ACTIVE_MONSTERS):
		if slot.card_id == 83: slot.persistent_flags |= 0x10
	return {"resolved": true, "kind": "terrain", "terrain": 6, "presentation": [] if suppressed else ["load_terrain", 6, 83, 83, 79]}

func _terrain_effect(state: SacredDuelState, terrain: int, card_id: int, pair: bool, suppressed: bool) -> Dictionary:
	state.terrain = terrain
	return {"resolved": true, "kind": "terrain", "terrain": terrain, "presentation": [] if suppressed else ["load_terrain", terrain, card_id, card_id if pair else 0, 79]}

func _discard_matching_type(state: SacredDuelState, active: int, card_type: int, effect_card: int, sound: int, respect_immunity: bool, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, OPPONENT_MONSTERS):
		var card := _card(slot.card_id)
		if card != null and card.card_type == card_type and (not respect_immunity or not state.is_effect_immune(slot.card_id)):
			_discard_slot(state, active, slot, OPPONENT_MONSTERS, true)
	return _shown_pair(effect_card, effect_card, sound, suppressed)

func _discard_matching_attribute(state: SacredDuelState, active: int, attribute: int, effect_card: int, sound: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, OPPONENT_MONSTERS):
		var card := _card(slot.card_id)
		if card != null and card.attribute == attribute:
			_discard_slot(state, active, slot, OPPONENT_MONSTERS, true)
	return _shown_pair(effect_card, effect_card, sound, suppressed)

func _boost_card(state: SacredDuelState, active: int, card_to_boost: int, stages: int, effect_card: int, shown_target: int, sound: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, ACTIVE_MONSTERS):
		if slot.card_id == card_to_boost:
			for _step in range(stages): _raise(slot)
	return _shown_pair(effect_card, shown_target, sound, suppressed)

func _raise_matching(state: SacredDuelState, active: int, row_id: int, card_ids: Array[int], effect_card: int, shown_target: int, sound: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, row_id):
		if slot.card_id in card_ids: _raise(slot)
	return _shown_pair(effect_card, shown_target, sound, suppressed)

func _pumpking(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, ACTIVE_MONSTERS):
		if slot.card_id in [96, 97, 98]: _raise(slot)
	return _shown_pair(99, 99, 73, suppressed)

func _lower_opponent_row(state: SacredDuelState, active: int, effect_card: int, shown_target: int, sound: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, OPPONENT_MONSTERS):
		if not slot.is_empty(): _lower(slot)
	return _shown_pair(effect_card, shown_target, sound, suppressed)

func _catapult_turtle(state: SacredDuelState, active: int, selected_column: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var damage := 0
	for index in range(5):
		var slot: DuelCardSlot = _row(state, active, ACTIVE_MONSTERS)[index]
		if index != selected_column and not slot.is_empty() and (slot.persistent_flags & LOCK_FLAG) == 0:
			damage += _attack(slot, state.terrain)
			_discard_slot(state, active, slot, ACTIVE_MONSTERS, true)
	_damage_opponent(state, active, damage)
	return _shown_pair(89, 89, 69, suppressed)

func _dragon_seeker(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, OPPONENT_MONSTERS):
		var card := _card(slot.card_id)
		if card != null and not state.is_effect_immune(card.id) and card.card_type == 1:
			_discard_slot(state, active, slot, OPPONENT_MONSTERS, true)
	return _shown(500, 76, suppressed)

func _trap_master(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, 3)
	if _count(row, 0) > 0:
		var slot := row[_find_card(row, 0)]
		slot.card_id = 685
		slot.persistent_flags &= 0xC8
		slot.zone_mode = 0
		slot.stage = 0
	return _shown_pair(224, 685, 58, suppressed)

func _fiends_hand(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count_empty_or_immune(state, enemy) != 5:
		var enemy_slot: DuelCardSlot = enemy[_strongest(state, active, OPPONENT_MONSTERS, 1)]
		_discard_slot(state, active, enemy_slot, OPPONENT_MONSTERS, true)
	_discard_slot(state, active, selected, ACTIVE_MONSTERS, true)
	return _shown_pair(135, 135, 76, suppressed)

func _lock_rows(state: SacredDuelState, active: int, row_ids: Array[int], effect_card: int, shown_target: int, sound: int, suppressed: bool) -> Dictionary:
	for row_id in row_ids:
		for slot in _row(state, active, row_id):
			if not slot.is_empty(): slot.persistent_flags |= LOCK_FLAG
	return _shown_pair(effect_card, shown_target, sound, suppressed) if shown_target > 0 else _shown(effect_card, sound, suppressed)

func _lock_strongest_unlocked(state: SacredDuelState, active: int, effect_card: int, sound: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, OPPONENT_MONSTERS)
	if _unlocked_count(row) > 0:
		row[_strongest(state, active, OPPONENT_MONSTERS, 2)].persistent_flags |= LOCK_FLAG
	return _shown(effect_card, sound, suppressed)

func _magician_girl(state: SacredDuelState, active: int, selected: DuelCardSlot, effect_card: int, suppressed: bool) -> Dictionary:
	var opponent := 1 - active
	if state.relative_graveyard_ids[active] in [35, 865]: _raise(selected)
	if state.relative_graveyard_ids[opponent] in [35, 865]: _raise(selected)
	return _shown_pair(effect_card, 35, 73, suppressed)

func _wodan(state: SacredDuelState, active: int, selected_column: int, suppressed: bool) -> Dictionary:
	var count := 0
	for slot in _row(state, active, ACTIVE_MONSTERS):
		var card := _card(slot.card_id)
		if card != null and card.card_type == 20:
			count += 1
	for _step in range(count): _raise(_row(state, active, ACTIVE_MONSTERS)[selected_column])
	return _shown_pair(235, 235, 73, suppressed)

func _red_archery_girl(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, OPPONENT_MONSTERS)
	if _unlocked_count(row) > 0:
		var slot: DuelCardSlot = row[_strongest(state, active, OPPONENT_MONSTERS, 2)]
		slot.persistent_flags |= LOCK_FLAG
		_lower(slot)
	return _shown(725, 74, suppressed)

func _raise_weak_monsters(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, ACTIVE_MONSTERS):
		if not slot.is_empty() and _attack(slot, state.terrain) <= 500: _raise(slot)
	return _shown_pair(90, 90, 73, suppressed)

func _reveal_opponent_hand(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	state.side(1 - active).hand_revealed = true
	return _shown(402, 60, suppressed)

func _duplicate_selected(state: SacredDuelState, active: int, selected: DuelCardSlot, effect_card: int, shown_target: int, sound: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, ACTIVE_MONSTERS)
	if _count(row, 0) > 0:
		var destination := row[_find_card(row, 0)]
		_copy_slot(destination, selected, active)
	if shown_target == 0:
		return _shown(effect_card, sound, suppressed)
	return _shown_pair(effect_card, shown_target, sound, suppressed)

func _raise_for_card(state: SacredDuelState, active: int, card_id: int, selected: DuelCardSlot, effect_card: int, shown_target: int, sound: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, ACTIVE_MONSTERS):
		if slot.card_id == card_id: _raise(selected)
	return _shown_pair(effect_card, shown_target, sound, suppressed)

func _summon_token(state: SacredDuelState, active: int, token_id: int, effect_card: int, shown_target: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, ACTIVE_MONSTERS)
	if _count(row, 0) > 0:
		var token := row[_find_card(row, 0)]
		token.card_id = token_id
		token.controller = active
		_ready(token)
		token.stage = 0
	return _shown_pair(effect_card, shown_target, 58, suppressed)

func _hourglass(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, ACTIVE_MONSTERS):
		if not slot.is_empty(): _raise(slot)
	_apply_life_operation(state, active, 1000, true)
	return _shown_pair(229, 229, 73, suppressed)

func _beastking(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	for row_id in [OPPONENT_MONSTERS, ACTIVE_MONSTERS]:
		for slot in _row(state, active, row_id):
			if not state.is_effect_immune(slot.card_id):
				_discard_slot(state, active, slot, row_id, not slot.is_empty())
	return _shown(258, 75, suppressed)

func _attribute_stages(state: SacredDuelState, active: int, lower_attribute: int, raise_attribute: int, effect_card: int, sound: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, ACTIVE_MONSTERS):
		var card := _card(slot.card_id)
		if card == null: continue
		if card.attribute == lower_attribute: _lower(slot)
		if card.attribute == raise_attribute: _raise(slot)
	return _shown(effect_card, sound, suppressed)

func _direct_damage_from_selected(state: SacredDuelState, active: int, selected: DuelCardSlot, effect_card: int, suppressed: bool) -> Dictionary:
	_damage_opponent(state, active, _attack(selected, state.terrain))
	return _shown(effect_card, 69, suppressed)

func _insect_queen(state: SacredDuelState, active: int, selected_column: int, suppressed: bool) -> Dictionary:
	var boosts := 0
	for row_id in [ACTIVE_MONSTERS, OPPONENT_MONSTERS]:
		for slot in _row(state, active, row_id):
			var card := _card(slot.card_id)
			if card != null and card.card_type == 10: boosts += 1
	for _step in range(boosts): _raise(_row(state, active, ACTIVE_MONSTERS)[selected_column])
	return _shown(762, 73, suppressed)

func _obelisk(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, OPPONENT_MONSTERS):
		_discard_slot(state, active, slot, OPPONENT_MONSTERS, not slot.is_empty())
	_damage_opponent(state, active, 4000)
	return _shown(832, 86, suppressed)

func _slifer(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var hand_size := state.side(1 - active).hand_count()
	for _card in range(hand_size):
		for _stage in range(3): _raise(selected)
	return _shown(833, 87, suppressed)

func _ra(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	var acting := state.side(active)
	var damage := (acting.life_points - 1) & 0xFFFF
	_damage_opponent(state, active, damage)
	acting.life_points = 1
	return _shown(834, 88, suppressed)

func _magnet_fusion(state: SacredDuelState, active: int, selected: DuelCardSlot, effect_card: int, first: int, second: int, suppressed: bool) -> Dictionary:
	var row := _row(state, active, ACTIVE_MONSTERS)
	if _count(row, first) > 0 and _count(row, second) > 0:
		_fusion_card(selected, 883)
		_clear_material(state, active, first)
		_clear_material(state, active, second)
	return _shown_pair(effect_card, 883, 83, suppressed)

func _valkyrion(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var row := _row(state, active, ACTIVE_MONSTERS)
	if _count(row, 0) > 1:
		_fusion_card(selected, 738)
		_fusion_card(row[_find_card(row, 0)], 757)
		_fusion_card(row[_find_card(row, 0)], 850)
	return _shown(883, 83, suppressed)

func _beast_of_gilfer(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count(enemy, 0) < 5:
		for slot in enemy:
			if not slot.is_empty(): _lower(slot)
	_discard_slot(state, active, selected, ACTIVE_MONSTERS, true)
	return _shown(778, 74, suppressed)

func _dark_necrofear(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count_empty_or_immune(state, enemy) != 5 and _count(enemy, 0) != 5:
		var source: DuelCardSlot = enemy[_strongest(state, active, OPPONENT_MONSTERS, 1)]
		var own := _row(state, active, ACTIVE_MONSTERS)
		var destination_index := _find_card(own, 0)
		if destination_index < 0: destination_index = 0
		var destination: DuelCardSlot = own[destination_index]
		_copy_slot(destination, source, active)
		_ready(destination)
		source.clear()
	return _shown(812, 85, suppressed)

func _zombyra(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count_empty_or_immune(state, enemy) != 5:
		_discard_slot(state, active, enemy[_strongest(state, active, OPPONENT_MONSTERS, 1)], OPPONENT_MONSTERS, true)
		_lower(selected)
	return _shown(858, 75, suppressed)

func _gilford(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	for slot in _row(state, active, OPPONENT_MONSTERS):
		if not state.is_effect_immune(slot.card_id): _discard_slot(state, active, slot, OPPONENT_MONSTERS, not slot.is_empty())
	return _shown(873, 75, suppressed)

func _serket(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count_empty_or_immune(state, enemy) != 5:
		enemy[_strongest(state, active, OPPONENT_MONSTERS, 1)].clear()
		_raise(selected)
	return _shown(874, 73, suppressed)

func _jinzo(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	var back_row := _row(state, active, OPPONENT_BACK_ROW)
	if _count(back_row, 0) != 5:
		for slot in back_row:
			var card := _card(slot.card_id)
			if card != null and card.metadata_1c != 0:
				_discard_slot(state, active, slot, OPPONENT_BACK_ROW, false)
	return _shown(752, 89, suppressed)

func _buster_blader(state: SacredDuelState, active: int, selected_column: int, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count(enemy, 0) != 5:
		_boost_for_type(state, active, OPPONENT_MONSTERS, 1, selected_column)
	return _shown(811, 73, suppressed)

func _boost_for_type(state: SacredDuelState, active: int, row_id: int, card_type: int, selected_column: int, _suppressed: bool = false) -> Dictionary:
	var selected := _row(state, active, ACTIVE_MONSTERS)[selected_column]
	for slot in _row(state, active, row_id):
		var card := _card(slot.card_id)
		if card != null and card.card_type == card_type: _raise(selected)
	return {"resolved": true, "kind": "type_boost", "presentation": []}

func _barrel_dragon(state: SacredDuelState, active: int, suppressed: bool, random_service: SacredRandom) -> Dictionary:
	if random_service == null:
		return {"resolved": false, "reason": "random_service_missing"}
	var destroyed: Array[int] = []
	for _shot in range(3):
		var enemy := _row(state, active, OPPONENT_MONSTERS)
		if _count_empty_or_immune(state, enemy) == 5: break
		if random_service.byte_inclusive(0, 1) == 1:
			var target: DuelCardSlot = enemy[_strongest(state, active, OPPONENT_MONSTERS, 1)]
			destroyed.append(target.card_id)
			_discard_slot(state, active, target, OPPONENT_MONSTERS, true)
	var shown := _shown(743, 76, suppressed)
	shown["destroyed_card_ids"] = destroyed
	return shown

func _reflect_bounder(state: SacredDuelState, active: int, selected_column: int, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count(enemy, 0) != 5:
		_damage_opponent(state, active, _attack(enemy[_strongest(state, active, OPPONENT_MONSTERS, 0)], state.terrain))
	var selected := _row(state, active, ACTIVE_MONSTERS)[selected_column]
	_discard_slot(state, active, selected, ACTIVE_MONSTERS, true)
	return _shown(756, 69, suppressed)

func _parasite_paracide(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count_empty_or_immune(state, enemy) != 5:
		var target: DuelCardSlot = enemy[_strongest(state, active, OPPONENT_MONSTERS, 1)]
		_copy_slot(target, selected, 1 - active)
		_ready(target)
		selected.clear()
	return _shown(763, 74, suppressed)

func _pinch_hopper(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	_discard_slot(state, active, selected, ACTIVE_MONSTERS, true)
	var opponent := state.side(1 - active)
	var candidates: Array[int] = []
	for index in range(opponent.hand.size()):
		if opponent.hand[index] == 0: continue
		var card := _card(opponent.hand[index])
		if card != null and card.card_type == 10: candidates.append(index)
	if not candidates.is_empty():
		var best_attack := -1
		var best_index := candidates[0]
		for hand_index in candidates:
			var hand_card_id: int = opponent.hand[hand_index]
			var card := _card(hand_card_id)
			var attack := 0 if card == null else int(stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, state.terrain, 0).attack)
			if attack >= best_attack:
				best_attack = attack
				best_index = hand_index
		var card_id: int = opponent.hand[best_index]
		var hand_flags := opponent.hand_flags[best_index] if best_index < opponent.hand_flags.size() else 0
		opponent.remove_hand_at(best_index)
		selected.card_id = card_id
		selected.controller = active
		selected.persistent_flags = (selected.persistent_flags & 0xC0) | (hand_flags & 0x3F)
		selected.stage = 0
		selected.zone_mode = 0
		_ready(selected)
	return _shown(766, 58, suppressed)

func _rocket_warrior(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count(enemy, 0) < 5:
		_lower(enemy[_strongest(state, active, OPPONENT_MONSTERS, 0)])
	return _shown(838, 74, suppressed)

func _des_volstgalph(state: SacredDuelState, active: int, suppressed: bool) -> Dictionary:
	var enemy := _row(state, active, OPPONENT_MONSTERS)
	if _count_empty_or_immune(state, enemy) < 5:
		_discard_slot(state, active, enemy[_strongest(state, active, OPPONENT_MONSTERS, 1)], OPPONENT_MONSTERS, true)
	_damage_opponent(state, active, 500)
	return _shown(871, 76, suppressed)

func _exarion(state: SacredDuelState, active: int, selected: DuelCardSlot, suppressed: bool) -> Dictionary:
	_damage_opponent(state, active, _attack(selected, state.terrain))
	_lower(selected)
	return _shown(877, 69, suppressed)

func _guardian_present(state: SacredDuelState, active: int) -> bool:
	var row := _row(state, active, ACTIVE_MONSTERS)
	return _count(row, 371) > 0 and _count(row, 372) > 0 and _count(row, 373) > 0

func _clear_material(state: SacredDuelState, active: int, card_id: int) -> void:
	var row := _row(state, active, ACTIVE_MONSTERS)
	var index := _find_card(row, card_id)
	if index >= 0: row[index].clear()

func _count(row: Array[DuelCardSlot], card_id: int) -> int:
	var result := 0
	for slot in row:
		if slot.card_id == card_id: result += 1
	return result

func _count_empty_or_immune(state: SacredDuelState, row: Array[DuelCardSlot]) -> int:
	var result := 0
	for slot in row:
		if slot.is_empty() or state.is_effect_immune(slot.card_id): result += 1
	return result

func _unlocked_count(row: Array[DuelCardSlot]) -> int:
	var result := 0
	for slot in row:
		if not slot.is_empty() and (slot.persistent_flags & LOCK_FLAG) == 0: result += 1
	return result

func _strongest(state: SacredDuelState, active: int, row_id: int, filter: int, card_type: int = 0) -> int:
	var best := 0
	var selected := 0
	for index in range(5):
		var slot: DuelCardSlot = _row(state, active, row_id)[index]
		if slot.is_empty(): continue
		if filter == 1 and state.is_effect_immune(slot.card_id): continue
		if filter == 2 and (slot.persistent_flags & LOCK_FLAG) != 0: continue
		var attack := _attack(slot, state.terrain)
		var definition := _card(slot.card_id)
		if filter == 3 and (definition == null or definition.card_type != card_type): continue
		if attack >= best:
			best = attack
			selected = index
	return selected

func _attack(slot: DuelCardSlot, terrain: int) -> int:
	var card := _card(slot.card_id)
	if card == null: return 0
	var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, terrain, slot.stage)
	return int(stats.attack)

func _damage_opponent(state: SacredDuelState, active: int, amount: int) -> void:
	_apply_life_operation(state, 1 - active, amount, true)

func _heal_self(state: SacredDuelState, active: int, amount: int) -> void:
	_apply_life_operation(state, active, amount, false)

func _apply_life_operation(state: SacredDuelState, affected_side: int, amount: int, damage: bool) -> void:
	var side_a := {"owner": 0, "attack": amount if affected_side == 0 else 0}
	var side_b := {"owner": 1, "attack": amount if affected_side == 1 else 0}
	if affected_side == 0:
		if damage: battle_state.prepare_damage_side_a(amount)
		else: battle_state.prepare_heal_side_a(amount)
	else:
		if damage: battle_state.prepare_damage_side_b(amount)
		else: battle_state.prepare_heal_side_b(amount)
	battle_state.resolve(state, side_a, side_b)
	if (battle_state.last_result_flags & 4) != 0: state.auxiliary_flags[0] = 2
	if (battle_state.last_result_flags & 16) != 0: state.auxiliary_flags[1] = 2

func _discard_slot(state: SacredDuelState, active: int, slot: DuelCardSlot, row_id: int, is_monster: bool) -> void:
	var owner := active if row_id >= 2 else 1 - active
	var zone_row := 2 if row_id in [1, 2] else 3
	var side := state.side(owner)
	var slots: Array[DuelCardSlot] = side.monster_zones if zone_row == 2 else side.back_row_zones
	for index in range(slots.size()):
		if slots[index] == slot:
			state.discard_slot(owner, zone_row, index, is_monster)
			return

func _row(state: SacredDuelState, active: int, row_id: int) -> Array[DuelCardSlot]:
	return state.relative_board_row(active, row_id)

func _find_card(row: Array[DuelCardSlot], card_id: int) -> int:
	for index in range(row.size()):
		if row[index].card_id == card_id: return index
	return -1

func _copy_slot(destination: DuelCardSlot, source: DuelCardSlot, controller: int) -> void:
	var destination_flags := destination.persistent_flags
	destination.card_id = source.card_id
	destination.controller = controller
	destination.face_down = source.face_down
	destination.defense_position = source.defense_position
	destination.has_attacked = source.has_attacked
	destination.stage = source.stage
	destination.zone_mode = source.zone_mode
	destination.persistent_flags = (destination_flags & 0xC0) | (source.persistent_flags & 0x3F)

func _ready(slot: DuelCardSlot) -> void:
	slot.persistent_flags = (slot.persistent_flags | 0x10) & 0xD8
	slot.zone_mode = 0
	slot.face_down = false
	slot.defense_position = false
	slot.has_attacked = false

func _fusion_card(slot: DuelCardSlot, card_id: int) -> void:
	slot.card_id = card_id
	slot.persistent_flags = ((slot.persistent_flags | 0x11) & 0xF9) & 0xDF
	slot.stage = 0
	slot.face_down = false
	slot.defense_position = false
	slot.has_attacked = false

func _raise(slot: DuelCardSlot) -> void:
	slot.stage = mini(127, slot.stage + 1)

func _lower(slot: DuelCardSlot) -> void:
	slot.stage = maxi(-128, slot.stage - 1)

func _card(card_id: int) -> CardDefinition:
	return card_database.get_card(card_id) if card_database != null and card_id > 0 else null

func _shown(card_id: int, sound: int, suppressed: bool) -> Dictionary:
	return {"resolved": true, "presentation": [] if suppressed else [card_id, sound]}

func _shown_pair(card_id: int, target_id: int, sound: int, suppressed: bool) -> Dictionary:
	return {"resolved": true, "presentation": [] if suppressed else [card_id, target_id, sound]}

func _load_tables() -> void:
	if not FileAccess.file_exists(TABLE_PATH):
		push_error("Missing recovered monster effect tables: %s" % TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if parsed is Dictionary:
		_guardian_pairs = parsed.get("gate_guardian_material_pairs", [])
