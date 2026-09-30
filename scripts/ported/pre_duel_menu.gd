class_name PreDuelMenuState
extends RefCounted
## Typed wager/list state from pre_duel_menu.c. Card order and inventory
## ownership are delegated to CardSortSystem and the caller's save model.

enum PopupKind { NONE, ACTION, SPECIAL_WAGER, NO_WAGER, SORT }
enum Action { NONE, INSPECT, WAGER, CANCEL, START_WITHOUT_WAGER, START_WITH_WAGER }

const CARD_COUNT := 900
const SORT_METHOD_BASE := 45
const PAGE_STEP := 50
const POPUP_NAVIGATION_PATH := "res://resources/pre_duel_navigation.json"
const POPUP_NAVIGATION_TABLE_SIZES := {
	"action_up": 3, "action_down": 3,
	"special_up": 2, "special_down": 2,
	"no_wager_up": 2, "no_wager_down": 2,
	"sort_up": 10, "sort_down": 10, "sort_left": 10, "sort_right": 10,
}

var sorted_card_ids: Array[int] = []
var collection_counts: Dictionary[int, int] = {}
var total_counts: Dictionary[int, int] = {}
var wagerable_cards: Dictionary[int, bool] = {}
var special_wager_cards: Dictionary[int, bool] = {}
var selected_index := 0
var sort_mode := 0
var view_mode := 1
var popup: PopupKind = PopupKind.NONE
var choice := 0
var wagered_card_id := 0
var popup_navigation: Dictionary[StringName, Array] = {}

func _init() -> void:
	_load_popup_navigation()

func initialize(collection: Dictionary, deck: Array[int], wagerable_ids: Array[int], special_ids: Array[int]) -> void:
	collection_counts.clear()
	for raw_id: Variant in collection:
		var card_id := int(raw_id)
		if card_id >= 0 and card_id <= CARD_COUNT:
			collection_counts[card_id] = int(collection[raw_id]) & 0xFF
	total_counts = collection_counts.duplicate()
	for card_id in deck:
		if card_id >= 0 and card_id <= CARD_COUNT:
			total_counts[card_id] = (int(total_counts.get(card_id, 0)) + 1) & 0xFF
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
	popup = PopupKind.ACTION
	choice = 0

func open_sort() -> void:
	popup = PopupKind.SORT
	choice = sort_mode

func navigate_popup(key_code: int) -> bool:
	var table_name := _popup_navigation_table(key_code)
	var table: Array = popup_navigation.get(table_name, [])
	if table_name == &"" or choice < 0 or choice >= table.size():
		return false
	choice = int(table[choice])
	return true

func _popup_navigation_table(key_code: int) -> StringName:
	match popup:
		PopupKind.ACTION:
			if key_code == 64: return &"action_up"
			if key_code == 128: return &"action_down"
		PopupKind.SPECIAL_WAGER:
			if key_code == 64: return &"special_up"
			if key_code == 128: return &"special_down"
		PopupKind.NO_WAGER:
			if key_code == 64: return &"no_wager_up"
			if key_code == 128: return &"no_wager_down"
		PopupKind.SORT:
			if key_code == 64: return &"sort_up"
			if key_code == 128: return &"sort_down"
			if key_code == 32: return &"sort_left"
			if key_code == 16: return &"sort_right"
	return &""

func _load_popup_navigation() -> bool:
	var file := FileAccess.open(POPUP_NAVIGATION_PATH, FileAccess.READ)
	if file == null:
		push_warning("Recovered pre-duel popup navigation is unavailable: %s" % POPUP_NAVIGATION_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("tables", {}) is Dictionary:
		push_warning("Recovered pre-duel popup navigation has an invalid structure.")
		return false
	var recovered_tables: Dictionary = parsed.tables
	for raw_name: Variant in POPUP_NAVIGATION_TABLE_SIZES:
		var table_name := str(raw_name)
		var expected_size := int(POPUP_NAVIGATION_TABLE_SIZES[raw_name])
		var raw_table: Variant = recovered_tables.get(table_name, null)
		if not raw_table is Array or raw_table.size() != expected_size:
			push_warning("Recovered pre-duel navigation table %s has the wrong size." % table_name)
			return false
		var table: Array[int] = []
		for raw_choice: Variant in raw_table:
			var next_choice := int(raw_choice)
			if next_choice < 0 or next_choice >= expected_size:
				push_warning("Recovered pre-duel navigation table %s has an invalid choice." % table_name)
				return false
			table.append(next_choice)
		popup_navigation[StringName(table_name)] = table
	return true

func confirm() -> Dictionary:
	match popup:
		PopupKind.NONE:
			var card_id := selected_card_id()
			if card_id == 0 or not wagerable_cards.get(card_id, false):
				return {"action": Action.NONE, "reason": "card_cannot_be_wagered", "sound": 57}
			open_action()
			return {"action": Action.NONE, "sound": 55}
		PopupKind.ACTION:
			if choice == 0: return {"action": Action.INSPECT, "card_id": selected_card_id(), "sound": 55}
			if choice == 1:
				if not wagerable_cards.get(selected_card_id(), false): return {"action": Action.NONE, "reason": "card_cannot_be_wagered", "sound": 57}
				if int(collection_counts.get(selected_card_id(), 0)) <= 0: return {"action": Action.NONE, "reason": "card_not_owned", "sound": 57}
				if special_wager_cards.get(selected_card_id(), false):
					popup = PopupKind.SPECIAL_WAGER
					choice = 0
					return {"action": Action.NONE, "popup": popup, "sound": 55}
				wagered_card_id = selected_card_id()
				close_popup()
				return {"action": Action.START_WITH_WAGER, "card_id": wagered_card_id, "sound": 222}
			close_popup()
			return {"action": Action.CANCEL, "sound": 56}
		PopupKind.SPECIAL_WAGER:
			if choice == 1:
				wagered_card_id = selected_card_id()
				close_popup()
				return {"action": Action.START_WITH_WAGER, "card_id": wagered_card_id, "sound": 222}
			close_popup()
			return {"action": Action.CANCEL, "sound": 55}
		PopupKind.NO_WAGER:
			if choice == 1:
				wagered_card_id = 0
				close_popup()
				return {"action": Action.START_WITHOUT_WAGER, "sound": 222}
			close_popup()
			return {"action": Action.CANCEL, "sound": 55}
		PopupKind.SORT:
			if choice == 9:
				close_popup()
				return {"action": Action.CANCEL, "sound": 56}
			sort_mode = choice
			close_popup()
			return {"action": Action.NONE, "sort_mode": sort_mode, "apply_sort": true, "sound": 55}
	return {"action": Action.NONE}

func open_no_wager() -> void:
	popup = PopupKind.NO_WAGER
	choice = 0

func close_popup() -> void:
	popup = PopupKind.NONE
	choice = 0
