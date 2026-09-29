class_name CollectionDisplay
extends Control
## Godot collection/deck list view. GBA VBlank callbacks and VRAM uploads are
## represented by a small frame-based transition and ordinary Control redraws.

const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")
const DECK_GRAPHICS_SCRIPT := preload("res://scripts/ported/deck_builder_graphics.gd")
const GOLD := Color("ffdc77")
const PAPER := Color("f5e6c3")

enum DisplayStage { IDLE, INITIALIZE, SHOW, RESTORE, RESTORE_PALETTES, ACTIVE }

signal card_selected(index: int)
signal stage_changed(stage: int)
signal graphics_operations_requested(operations: Array[StringName])

var card_database: CardDatabase
var card_ids: Array[int] = []
var selected_index := 0
var deck_view := false
var detail_mode := 0
var deck_graphics: DeckBuilderGraphics
var display_stage: int = DisplayStage.IDLE
var _transition_running := false
var _transition_stages: Array[int] = []
var _transition_index := 0

func present(cards: Array[int], selected: int, database: CardDatabase, editing_deck: bool, mode: int = 0) -> void:
	card_ids = cards.duplicate()
	selected_index = selected
	card_database = database
	deck_view = editing_deck
	detail_mode = mode
	deck_graphics = DECK_GRAPHICS_SCRIPT.new()
	_render_rows()
	if not _transition_running:
		_transition_running = true
		_transition_stages = [DisplayStage.INITIALIZE, DisplayStage.SHOW, DisplayStage.RESTORE]
		if deck_view:
			_transition_stages.append(DisplayStage.RESTORE_PALETTES)
		_transition_stages.append(DisplayStage.ACTIVE)
		_transition_index = 0
		_set_stage(_transition_stages[0])
		get_tree().process_frame.connect(_advance_transition, CONNECT_ONE_SHOT)

func _advance_transition() -> void:
	_transition_index += 1
	if _transition_index >= _transition_stages.size():
		_transition_running = false
		return
	_set_stage(_transition_stages[_transition_index])
	get_tree().process_frame.connect(_advance_transition, CONNECT_ONE_SHOT)

func _set_stage(stage: int) -> void:
	display_stage = stage
	stage_changed.emit(stage)
	if deck_view and deck_graphics != null:
		var source_stage := _source_stage_for_control_stage(stage)
		var operations := deck_graphics.stage_operations(source_stage)
		graphics_operations_requested.emit(operations)
		if operations.has(&"draw_cards") or operations.has(&"draw_details"):
			_render_rows()
	queue_redraw()

func _source_stage_for_control_stage(stage: int) -> int:
	match stage:
		DisplayStage.INITIALIZE: return 0
		DisplayStage.SHOW: return 2
		DisplayStage.RESTORE: return 3
		DisplayStage.RESTORE_PALETTES: return 7
		DisplayStage.ACTIVE: return 5
	return -1

func _render_rows() -> void:
	for child in get_children():
		child.queue_free()
	var heading := _pixel_text("%s  %02d" % ["DECK" if deck_view else "COLLECTION", card_ids.size()], Vector2(7, 24), GOLD, 7)
	add_child(heading)
	for row in range(5):
		var item_index := selected_index + row - 2
		if deck_view:
			if item_index < 0 or item_index >= card_ids.size():
				continue
		elif card_ids.is_empty():
			continue
		else:
			item_index = posmod(item_index, card_ids.size())
		var card_id := card_ids[item_index]
		var definition := card_database.get_card(card_id) if card_database != null else null
		var row_y := 34 + row * 24
		var picked := item_index == selected_index
		var row_panel := Panel.new()
		row_panel.position = Vector2(4, row_y)
		row_panel.size = Vector2(232, 22)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("293126", 0.92) if picked else Color("101714", 0.72)
		style.border_color = GOLD if picked else Color("756849")
		style.set_border_width_all(1 if picked else 0)
		row_panel.add_theme_stylebox_override("panel", style)
		add_child(row_panel)
		if definition != null and ResourceLoader.exists(definition.miniature_path):
			var icon := TextureRect.new()
			icon.texture = load(definition.miniature_path) as Texture2D
			icon.position = Vector2(3, -1)
			icon.size = Vector2(22, 22)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_panel.add_child(icon)
		var title := definition.name if definition != null else "UNKNOWN CARD"
		row_panel.add_child(_pixel_text("%04d  %s" % [card_id, title.to_upper()], Vector2(29, 6), GOLD if picked else PAPER, 6))
		if deck_view and definition != null:
			row_panel.add_child(_pixel_text(_detail_for_card(definition), Vector2(29, 14), Color("c4b68e"), 5))
		var pick := Button.new()
		pick.position = Vector2(4, row_y)
		pick.size = Vector2(232, 22)
		pick.flat = true
		pick.modulate = Color(1, 1, 1, 0)
		pick.pressed.connect(_emit_card_selected.bind(item_index))
		add_child(pick)
	if deck_view and not card_ids.is_empty():
		var thumb := ColorRect.new()
		thumb.position = Vector2(233, 25 + deck_graphics.scrollbar_offset(selected_index, card_ids.size()))
		thumb.size = Vector2(3, 8)
		thumb.color = GOLD
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(thumb)

func _emit_card_selected(index: int) -> void:
	card_selected.emit(index)

func _detail_for_card(card: CardDefinition) -> String:
	return deck_graphics.detail_text(card, detail_mode)

func _pixel_text(value: String, at: Vector2, color: Color, nominal_size: int) -> PixelText:
	var label: PixelText = PIXEL_TEXT_SCRIPT.new()
	label.position = at
	label.text = value
	label.font_color = color
	var pixel_scale := float(nominal_size) / 8.0
	label.scale = Vector2(pixel_scale, pixel_scale)
	return label
