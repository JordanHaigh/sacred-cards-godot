extends RefCounted
class_name SceneScriptEvents

## Data-oriented translation of the 58 ^2 scene event entries. Hardware
## actors, shops, audio, saves and scene loads are performed by injected services.
signal scene_change_requested(scene_id: int, variant: int, spawn: int, use_variant_rules: bool)
signal service_requested(service: StringName, data: Dictionary)
signal actor_motion_requested(event_id: int, actor_ids: Array, choreography_id: StringName)
signal actor_motion_path_requested(event_id: int, descriptor: Dictionary, x_steps: Array[int], y_steps: Array[int])
signal actor_state_requested(actor_id: int, changes: Dictionary)

var event_flags: EventFlagBank
var scene_id := 0
var scene_variant := 0
var scene_spawn := 0
var scene_flags := 0
var progress_rank := 0
var variant_rules: Array[Dictionary] = []
var actor_runtime: SceneActorRuntime
var load_error := ""
var motion_words := PackedInt32Array()
var motion_events: Dictionary = {}

const SCENE_CHANGES := {
	2: [38, 7, 0], 13: [1, 3, 0], 14: [28, 1, 4], 15: [-1, 0, -1],
	19: [19, 0, 3], 20: [54, 0, 3], 21: [55, 0, 3], 22: [30, 1, 4],
	25: [42, 1, 4], 26: [40, 1, 4], 28: [42, 2, 4], 29: [53, 0, 0],
	30: [40, 2, 4], 31: [42, 3, 4], 32: [51, 1, 0], 33: [42, 4, 4],
	34: [51, 2, 0], 35: [43, 0, 0], 39: [41, 0, 3], 40: [49, 0, 3],
	41: [42, 0, 3], 42: [53, 1, 0], 43: [45, 1, 0], 44: [51, 4, 0],
	45: [23, 3, 0], 46: [5, 5, 0], 47: [57, 0, 0], 48: [53, 3, 0],
	49: [53, 4, 0], 50: [42, 5, 0], 51: [45, 3, 0], 54: [40, 0, 4],
	55: [22, 0, 4]
}
const DOOR_EVENTS := [19, 20, 21, 39, 40, 41]
const CHOREOGRAPHY := {
	0: [&"walk_out_npc_1", [1]], 1: [&"walk_out_player", [0]],
	12: [&"paired_stage_entrance", [0, 1]],
	16: [&"walk_out_actor_3", [3]], 18: [&"vanish_actor_4", [4]],
	27: [&"vanish_actor_3_a", [3]], 37: [&"vanish_actor_3_b", [3]],
	38: [&"vanish_actor_3_c", [3]], 52: [&"vanish_actor_4_b", [4]],
	53: [&"vanish_actor_6", [6]], 56: [&"group_entrance", [1, 10, 11, 12]]
}

func dispatch(event_id: int, script_state: Dictionary = {}, door_timing_handled: bool = false) -> void:
	if event_id < 0 or event_id > 57:
		return
	if CHOREOGRAPHY.has(event_id):
		actor_motion_requested.emit(event_id, CHOREOGRAPHY[event_id][1], CHOREOGRAPHY[event_id][0])
		if motion_events.has(event_id):
			var descriptor: Dictionary = motion_events[event_id]
			var paths := _motion_paths(descriptor)
			actor_motion_path_requested.emit(event_id, descriptor, paths.x, paths.y)
		return
	if event_id in SCENE_CHANGES:
		_handle_scene_change(event_id, door_timing_handled)
		return
	match event_id:
		3, 4, 5, 6, 7:
			progress_rank |= 1 << (event_id - 2)
			service_requested.emit(&"progress_rank_changed", {"rank": progress_rank})
		8: service_requested.emit(&"buy_shop", {})
		9: service_requested.emit(&"native_scene_service", {"source_routine": "08000224"})
		10: service_requested.emit(&"name_entry", {"save_after": true})
		11: service_requested.emit(&"sell_shop", {})
		17:
			if event_flags != null: event_flags.clear_flag(114)
		23:
			for actor_id in range(2, 8):
				actor_state_requested.emit(actor_id, {"position": Vector2i.ZERO, "clear_flag_mask": 0x24})
		24: service_requested.emit(&"password_feature", {})
		36: pass
		57: service_requested.emit(&"restore_scene_and_dialogue", {})

func load_variant_rules(path: String = "res://resources/scene_variant_rules.json") -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error = "Unable to open scene variant rules: %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("rules", []) is Array:
		load_error = "Scene variant rule data has an invalid structure."
		return false
	variant_rules.clear()
	for raw_rule: Variant in parsed.rules:
		if raw_rule is Dictionary: variant_rules.append(raw_rule)
	load_error = ""
	return true

func load_motion_data(path: String = "res://resources/scene_script_motion.json") -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error = "Unable to open scene script motion data: %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("motion_words", []) is Array or not parsed.get("events", {}) is Dictionary:
		load_error = "Scene script motion data has an invalid structure."
		return false
	motion_words = PackedInt32Array(parsed.motion_words)
	motion_events.clear()
	for key: Variant in parsed.events:
		motion_events[int(key)] = parsed.events[key]
	load_error = ""
	return motion_words.size() == 196

func _motion_paths(descriptor: Dictionary) -> Dictionary:
	var x_steps: Array[int] = []
	var y_steps: Array[int] = []
	var termination := int(descriptor.get("termination", -1))
	var x_start := int(descriptor.get("x", -1))
	var y_start := int(descriptor.get("y", -1))
	if termination < 0 or x_start < 0 or y_start < 0:
		return {"x": x_steps, "y": y_steps}
	var step_count := 0
	while termination + step_count < motion_words.size() and motion_words[termination + step_count] != 127:
		step_count += 1
	for index in range(step_count):
		if x_start + index >= motion_words.size() or y_start + index >= motion_words.size(): break
		x_steps.append(motion_words[x_start + index])
		y_steps.append(motion_words[y_start + index])
	return {"x": x_steps, "y": y_steps}

func motion_path_for_event(event_id: int) -> Dictionary:
	return _motion_paths(motion_events.get(event_id, {}))

func _handle_scene_change(event_id: int, door_timing_handled: bool = false) -> void:
	var values: Array = SCENE_CHANGES[event_id]
	var next_scene := scene_id if int(values[0]) == -1 else int(values[0])
	var next_variant := int(values[1])
	var next_spawn := scene_spawn if int(values[2]) == -1 else int(values[2])
	if event_id in DOOR_EVENTS and not door_timing_handled:
		service_requested.emit(&"door_transition", {"music_fade_frames": 1, "wait_before_sound": 8, "audio_id": 92, "wait_after_sound": 50})
	scene_flags |= 2
	scene_id = next_scene
	scene_variant = next_variant if event_id == 13 else _resolve_variant(next_scene, next_variant)
	scene_spawn = next_spawn
	scene_change_requested.emit(scene_id, scene_variant, scene_spawn, event_id != 13)

func is_door_event(event_id: int) -> bool:
	return event_id in DOOR_EVENTS

func _resolve_variant(target_scene: int, target_variant: int) -> int:
	var result := target_variant
	for rule in variant_rules:
		if int(rule.get("scene", -1)) != target_scene or int(rule.get("variant", -1)) != result:
			continue
		var eligible := true
		for flag_id: Variant in rule.get("required_flags", []):
			if int(flag_id) >= 0 and (event_flags == null or not event_flags.is_set(int(flag_id))):
				eligible = false
				break
		if eligible:
			result = int(rule.get("replacement", result))
	return result

func bind_script_runtime(runtime: SceneScriptRuntime) -> void:
	if runtime == null: return
	runtime.commands.event_requested.connect(func(event_id: int) -> void: dispatch(event_id, runtime.state))
