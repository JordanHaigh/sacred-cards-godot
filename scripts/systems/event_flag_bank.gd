extends RefCounted
class_name EventFlagBank

const FLAG_COUNT := 400
var _flags := PackedByteArray()

func _init() -> void:
	_flags.resize(50)
	clear_all()

func clear_all() -> void:
	_flags.fill(0)

func set_flag(flag_id: int) -> void:
	if flag_id < 0 or flag_id >= FLAG_COUNT:
		return
	_flags[flag_id >> 3] |= 1 << (7 - (flag_id & 7))

func clear_flag(flag_id: int) -> void:
	if flag_id < 0 or flag_id >= FLAG_COUNT:
		return
	_flags[flag_id >> 3] &= ~(1 << (7 - (flag_id & 7)))

func is_set(flag_id: int) -> bool:
	if flag_id < 0 or flag_id >= FLAG_COUNT:
		return false
	return (_flags[flag_id >> 3] & (1 << (7 - (flag_id & 7)))) != 0

func to_bytes() -> PackedByteArray:
	return _flags.duplicate()

func load_bytes(values: PackedByteArray) -> void:
	_flags.fill(0)
	for index in range(mini(values.size(), _flags.size())):
		_flags[index] = values[index]
