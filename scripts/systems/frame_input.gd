extends RefCounted
class_name FrameInput

## Per-frame input edges and repeat state using Godot actions, with no key matrix access.
const REPEAT_DELAY := 10
const REPEAT_INTERVAL := 3
var held: Dictionary[StringName, bool] = {}
var pressed: Dictionary[StringName, bool] = {}
var repeated: Dictionary[StringName, bool] = {}
var repeat_timers: Dictionary[StringName, int] = {}

func poll_actions(actions: Array[StringName]) -> void:
	pressed.clear()
	repeated.clear()
	for action in actions:
		var is_down := Input.is_action_pressed(action)
		var was_down := bool(held.get(action, false))
		pressed[action] = is_down and not was_down
		if not is_down:
			repeat_timers[action] = REPEAT_DELAY
		elif not was_down:
			repeated[action] = true
			repeat_timers[action] = REPEAT_DELAY
		else:
			var timer := int(repeat_timers.get(action, REPEAT_DELAY))
			if timer == 0:
				repeated[action] = true
				timer = REPEAT_INTERVAL
			else:
				timer -= 1
			repeat_timers[action] = timer
		held[action] = is_down

func was_pressed(action: StringName) -> bool:
	return bool(pressed.get(action, false))

func was_repeated(action: StringName) -> bool:
	return bool(repeated.get(action, false))

func reset() -> void:
	held.clear()
	pressed.clear()
	repeated.clear()
	repeat_timers.clear()
