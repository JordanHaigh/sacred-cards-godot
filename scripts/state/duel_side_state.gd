extends RefCounted
class_name DuelSideState

var side_id: int = 0
var life_points: int = 8000
var graveyard_monster_id: int = 0
var monster_zones: Array[DuelCardSlot] = []
var back_row_zones: Array[DuelCardSlot] = []
var hand: Array[int] = []
## Per-card hand flags mirror duel-cell flags without byte aliases.
var hand_flags: Array[int] = []
var deck: Array[int] = []
## Native deck storage has forty slots and a separate remaining-count byte.
## Shuffling can move zero-filled slots, so array length is not the draw count.
var deck_remaining_count: int = 0
var deck_out: bool = false
var attack_restriction_turns: int = 0
var defeated: bool = false
var duel_flags: int = 0
var hand_revealed: bool = false

func _init(owner_id: int = 0) -> void:
	side_id = owner_id
	for _slot in range(5):
		monster_zones.append(DuelCardSlot.new())
		back_row_zones.append(DuelCardSlot.new())
