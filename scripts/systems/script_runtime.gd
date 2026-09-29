extends Node
class_name SceneScriptRuntime

## Frame-stepped interpreter for the recovered scene-script graph. Tokens are
## bounded dictionaries loaded from SceneScriptDatabase; no ROM addresses or
## native pointers are retained at runtime.
signal text_requested(text: String, language: int, glyph_offset: int)
signal portrait_tick(portrait_id: int, part: StringName, frame: int)
signal dialogue_glyph_requested(code: int, position: int, highlighted: bool)
signal dialogue_clear_requested
signal script_finished
signal script_error(message: String)
signal token_processed(node_id: StringName, token_index: int, token: Dictionary)

const COMMANDS_SCRIPT := preload("res://scripts/systems/script_commands.gd")
const DIALOGUE_SCRIPT := preload("res://scripts/systems/script_dialogue.gd")
const KEY_ADVANCE_MASK := 0x103
const BLINK_DURATIONS := [50, 1, 1, 80, 1, 1, 2, 1, 1, 60, 1, 1, 70, 1, 1, 50, 1, 1, 50, 1, 1, 60, 1, 1, 70, 1, 1, 65, 1, 1]
const BLINK_FRAMES := [0, 2, 1, 0, 2, 1, 0, 2, 1, 0, 2, 1, 0, 2, 1, 0, 2, 1, 0, 2, 1, 0, 2, 1, 0, 2, 1, 0, 2, 1]
const MOUTH_DURATIONS := [2, 3, 2, 3]
const MOUTH_FRAMES := [0, 1, 2, 1]

var database: SceneScriptDatabase
var commands: SceneScriptCommands
var dialogue: SceneScriptDialogue
var node_id: StringName
var token_index := 0
var state: Dictionary = {
	"mode": &"text", "cursor": 0, "glyph_position": 1,	"choice_layout": 0,
	"branch_flags": 0, "portrait": 0, "portrait_flags": 0, "dirty": false,
	"speaking": false, "embedded_text_index": 0, "blink_index": 29,
	"blink_ticks": 0, "mouth_index": 3, "mouth_ticks": 0, "wait_frames": 0
}
var context: Dictionary = {}
var running := false
var blocking_service_waiting := false
var execution_generation := 0

func _ready() -> void:
	set_physics_process(false)

func configure(script_database: SceneScriptDatabase, command_adapter: SceneScriptCommands = null) -> void:
	database = script_database
	commands = command_adapter if command_adapter != null else COMMANDS_SCRIPT.new()
	dialogue = DIALOGUE_SCRIPT.new()
	dialogue.glyph_requested.connect(func(code: int, position: int, highlighted: bool) -> void: dialogue_glyph_requested.emit(code, position, highlighted))
	dialogue.text_clear_requested.connect(func() -> void: dialogue_clear_requested.emit())
	dialogue.audio_requested.connect(_on_audio_requested)
	commands.condition_requested.connect(_on_condition_requested)
	commands.dialogue_requested.connect(_on_dialogue_requested)
	commands.audio_requested.connect(_on_audio_requested)
	commands.music_fade_requested.connect(_on_music_fade_requested)
	commands.save_requested.connect(_on_save_requested)
	commands.collection_card_requested.connect(_on_collection_card_requested)
	commands.dialogue_visibility_requested.connect(_on_dialogue_visibility_requested)
	commands.effect_music_stop_requested.connect(_on_effect_music_stop_requested)

func start(root_id: StringName, initial_context: Dictionary = {}) -> bool:
	if database == null:
		script_error.emit("Scene script runtime has no database.")
		return false
	if database.get_node(root_id) == null:
		script_error.emit("Unknown scene script node: %s" % String(root_id))
		return false
	context = initial_context.duplicate()
	context["language_segment"] = clampi(int(context.get("language_segment", 0)), 0, 5)
	commands.scene_grid = context.get("scene_grid") as SceneGrid
	state = {
		"mode": &"text", "cursor": 0, "glyph_position": 1, "choice_layout": 0,
		"branch_flags": 0, "portrait": 0, "portrait_flags": 0, "dirty": false,
		"speaking": false, "embedded_text_index": 0, "blink_index": 29,
		"blink_ticks": 0, "mouth_index": 3, "mouth_ticks": 0, "wait_frames": 0
	}
	execution_generation += 1
	blocking_service_waiting = false
	dialogue.reset(state, String(context.get("player_name", commands.player_name)))
	node_id = root_id
	token_index = 0
	running = true
	set_physics_process(true)
	return true

func stop() -> void:
	execution_generation += 1
	running = false
	blocking_service_waiting = false
	set_physics_process(false)
	state.mode = &"stopped"

func submit_dialogue_input(pressed_mask: int, horizontal: int = 0, vertical: int = 0) -> void:
	if not running: return
	dialogue.handle_input(pressed_mask, horizontal, vertical)
	if (pressed_mask & KEY_ADVANCE_MASK) != 0 and state.mode == &"text":
		state.wait_frames = 0

func _physics_process(_delta: float) -> void:
	if not running or blocking_service_waiting: return
	if int(state.wait_frames) > 0:
		state.wait_frames = int(state.wait_frames) - 1
		return
	if state.mode in [&"wait_input", &"binary_choice", &"free_choice"]:
		if state.mode == &"wait_input": dialogue.tick_wait_cursor()
		_update_portrait()
		return
	if state.mode == &"player_name":
		var name := String(dialogue.player_name)
		var name_index := int(state.embedded_text_index)
		if name_index >= 0 and name_index < name.length():
			text_requested.emit(name.substr(name_index, 1), int(context.language_segment), int(state.glyph_position))
		dialogue.write_player_name()
		return
	var node := database.get_node(node_id)
	if node == null:
		_fail("Script branch references missing node %s" % String(node_id))
		return
	if node.terminal or token_index >= node.tokens.size():
		_finish()
		return
	var token: Dictionary = node.tokens[token_index]
	token_index += 1
	var kind := StringName(token.get("kind", ""))
	match kind:
		&"end":
			_follow_branch(node)
		&"terminal_node":
			_finish()
		&"text":
			state.speaking = true
			state.dirty = true
			text_requested.emit(String(token.get("text", "")), int(context.language_segment), int(state.glyph_position))
			if dialogue != null: dialogue.write_plain_token(token)
			else: state.glyph_position += String(token.get("text", "")).length()
		&"language":
			_skip_to_language_segment(node.tokens, int(token.get("marker", 6)))
		&"command":
			var result := commands.execute(token, {"state": state, "node_id": node_id, "player_cell": context.get("player_cell", Vector2i.ZERO)})
			if not bool(result.get("handled", false)):
				script_error.emit("Unrecognized scene command %s at %s:%d" % [token.get("command", "?"), String(node_id), int(token.get("offset", -1))])
			if result.has("wait_frames"): state.wait_frames = int(result.wait_frames)
			var awaited_generation := execution_generation
			if result.has("actor_command"):
				blocking_service_waiting = true
				awaited_generation = execution_generation
				await _service(&"actor", [StringName(result.actor_command), result.actor_operands, self])
				if awaited_generation != execution_generation: return
				blocking_service_waiting = false
				if not running: return
			if result.has("fade_delay_frames"):
				blocking_service_waiting = true
				awaited_generation = execution_generation
				await _service(&"fade", [int(result.fade_delay_frames)])
				if awaited_generation != execution_generation: return
				blocking_service_waiting = false
				if not running: return
			if result.has("script_event_id"):
				blocking_service_waiting = true
				awaited_generation = execution_generation
				await _service(&"event", [int(result.script_event_id), self])
				if awaited_generation != execution_generation: return
				blocking_service_waiting = false
				if not running: return
			if result.has("duel_opponent_id"):
				blocking_service_waiting = true
				awaited_generation = execution_generation
				var outcome: Variant = await _service(&"duel", [int(result.duel_opponent_id), self])
				if awaited_generation != execution_generation: return
				blocking_service_waiting = false
				if not running: return
				state.branch_flags = 0 if int(outcome) == 1 else 1
				state.portrait = 0
		_: pass
	token_processed.emit(node_id, token_index - 1, token)
	_update_portrait()

func _follow_branch(node: SceneScriptNode) -> void:
	var selected := node.next_if_zero if int(state.branch_flags) == 0 else node.next_if_nonzero
	if selected == &"" or database.get_node(selected) == null:
		_finish()
		return
	node_id = selected
	token_index = 0
	state.branch_flags = 0
	state.glyph_position = 1 if int(state.choice_layout) != 1 else 0
	state.mode = &"text"

## The recovered '$' command scans forward to the selected language marker,
## skipping other language payloads in one interpreter step. Marker 6 is the
## shared fallback segment used when the requested language is not present.
func _skip_to_language_segment(tokens: Array[Dictionary], marker: int) -> void:
	var selected := int(context.get("language_segment", 0))
	if marker == selected or marker == 6:
		return
	var target := selected if marker < selected else 6
	while token_index < tokens.size():
		var candidate: Dictionary = tokens[token_index]
		token_index += 1
		if StringName(candidate.get("kind", "")) != &"language":
			continue
		var candidate_marker := int(candidate.get("marker", 6))
		if candidate_marker == target or candidate_marker == 6:
			return

func _update_portrait() -> void:
	if int(state.portrait) <= 0: return
	state.blink_ticks = int(state.blink_ticks) - 1
	if int(state.blink_ticks) <= 0:
		var index := posmod(int(state.blink_index), 30)
		state.blink_ticks = BLINK_DURATIONS[index] * 4
		portrait_tick.emit(int(state.portrait), &"blink", BLINK_FRAMES[index])
		state.blink_index = posmod(index - 1, 30)
	state.mouth_ticks = int(state.mouth_ticks) - 1
	if int(state.mouth_ticks) <= 0:
		var mouth_index := posmod(int(state.mouth_index), 4)
		state.mouth_ticks = MOUTH_DURATIONS[mouth_index] if bool(state.speaking) else MOUTH_DURATIONS[mouth_index] * 4
		portrait_tick.emit(int(state.portrait), &"mouth", MOUTH_FRAMES[mouth_index])
		if bool(state.speaking):
			state.mouth_index = posmod(mouth_index - 1, 4)
		else:
			state.mouth_index = 0
			state.mouth_ticks = 1

func _finish() -> void:
	stop()
	script_finished.emit()

func _fail(message: String) -> void:
	stop()
	script_error.emit(message)

func _service(name: StringName, args: Array = []) -> Variant:
	var callback: Callable = context.get(name, Callable())
	if callback.is_valid(): return callback.callv(args)
	return null

func _on_condition_requested(condition_id: int) -> void:
	var result: Variant = _service(&"condition", [condition_id, self])
	if result != null: state.branch_flags = int(result)
func _on_dialogue_requested(operation: StringName, data: Dictionary) -> void: _service(&"dialogue", [operation, data, self])
func _on_audio_requested(audio_id: int) -> void: _service(&"audio", [audio_id])
func _on_music_fade_requested(frames: int) -> void: _service(&"music_fade", [frames])
func _on_save_requested() -> void: _service(&"save", [])
func _on_collection_card_requested(card_id: int, count: int) -> void: _service(&"collection_card", [card_id, count])
func _on_dialogue_visibility_requested(visible: bool) -> void: _service(&"dialogue_visibility", [visible])
func _on_effect_music_stop_requested() -> void: _service(&"effect_music_stop", [])
