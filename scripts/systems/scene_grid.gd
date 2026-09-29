extends RefCounted
class_name SceneGrid

## Scene cell helpers from scene_data.c over an owned 120-column grid.
const WIDTH := 120
var cells: PackedInt32Array = []

func _init(initial_cells: PackedInt32Array = PackedInt32Array()) -> void:
	cells = initial_cells.duplicate()

func cell_at(x: int, y: int) -> int:
	var index := y * WIDTH + x
	return cells[index] & 0xffff if x >= 0 and x < WIDTH and y >= 0 and index >= 0 and index < cells.size() else 0

static func has_base_flag(cell: int) -> bool:
	return (cell & 0xfe00) == 0 and (cell & 1) != 0

static func has_bit_8(cell: int) -> bool:
	return (cell & 0x0100) != 0

static func event_class(cell: int) -> int:
	if (cell & 0x0200) != 0:
		return 1
	return 2 if (cell & 0x0400) != 0 else 0
