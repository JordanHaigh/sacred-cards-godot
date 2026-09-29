extends RefCounted
class_name SceneScriptDialogue

## Dialogue state machine from script_dialogue.c. Pixel placement and glyph
## rasterization belong to PixelText; this model emits content and cursor data.
signal glyph_requested(code: int, position: int, highlighted: bool)
signal text_clear_requested
signal audio_requested(audio_id: int)
signal dialogue_finished

const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")
const ADVANCE_MASK := 0x103
const GLYPH_NEXT := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 55]
const CHOICE_LINE_POSITIONS := [28, 28, 0, 0]

var glyph_codes: Dictionary[int, int] = {}
var choice_next_positions: PackedInt32Array = PackedInt32Array(GLYPH_NEXT)
var dialogue_next_positions: PackedInt32Array = PackedInt32Array(GLYPH_NEXT)
var card_name_provider: Callable
var player_name := ""
var wait_counter := 0
var selection := 0
var state: Dictionary = {}

func _init() -> void:
	var ascii_glyphs: Dictionary = PIXEL_TEXT_SCRIPT.GLYPHS
	for codepoint: Variant in ascii_glyphs:
		glyph_codes[int(codepoint)] = int(ascii_glyphs[codepoint])

func configure(glyph_mapping: Dictionary, choice_positions: PackedInt32Array, dialogue_positions: PackedInt32Array, card_provider: Callable = Callable()) -> void:
	glyph_codes.clear()
	for key: Variant in glyph_mapping: glyph_codes[int(key)] = int(glyph_mapping[key])
	choice_next_positions = choice_positions.duplicate()
	dialogue_next_positions = dialogue_positions.duplicate()
	card_name_provider = card_provider

func reset(script_state: Dictionary, name: String = "") -> void:
	state = script_state
	player_name = name
	wait_counter = 0
	selection = 0

func handle_input(pressed_mask: int, horizontal: int = 0, vertical: int = 0) -> void:
	if state.is_empty(): return
	match StringName(state.get("mode", &"text")):
		&"wait_input": _wait_for_advance(pressed_mask)
		&"binary_choice": _binary_choice_input(pressed_mask, horizontal, vertical)
		&"free_choice": _free_choice_input(pressed_mask, vertical)

func tick_wait_cursor() -> void:
	if state.get("mode") != &"wait_input": return
	if wait_counter == 0: glyph_requested.emit(0xA081, int(state.get("glyph_position", 0)), false)
	elif wait_counter == 15: glyph_requested.emit(0x4081, int(state.get("glyph_position", 0)), false)
	wait_counter = 0 if wait_counter == 29 else (wait_counter + 1) & 0xFFFF

func write_plain_token(token: Dictionary) -> bool:
	var text := String(token.get("text", ""))
	var supported := true
	for character in text:
		var codepoint := character.unicode_at(0)
		var glyph := int(glyph_codes.get(codepoint, -1))
		if glyph < 0:
			supported = false
			continue
		glyph_requested.emit(glyph, int(state.get("glyph_position", 0)), false)
		_advance_glyph()
	state.speaking = true
	state.dirty = true
	return supported

func write_player_name() -> bool:
	return _write_embedded_text(player_name, int(state.get("embedded_text_index", 0)), true)

func write_card_name(card_id: int, language: int = 0) -> bool:
	if not card_name_provider.is_valid(): return false
	var value: Variant = card_name_provider.call(card_id, language)
	return _write_embedded_text(String(value), int(state.get("embedded_text_index", 0)), false)

func _write_embedded_text(text: String, index: int, _is_player_name: bool) -> bool:
	if index < 0 or index >= text.length():
		state.mode = &"text"
		return false
	var codepoint := text.unicode_at(index)
	var glyph := int(glyph_codes.get(codepoint, codepoint if codepoint >= 0x80 else -1))
	if glyph < 0: return false
	glyph_requested.emit(glyph, int(state.get("glyph_position", 0)), false)
	state.embedded_text_index = index + 1
	state.dirty = true
	_advance_glyph()
	if int(state.embedded_text_index) >= text.length(): state.mode = &"text"
	return true

func _wait_for_advance(pressed_mask: int) -> void:
	if (pressed_mask & ADVANCE_MASK) == 0: return
	audio_requested.emit(202)
	_finish_embedded_input()

func _binary_choice_input(pressed_mask: int, horizontal: int, vertical: int) -> void:
	if (pressed_mask & ADVANCE_MASK) != 0:
		audio_requested.emit(55)
		state.branch_flags = int(state.get("branch_flags", 0)) & 0x7F
		_finish_embedded_input()
		return
	# The recovered handler checks both direction masks independently. If both
	# are pressed, the second check observes any change made by the first.
	var flags := int(state.get("branch_flags", 0))
	if (horizontal < 0 or vertical < 0) and (flags & 0x7F) == 1:
		audio_requested.emit(54)
		flags &= 0x80
	if (horizontal > 0 or vertical > 0) and (flags & 0x7F) == 0:
		audio_requested.emit(54)
		flags |= 1
	state.branch_flags = flags
	selection = flags & 1
	var first_position := 0x20 if (flags & 0x80) != 0 else 0x720
	var second_position := 0x720 if (flags & 0x80) != 0 else 0xA40
	var first_glyph := 0x4081 if selection != 0 else 0x7281
	var second_glyph := 0x7281 if selection != 0 else 0x4081
	glyph_requested.emit(first_glyph, first_position, selection != 0)
	glyph_requested.emit(second_glyph, second_position, selection == 0)

func _free_choice_input(pressed_mask: int, vertical: int) -> void:
	if vertical != 0:
		var current := int(state.get("branch_flags", 0)) & 1
		var next := 1 if vertical > 0 else 0
		if current != next:
			state.branch_flags = (int(state.get("branch_flags", 0)) & 0x80) | next
			audio_requested.emit(54)
	if (pressed_mask & ADVANCE_MASK) == 0: return
	state.branch_flags = int(state.get("branch_flags", 0)) & 0x7F
	_finish_embedded_input()

func _finish_embedded_input() -> void:
	state.mode = &"text"
	state.wait_counter = 0
	text_clear_requested.emit()
	dialogue_finished.emit()

func _advance_glyph() -> void:
	var table := choice_next_positions if int(state.get("choice_layout", 0)) == 1 else dialogue_next_positions
	var position := int(state.get("glyph_position", 0))
	if position >= 0 and position < table.size(): state.glyph_position = table[position]
