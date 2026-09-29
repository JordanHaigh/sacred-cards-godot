extends RefCounted
class_name DeckBuilderMenu

## Input and popup state recovered from deck_builder_menu.c. Action requests are
## returned as values so the UI can invoke deck and sort services directly.

enum PopupKind { NONE, COLLECTION_ACTION, DECK_ACTION, COLLECTION_SORT, DECK_SORT }
enum Action { NONE, OPENED, CLOSED, EXIT, DESCRIBE, ADD_TO_DECK, REMOVE_FROM_DECK, SORT_COLLECTION, SORT_DECK, CYCLE_FILTER }

const COLLECTION_ACTION_NAVIGATION_PATH := "res://decompiled/build/assets/deck-builder/collection-action-navigation.bin"
const DECK_ACTION_NAVIGATION_PATH := "res://decompiled/build/assets/deck-builder/deck-action-navigation.bin"
const COLLECTION_SORT_NAVIGATION_PATH := "res://decompiled/build/assets/deck-builder/collection-sort-navigation.bin"
const DECK_SORT_NAVIGATION_PATH := "res://decompiled/build/assets/deck-builder/deck-sort-navigation.bin"

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

func _init() -> void:
	collection_action_navigation = FileAccess.get_file_as_bytes(COLLECTION_ACTION_NAVIGATION_PATH)
	deck_action_navigation = FileAccess.get_file_as_bytes(DECK_ACTION_NAVIGATION_PATH)
	collection_sort_navigation = FileAccess.get_file_as_bytes(COLLECTION_SORT_NAVIGATION_PATH)
	deck_sort_navigation = FileAccess.get_file_as_bytes(DECK_SORT_NAVIGATION_PATH)

func handle_key(key: int, deck_view: bool) -> Dictionary:
	var popup_active := popup != PopupKind.NONE
	if popup_active:
		if key == 2 or key == 8:
			popup = PopupKind.NONE
			return {"action": Action.CLOSED, "sound": 56}
		if key in [64, 128, 32, 16]:
			var sort_popup := popup in [PopupKind.COLLECTION_SORT, PopupKind.DECK_SORT]
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
