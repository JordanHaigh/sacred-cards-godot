extends RefCounted
class_name DuelDeck

## Port of duel_deck.c using card ID arrays instead of shared RAM records.

static func draw_card(side: DuelSideState) -> int:
	var hand_slot := -1
	for index in range(mini(side.hand.size(), 5)):
		if side.hand[index] == 0:
			hand_slot = index
			break
	if hand_slot < 0 and side.hand.size() < 5:
		hand_slot = side.hand.size()
	if hand_slot < 0:
		return 0
	if side.deck_remaining_count <= 0:
		side.deck_out = true
		return 0
	side.deck_remaining_count -= 1
	var card_id := int(side.deck[side.deck_remaining_count])
	if hand_slot == side.hand.size():
		side.hand.append(card_id)
		side.hand_flags.append(0)
	else:
		side.hand[hand_slot] = card_id
		side.hand_flags[hand_slot] = 0
	return card_id

static func set_attack_restriction(side: DuelSideState) -> void:
	side.attack_restriction_turns |= 3
