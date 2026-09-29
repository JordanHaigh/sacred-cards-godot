extends RefCounted
class_name SacredRandom

## Deterministic 32 bit shift register recovered in random.c.

var state: int = 1

func initialize() -> void:
	state = 1

func next_bit() -> int:
	var bit := (state >> 31) & 1
	if bit != 0:
		state = (((state ^ 0x10000) << 1) | 1) & 0xFFFFFFFF
	else:
		state = (state << 1) & 0xFFFFFFFF
	return bit

func next_byte() -> int:
	var value := 0
	for _index in range(8):
		value = ((value << 1) | next_bit()) & 0xFF
	return value

func byte_inclusive(minimum: int, maximum: int) -> int:
	minimum &= 0xFF
	maximum &= 0xFF
	if minimum == maximum:
		return minimum
	var span := maximum - minimum + 1
	var remainder := next_byte() % span if span != 0 else 0
	return (minimum + remainder) & 0xFF

func next_halfword() -> int:
	return (next_byte() << 8) | next_byte()

func halfword_inclusive(minimum: int, maximum: int) -> int:
	minimum &= 0xFFFF
	maximum &= 0xFFFF
	var value := next_halfword()
	var span := maximum - minimum + 1
	return (minimum + (value % span if span != 0 else 0)) & 0xFFFF
