class_name ShopMenuState
extends RefCounted
## Shop navigation, popup and sort state recovered from shop_menu.c.

enum PopupKind { NONE, ACTION, SORT }
enum Action { NONE, BUY_OR_SELL, CARD_INFO, CANCEL, SORT_SELECTED, SORT_CLOSED }

const SORT_METHODS_BUY_PATH := "res://decompiled/build/assets/player-menus/shop.buy-sort-methods.bin"
const SORT_METHODS_SELL_PATH := "res://decompiled/build/assets/player-menus/shop.sell-sort-methods.bin"
const POPUP_NAVIGATION_PATH := "res://resources/shop_navigation.json"
const POPUP_NAVIGATION_TABLE_SIZES := {
	"action_up": 3, "action_down": 3,
	"sort_up": 10, "sort_down": 10, "sort_left": 10, "sort_right": 10,
}

var popup: PopupKind = PopupKind.NONE
var choice := 0
var sort_mode := 0
var selected_index := 0
var selling := false
var sort_methods_buy := PackedByteArray()
var sort_methods_sell := PackedByteArray()
var popup_navigation: Dictionary[StringName, Array] = {}

func _init() -> void:
	sort_methods_buy = FileAccess.get_file_as_bytes(SORT_METHODS_BUY_PATH)
	sort_methods_sell = FileAccess.get_file_as_bytes(SORT_METHODS_SELL_PATH)
	_load_popup_navigation()

func begin(is_selling: bool, selection: int = 0) -> void:
	selling = is_selling
	selected_index = maxi(selection, 0)
	popup = PopupKind.NONE
	choice = 0

func set_selling(is_selling: bool) -> void:
	selling = is_selling
	selected_index = 0
	popup = PopupKind.NONE
	choice = 0
	sort_mode = 0

func select(index: int, count: int) -> int:
	selected_index = clampi(index, 0, maxi(count - 1, 0))
	return selected_index

func move(delta: int, count: int) -> int:
	if count > 0:
		selected_index = posmod(selected_index + delta, count)
	return selected_index

func page(delta_pages: int, count: int) -> int:
	return move(delta_pages * 70, count)

func open_action() -> void:
	popup = PopupKind.ACTION
	choice = 0

func open_sort() -> void:
	popup = PopupKind.SORT
	choice = sort_mode

func close_popup() -> void:
	popup = PopupKind.NONE
	choice = 0

func navigate_popup(direction: Vector2i) -> bool:
	var key_code := 64 if direction.y < 0 else 128 if direction.y > 0 else 32 if direction.x < 0 else 16 if direction.x > 0 else 0
	var table_name := _popup_navigation_table(key_code)
	var table: Array = popup_navigation.get(table_name, [])
	if table_name == &"" or choice < 0 or choice >= table.size():
		return false
	choice = int(table[choice])
	return true

func _popup_navigation_table(key_code: int) -> StringName:
	if popup == PopupKind.ACTION:
		if key_code == 64: return &"action_up"
		if key_code == 128: return &"action_down"
	elif popup == PopupKind.SORT:
		if key_code == 64: return &"sort_up"
		if key_code == 128: return &"sort_down"
		if key_code == 32: return &"sort_left"
		if key_code == 16: return &"sort_right"
	return &""

func _load_popup_navigation() -> bool:
	var file := FileAccess.open(POPUP_NAVIGATION_PATH, FileAccess.READ)
	if file == null:
		push_warning("Recovered shop popup navigation is unavailable: %s" % POPUP_NAVIGATION_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("tables", {}) is Dictionary:
		push_warning("Recovered shop popup navigation has an invalid structure.")
		return false
	var recovered_tables: Dictionary = parsed.tables
	for raw_name: Variant in POPUP_NAVIGATION_TABLE_SIZES:
		var table_name := str(raw_name)
		var expected_size := int(POPUP_NAVIGATION_TABLE_SIZES[raw_name])
		var raw_table: Variant = recovered_tables.get(table_name, null)
		if not raw_table is Array or raw_table.size() != expected_size:
			push_warning("Recovered shop navigation table %s has the wrong size." % table_name)
			return false
		var table: Array[int] = []
		for raw_choice: Variant in raw_table:
			var next_choice := int(raw_choice)
			if next_choice < 0 or next_choice >= expected_size:
				push_warning("Recovered shop navigation table %s has an invalid choice." % table_name)
				return false
			table.append(next_choice)
		popup_navigation[StringName(table_name)] = table
	return true

func cycle_sort() -> void:
	sort_mode = posmod(sort_mode + 1, 9)

func confirm() -> Dictionary:
	if popup == PopupKind.NONE:
		open_action()
		return {"action": Action.NONE, "sound": 55}
	if popup == PopupKind.ACTION:
		if choice == 0:
			return {"action": Action.BUY_OR_SELL, "sound": 0}
		if choice == 1:
			return {"action": Action.CARD_INFO, "sound": 55}
		close_popup()
		return {"action": Action.CANCEL, "sound": 55}
	if choice == 9:
		close_popup()
		return {"action": Action.SORT_CLOSED, "sound": 55}
	sort_mode = choice
	close_popup()
	return {"action": Action.SORT_SELECTED, "sort_mode": sort_mode, "sound": 55}

func sort_method() -> int:
	var methods := sort_methods_sell if selling else sort_methods_buy
	if methods.size() != 9:
		return 28 if selling else 20
	return int(methods[clampi(sort_mode, 0, methods.size() - 1)])
