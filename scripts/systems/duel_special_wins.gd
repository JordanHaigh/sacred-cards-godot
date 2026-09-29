extends RefCounted
class_name DuelSpecialWins

## Exodia and Destiny Board condition checks from duel_special_wins.c.
signal special_win(side_id: int, message_id: int)

const EXODIA_MESSAGE := 17
const DESTINY_BOARD_MESSAGE := 18

func exodia_piece_mask(card_id: int) -> int:
	return 1 << (card_id - 17) if card_id >= 17 and card_id <= 21 else 0

func destiny_piece_mask(card_id: int) -> int:
	return 1 << (card_id - 583) if card_id >= 583 and card_id <= 587 else 0

func exodia_hand_mask(hand: Array[int]) -> int:
	var mask := 0
	for card_id in hand:
		mask |= exodia_piece_mask(card_id)
	return mask & 31

func destiny_board_mask(back_row: Array[DuelCardSlot]) -> int:
	var mask := 0
	for slot in back_row:
		mask |= destiny_piece_mask(slot.card_id)
	return mask & 31

func check_exodia(duel: SacredDuelState, side_id: int) -> bool:
	if duel == null or side_id < 0 or side_id >= duel.sides.size() or duel.status != SacredDuelState.Status.ACTIVE:
		return false
	if exodia_hand_mask(duel.sides[side_id].hand) != 31:
		return false
	_finish(duel, side_id, EXODIA_MESSAGE)
	return true

func check_destiny_board(duel: SacredDuelState, side_id: int) -> bool:
	if duel == null or side_id < 0 or side_id >= duel.sides.size() or duel.status != SacredDuelState.Status.ACTIVE:
		return false
	if destiny_board_mask(duel.sides[side_id].back_row_zones) != 31:
		return false
	_finish(duel, side_id, DESTINY_BOARD_MESSAGE)
	return true

func _finish(duel: SacredDuelState, winner: int, message_id: int) -> void:
	duel.auxiliary_flags[1 - winner] = 2
	duel.status = SacredDuelState.Status.PLAYER_ONE_WON if winner == 0 else SacredDuelState.Status.PLAYER_TWO_WON
	special_win.emit(winner, message_id)
