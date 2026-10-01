class_name CardPresentation
extends Control
## Godot presentation for the recovered full-card and paged-description viewer.
## The original card face is retained as an indexed PNG; UI and paging are native.

const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")
const LOCKED_DESCRIPTION_PATH := "res://resources/card_locked_description.json"
const GOLD := Color("ffdc77")
const PAPER := Color("f5e6c3")
const PANEL := Color("171817")

var definition: CardDefinition
var card_art: CardArt
var pages: Array[String] = []
var page_index := 0
var description_locked := false
var card_texture: Texture2D
var page_counter: PixelText
var page_lines: Array[PixelText] = []

func present(card: CardDefinition, art_renderer: CardArt = null, duelist_level: int = -1) -> void:
	definition = card
	card_art = art_renderer
	description_locked = duelist_level >= 0 and duelist_level < card.cost
	pages = [_load_locked_description()] if description_locked else _parse_description_pages(card.description)
	page_index = 0
	_build_view()

func previous_page() -> void:
	if pages.size() > 1:
		page_index = posmod(page_index - 1, pages.size())
		_update_page()

func next_page() -> void:
	if pages.size() > 1:
		page_index = posmod(page_index + 1, pages.size())
		_update_page()

func _build_view() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("10130f")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var card_panel := Panel.new()
	card_panel.position = Vector2(6, 4)
	card_panel.size = Vector2(78, 106)
	card_panel.add_theme_stylebox_override("panel", _panel_style(Color("33291e")))
	add_child(card_panel)
	if definition != null:
		card_texture = card_art.load_card_texture(definition.id) if card_art != null else null
		if card_texture == null and ResourceLoader.exists(definition.art_path):
			card_texture = load(definition.art_path) as Texture2D
	if card_texture != null:
		var image := TextureRect.new()
		image.texture = card_texture
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_panel.add_child(image)
	var info := Panel.new()
	info.position = Vector2(89, 4)
	info.size = Vector2(145, 146)
	info.add_theme_stylebox_override("panel", _panel_style(PANEL))
	add_child(info)
	var heading := _text_label(definition.name.to_upper(), Vector2(5, 4), Vector2(135, 12), 7, GOLD)
	info.add_child(heading)
	info.add_child(_text_label("ATK %04d   DEF %04d" % [definition.attack, definition.defense], Vector2(5, 19), Vector2(135, 8), 6, PAPER))
	info.add_child(_text_label("COST %05d" % definition.cost, Vector2(5, 29), Vector2(135, 8), 6, PAPER))
	var separator := ColorRect.new()
	separator.position = Vector2(4, 44)
	separator.size = Vector2(135, 1)
	separator.color = Color("8f7a4d")
	info.add_child(separator)
	page_lines.clear()
	page_counter = PIXEL_TEXT_SCRIPT.new()
	page_counter.position = Vector2(5, 132)
	page_counter.size = Vector2(135, 10)
	page_counter.font_color = GOLD
	info.add_child(page_counter)
	var controls := PIXEL_TEXT_SCRIPT.new()
	controls.position = Vector2(7, 153)
	controls.text = "LEFT / RIGHT PAGE   ESC BACK"
	controls.font_color = Color("c4b68e")
	controls.scale = Vector2(0.45, 0.45)
	add_child(controls)
	_update_page()

func _update_page() -> void:
	if page_counter == null:
		return
	for line in page_lines:
		line.queue_free()
	page_lines.clear()
	var info := get_child(2) as Panel
	var text_value := pages[page_index] if not pages.is_empty() else "No description available."
	var wrapped := _wrap_locked_description(text_value) if description_locked else _wrap_description(text_value, 12)
	for line_index in range(wrapped.size()):
		var line: PixelText = PIXEL_TEXT_SCRIPT.new()
		line.position = Vector2(5, 49 + line_index * 6)
		line.size = Vector2(135, 8)
		line.scale = Vector2(0.55, 0.55)
		line.font_color = PAPER
		line.text = wrapped[line_index]
		info.add_child(line)
		page_lines.append(line)
	page_counter.text = "" if description_locked else "PAGE %d / %d" % [page_index + 1, maxi(pages.size(), 1)]

func _load_locked_description() -> String:
	var file := FileAccess.open(LOCKED_DESCRIPTION_PATH, FileAccess.READ)
	if file == null:
		push_warning("Recovered locked-card description is unavailable: %s" % LOCKED_DESCRIPTION_PATH)
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("english", null) is String:
		push_warning("Recovered locked-card description has an invalid structure.")
		return ""
	return str(parsed.english)

func _wrap_locked_description(source: String) -> Array[String]:
	var lines: Array[String] = []
	for offset in range(0, source.length(), 12):
		lines.append(source.substr(offset, 12))
	return lines

func _wrap_description(source: String, line_width: int) -> Array[String]:
	var lines: Array[String] = []
	if line_width <= 0:
		return lines
	for offset in range(0, source.length(), line_width):
		lines.append(source.substr(offset, line_width))
	if lines.is_empty():
		lines.append("")
	return lines

func _parse_description_pages(source: String) -> Array[String]:
	var result: Array[String] = []
	if not source.begins_with("^"):
		var plain_text := source.split("$", false)[0]
		if not plain_text.is_empty(): result.append(plain_text)
		return result
	# ShowCardDescription consumes the two-byte '^N' page header. Values 2–9
	# select that many pages; other values retain the native one-page fallback.
	var page_count := 1
	var page_start := 2
	if source.length() > 1:
		var count_character := source.unicode_at(1)
		if count_character >= 50 and count_character <= 57:
			page_count = count_character - 48
	var page_source := source.substr(page_start).split("$", false)[0]
	var sections := page_source.split("^", true)
	for page_index_value in range(page_count):
		result.append(str(sections[page_index_value]) if page_index_value < sections.size() else "")
	return result

func _text_label(value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> PixelText:
	var label: PixelText = PIXEL_TEXT_SCRIPT.new()
	label.position = at
	label.size = dimensions
	label.text = value
	label.font_color = color
	var text_scale := float(font_size) / 8.0
	label.scale = Vector2(text_scale, text_scale)
	return label

func _panel_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("c5aa6d")
	style.set_border_width_all(1)
	style.set_content_margin_all(1)
	return style
