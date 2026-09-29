extends RefCounted
class_name DeckManagement

## Hardware-independent state and decisions from deck_management.c. Graphics,
## VBlank callbacks and register writes are replaced by a small Godot view model.

enum Action { NONE, PLAYER_STATUS, COLLECTION_EDITOR, DECK_EDITOR, EXIT, INVALID_DECK_SIZE, INVALID_DECK_CAPACITY, EMPTY_DECK }

const DECK_CAPACITY := 40
const BUTTON_A := 1
const BUTTON_B := 2
const BUTTON_UP := 64
const BUTTON_DOWN := 128

var choice: int = 0

func handle_buttons(buttons: int, deck: Array[int], deck_cost: int, capacity: int) -> Dictionary:
	var action := Action.NONE
	var sounds: Array[int] = []
	if (buttons & BUTTON_B) != 0:
		if deck.size() != DECK_CAPACITY:
			action = Action.INVALID_DECK_SIZE
			sounds.append(57)
		elif deck_cost > capacity:
			action = Action.INVALID_DECK_CAPACITY
			sounds.append(57)
		else:
			action = Action.EXIT
			sounds.append(56)
			return {"action": action, "sounds": sounds, "choice": choice}
	if (buttons & BUTTON_UP) != 0 and choice > 0:
		choice -= 1
		sounds.append(54)
	if (buttons & BUTTON_DOWN) != 0 and choice < 2:
		choice += 1
		sounds.append(54)
	if (buttons & BUTTON_A) != 0:
		sounds.append(55)
		match choice:
			0: action = Action.PLAYER_STATUS
			1: action = Action.COLLECTION_EDITOR
			2:
				if deck.is_empty():
					action = Action.EMPTY_DECK
					sounds.append(57)
				else: action = Action.DECK_EDITOR
	return {"action": action, "sounds": sounds, "choice": choice}

func player_status(save: PlayerSaveData) -> Dictionary:
	if save == null: return {}
	var rank_count := 0
	for bit in range(6): rank_count += (int(save.extensions.get("progress_rank", 0)) >> bit) & 1
	var deck_count := 0
	for card_id in save.deck:
		if card_id != 0: deck_count += 1
	return {
		"name": save.player_name,
		"duelist_level": save.duelist_level & 0xFFFF,
		"deck_capacity": save.deck_capacity & 0xFFFF,
		"rank_marks": rank_count,
		"money": save.money,
		"deck_count": deck_count,
	}
