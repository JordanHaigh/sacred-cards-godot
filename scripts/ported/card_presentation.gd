class_name CardPresentation
extends Control
## Godot presentation for the recovered full-card and paged-description viewer.
## Recovered frame art, card data and descriptions compose through Godot controls.

const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")
const LOCKED_DESCRIPTION_PATH := "res://resources/card_locked_description.json"
const FULL_CARD_FRAME_PATH := "res://decompiled/build/assets/ui/frame-%d.png"
const FULL_CARD_TYPE_PATH := "res://decompiled/build/assets/ui/type-%02d.png"
const FULL_CARD_SUMMON_PATH := "res://decompiled/build/assets/ui/summon-%02d.png"
const LEVEL_STAR_TEXTURE := preload("res://decompiled/build/assets/duel/hud-level.png")
const GOLD := Color("ffdc77")
const PAPER := Color("f5e6c3")

var definition: CardDefinition
var card_art: CardArt
var language_id := 0
var localized_title := ""
var pages: Array[String] = []
var page_index := 0
var description_locked := false
var card_texture: Texture2D
var page_lines: Array[PixelText] = []

func present(card: CardDefinition, art_renderer: CardArt = null, duelist_level: int = -1, selected_language: int = 0, card_name: String = "", card_description: String = "") -> void:
	definition = card
	card_art = art_renderer
	language_id = clampi(selected_language, 0, 5)
	localized_title = card_name if not card_name.is_empty() else card.name
	description_locked = duelist_level >= 0 and duelist_level < card.cost
	var selected_description := card_description if not card_description.is_empty() else card.description
	pages = [_load_locked_description()] if description_locked else _parse_description_pages(selected_description)
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
	var frame_path := FULL_CARD_FRAME_PATH % (definition.frame_index if definition != null else 0)
	if ResourceLoader.exists(frame_path):
		var frame := TextureRect.new()
		frame.texture = load(frame_path) as Texture2D
		frame.position = Vector2.ZERO
		frame.size = Vector2(112, 152)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
	if definition != null:
		card_texture = card_art.load_card_texture(definition.id) if card_art != null else null
		if card_texture == null and ResourceLoader.exists(definition.art_path):
			card_texture = load(definition.art_path) as Texture2D
	if card_texture != null:
		var image := TextureRect.new()
		image.texture = card_texture
		image.position = Vector2(16, 40)
		image.size = Vector2(80, 80)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
	if definition != null:
		_add_level_stars()
		_add_full_card_icon(FULL_CARD_TYPE_PATH % definition.card_type, Vector2(16, 128))
		_add_full_card_icon(FULL_CARD_SUMMON_PATH % definition.attribute, Vector2(32, 128))
		add_child(_text_label(_full_card_title(), Vector2(8, 7), Vector2(96, 9), 8, GOLD))
		add_child(_text_label("%05d" % definition.attack, Vector2(56, 128), Vector2(40, 8), 8, PAPER))
		add_child(_text_label("%05d" % definition.defense, Vector2(56, 136), Vector2(40, 8), 8, PAPER))
		add_child(_text_label(definition.type_name, Vector2(165, 24), Vector2(74, 8), 6, PAPER))
		add_child(_text_label(definition.summon_name, Vector2(165, 42), Vector2(74, 8), 6, PAPER))
		add_child(_text_label("%05d" % definition.cost, Vector2(165, 59), Vector2(74, 8), 6, PAPER))
	page_lines.clear()
	_update_page()

func _add_level_stars() -> void:
	# DrawFullCardLevel caps at twelve and overlays the rightmost N slots in
	# the frame map's twelve-cell row. Reuse the recovered 8x8 level-star tile.
	var star_count := mini(maxi(definition.level, 0), 12)
	for slot in range(12 - star_count, 12):
		var star := TextureRect.new()
		star.texture = LEVEL_STAR_TEXTURE
		star.position = Vector2(8 + slot * 8, 24)
		star.size = Vector2(8, 8)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_SCALE
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)

func _add_full_card_icon(path: String, at: Vector2) -> void:
	if not ResourceLoader.exists(path):
		return
	var icon := TextureRect.new()
	icon.texture = load(path) as Texture2D
	icon.position = at
	icon.size = icon.texture.get_size()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

func _update_page() -> void:
	for line in page_lines:
		line.queue_free()
	page_lines.clear()
	var text_value := pages[page_index] if not pages.is_empty() else "No description available."
	var wrapped := _wrap_locked_description(text_value) if description_locked else _wrap_description(text_value, 12)
	for line_index in range(wrapped.size()):
		var line: PixelText = PIXEL_TEXT_SCRIPT.new()
		line.position = Vector2(120, 80 + line_index * 8)
		line.size = Vector2(120, 8)
		line.font_color = PAPER
		line.text = wrapped[line_index]
		add_child(line)
		page_lines.append(line)

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

func _full_card_title() -> String:
	if definition == null:
		return ""
	var source_name := localized_title if not localized_title.is_empty() else definition.name
	if language_id == 0 and definition.id in [364, 670]:
		# Native DrawFullCardName emits blank glyph 0x4481 at slot 1, then
		# advances four English source bytes before resuming at slot 2.
		return source_name.substr(0, 1) + " " + source_name.substr(5, 8)
	return source_name.substr(0, 10)

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
