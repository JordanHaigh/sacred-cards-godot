extends RefCounted
class_name DeckBuilderMenu

## Input and popup state recovered from deck_builder_menu.c. Action requests are
## returned as values so the UI can invoke deck and sort services directly.

enum PopupKind { NONE, COLLECTION_ACTION, DECK_ACTION, COLLECTION_SORT, DECK_SORT }
enum Action { NONE, OPENED, CLOSED, EXIT, DESCRIBE, ADD_TO_DECK, REMOVE_FROM_DECK, SORT_COLLECTION, SORT_DECK, CYCLE_FILTER }

const COLLECTION_ACTION_NAVIGATION_PATH := "res://decompiled/build/assets/deck-builder/collection-action-navigation.bin"
const DECK_ACTION_NAVIGATION_PATH := "res://decompiled/build/assets/deck-builder/deck-action-navigation.bin"
const ACTION_TEXT_RECORDS_PATH := "res://decompiled/build/assets/deck-builder/strings.json"
const COLLECTION_SORT_NAVIGATION_PATH := "res://decompiled/build/assets/deck-builder/collection-sort-navigation.bin"
const DECK_SORT_NAVIGATION_PATH := "res://decompiled/build/assets/deck-builder/deck-sort-navigation.bin"
const SORT_COORDINATE_Y_OFFSET := 40
const SORT_COORDINATE_X_OFFSET := 50
const COLLECTION_ACTION_COORDINATE_Y_OFFSET := 6
const COLLECTION_ACTION_COORDINATE_X_OFFSET := 9
const DECK_ACTION_COORDINATE_Y_OFFSET := 4
const DECK_ACTION_COORDINATE_X_OFFSET := 7
const SORT_LABELS_EN := ["No.", "Name", "ATK", "DEF", "Type", "Summon", "Qty.", "Cost", "Stars", "Exit"]
const SORT_LABELS_JP := ["番号", "名前", "こうげき力", "守備力", "種族", "しょうかん", "まい数", "コスト", "星", "やめる"]

var popup: PopupKind = PopupKind.NONE
var choice: int = 0
var collection_sort: int = 0
var deck_sort: int = 0
var collection_filter: int = 0
var deck_filter: int = 0
var collection_action_navigation := PackedByteArray()
var deck_action_navigation := PackedByteArray()
var collection_sort_navigation := PackedByteArray()
var deck_sort_navigation := PackedByteArray()
var action_text_records: Dictionary = {}

func _init() -> void:
	collection_action_navigation = FileAccess.get_file_as_bytes(COLLECTION_ACTION_NAVIGATION_PATH)
	deck_action_navigation = FileAccess.get_file_as_bytes(DECK_ACTION_NAVIGATION_PATH)
	collection_sort_navigation = FileAccess.get_file_as_bytes(COLLECTION_SORT_NAVIGATION_PATH)
	deck_sort_navigation = FileAccess.get_file_as_bytes(DECK_SORT_NAVIGATION_PATH)
	_load_action_text_records()

func begin_hub_session() -> void:
	popup = PopupKind.NONE
	choice = 0
	collection_sort = 0
	deck_sort = 0
	collection_filter = 1
	deck_filter = 1

func sort_popup_cursor_position(choice_index: int, deck_view: bool = false) -> Vector2i:
	var table := deck_sort_navigation if deck_view else collection_sort_navigation
	var index := clampi(choice_index, 0, 9)
	if table.size() < SORT_COORDINATE_X_OFFSET + 10:
		return Vector2i.ZERO
	return Vector2i(table[SORT_COORDINATE_X_OFFSET + index], table[SORT_COORDINATE_Y_OFFSET + index])

func action_popup_cursor_position(choice_index: int, deck_view: bool = false) -> Vector2i:
	var table := deck_action_navigation if deck_view else collection_action_navigation
	var choice_count := 2 if deck_view else 3
	var y_offset := DECK_ACTION_COORDINATE_Y_OFFSET if deck_view else COLLECTION_ACTION_COORDINATE_Y_OFFSET
	var x_offset := DECK_ACTION_COORDINATE_X_OFFSET if deck_view else COLLECTION_ACTION_COORDINATE_X_OFFSET
	var index := clampi(choice_index, 0, choice_count - 1)
	if table.size() < x_offset + choice_count:
		return Vector2i.ZERO
	return Vector2i(table[x_offset + index], table[y_offset + index])

func action_popup_labels(language_id: int, deck_view: bool = false) -> Array[String]:
	var record_address := "0x080B46E0" if deck_view else "0x08086AC4"
	var record: Dictionary = action_text_records.get(record_address, {})
	var languages: Dictionary = record.get("languages", {})
	var source_text := str(languages.get(str(clampi(language_id, 0, 5)), languages.get("0", "")))
	var labels: Array[String] = []
	var current := ""
	var whitespace_run := 0
	for index in range(source_text.length()):
		var character := source_text.substr(index, 1)
		var codepoint := source_text.unicode_at(index)
		if codepoint == 32 or codepoint == 0x3000:
			whitespace_run += 1
			continue
		if whitespace_run >= 3:
			if not current.strip_edges().is_empty():
				labels.append(current.strip_edges())
			current = ""
		elif whitespace_run > 0:
			current += " ".repeat(whitespace_run)
		whitespace_run = 0
		current += character
	if not current.strip_edges().is_empty():
		labels.append(current.strip_edges())
	return labels

func sort_popup_labels(language_id: int) -> Array[String]:
	# Choices 0–8 are sort methods and choice 9 exits, matching both recovered
	# text records at 08086C00 and 080B4820.
	var source: Array = SORT_LABELS_JP if clampi(language_id, 0, 5) == 5 else SORT_LABELS_EN
	var labels: Array[String] = []
	for value: Variant in source:
		labels.append(str(value))
	return labels

func _load_action_text_records() -> void:
	if not FileAccess.file_exists(ACTION_TEXT_RECORDS_PATH):
		push_error("Missing recovered action popup text records: %s" % ACTION_TEXT_RECORDS_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACTION_TEXT_RECORDS_PATH))
	if not parsed is Array:
		push_error("Recovered action popup text catalog is not an array.")
		return
	for value: Variant in parsed:
		if not value is Dictionary:
			continue
		var address := str(value.get("address", ""))
		if address in ["0x08086AC4", "0x080B46E0"]:
			action_text_records[address] = value

func handle_key(key: int, deck_view: bool) -> Dictionary:
	var popup_active := popup != PopupKind.NONE
	if popup_active:
		var sort_popup := popup in [PopupKind.COLLECTION_SORT, PopupKind.DECK_SORT]
		if key == 2 or (key == 8 and sort_popup):
			popup = PopupKind.NONE
			return {"action": Action.CLOSED, "sound": 56}
		if key in [64, 128, 32, 16]:
			if not sort_popup and key in [32, 16]:
				return {"action": Action.NONE, "sound": 0}
			var direction_index := 0 if key == 64 else 1 if key == 128 else 2 if key == 32 else 3
			var navigation := _navigation_for_popup(sort_popup, deck_view)
			var row_width := 10 if sort_popup else 2 if deck_view else 3
			var navigation_index := direction_index * row_width + choice
			if navigation_index >= 0 and navigation_index < navigation.size():
				choice = int(navigation[navigation_index])
				return {"action": Action.NONE, "sound": 54}
			return {"action": Action.NONE, "sound": 0}
		if key == 1:
			match popup:
				PopupKind.COLLECTION_ACTION:
					if choice == 0: return {"action": Action.DESCRIBE, "sound": 55}
					if choice == 1: return {"action": Action.ADD_TO_DECK, "sound": 0}
					return {"action": Action.REMOVE_FROM_DECK, "sound": 0}
				PopupKind.DECK_ACTION:
					if choice == 0: return {"action": Action.DESCRIBE, "sound": 55}
					popup = PopupKind.NONE
					return {"action": Action.REMOVE_FROM_DECK, "sound": 0}
				PopupKind.COLLECTION_SORT:
					if choice == 9:
						popup = PopupKind.NONE
						return {"action": Action.CLOSED, "sound": 55}
					collection_sort = choice
					popup = PopupKind.NONE
					return {"action": Action.SORT_COLLECTION, "method": collection_sort, "reset_selection": true, "sound": 55}
				PopupKind.DECK_SORT:
					if choice == 9:
						popup = PopupKind.NONE
						return {"action": Action.CLOSED, "sound": 55}
					deck_sort = choice
					popup = PopupKind.NONE
					return {"action": Action.SORT_DECK, "method": deck_sort, "reset_selection": true, "sound": 55}
		return {"action": Action.NONE, "sound": 0}
	if key == 2: return {"action": Action.EXIT, "sound": 56}
	if key == 1:
		popup = PopupKind.DECK_ACTION if deck_view else PopupKind.COLLECTION_ACTION
		choice = 0
		return {"action": Action.OPENED, "sound": 55}
	if key == 4:
		if deck_view:
			deck_sort = (deck_sort + 1) % 9
			return {"action": Action.SORT_DECK, "method": deck_sort, "reset_selection": true, "sound": 55}
		collection_sort = (collection_sort + 1) % 9
		return {"action": Action.SORT_COLLECTION, "method": collection_sort, "reset_selection": true, "sound": 54}
	if key == 8:
		popup = PopupKind.DECK_SORT if deck_view else PopupKind.COLLECTION_SORT
		choice = deck_sort if deck_view else collection_sort
		return {"action": Action.OPENED, "sound": 55}
	if key == 512:
		if deck_view: deck_filter = (deck_filter + 1) % 4
		else: collection_filter = (collection_filter + 1) % 4
		return {"action": Action.CYCLE_FILTER, "filter": deck_filter if deck_view else collection_filter, "sound": 54}
	if not deck_view and key == 16: return {"action": Action.ADD_TO_DECK, "sound": 0}
	if not deck_view and key == 32: return {"action": Action.REMOVE_FROM_DECK, "sound": 0}
	return {"action": Action.NONE, "sound": 0}

func _navigation_for_popup(sort_popup: bool, deck_view: bool) -> PackedByteArray:
	if sort_popup:
		return deck_sort_navigation if popup == PopupKind.DECK_SORT else collection_sort_navigation
	return deck_action_navigation if deck_view else collection_action_navigation
