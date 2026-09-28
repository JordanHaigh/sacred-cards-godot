class_name PreDuelMenuState
extends RefCounted
## Typed wager/list state from pre_duel_menu.c. Card order and inventory
## ownership are delegated to CardSortSystem and the caller's save model.

enum Popup { NONE, ACTION, SPECIAL_WAGER, NO_WAGER, SORT }
enum Action { NONE, INSPECT, WAGER, CANCEL, START_WITHOUT_WAGER, START_WITH_WAGER }

const CARD_COUNT := 900
const SORT_METHOD_BASE := 45
const PAGE_STEP := 50

var sorted_card_ids: Array[int] = []
var collection_counts: Dictionary[int, int] = {}
var total_counts: Dictionary[int, int] = {}
var wagerable_cards: Dictionary[int, bool] = {}
var special_wager_cards: Dictionary[int, bool] = {}
var selected_index := 0
var sort_mode := 0
var view_mode := 1
var popup: Popup = Popup.NONE
var choice := 0
var wagered_card_id := 0

func initialize(collection: Dictionary, deck: Array[int], wagerable_ids: Array[int], special_ids: Array[int]) -> void:
	collection_counts.clear()
	for raw_id: Variant in collection:
		collection_counts[int(raw_id)] = int(collection[raw_id])
	total_counts = collection_counts.duplicate()
	for card_id in deck:
		total_counts[card_id] = int(total_counts.get(card_id, 0)) + 1
	wagerable_cards.clear()
	for card_id in wagerable_ids: wagerable_cards[card_id] = true
	special_wager_cards.clear()
	for card_id in special_ids: special_wager_cards[card_id] = true
	sorted_card_ids.clear()
	for card_id in range(1, CARD_COUNT + 1): sorted_card_ids.append(card_id)
	selected_index = 0
	sort_mode = 0
	view_mode = 1
	wagered_card_id = 0
	close_popup()

func apply_sort(sorter: CardSortSystem) -> void:
	if sorter == null: return
	sorted_card_ids = sorter.sort_cards(sorted_card_ids, SORT_METHOD_BASE + sort_mode, collection_counts, {}, collection_counts, total_counts)

func move(offset: int) -> int:
	selected_index += offset
	if selected_index < 0: selected_index += CARD_COUNT
	elif selected_index >= CARD_COUNT: selected_index -= CARD_COUNT
	return selected_index

func page(direction: int) -> int:
	move(PAGE_STEP * direction)
	return selected_index

func cycle_view() -> int:
	view_mode = posmod(view_mode + 1, 4)
	return view_mode

func cycle_sort(sorter: CardSortSystem) -> int:
	sort_mode = posmod(sort_mode + 1, 9)
	selected_index = 0
	apply_sort(sorter)
	return sort_mode

func selected_card_id() -> int:
	return int(sorted_card_ids[clampi(selected_index, 0, sorted_card_ids.size() - 1)]) if not sorted_card_ids.is_empty() else 0

func card_at_visible_row(row: int) -> int:
	var index := posmod(selected_index + row - 2, CARD_COUNT)
	return int(sorted_card_ids[index]) if index >= 0 and index < sorted_card_ids.size() else 0

func open_action() -> void:
	popup = Popup.ACTION
	choice = 0

func open_sort() -> void:
	popup = Popup.SORT
	choice = sort_mode

func navigate_popup(direction: int) -> int:
	var count := 3 if popup == Popup.ACTION else 10 if popup == Popup.SORT else 2
	choice = posmod(choice + direction, count)
	return choice

func confirm() -> Dictionary:
	match popup:
		Popup.NONE:
			var card_id := selected_card_id()
			if card_id == 0 or not wagerable_cards.get(card_id, false):
				return {"action": Action.NONE, "reason": "card_cannot_be_wagered", "sound": 57}
			open_action()
			return {"action": Action.NONE, "sound": 55}
		Popup.ACTION:
			if choice == 0: return {"action": Action.INSPECT, "card_id": selected_card_id(), "sound": 55}
			if choice == 1:
				if not wagerable_cards.get(selected_card_id(), false): return {"action": Action.NONE, "reason": "card_cannot_be_wagered", "sound": 57}
				if int(collection_counts.get(selected_card_id(), 0)) <= 0: return {"action": Action.NONE, "reason": "card_not_owned", "sound": 57}
				if special_wager_cards.get(selected_card_id(), false):
					popup = Popup.SPECIAL_WAGER
					choice = 0
					return {"action": Action.NONE, "popup": popup, "sound": 55}
				wagered_card_id = selected_card_id()
				close_popup()
				return {"action": Action.START_WITH_WAGER, "card_id": wagered_card_id, "sound": 222}
			close_popup()
			return {"action": Action.CANCEL, "sound": 56}
		Popup.SPECIAL_WAGER:
			if choice == 1:
				wagered_card_id = selected_card_id()
				close_popup()
				return {"action": Action.START_WITH_WAGER, "card_id": wagered_card_id, "sound": 222}
			close_popup()
			return {"action": Action.CANCEL, "sound": 55}
		Popup.NO_WAGER:
			if choice == 1:
				wagered_card_id = 0
				close_popup()
				return {"action": Action.START_WITHOUT_WAGER, "sound": 222}
			close_popup()
			return {"action": Action.CANCEL, "sound": 55}
		Popup.SORT:
			if choice == 9:
				close_popup()
				return {"action": Action.CANCEL, "sound": 56}
			sort_mode = choice
			close_popup()
			return {"action": Action.NONE, "sort_mode": sort_mode, "apply_sort": true, "sound": 55}
	return {"action": Action.NONE}

func open_no_wager() -> void:
	popup = Popup.NO_WAGER
	choice = 0

func close_popup() -> void:
	popup = Popup.NONE
	choice = 0
