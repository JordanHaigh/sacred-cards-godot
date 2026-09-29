class_name ShopMenuState
extends RefCounted
## Shop navigation, popup and sort state recovered from shop_menu.c.

enum PopupKind { NONE, ACTION, SORT }
enum Action { NONE, BUY_OR_SELL, CARD_INFO, CANCEL, SORT_SELECTED, SORT_CLOSED }

const SORT_METHODS_BUY_PATH := "res://decompiled/build/assets/player-menus/shop.buy-sort-methods.bin"
const SORT_METHODS_SELL_PATH := "res://decompiled/build/assets/player-menus/shop.sell-sort-methods.bin"

var popup: PopupKind = PopupKind.NONE
var choice := 0
var sort_mode := 0
var selected_index := 0
var selling := false
var sort_methods_buy := PackedByteArray()
var sort_methods_sell := PackedByteArray()

func _init() -> void:
	sort_methods_buy = FileAccess.get_file_as_bytes(SORT_METHODS_BUY_PATH)
	sort_methods_sell = FileAccess.get_file_as_bytes(SORT_METHODS_SELL_PATH)

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

func navigate_popup(direction: Vector2i) -> void:
	if popup == PopupKind.ACTION:
		choice = posmod(choice + direction.y, 3)
	elif popup == PopupKind.SORT:
		var next := choice
		if direction.x < 0: next -= 1
		elif direction.x > 0: next += 1
		elif direction.y < 0: next -= 2
		elif direction.y > 0: next += 2
		# The recovered sort cursor is a 2-column, 5-row grid and uses
		# per-direction transition tables. This bounded cursor keeps the
		# Godot menu usable until those table values are recovered.
		choice = clampi(next, 0, 9)

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
		return {"action": Action.CANCEL, "sound": 56}
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
