extends RefCounted
class_name DuelCardSlot

## Value-owned replacement for the original eight-byte duel cell.

var card_id: int = 0
var controller: int = 0
var face_down: bool = false
var defense_position: bool = false
var has_attacked: bool = false
var stage: int = 0
var zone_mode: int = 0
var persistent_flags: int = 0

func is_empty() -> bool:
	return card_id == 0

func clear() -> void:
	card_id = 0
	controller = 0
	face_down = false
	defense_position = false
	has_attacked = false
	stage = 0
	zone_mode = 0
	# Native ClearDuelCell keeps the high two flag bits.
	persistent_flags &= 0xC0
