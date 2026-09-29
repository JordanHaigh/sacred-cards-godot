extends RefCounted
class_name PlayerProgression

const TABLE_PATH := "res://resources/game_tables.json"
const MAX_CAPACITY := 99999

var capacity: int = 1600
var duelist_level: int = 72
var level_up_pending: bool = false
var _thresholds: Array = []

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if parsed is Dictionary:
		_thresholds = parsed.get("gLevelCapacityThresholds", [])

func can_raise_level() -> bool:
	if duelist_level > 998 or _thresholds.size() < 1000:
		return false
	if capacity < int(_thresholds[duelist_level + 1]):
		return false
	level_up_pending = true
	return true

func update_level() -> void:
	while can_raise_level():
		duelist_level += 1

func add_capacity(amount: int) -> void:
	capacity = mini(capacity + amount, MAX_CAPACITY)
	update_level()

func subtract_capacity(amount: int) -> void:
	capacity = maxi(0, capacity - amount)
	# Native subtraction deliberately does not lower the saved level.

func deck_capacity() -> int:
	return capacity
