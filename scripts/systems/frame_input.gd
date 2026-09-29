extends RefCounted
class_name FrameInput

## Per-frame input edges and repeat state using Godot actions, with no key matrix access.
const REPEAT_DELAY := 10
const REPEAT_INTERVAL := 3
var held: Dictionary[StringName, bool] = {}
var pressed: Dictionary[StringName, bool] = {}
var repeated: Dictionary[StringName, bool] = {}
var repeat_timer: int = REPEAT_DELAY
var _known_actions: Dictionary[StringName, bool] = {}

func poll_actions(actions: Array[StringName]) -> void:
	pressed.clear()
	repeated.clear()
	for action in actions:
		_known_actions[action] = true
	var current: Dictionary[StringName, bool] = {}
	var changed := false
	for action in _known_actions:
		var is_down := Input.is_action_pressed(action)
		var was_down := bool(held.get(action, false))
		current[action] = is_down
		if is_down != was_down:
			changed = true
		pressed[action] = is_down and not was_down
	if changed:
		repeat_timer = REPEAT_DELAY
		for action in current:
			if current[action]:
				repeated[action] = true
	else:
		repeat_timer -= 1
		if repeat_timer == 0:
			repeat_timer = REPEAT_INTERVAL
			for action in current:
				if current[action]:
					repeated[action] = true
	held = current

func was_pressed(action: StringName) -> bool:
	return bool(pressed.get(action, false))

func was_repeated(action: StringName) -> bool:
	return bool(repeated.get(action, false))

func reset() -> void:
	held.clear()
	pressed.clear()
	repeated.clear()
	_known_actions.clear()
	repeat_timer = REPEAT_DELAY
