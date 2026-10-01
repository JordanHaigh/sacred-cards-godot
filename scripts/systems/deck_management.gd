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
const TEXT_RECORDS_PATH := "res://decompiled/build/assets/deck-builder/strings.json"
const TEXT_FILE_BY_KEY := {
	"count_error": "text/080706B0.bin",
	"capacity_error": "text/0807082C.bin",
	"hub_status": "text/080709A8.bin",
	"hub_trunk": "text/080709F4.bin",
	"hub_deck": "text/08070A3C.bin",
	"status_name": "text/0807EEC0.bin",
	"status_level": "text/0807EEF8.bin",
	"status_capacity": "text/0807EF7C.bin",
	"status_locator_card": "text/0807F000.bin",
	"status_money": "text/0807F098.bin",
	"status_domino": "text/0807F0E0.bin",
}

var choice: int = 0
var _localized_records: Dictionary = {}

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
	return {
		"name": save.player_name,
		"duelist_level": save.duelist_level & 0xFFFF,
		"duelist_level_digits": _native_digits(save.duelist_level & 0xFFFF, 4),
		"deck_capacity": save.deck_capacity & 0xFFFF,
		"deck_capacity_digits": _native_digits(save.deck_capacity & 0xFFFF, 5),
		"rank_marks": rank_count,
		"money": save.money,
		"money_digits": _native_digits(save.money, 13, true),
	}

func localized_text(key: String, language_id: int = 0) -> String:
	if _localized_records.is_empty():
		_load_localized_records()
	if not _localized_records.has(key):
		push_error("DeckManagement has no recovered text record for '%s'." % key)
		return ""
	var languages: Dictionary = _localized_records[key]
	var selected := str(clampi(language_id, 0, 5))
	return str(languages.get(selected, languages.get("0", "")))

func _load_localized_records() -> void:
	if not FileAccess.file_exists(TEXT_RECORDS_PATH):
		push_error("Missing recovered deck-builder text data: %s" % TEXT_RECORDS_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_RECORDS_PATH))
	if not parsed is Array:
		push_error("Recovered deck-builder text data is not an array.")
		return
	for row: Variant in parsed:
		if not row is Dictionary:
			continue
		for key: Variant in TEXT_FILE_BY_KEY:
			if str(row.get("file", "")) == str(TEXT_FILE_BY_KEY[key]):
				var languages: Variant = row.get("languages", {})
				if languages is Dictionary:
					_localized_records[str(key)] = languages

func _native_digits(value: int, digit_count: int, zero_units_when_empty: bool = false) -> Array[int]:
	# StatusNumber uses decimal divisors and replaces leading zero digits with
	# tile 10 (blank). The money loop keeps a zero in its final units tile.
	var decimal := str(maxi(value, 0))
	if decimal.length() > digit_count:
		decimal = decimal.right(digit_count)
	while decimal.length() < digit_count:
		decimal = "0" + decimal
	var digits: Array[int] = []
	var seen_nonzero := false
	for index in range(decimal.length()):
		var digit := int(decimal.substr(index, 1))
		if digit != 0:
			seen_nonzero = true
			digits.append(digit)
		elif seen_nonzero or (zero_units_when_empty and index == decimal.length() - 1):
			digits.append(0)
		else:
			digits.append(10)
	return digits

static func native_digit_text(digits: Array) -> String:
	var result := ""
	for value in digits:
		var digit := int(value)
		result += " " if digit == 10 else str(clampi(digit, 0, 9))
	return result
