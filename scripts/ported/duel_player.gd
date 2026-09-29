class_name PlayerDuelController
extends RefCounted
## Value-state port of the player duel cursor and selection flow from duel_player.c.
## Rules stay in the existing duel, summon, effect and battle systems; this
## controller translates player intent into typed operations for those systems.

enum Mode { FIELD, PLACE_CARD, SPELL_TARGET, ATTACK_TARGET }
enum InputCode { NONE, UP, DOWN, LEFT, RIGHT, CONFIRM, STATS, OPPONENT_HAND, CANCEL, END_PLAYER_TURN, END_OPPONENT_TURN }

const INPUT_ORDER := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "duel_stats", "duel_opponent_hand", "ui_cancel", "duel_end_player_turn", "duel_end_opponent_turn"]

var cursor := Vector2i.ZERO # x is column, y is recovered visible row 0..4.
var saved_cursor := Vector2i.ZERO
var mode: Mode = Mode.FIELD
var view_row := 0
var player_turn_done := false
var selected_hand_card_id := 0

func reset_turn() -> void:
	player_turn_done = false
	mode = Mode.FIELD
	view_row = cursor.y
	saved_cursor = cursor

## Direction repeats take priority, followed by confirm, shoulder buttons and cancel.
## A FrameInput instance supplies Godot action edges and repeat timing.
func read_input(input: FrameInput) -> int:
	if input == null:
		return InputCode.NONE
	for index in range(INPUT_ORDER.size()):
		var action := StringName(INPUT_ORDER[index])
		if index < 4:
			if input.was_repeated(action): return index + 1
		elif input.was_pressed(action):
			return index + 1
	return InputCode.NONE

func move_cursor(direction: Vector2i) -> Vector2i:
	view_row = cursor.y
	if direction.y < 0: cursor.y = maxi(cursor.y - 1, 0)
	elif direction.y > 0: cursor.y = mini(cursor.y + 1, 4)
	elif direction.x < 0: cursor.x = posmod(cursor.x - 1, 5)
	elif direction.x > 0: cursor.x = posmod(cursor.x + 1, 5)
	return cursor

func begin_card_placement(duel: SacredDuelState, acting_side: int, card_id: int, summon_rules: SummonRules, database: CardDatabase) -> Dictionary:
	if not _valid_side(duel, acting_side) or card_id <= 0 or summon_rules == null:
		return {"accepted": false}
	var kind := summon_rules.classify_card(card_id, database)
	var target_row := 2 if kind == 1 else 3 if kind > 1 and kind < 5 else -1
	if target_row < 0:
		return {"accepted": false, "reason": "unsupported_card_type"}
	var slots: Array[DuelCardSlot] = _row(duel.side(acting_side), target_row)
	var target_column := _first_empty(slots)
	if target_column < 0:
		return {"accepted": false, "reason": "row_full"}
	saved_cursor = cursor
	selected_hand_card_id = card_id
	mode = Mode.PLACE_CARD
	view_row = cursor.y
	cursor = Vector2i(target_column, target_row)
	return {"accepted": true, "card_id": card_id, "target_row": target_row, "target_column": target_column}

func begin_spell_target(card_id: int, target_class: int) -> Dictionary:
	if target_class == 0:
		return {"accepted": true, "mode": "immediate_spell", "card_id": card_id}
	if target_class == 2:
		return {"accepted": false, "reason": "unsupported_target_class"}
	saved_cursor = cursor
	selected_hand_card_id = card_id
	mode = Mode.SPELL_TARGET
	view_row = cursor.y
	cursor.y = 2
	cursor.x = 0
	return {"accepted": true, "mode": "target_monster", "card_id": card_id}

func begin_attack_target(duel: SacredDuelState, opposing_side: int) -> Dictionary:
	if not _valid_side(duel, opposing_side):
		return {"accepted": false}
	var monsters: Array[DuelCardSlot] = duel.side(opposing_side).monster_zones
	var target_column := _last_monster(monsters)
	saved_cursor = cursor
	mode = Mode.ATTACK_TARGET
	view_row = cursor.y
	cursor = Vector2i(target_column, 1)
	return {"accepted": true, "target_column": target_column}

func confirm_placement(duel: SacredDuelState, acting_side: int, summon_rules: SummonRules, database: CardDatabase) -> Dictionary:
	if mode != Mode.PLACE_CARD or not _valid_side(duel, acting_side):
		return {"accepted": false}
	var card_kind := summon_rules.classify_card(selected_hand_card_id, database)
	if (card_kind == 1 and cursor.y != 2) or (card_kind > 1 and card_kind < 5 and cursor.y != 3) or card_kind < 1 or card_kind >= 5:
		return {"accepted": false, "reason": "invalid_placement_row"}
	var required := summon_rules.remaining_monster_tributes(selected_hand_card_id, duel.tributes_committed, database) if card_kind == 1 else summon_rules.remaining_category_four_requirement(selected_hand_card_id, duel.tributes_committed, database)
	if required > 0:
		return {"accepted": false, "reason": "tributes_required", "remaining": required}
	var hand_index := saved_cursor.x
	var side := duel.side(acting_side)
	if hand_index < 0 or hand_index >= side.hand.size() or side.hand[hand_index] != selected_hand_card_id:
		return {"accepted": false, "reason": "hand_selection_changed"}
	var target_row: Array[DuelCardSlot] = _row(side, cursor.y)
	var destination := target_row[cursor.x]
	var placed_row := cursor.y
	var placed_column := cursor.x
	var card_id := side.hand[hand_index]
	var source_flags := side.hand_flags[hand_index] if hand_index < side.hand_flags.size() else 0
	side.remove_hand_at(hand_index)
	destination.card_id = card_id
	destination.controller = acting_side
	# CommitPlacement copies the saved native cell, retaining the destination's
	# high flag bits and copying the source cell's low flag bits.
	destination.persistent_flags = (destination.persistent_flags & 0xC0) | (source_flags & 0x3F)
	destination.stage = 0
	destination.zone_mode = 0
	destination.face_down = cursor.y == 3
	destination.defense_position = false
	destination.has_attacked = false
	if card_kind == 1:
		side.duel_flags |= 8
		for remaining_index in range(side.hand.size()):
			var remaining_card_id: int = side.hand[remaining_index]
			if remaining_card_id != 0 and summon_rules.classify_card(remaining_card_id, database) == 1:
				side.hand_flags[remaining_index] |= 1
		duel.tributes_committed = 0
	mode = Mode.FIELD
	saved_cursor = cursor
	selected_hand_card_id = 0
	return {"accepted": true, "action": "place", "card_id": card_id, "row": placed_row, "column": placed_column}

func validate_spell_target(duel: SacredDuelState, acting_side: int, target_class: int) -> Dictionary:
	if mode != Mode.SPELL_TARGET or not _valid_side(duel, acting_side):
		return {"accepted": false}
	if cursor.y != 2 or cursor.x < 0 or cursor.x >= 5:
		return {"accepted": false, "reason": "invalid_zone"}
	var target := duel.side(acting_side).monster_zones[cursor.x]
	if target.is_empty() or (target.persistent_flags & 1) != 0:
		return {"accepted": false, "reason": "invalid_target"}
	return {"accepted": true, "action": "resolve_spell", "card_id": selected_hand_card_id, "target_card_id": target.card_id, "source_row": saved_cursor.y, "source_column": saved_cursor.x, "target_row": cursor.y, "target_column": cursor.x, "target_class": target_class}

func finish_spell_target_action() -> void:
	mode = Mode.FIELD
	saved_cursor = cursor
	selected_hand_card_id = 0

func finish_attack_target_action() -> void:
	mode = Mode.FIELD
	cursor = saved_cursor
	selected_hand_card_id = 0

func cancel_selection() -> Dictionary:
	if mode == Mode.FIELD:
		return {"action": "open_context_menu"}
	var previous_row := cursor.y
	mode = Mode.FIELD
	cursor = saved_cursor
	selected_hand_card_id = 0
	return {"action": "cancel_selection", "previous_row": previous_row, "row": cursor.y}

func selected_card_id(duel: SacredDuelState, acting_side: int) -> int:
	if not _valid_side(duel, acting_side) or cursor.x < 0 or cursor.x >= 5:
		return 0
	if cursor.y == 2: return duel.side(acting_side).monster_zones[cursor.x].card_id
	if cursor.y == 3: return duel.side(acting_side).back_row_zones[cursor.x].card_id
	if cursor.y == 4:
		var hand := duel.side(acting_side).hand
		return int(hand[cursor.x]) if cursor.x < hand.size() else 0
	return 0

func direct_attack_available(duel: SacredDuelState, opposing_side: int) -> bool:
	if not _valid_side(duel, opposing_side): return false
	for slot: DuelCardSlot in duel.side(opposing_side).monster_zones:
		if not slot.is_empty(): return false
	return true

func _valid_side(duel: SacredDuelState, side_id: int) -> bool:
	return duel != null and side_id >= 0 and side_id < duel.sides.size()

func _row(side: DuelSideState, row_index: int) -> Array[DuelCardSlot]:
	return side.monster_zones if row_index == 2 else side.back_row_zones

func _first_empty(slots: Array[DuelCardSlot]) -> int:
	for index in range(slots.size()):
		if slots[index].is_empty(): return index
	return -1

func _last_monster(slots: Array[DuelCardSlot]) -> int:
	for index in range(slots.size() - 1, -1, -1):
		if not slots[index].is_empty(): return index
	return 4
