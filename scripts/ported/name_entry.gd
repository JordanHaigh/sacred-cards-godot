class_name NameEntryView
extends Control
## Godot name-entry view using LineEdit and native Controls in place of the
## GBA glyph workspace and OAM keyboard sprites.

const BACKGROUND_PATH := "res://art/screens/name-entry-background.png"
const PAGE_LABELS := ["A-Z", "a-z", "0-9", "SYMBOLS"]
const PAGE_KEYS := [
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_",
	"abcdefghijklmnopqrstuvwxyz0123456789 -_",
	"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ -_",
	"!?.,:;'+-()[]@#$%&*=/\\ \""
]
const MAX_NAME_GLYPHS := 8

signal name_confirmed(value: String)
signal cancelled

var player_name := ""
var keyboard_page := 0
var selected_key := Vector2i.ZERO
var name_field: LineEdit
var page_button: Button
var key_buttons: Array[Button] = []

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func begin(initial_name: String = "") -> void:
	player_name = initial_name
	if is_node_ready() and name_field != null:
		name_field.text = initial_name
		name_field.caret_column = name_field.text.length()

func accept_name() -> bool:
	var value := name_field.text.strip_edges() if name_field != null else player_name.strip_edges()
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
	var codepoint := insertion.unicode_at(0)
	var combining := codepoint >= 0x0300 and codepoint <= 0x036F
	if _glyph_count(value) >= MAX_NAME_GLYPHS and not combining: return
	name_field.insert_text_at_caret(insertion)
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
	player_name = value
	queue_redraw()

func _glyph_count(value: String) -> int:
	var count := 0
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if not (codepoint >= 0x0300 and codepoint <= 0x036F) and codepoint not in [0x3099, 0x309A]:
			count += 1
	return count
