extends RefCounted
class_name PasswordEntryState

## Eight-digit input/navigation state from password.c.
const KEY_MOVES := [
	[1, 4, 5, 6, 7, 8, 9, 0, 10, 10, 2],
	[7, 0, 10, 10, 1, 2, 3, 4, 5, 6, 8],
	[10, 3, 1, 2, 6, 4, 5, 9, 7, 8, 0],
	[10, 2, 3, 1, 5, 6, 4, 8, 9, 7, 0],
]

var digits: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var digit_index := 0
var key_index := 1
var blink_counter := 0
var press_counter := 0
var finished := false

func move_key(direction: int) -> void:
	if direction < 0 or direction >= KEY_MOVES.size() or key_index < 0 or key_index >= 11:
		return
	key_index = KEY_MOVES[direction][key_index]
	press_counter = 0

func move_digit(right: bool) -> void:
	digit_index = (digit_index + (1 if right else 7)) % 8
	blink_counter = 15

func press_selected_key() -> bool:
	if finished:
		return true
	press_counter = 8
	blink_counter = 0
	if key_index == 10:
		finished = true
		return true
	digits[digit_index] = key_index
	if digit_index == 7:
		press_counter = 0
		key_index = 10
	else:
		move_digit(true)
	return false

func choose_key(index: int) -> void:
	if index >= 0 and index <= 10:
		key_index = index

func password() -> String:
	var result := ""
	for digit in digits:
		result += str(digit)
	return result

func tick() -> void:
	blink_counter = (blink_counter + 1) % 30
	if press_counter > 0:
		press_counter -= 1

func digit_frame(slot: int) -> int:
	return digits[slot] + (10 if slot == digit_index and blink_counter > 15 else 0)

func key_frame() -> int:
	if press_counter == 0:
		return 0
	return 2 if (((press_counter - 4) & 255) < 2) else 1
