class_name NameEntryView
extends Control
## Godot name-entry view using LineEdit and native Controls in place of the
## GBA glyph workspace and OAM keyboard sprites.

const BACKGROUND_PATH := "res://art/screens/name-entry-background.png"
const FONT_MAPPING_PATH := "res://decompiled/build/assets/ui/font-mapping.json"
const PAGE_LABELS := ["A-Z", "a-z", "0-9", "SYMBOLS"]
const PAGE_KEYS := [
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_",
	"abcdefghijklmnopqrstuvwxyz0123456789 -_",
	"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ -_",
	"!?.,:;'+-()[]@#$%&*=/\\ \""
]
const MAX_NAME_GLYPHS := 8
const VOICEABLE_CODES := [0x834A, 0x834C, 0x834E, 0x8350, 0x8152, 0x8352, 0x8154, 0x8354, 0x8356, 0x8358, 0x835A, 0x835C, 0x835E, 0x8360, 0x8363, 0x8365, 0x8367, 0x836E, 0x8371, 0x8374, 0x8377, 0x837A, 0x82A9, 0x82AB, 0x82AD, 0x82AF, 0x82B1, 0x82B3, 0x82B5, 0x82B7, 0x82B9, 0x82BB, 0x82BD, 0x82BF, 0x82C2, 0x82C4, 0x82C6, 0x82CD, 0x82D0, 0x82D3, 0x82D6, 0x82D9]
const SEMIVOICEABLE_CODES := [0x836E, 0x8371, 0x8374, 0x8377, 0x837A, 0x82CD, 0x82D0, 0x82D3, 0x82D6, 0x82D9]

signal name_confirmed(value: String)
signal cancelled

var player_name := ""
var keyboard_page := 0
var selected_key := Vector2i.ZERO
var name_field: LineEdit
var page_button: Button
var key_buttons: Array[Button] = []
var unicode_to_encoded: Dictionary = {}
var encoded_to_unicode: Dictionary = {}
var _normalizing_input := false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_glyph_mapping()
	_build()

func begin(initial_name: String = "") -> void:
	player_name = initial_name
	if is_node_ready() and name_field != null:
		name_field.text = initial_name
		name_field.caret_column = name_field.text.length()

func accept_name() -> bool:
	var value := _compose_voice_marks(name_field.text if name_field != null else player_name)
	if value.is_empty() or value.begins_with(" ") or value.begins_with("　"):
		return false
	while value.ends_with(" ") or value.ends_with("　"):
		value = value.substr(0, value.length() - 1)
	if value.is_empty() or _glyph_count(value) > MAX_NAME_GLYPHS:
		return false
	player_name = value
	name_confirmed.emit(player_name)
	return true

func handle_key(keycode: int) -> bool:
	match keycode:
		KEY_LEFT: selected_key.x = posmod(selected_key.x - 1, 11)
		KEY_RIGHT: selected_key.x = posmod(selected_key.x + 1, 11)
		KEY_UP: selected_key.y = maxi(selected_key.y - 1, 0)
		KEY_DOWN: selected_key.y = mini(selected_key.y + 1, 6)
		KEY_PAGEUP, KEY_PAGEDOWN:
			keyboard_page = posmod(keyboard_page + (1 if keycode == KEY_PAGEDOWN else -1), PAGE_KEYS.size())
			_refresh_keyboard()
		KEY_BACKSPACE:
			if name_field != null:
				var caret := name_field.caret_column
				if caret > 0:
					name_field.delete_text(caret - 1, caret)
					name_field.caret_column = caret - 1
		KEY_ENTER, KEY_KP_ENTER: return accept_name()
		KEY_ESCAPE:
			cancelled.emit()
			return true
		_: return false
	_focus_selected_key()
	return true

func _build() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = load(BACKGROUND_PATH) as Texture2D
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(240, 160)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	name_field = LineEdit.new()
	name_field.position = Vector2(58, 7)
	name_field.size = Vector2(92, 16)
	name_field.max_length = 16 # up to eight base glyphs plus combining marks
	name_field.text = player_name
	name_field.text_changed.connect(_on_name_changed)
	add_child(name_field)
	var grid := GridContainer.new()
	grid.columns = 11
	grid.position = Vector2(15, 40)
	grid.size = Vector2(180, 84)
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	for index in range(77):
		var key_button := Button.new()
		key_button.custom_minimum_size = Vector2(16, 11)
		key_button.size = Vector2(16, 11)
		key_button.add_theme_font_size_override("font_size", 6)
		key_button.focus_mode = Control.FOCUS_ALL
		key_button.pressed.connect(_insert_key.bind(index))
		key_buttons.append(key_button)
		grid.add_child(key_button)
	page_button = Button.new()
	page_button.position = Vector2(17, 130)
	page_button.size = Vector2(42, 14)
	page_button.add_theme_font_size_override("font_size", 6)
	page_button.pressed.connect(_next_page)
	add_child(page_button)
	var delete_button := Button.new()
	delete_button.text = "DELETE"
	delete_button.position = Vector2(82, 130)
	delete_button.size = Vector2(42, 14)
	delete_button.add_theme_font_size_override("font_size", 6)
	delete_button.pressed.connect(_delete_character)
	add_child(delete_button)
	var cancel_button := Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.position = Vector2(130, 130)
	cancel_button.size = Vector2(42, 14)
	cancel_button.add_theme_font_size_override("font_size", 6)
	cancel_button.pressed.connect(func(): cancelled.emit())
	add_child(cancel_button)
	var accept_button := Button.new()
	accept_button.text = "OK"
	accept_button.position = Vector2(181, 130)
	accept_button.size = Vector2(38, 14)
	accept_button.add_theme_font_size_override("font_size", 6)
	accept_button.pressed.connect(accept_name)
	add_child(accept_button)
	_refresh_keyboard()

func _refresh_keyboard() -> void:
	if key_buttons.is_empty(): return
	var page_text: String = PAGE_KEYS[keyboard_page]
	for index in range(key_buttons.size()):
		var key := page_text.substr(index, 1) if index < page_text.length() else ""
		key_buttons[index].text = "SPACE" if key == " " else key
		key_buttons[index].disabled = key.is_empty()
	if page_button != null: page_button.text = PAGE_LABELS[keyboard_page]
	_focus_selected_key()

func _insert_key(index: int) -> void:
	var page_text: String = PAGE_KEYS[keyboard_page]
	if index >= page_text.length() or name_field == null: return
	var insertion := page_text.substr(index, 1)
	var value := name_field.text
	var candidate := _compose_voice_marks(value.insert(name_field.caret_column, insertion))
	if _glyph_count(candidate) > MAX_NAME_GLYPHS: return
	name_field.text = candidate
	name_field.caret_column = mini(name_field.caret_column + insertion.length(), candidate.length())
	name_field.grab_focus()

func _delete_character() -> void:
	if name_field == null: return
	var caret := name_field.caret_column
	if caret > 0:
		name_field.delete_text(caret - 1, caret)
		name_field.caret_column = caret - 1
		name_field.grab_focus()

func _next_page() -> void:
	keyboard_page = posmod(keyboard_page + 1, PAGE_KEYS.size())
	_refresh_keyboard()

func _focus_selected_key() -> void:
	var index := selected_key.y * 11 + selected_key.x
	if index >= 0 and index < key_buttons.size() and is_node_ready():
		key_buttons[index].grab_focus()

func _on_name_changed(value: String) -> void:
	if _normalizing_input:
		player_name = value
		return
	var normalized := _compose_voice_marks(value)
	if _glyph_count(normalized) > MAX_NAME_GLYPHS:
		normalized = normalized.substr(0, MAX_NAME_GLYPHS)
	if normalized != value and name_field != null:
		var caret := name_field.caret_column
		_normalizing_input = true
		name_field.text = normalized
		name_field.caret_column = mini(caret, normalized.length())
		_normalizing_input = false
	player_name = normalized
	queue_redraw()

func _glyph_count(value: String) -> int:
	return value.length()

func _load_glyph_mapping() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FONT_MAPPING_PATH)) if FileAccess.file_exists(FONT_MAPPING_PATH) else null
	if not parsed is Array:
		push_warning("Recovered glyph map is unavailable; kana voicing cannot be composed.")
		return
	for entry: Dictionary in parsed:
		var candidate := str(entry.get("unicode_candidate", ""))
		if candidate.length() != 1:
			continue
		var encoded := str(entry.get("encoded", "0x0")).trim_prefix("0x").hex_to_int()
		var codepoint := candidate.unicode_at(0)
		unicode_to_encoded[codepoint] = encoded
		encoded_to_unicode[encoded] = candidate

func _compose_voice_marks(value: String) -> String:
	var composed: Array[String] = []
	for index in range(value.length()):
		var character := value.substr(index, 1)
		var codepoint := character.unicode_at(0)
		var is_dakuten := codepoint in [0x3099, 0x309B]
		var is_handakuten := codepoint in [0x309A, 0x309C]
		if (is_dakuten or is_handakuten) and not composed.is_empty():
			var previous := composed.back()
			var previous_codepoint := previous.unicode_at(0)
			var previous_code := int(unicode_to_encoded.get(previous_codepoint, -1))
			var can_compose := false
			if is_dakuten:
				can_compose = previous_code in VOICEABLE_CODES
			else:
				can_compose = previous_code in SEMIVOICEABLE_CODES
			if is_dakuten and previous_code == 0x8345:
				can_compose = true
			if can_compose:
				var voiced_code := 0x8394 if is_dakuten and previous_code == 0x8345 else previous_code + (1 if is_dakuten else 2)
				if encoded_to_unicode.has(voiced_code):
					composed[composed.size() - 1] = str(encoded_to_unicode[voiced_code])
					continue
		composed.append(character)
	return "".join(composed)
