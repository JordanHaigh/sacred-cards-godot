class_name CollectionDisplay
extends Control
## Godot collection/deck list view. GBA VBlank callbacks and VRAM uploads are
## represented by a small frame-based transition and ordinary Control redraws.

const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")
const DECK_GRAPHICS_SCRIPT := preload("res://scripts/ported/deck_builder_graphics.gd")
const ATTRIBUTE_ICON_PATH := "res://decompiled/build/assets/duel/hud-attribute-%d.png"
const TYPE_ICON_PATH := "res://decompiled/build/assets/duel/hud-type-%d.png"
const FRAMED_MINIATURE_PATH := "res://decompiled/build/assets/cards/%04d.framed.png"
const DEFAULT_DETAIL_ATLAS := preload("res://art/ui/deck-builder/detail-mode-0.png")
const GOLD := Color("ffdc77")
const PAPER := Color("f5e6c3")

enum DisplayStage { IDLE, INITIALIZE, SHOW, ACTIVE }

signal card_selected(index: int)
signal stage_changed(stage: int)
signal graphics_operations_requested(operations: Array[StringName])

var card_database: CardDatabase
var card_ids: Array[int] = []
var selected_index := 0
var deck_view := false
var detail_mode := 0
var language_id := 0
var deck_graphics: DeckBuilderGraphics
var display_stage: int = DisplayStage.IDLE
var _transition_running := false
var _transition_stages: Array[int] = []
var _transition_index := 0
var _ascii_glyphs: Dictionary = {}

func present(cards: Array[int], selected: int, database: CardDatabase, editing_deck: bool, mode: int = 0, selected_language: int = 0, screen_entry: bool = true) -> void:
	card_ids = cards.duplicate()
	selected_index = selected
	card_database = database
	deck_view = editing_deck
	detail_mode = mode
	language_id = clampi(selected_language, 0, 5)
	deck_graphics = DECK_GRAPHICS_SCRIPT.new()
	_ascii_glyphs = PIXEL_TEXT_SCRIPT.load_ascii_glyphs()
	_render_rows()
	if not screen_entry:
		display_stage = DisplayStage.ACTIVE
		stage_changed.emit(display_stage)
		return
	if not _transition_running:
		_transition_running = true
		_transition_stages = [DisplayStage.INITIALIZE, DisplayStage.SHOW]
		_transition_index = 0
		_set_stage(_transition_stages[0])
		get_tree().process_frame.connect(_advance_transition, CONNECT_ONE_SHOT)

func _advance_transition() -> void:
	_transition_index += 1
	if _transition_index >= _transition_stages.size():
		_transition_running = false
		display_stage = DisplayStage.ACTIVE
		stage_changed.emit(display_stage)
		queue_redraw()
		return
	_set_stage(_transition_stages[_transition_index])
	get_tree().process_frame.connect(_advance_transition, CONNECT_ONE_SHOT)

func _set_stage(stage: int) -> void:
	display_stage = stage
	stage_changed.emit(stage)
	var operations: Array[StringName] = []
	match stage:
		DisplayStage.INITIALIZE:
			operations = [&"initialize_windows", &"configure_background_layers", &"upload_background_offsets"]
		DisplayStage.SHOW:
			operations = [&"upload_oam", &"upload_palettes", &"show_display"]
	if not operations.is_empty():
		graphics_operations_requested.emit(operations)
	queue_redraw()

func _render_rows() -> void:
	for child in get_children():
		child.queue_free()
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
		var row_content := Control.new()
		row_content.position = Vector2(4, row_y)
		row_content.size = Vector2(232, 22)
		row_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row_content)
		var framed_path := FRAMED_MINIATURE_PATH % card_id
		if card_id > 0 and ResourceLoader.exists(framed_path):
			var icon := TextureRect.new()
			icon.texture = load(framed_path) as Texture2D
			# deck_builder_graphics.c writes five 32x32 OBJ records at x=210,
			# y=12+32*row; the last record is naturally clipped by the screen.
			icon.position = Vector2(206, 12 + row * 32 - row_y)
			icon.size = Vector2(32, 32)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_content.add_child(icon)
		var title_record := card_database.get_localized_card_name_record(card_id, language_id) if definition != null and card_database != null else {}
		var localized_name := str(title_record.get("text", "UNKNOWN CARD"))
		var name_glyph_limit := 22 if deck_view else 18
		var title := localized_name.left(name_glyph_limit)
		var title_glyphs: PackedInt32Array = title_record.get("glyph_indices", PackedInt32Array())
		var row_text := "%04d  %s" % [card_id, title]
		var row_glyphs := _row_title_glyph_indices(card_id, title_glyphs, title.length())
		row_content.add_child(_pixel_text(row_text, Vector2(29, 6), GOLD if picked else PAPER, 6, row_glyphs))
		if detail_mode == DeckBuilderGraphics.DETAIL_DEFAULT_ART:
			_add_default_detail_art(row_content, row)
		elif definition != null:
			if detail_mode == DeckBuilderGraphics.DETAIL_ATTRIBUTE_TYPE:
				_add_attribute_type_icons(row_content, definition)
			else:
				row_content.add_child(_pixel_text(_detail_for_card(definition), Vector2(29, 14), Color("c4b68e"), 5))
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

func _add_attribute_type_icons(parent: Control, card: CardDefinition) -> void:
	var type_path := TYPE_ICON_PATH % card.card_type
	var attribute_path := ATTRIBUTE_ICON_PATH % card.attribute
	_add_detail_icon(parent, type_path, 212.0)
	_add_detail_icon(parent, attribute_path, 232.0)

func _add_default_detail_art(parent: Control, visible_row: int) -> void:
	var art := TextureRect.new()
	art.texture = DEFAULT_DETAIL_ATLAS
	art.region_enabled = true
	art.region_rect = Rect2(visible_row * 48, 0, 48, 16)
	art.position = Vector2(156, 3)
	art.size = Vector2(48, 16)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)

func _add_detail_icon(parent: Control, texture_path: String, right_edge: float) -> void:
	var texture := load(texture_path) as Texture2D if ResourceLoader.exists(texture_path) else null
	if texture == null:
		push_error("Missing recovered deck detail icon: %s" % texture_path)
		return
	var icon := TextureRect.new()
	icon.texture = texture
	icon.position = Vector2(right_edge - texture.get_width(), 3)
	icon.size = texture.get_size()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)

func _row_title_glyph_indices(card_id: int, title_glyphs: PackedInt32Array, title_length: int) -> PackedInt32Array:
	if title_glyphs.size() < title_length:
		return PackedInt32Array()
	var result := PackedInt32Array()
	for character in ("%04d  " % card_id):
		result.append(int(_ascii_glyphs.get(character.unicode_at(0), -1)))
	result.append_array(title_glyphs.slice(0, title_length))
	return result

func _pixel_text(value: String, at: Vector2, color: Color, nominal_size: int, glyph_indices: PackedInt32Array = PackedInt32Array()) -> PixelText:
	var label: PixelText = PIXEL_TEXT_SCRIPT.new()
	label.position = at
	label.text = value
	if not glyph_indices.is_empty(): label.set_glyph_indices(glyph_indices)
	label.font_color = color
	var pixel_scale := float(nominal_size) / 8.0
	label.scale = Vector2(pixel_scale, pixel_scale)
	return label
