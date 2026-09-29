extends RefCounted
class_name SceneScriptCommands

const CHOICE_LINE_POSITIONS := [28, 28, 0, 0]

## Command adapter for the 27 recovered #/@/^ forms. Gameplay systems are
## injected as Callables; display and audio requests are emitted as signals.
signal dialogue_requested(operation: StringName, data: Dictionary)
signal audio_requested(audio_id: int)
signal music_fade_requested(frames: int)
signal save_requested
signal collection_card_requested(card_id: int, count: int)
signal actor_command_requested(command: StringName, operands: Array)
signal event_requested(event_id: int)
signal condition_requested(condition_id: int)
signal dialogue_visibility_requested(visible: bool)
signal fade_requested(delay_frames: int)
signal effect_music_stop_requested

var event_flags: EventFlagBank
var scene_grid: SceneGrid
var service_handlers: Dictionary[StringName, Callable] = {}
var player_name := ""

func execute(token: Dictionary, context: Dictionary) -> Dictionary:
	var command := String(token.get("command", ""))
	var operands: Array = token.get("operands", [])
	var state: Dictionary = context.get("state", {})
	match command:
		"#0": _line_advance(state)
		"#1":
			state.speaking = false
			state.mode = &"wait_input"
		"#2":
			state.choice_layout = 0
			state.branch_flags = 0
			state.glyph_position = 0
			state.mode = &"free_choice"
			dialogue_requested.emit(&"free_choice", {"node": context.get("node_id", &""), "offset": token.get("offset", 0)})
		"#3":
			state.speaking = false
			state.choice_layout = 1
			state.mode = &"binary_choice"
			dialogue_requested.emit(&"binary_choice", {})
		"#4":
			state.dirty = true
			state.portrait = _operand(operands, 0)
			state.portrait_flags = _operand(operands, 1)
			dialogue_requested.emit(&"portrait", {"portrait": state.portrait, "flags": state.portrait_flags})
		"#5":
			state.embedded_text_index = 0
			state.mode = &"player_name"
			dialogue_requested.emit(&"player_name", {"name": player_name})
		"#6": _flag_set(_operand(operands, 0), true)
		"#7": state.branch_flags = 1 if _flag_is_set(_operand(operands, 0)) else 0
		"#8":
			var opponent := _operand(operands, 0)
			state.portrait = 0
			return {"handled": true, "duel_opponent_id": opponent}
		"#9": collection_card_requested.emit(_u16(operands), 1)
		"@0", "@1", "@4", "@5", "@6", "^5":
			actor_command_requested.emit(StringName(command), operands.duplicate())
			return {"handled": true, "actor_command": StringName(command), "actor_operands": operands.duplicate()}
		"@2": save_requested.emit()
		"@3": music_fade_requested.emit(_u16(operands))
		"@7":
			return {"handled": true, "wait_frames": _operand(operands, 0)}
		"@8":
			var audio_id := _operand(operands, 0)
			if audio_id not in [111, 122, 123]: audio_requested.emit(audio_id)
		"@9":
			var player_cell: Vector2i = context.get("player_cell", Vector2i.ZERO)
			var expected := _operand(operands, 0)
			var cell_handler: Callable = service_handlers.get(&"scene_cell_low_byte", Callable())
			var actual := int(cell_handler.call(player_cell)) if cell_handler.is_valid() else _scene_cell_low_byte(player_cell)
			state.branch_flags = 1 if actual != expected else 0
		"^0": condition_requested.emit(_operand(operands, 0))
		"^1": effect_music_stop_requested.emit()
		"^2":
			var event_id := _operand(operands, 0)
			event_requested.emit(event_id)
			return {"handled": true, "script_event_id": event_id}
		"^3":
			var delay_frames := _operand(operands, 0)
			fade_requested.emit(delay_frames)
			return {"handled": true, "fade_delay_frames": delay_frames}
		"^4":
			state.dirty = false
			dialogue_visibility_requested.emit(false)
		"^6": pass
		_:
			return {"handled": false, "command": command}
	return {"handled": true}

func _line_advance(state: Dictionary) -> void:
	if int(state.get("choice_layout", 0)) == 1:
		var line_index := clampi(int(state.get("glyph_position", 0)) / 28, 0, CHOICE_LINE_POSITIONS.size() - 1)
		state.glyph_position = CHOICE_LINE_POSITIONS[line_index]
	elif (int(state.get("branch_flags", 0)) & 0x80) != 0:
		state.glyph_position = 1 if int(state.get("glyph_position", 0)) == 0 else 29
	else:
		var position := int(state.get("glyph_position", 0))
		state.glyph_position = 29 if position <= 28 else (42 if position <= 41 else 1)

func _flag_set(flag_id: int, enabled: bool) -> void:
	if event_flags == null: return
	if enabled: event_flags.set_flag(flag_id)
	else: event_flags.clear_flag(flag_id)

func _flag_is_set(flag_id: int) -> bool:
	return event_flags != null and event_flags.is_set(flag_id)

func _scene_cell_low_byte(cell: Vector2i) -> int:
	if scene_grid == null: return 0
	return scene_grid.cell_at(cell.x, cell.y) & 0xFF

func _operand(values: Array, index: int) -> int:
	return int(values[index]) if index >= 0 and index < values.size() else 0

func _u16(values: Array) -> int:
	return _operand(values, 0) | (_operand(values, 1) << 8)
