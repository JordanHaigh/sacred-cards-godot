class_name PreDuelDisplay
extends Control
## Godot Control for the pre-duel five-card wager list and its popup menus.
## The recovered wager backdrop is supplied by the owning screen layer.

const GRAPHICS_SCRIPT = preload("res://scripts/ported/pre_duel_graphics.gd")
const ROW_HEIGHTS := [14, 14, 20, 14, 14]
const ROW_Y := [37, 53, 70, 93, 109]
const ACTION_LABELS := ["CARD INFO", "WAGER CARD", "CANCEL"]
const SPECIAL_LABELS := ["KEEP SELECTING", "WAGER THIS CARD"]
const NO_WAGER_LABELS := ["RETURN TO LIST", "DUEL WITHOUT WAGER"]
const SORT_LABELS := ["NUMBER", "NAME", "ATTACK", "DEFENSE", "TYPE", "ATTRIBUTE", "OWNED", "COST", "LEVEL", "CANCEL"]
const PAPER := Color("f5e6c3")
const GOLD := Color("ffdc77")

signal row_selected(row: int)
signal popup_selected(choice: int)

var menu_state: PreDuelMenuState
var database: CardDatabase
var deck: Array[int] = []
var graphics: PreDuelGraphics
var deck_capacity := 0
var deck_cost := 0

func present(menu: PreDuelMenuState, card_database: CardDatabase, player_deck: Array[int], capacity: int = 0, current_cost: int = 0) -> void:
	menu_state = menu
	database = card_database
	deck = player_deck.duplicate()
	deck_capacity = capacity
	deck_cost = current_cost
	graphics = GRAPHICS_SCRIPT.new(database)
	queue_redraw()

func _draw() -> void:
	if menu_state == null or database == null: return
	_draw_header()
	_draw_list()
	_draw_scrollbar()
	_draw_popup()

func _draw_header() -> void:
	var selected_id := menu_state.selected_card_id()
	var selected := database.get_card(selected_id)
	_draw_text("%05d" % deck_capacity, Vector2(108, 15), 6, GOLD)
	_draw_text("%02d" % deck.size(), Vector2(210, 15), 6, GOLD)
	if selected != null:
		_draw_text("%05d" % deck_cost, Vector2(157, 15), 5, PAPER)

func _draw_list() -> void:
	for row: Dictionary in graphics.build_rows(menu_state, deck):
		var row_index := int(row.row)
		var y := int(row.y)
		var color := GOLD if bool(row.selected) else PAPER
		var owned := int(row.owned_count)
		if owned == 0: color = Color("9a9384") if not bool(row.selected) else Color("c9ad69")
		var label := "%03d %s" % [int(row.card_id), str(row.name).left(18)]
		_draw_text(label, Vector2(9, y + 8), 6, color)
		var details: Dictionary = row.detail
		if menu_state.view_mode == 1:
			_draw_text("%s %04d  %s %04d" % [str(details.left_label), int(details.left_value), str(details.right_label), int(details.right_value)], Vector2(112, y + 8), 5, color)
		elif menu_state.view_mode == 2:
			_draw_text("%s %02d %s %02d" % [str(details.left_label), int(details.left_value), str(details.right_label), int(details.right_value)], Vector2(134, y + 8), 5, color)
		elif menu_state.view_mode == 3:
			_draw_text("%s %03d" % [str(details.left_label), int(details.left_value)], Vector2(151, y + 8), 5, color)
		_draw_text("%02d/%02d" % [owned, int(row.deck_count)], Vector2(187, y + 8), 4, color)
		var card := database.get_card(int(row.card_id))
		if card != null and ResourceLoader.exists(card.miniature_path):
			draw_texture_rect(load(card.miniature_path) as Texture2D, Rect2(211, y, 24, 24), false, Color.WHITE if owned > 0 else Color(0.45, 0.45, 0.45))
		if bool(row.selected):
			draw_rect(Rect2(5, y - 1, 203, ROW_HEIGHTS[row_index]), GOLD, false, 1.0)

func _draw_scrollbar() -> void:
	var y := 35 + graphics.scrollbar_offset(menu_state.selected_index)
	draw_rect(Rect2(235, 35, 2, 91), Color("433e32"), true)
	draw_rect(Rect2(234, y, 4, 6), GOLD, true)

func _draw_popup() -> void:
	if menu_state.popup == PreDuelMenuState.PopupKind.NONE: return
	var box := Rect2(55, 43, 130, 72)
	draw_rect(box, Color(0.05, 0.06, 0.07, 0.96), true)
	draw_rect(box, GOLD, false, 1.0)
	var labels: Array = []
	match menu_state.popup:
		PreDuelMenuState.PopupKind.ACTION: labels = ACTION_LABELS
		PreDuelMenuState.PopupKind.SPECIAL_WAGER: labels = SPECIAL_LABELS
		PreDuelMenuState.PopupKind.NO_WAGER: labels = NO_WAGER_LABELS
		PreDuelMenuState.PopupKind.SORT: labels = SORT_LABELS
	if menu_state.popup == PreDuelMenuState.PopupKind.SORT:
		for index in range(labels.size()):
			var column := index % 2
			var row := floori(float(index) / 2.0)
			var at := Vector2(63 + column * 60, 52 + row * 11)
			_draw_text((">" if index == menu_state.choice else " ") + str(labels[index]), at, 5, GOLD if index == menu_state.choice else PAPER)
	else:
		for index in range(labels.size()):
			var at := Vector2(68, 57 + index * 16)
			_draw_text(("> " if index == menu_state.choice else "  ") + str(labels[index]), at, 7, GOLD if index == menu_state.choice else PAPER)

func _draw_text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	if menu_state != null and menu_state.popup != PreDuelMenuState.PopupKind.NONE:
		var choice_row := floori((event.position.y - 52) / 11.0)
		var choice_column := floori((event.position.x - 63) / 60.0)
		var selected_choice := choice_row * 2 + choice_column if menu_state.popup == PreDuelMenuState.PopupKind.SORT else floori((event.position.y - 57) / 16.0)
		if selected_choice >= 0:
			popup_selected.emit(selected_choice)
			accept_event()
		return
	for row_index in range(5):
		var row_y: int = ROW_Y[row_index]
		if event.position.y >= row_y - 2 and event.position.y <= row_y + ROW_HEIGHTS[row_index]:
			row_selected.emit(row_index)
			accept_event()
			return
