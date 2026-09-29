extends RefCounted
class_name DeckBuilderMenu

## Input and popup state recovered from deck_builder_menu.c. Action requests are
## returned as values so the UI can invoke deck and sort services directly.

enum PopupKind { NONE, COLLECTION_ACTION, DECK_ACTION, COLLECTION_SORT, DECK_SORT }
enum Action { NONE, OPENED, CLOSED, EXIT, DESCRIBE, ADD_TO_DECK, REMOVE_FROM_DECK, SORT_COLLECTION, SORT_DECK, CYCLE_FILTER }

var popup: PopupKind = PopupKind.NONE
var choice: int = 0
var collection_sort: int = 0
var deck_sort: int = 0
var collection_filter: int = 0
var deck_filter: int = 0

func handle_key(key: int, deck_view: bool) -> Dictionary:
	var popup_active := popup != PopupKind.NONE
	if popup_active:
		if key == 2 or key == 8:
			popup = PopupKind.NONE
			return {"action": Action.CLOSED, "sound": 56}
		if key == 64 or key == 128:
			var maximum := 8 if popup in [PopupKind.COLLECTION_SORT, PopupKind.DECK_SORT] else (1 if deck_view else 2)
			choice = posmod(choice + (-1 if key == 64 else 1), maximum + 1)
			return {"action": Action.NONE, "sound": 54}
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
					collection_sort = choice
					popup = PopupKind.NONE
					return {"action": Action.SORT_COLLECTION, "method": collection_sort, "reset_selection": true, "sound": 55}
				PopupKind.DECK_SORT:
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
