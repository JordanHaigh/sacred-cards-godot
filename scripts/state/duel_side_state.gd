extends RefCounted
class_name DuelSideState

var side_id: int = 0
var life_points: int = 8000
var graveyard_monster_id: int = 0
var monster_zones: Array[DuelCardSlot] = []
var back_row_zones: Array[DuelCardSlot] = []
## Native hand cells are fixed slots; zero means the slot is empty.
var hand: Array[int] = []
## Per-card hand flags mirror duel-cell flags without byte aliases.
var hand_flags: Array[int] = []
var deck: Array[int] = []
## Native deck storage has forty slots and a separate remaining-count byte.
## Shuffling can move zero-filled slots, so array length is not the draw count.
var deck_remaining_count: int = 0
var deck_out: bool = false
var defeated: bool = false
var duel_flags: int = 0

func _init(owner_id: int = 0) -> void:
	side_id = owner_id
	for _slot in range(5):
		monster_zones.append(DuelCardSlot.new())
		back_row_zones.append(DuelCardSlot.new())
	hand.resize(5)
	hand_flags.resize(5)

func hand_count() -> int:
	var count := 0
	for card_id in hand:
		if card_id != 0:
			count += 1
	return count

## Mirrors clearing a native eight-byte hand cell: the ID is cleared while
## persistent high flag bits survive for the next draw into this same slot.
func remove_hand_at(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= hand.size():
		return 0
	var card_id := hand[slot_index]
	hand[slot_index] = 0
	hand_flags[slot_index] &= 0xC0
	return card_id

func clear_hand() -> void:
	for slot_index in range(hand.size()):
		remove_hand_at(slot_index)
