extends RefCounted
class_name DuelDeck

## Port of duel_deck.c using card ID arrays instead of shared RAM records.

static func draw_card(side: DuelSideState) -> int:
	if side.hand.size() >= 5:
		return 0
	if side.deck.is_empty():
		side.deck_out = true
		return 0
	var card_id: int = side.deck.pop_back()
	side.hand.append(card_id)
	side.hand_flags.append(0)
	return card_id

static func set_attack_restriction(side: DuelSideState) -> void:
	side.attack_restriction_turns |= 3
