extends RefCounted
class_name DuelDeck

## Port of duel_deck.c using card ID arrays instead of shared RAM records.

static func draw_card(side: DuelSideState, duel_state: SacredDuelState = null) -> int:
	var hand_slot := -1
	for index in range(side.hand.size()):
		if side.hand[index] == 0:
			hand_slot = index
			break
	if hand_slot < 0:
		return 0
	if side.deck_remaining_count <= 0:
		side.deck_out = true
		if duel_state != null and side.side_id >= 0 and side.side_id < duel_state.auxiliary_flags.size():
			duel_state.auxiliary_flags[side.side_id] = 2
			duel_state.status = SacredDuelState.Status.PLAYER_TWO_WON if side.side_id == 0 else SacredDuelState.Status.PLAYER_ONE_WON
		return 0
	side.deck_remaining_count -= 1
	var card_id := int(side.deck[side.deck_remaining_count])
	if card_id == 0:
		return 0
	side.hand[hand_slot] = card_id
	return card_id

static func set_attack_restriction(side: DuelSideState) -> void:
	side.duel_flags |= 3
