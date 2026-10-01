class_name DuelTextPresenter
extends RefCounted
## Resumable text VM port of duel_text.c. It yields plain Godot text and pause
## state; a Control/PackedScene can render it without exposing tile addresses.

enum State { TEXT, WAIT_FOR_INPUT, CARD_NAME, PLAYER_NAME, NUMBER }

const NATIVE_ASCII_WHITELIST := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz !\"%',-.:;?"
const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")

signal text_changed(value: String, glyph_position: int, wait_state: bool)
signal glyph_requested(glyph_index: int, glyph_position: int, character: String, substitution: bool)
signal text_finished

var card_database: CardDatabase
var language := 0
var raw_text := ""
var cursor := 0
var glyph_position := 0
var state: State = State.TEXT
var blink := 0
var card_id := 0
var other_card_id := 0
var number := 0
var other_number := 0
var player_name := ""
var working_value := 0
var substitution := ""
var substitution_cursor := 0
var substitution_glyph_indices := PackedInt32Array()
var ascii_glyph_indices: Dictionary = {}
var unicode_glyph_indices: Dictionary = {}
var output := ""
var unresolved_wrap_context := false

func _init(database: CardDatabase = null) -> void:
	card_database = database
	ascii_glyph_indices = PIXEL_TEXT_SCRIPT.load_ascii_glyphs()
	var path := "res://decompiled/build/assets/ui/font-mapping.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if parsed is Array:
		for entry: Variant in parsed:
			if not entry is Dictionary: continue
			var candidate := str(entry.get("unicode_candidate", ""))
			if candidate.length() == 1:
				unicode_glyph_indices[candidate.unicode_at(0)] = int(entry.get("glyph_index", -1))

func begin(text: String, card: int = 0, other: int = 0, value: int = 0, other_value: int = 0, selected_language: int = 0, owner_name: String = "") -> void:
	raw_text = select_language_segment(text, selected_language)
	card_id = card & 0xFFFF
	other_card_id = other & 0xFFFF
	number = value & 0xFFFF
	other_number = other_value & 0xFFFF
	player_name = owner_name
	language = selected_language
	cursor = 0
	glyph_position = 0
	state = State.TEXT
	blink = 0
	working_value = 0
	substitution = ""
	substitution_cursor = 0
	substitution_glyph_indices = PackedInt32Array()
	output = ""
	unresolved_wrap_context = false
	text_changed.emit(output, glyph_position, false)
	if raw_text.is_empty(): text_finished.emit()

## Advances one VM operation/glyph. Text additions are Unicode strings; the
## old two-byte glyph codes are handled by the chosen Godot font resource.
func step() -> Dictionary:
	if cursor >= raw_text.length() and state == State.TEXT:
		return _finish()
	if state == State.WAIT_FOR_INPUT:
		blink = (blink + 1) % 30
		return {"waiting": true, "blink_on": blink == 1 or blink == 16, "glyph_position": glyph_position}
	if state in [State.CARD_NAME, State.PLAYER_NAME, State.NUMBER]:
		return _step_substitution()
	var character := raw_text.substr(cursor, 1)
	if character == "$":
		cursor += _next_language_segment_length(raw_text, cursor, language)
		return {"waiting": false, "language_segment": true}
	if character == "#" and cursor + 1 < raw_text.length():
		cursor += 1
		var directive := raw_text.substr(cursor, 1)
		cursor += 1
		match directive:
			"0":
				glyph_position = mini((int(glyph_position / 28) + 1) * 28, 84)
				output += "\n"
			"1": state = State.WAIT_FOR_INPUT
			"2": _begin_name(card_id)
			"3": _begin_name(other_card_id)
			"5": _begin_substitution(State.PLAYER_NAME, player_name)
			"6": _begin_substitution(State.NUMBER, str(number))
			"7": _begin_substitution(State.NUMBER, str(other_number))
		text_changed.emit(output, glyph_position, state == State.WAIT_FOR_INPUT)
		return {"waiting": state == State.WAIT_FOR_INPUT, "directive": directive}
	var codepoint := character.unicode_at(0)
	if codepoint < 0x80 and not NATIVE_ASCII_WHITELIST.contains(character):
		# StepDuelText draws blank glyph zero for unsupported ASCII and leaves
		# the source cursor untouched; the next VM step observes the same byte.
		glyph_position += 1
		text_changed.emit(output, glyph_position, false)
		return {"waiting": false, "unsupported_ascii": true, "glyph_position": glyph_position}
	output += character
	cursor += 1
	glyph_position += 1
	text_changed.emit(output, glyph_position, false)
	if cursor >= raw_text.length(): return _finish()
	return {"waiting": false, "glyph": character, "glyph_position": glyph_position}

func advance_input() -> void:
	if state != State.WAIT_FOR_INPUT: return
	if cursor < raw_text.length(): cursor += 1 # consume the pause directive digit
	state = State.TEXT
	glyph_position = 0
	blink = 0
	output = ""
	text_changed.emit(output, glyph_position, false)
	if cursor >= raw_text.length(): text_finished.emit()

func run_to_next_pause(max_steps: int = 256) -> Dictionary:
	var result: Dictionary = {}
	for _step_index in range(maxi(max_steps, 1)):
		result = step()
		if bool(result.get("waiting", false)) or bool(result.get("finished", false)):
			return result
	return {"waiting": false, "yielded": true, "cursor": cursor}

func select_language_segment(text: String, selected_language: int) -> String:
	var bytes := text.to_utf8_buffer()
	var selected := SacredTextRules.select_language_segment(bytes, clampi(selected_language, 0, 5))
	return (selected.bytes as PackedByteArray).get_string_from_utf8()

func _next_language_segment_length(text: String, at: int, selected_language: int) -> int:
	var cursor_index := at + 1
	while cursor_index < text.length():
		var tag := text.substr(cursor_index, 1)
		if tag >= "0" and tag <= "5":
			var language_id := int(tag)
			cursor_index += 1
			if language_id == clampi(selected_language, 0, 5): return cursor_index - at
			while cursor_index < text.length() and text.substr(cursor_index, 1) != "$": cursor_index += 1
		elif tag == "6":
			return cursor_index + 1 - at
		else:
			return 1
	return text.length() - at

func _begin_name(id: int) -> void:
	if card_database == null:
		_begin_substitution(State.CARD_NAME, "")
		return
	var record := card_database.get_localized_card_name_record(id, language)
	var wrapped := _wrap_card_name_record(str(record.get("text", "")), record.get("glyph_indices", PackedInt32Array()))
	_begin_substitution(State.CARD_NAME, str(wrapped.text), wrapped.glyph_indices)

func _wrap_card_name(card_name: String) -> String:
	if card_name.length() < 26: return card_name
	var boundary := -1
	for index in range(mini(card_name.length(), 28)):
		if card_name.substr(index, 1) == " ": boundary = index
	if boundary < 0:
		# duel_text.c inherits R8 for a German no-space fallback. Godot has no
		# equivalent call-context register, so retain the full name and report it.
		unresolved_wrap_context = true
		return card_name
	return card_name.substr(0, boundary) + " ".repeat(maxi(28 - boundary, 1)) + card_name.substr(boundary + 1)

func _wrap_card_name_record(card_name: String, glyph_indices: PackedInt32Array) -> Dictionary:
	var wrapped_text := _wrap_card_name(card_name)
	if wrapped_text == card_name or glyph_indices.size() != card_name.length():
		return {"text": wrapped_text, "glyph_indices": glyph_indices}
	var boundary := -1
	for index in range(mini(card_name.length(), 28)):
		if card_name.substr(index, 1) == " ": boundary = index
	if boundary < 0:
		return {"text": wrapped_text, "glyph_indices": PackedInt32Array()}
	var result := PackedInt32Array()
	result.append_array(glyph_indices.slice(0, boundary))
	var space_glyph := int(ascii_glyph_indices.get(32, -1))
	for _index in range(maxi(28 - boundary, 1)):
		result.append(space_glyph)
	result.append_array(glyph_indices.slice(boundary + 1))
	return {"text": wrapped_text, "glyph_indices": result}

func _begin_substitution(next_state: State, value: String, glyph_indices: PackedInt32Array = PackedInt32Array()) -> void:
	state = next_state
	substitution = value
	substitution_cursor = 0
	substitution_glyph_indices = glyph_indices.duplicate()

func _step_substitution() -> Dictionary:
	if substitution_cursor >= substitution.length():
		state = State.TEXT
		if cursor >= raw_text.length(): return _finish()
		return {"waiting": false, "substitution_finished": true}
	var character := substitution.substr(substitution_cursor, 1)
	var current_position := glyph_position
	var glyph_index := -1
	if state == State.CARD_NAME and substitution_cursor < substitution_glyph_indices.size():
		glyph_index = int(substitution_glyph_indices[substitution_cursor])
	else:
		var codepoint := character.unicode_at(0)
		glyph_index = int(ascii_glyph_indices.get(codepoint, unicode_glyph_indices.get(codepoint, -1)))
	output += character
	substitution_cursor += 1
	glyph_position += 1
	glyph_requested.emit(glyph_index, current_position, character, state == State.CARD_NAME)
	if substitution_cursor >= substitution.length(): state = State.TEXT
	text_changed.emit(output, glyph_position, false)
	return {"waiting": false, "glyph": character, "substitution": true, "glyph_position": glyph_position}

func _finish() -> Dictionary:
	text_finished.emit()
	return {"finished": true, "waiting": false}
