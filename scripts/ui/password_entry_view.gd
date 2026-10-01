extends Control
class_name PasswordEntryView

signal submitted(password: String)
signal canceled

const SPRITES_PATH := "res://resources/password_sprites.json"
const ENTRY_STATE_SCRIPT = preload("res://scripts/state/password_entry_state.gd")
const FRAME_INPUT_SCRIPT = preload("res://scripts/systems/frame_input.gd")

var state: PasswordEntryState = ENTRY_STATE_SCRIPT.new()
var _frame_input: FrameInput = FRAME_INPUT_SCRIPT.new()
var _password_repeat_timer: int = 0
var _password_input_edge := false
var _digits: Array = []
var _keys: Array = []
var _pressed: Array = []
var _digit_nodes: Array[TextureRect] = []
var _key_nodes: Array[TextureRect] = []
var _key_buttons: Array[Button] = []
var _digit_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPRITES_PATH))
	if not parsed is Dictionary:
		push_error("Could not load recovered password sprite data.")
		return
	_digits = parsed.get("digits", [])
	_keys = parsed.get("keys", [])
	_pressed = parsed.get("pressed", [])
	_build_view(str(parsed.get("background", "")))
	_refresh()
	grab_focus()

func _process(_delta: float) -> void:
	_frame_input.poll_actions([&"ui_up", &"ui_down", &"ui_left", &"ui_right"])
	var direction := _pressed_password_direction()
	if direction >= 0:
		_password_repeat_timer = 10
	elif _password_input_edge:
		_password_repeat_timer = 10
	else:
		if _password_repeat_timer == 0:
			direction = _held_password_direction()
			_password_repeat_timer = 3
		else:
			_password_repeat_timer -= 1
	if direction >= 0:
		state.move_key(direction)
	_password_input_edge = false
	state.tick()
	_refresh()

func _pressed_password_direction() -> int:
	# ReadPasswordKey starts with gKeysPressed, then scans low-to-high bits.
	if bool(_frame_input.pressed.get(&"ui_down", false)): return 1
	if bool(_frame_input.pressed.get(&"ui_up", false)): return 0
	if bool(_frame_input.pressed.get(&"ui_left", false)): return 2
	if bool(_frame_input.pressed.get(&"ui_right", false)): return 3
	return -1

func _held_password_direction() -> int:
	# The held-key repeat mask uses the same highest-bit priority.
	if bool(_frame_input.held.get(&"ui_down", false)): return 1
	if bool(_frame_input.held.get(&"ui_up", false)): return 0
	if bool(_frame_input.held.get(&"ui_left", false)): return 2
	if bool(_frame_input.held.get(&"ui_right", false)): return 3
	return -1

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT: pass
		KEY_BACKSPACE: state.move_digit(false)
		KEY_TAB: state.move_digit(true)
		KEY_ENTER, KEY_SPACE:
			if state.press_selected_key():
				submitted.emit(state.password())
		KEY_ESCAPE:
			canceled.emit()
		_: return
	# ReadPasswordKey resets its shared timer for any new key, including digit
	# selection and confirm/cancel inputs, before considering held-key repeats.
	_password_repeat_timer = 10
	_password_input_edge = true
	get_viewport().set_input_as_handled()
	_refresh()

func _build_view(background_path: String) -> void:
	var background := TextureRect.new()
	background.texture = load(background_path)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_digits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.index) < int(b.index)
	)
	_keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.index) < int(b.index)
	)
	_pressed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.index) < int(b.index) or (int(a.index) == int(b.index) and int(a.frame) < int(b.frame))
	)
	for slot in range(8):
		var digit_position := Vector2(56 + slot * 16, 18)
		var visual := _make_visual(_digits[slot], digit_position)
		add_child(visual)
		_digit_nodes.append(visual)
		var click := _make_click_area(_digits[slot], _select_digit.bind(slot), digit_position)
		add_child(click)
		_digit_buttons.append(click)
	for key_index in range(11):
		var normal: Dictionary = _keys[key_index]
		var visual := _make_visual(normal)
		add_child(visual)
		_key_nodes.append(visual)
		var click := _make_click_area(normal, _click_key.bind(key_index))
		add_child(click)
		_key_buttons.append(click)
	var close := Button.new()
	close.text = "×"
	close.position = Vector2(220, 0)
	close.size = Vector2(20, 20)
	close.pressed.connect(func(): canceled.emit())
	add_child(close)

func _make_visual(sprite: Dictionary, position_override: Vector2 = Vector2(-1, -1)) -> TextureRect:
	var visual := TextureRect.new()
	visual.texture = load(str(sprite.path))
	visual.position = position_override if position_override.x >= 0 else Vector2(int(sprite.position[0]), int(sprite.position[1]))
	visual.size = Vector2(int(sprite.size[0]), int(sprite.size[1]))
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_SCALE
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return visual

func _make_click_area(sprite: Dictionary, action: Callable, position_override: Vector2 = Vector2(-1, -1)) -> Button:
	var button := Button.new()
	button.position = position_override if position_override.x >= 0 else Vector2(int(sprite.position[0]), int(sprite.position[1]))
	button.size = Vector2(int(sprite.size[0]), int(sprite.size[1]))
	button.flat = true
	button.modulate = Color(1, 1, 1, 0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button

func _select_digit(slot: int) -> void:
	state.digit_index = slot
	_refresh()

func _click_key(key_index: int) -> void:
	state.choose_key(key_index)
	if state.press_selected_key():
		submitted.emit(state.password())
	_refresh()

func _refresh() -> void:
	if _digit_nodes.size() != 8 or _key_nodes.size() != 11:
		return
	for index in range(8):
		var frame_index := state.digit_frame(index)
		_digit_nodes[index].texture = load(str(_digits[frame_index].path))
	for index in range(11):
		var texture_path := str(_keys[index].path)
		if index == state.key_index and state.key_frame() > 0:
			var frame := 0 if state.key_frame() == 1 else 1
			for sprite: Dictionary in _pressed:
				if int(sprite.index) == index and int(sprite.frame) == frame:
					texture_path = str(sprite.path)
					break
		_key_nodes[index].texture = load(texture_path)
