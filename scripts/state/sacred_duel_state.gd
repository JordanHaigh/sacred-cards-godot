extends RefCounted
class_name SacredDuelState

enum Phase { DRAW, MAIN, BATTLE, END }
enum Status { ACTIVE, PLAYER_ONE_WON, PLAYER_TWO_WON, DRAW }

var sides: Array[DuelSideState] = [DuelSideState.new(0), DuelSideState.new(1)]
var active_side: int = 0
var turn_number: int = 1
var phase: Phase = Phase.DRAW
var status: Status = Status.ACTIVE
var terrain: int = 0
var tributes_committed: int = 0
var auxiliary_flags: Array[int] = [0, 0]
var absolute_graveyard_ids: Array[int] = [0, 0]
var relative_graveyard_ids: Array[int] = [0, 0]

const EFFECT_IMMUNE_CARD_IDS := [832, 833, 834]

func side(side_id: int) -> DuelSideState:
	if side_id < 0 or side_id >= sides.size():
		return null
	return sides[side_id]

## Returns a visible duel row in the active player's native board orientation.
## The two opponent rows are mirrored; own rows retain their storage order.
func relative_board_row(acting_side: int, row_id: int) -> Array[DuelCardSlot]:
	if acting_side < 0 or acting_side >= sides.size() or row_id < 0 or row_id > 3:
		return []
	var owner := acting_side if row_id >= 2 else 1 - acting_side
	var source: Array[DuelCardSlot] = sides[owner].monster_zones if row_id in [1, 2] else sides[owner].back_row_zones
	var result: Array[DuelCardSlot] = []
	if row_id < 2:
		for column in range(source.size() - 1, -1, -1):
			result.append(source[column])
	else:
		result.assign(source)
	return result

func relative_board_slot(acting_side: int, row_id: int, column: int) -> DuelCardSlot:
	if column < 0 or column >= 5:
		return null
	var row := relative_board_row(acting_side, row_id)
	return row[column] if column < row.size() else null

## Converts a visible row/column back to the side's left-to-right storage slot.
func absolute_board_column(row_id: int, relative_column: int) -> int:
	if relative_column < 0 or relative_column >= 5:
		return -1
	return 4 - relative_column if row_id in [0, 1] else relative_column

func finish_turn() -> void:
	if status != Status.ACTIVE:
		return
	active_side = 1 - active_side
	turn_number += 1
	phase = Phase.DRAW

func check_victory() -> Status:
	var first_out := sides[0].life_points <= 0
	var second_out := sides[1].life_points <= 0
	if first_out and second_out:
		status = Status.DRAW
		auxiliary_flags[0] = 2
		auxiliary_flags[1] = 2
	elif first_out:
		status = Status.PLAYER_TWO_WON
		auxiliary_flags[0] = 2
	elif second_out:
		status = Status.PLAYER_ONE_WON
		auxiliary_flags[1] = 2
	return status

func has_ended() -> bool:
	return auxiliary_flags[0] == 2 or auxiliary_flags[1] == 2

func is_effect_immune(card_id: int) -> bool:
	return card_id in EFFECT_IMMUNE_CARD_IDS

func remember_grave_card(side_id: int, card_id: int, is_monster: bool, absolute_view: bool = false) -> void:
	if not is_monster or side_id < 0 or side_id >= 2:
		return
	if absolute_view:
		absolute_graveyard_ids[side_id] = card_id
	else:
		relative_graveyard_ids[side_id] = card_id

func take_grave_card(side_id: int, absolute_view: bool = false) -> int:
	if side_id < 0 or side_id >= 2:
		return 0
	var cards: Array[int] = absolute_graveyard_ids if absolute_view else relative_graveyard_ids
	var card_id := cards[side_id]
	cards[side_id] = 0
	return card_id

func discard_slot(side_id: int, row: int, column: int, is_monster: bool = false, absolute_view: bool = false) -> int:
	var selected_side := side(side_id)
	if selected_side == null or column < 0 or column >= 5:
		return 0
	var slots: Array[DuelCardSlot] = selected_side.monster_zones if row == 2 else selected_side.back_row_zones if row == 3 else []
	if slots.is_empty():
		return 0
	var slot := slots[column]
	var card_id := slot.card_id
	remember_grave_card(side_id, card_id, is_monster, absolute_view)
	slot.clear()
	return card_id

func count_empty_or_immune(row: Array[DuelCardSlot]) -> int:
	var count := 0
	for slot in row:
		if slot.is_empty() or is_effect_immune(slot.card_id):
			count += 1
	return count

## Value copy used for AI candidate simulation. No slot or hand arrays are aliased.
func duplicate_state() -> SacredDuelState:
	var copy := SacredDuelState.new()
	copy.active_side = active_side
	copy.turn_number = turn_number
	copy.phase = phase
	copy.status = status
	copy.terrain = terrain
	copy.tributes_committed = tributes_committed
	copy.auxiliary_flags = auxiliary_flags.duplicate()
	copy.absolute_graveyard_ids = absolute_graveyard_ids.duplicate()
	copy.relative_graveyard_ids = relative_graveyard_ids.duplicate()
	for side_index in range(sides.size()):
		var source := sides[side_index]
		var destination := DuelSideState.new(source.side_id)
		destination.life_points = source.life_points
		destination.graveyard_monster_id = source.graveyard_monster_id
		destination.hand = source.hand.duplicate()
		destination.hand_flags = source.hand_flags.duplicate()
		destination.deck = source.deck.duplicate()
		destination.deck_remaining_count = source.deck_remaining_count
		destination.deck_out = source.deck_out
		destination.defeated = source.defeated
		destination.duel_flags = source.duel_flags
		for column in range(source.monster_zones.size()):
			destination.monster_zones[column] = _duplicate_slot(source.monster_zones[column])
			destination.back_row_zones[column] = _duplicate_slot(source.back_row_zones[column])
		copy.sides[side_index] = destination
	return copy

func _duplicate_slot(source: DuelCardSlot) -> DuelCardSlot:
	var copy := DuelCardSlot.new()
	copy.card_id = source.card_id
	copy.controller = source.controller
	copy.face_down = source.face_down
	copy.defense_position = source.defense_position
	copy.has_attacked = source.has_attacked
	copy.stage = source.stage
	copy.zone_mode = source.zone_mode
	copy.persistent_flags = source.persistent_flags
	return copy
