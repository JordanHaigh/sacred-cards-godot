extends RefCounted
class_name TitleMenuState

## Native menu-state port of title_screen.c, independent of GBA display effects.
enum Choice { NEW_GAME, CONTINUE }
enum Action { NONE, START_NEW_GAME, CONTINUE_GAME, CONFIRM_OVERWRITE }
enum OverwriteChoice { CONFIRM, CANCEL }

const TITLE_ALPHA_CYCLE_PATH := "res://decompiled/build/assets/player-menus/title.alpha-cycle.u16"

var has_save := false
var choice := Choice.NEW_GAME
var overwrite_choice := OverwriteChoice.CANCEL
var overwrite_pending := false
var pulse_values: Array[int] = []
var pulse_phase := 0
var pulse_coefficient := 0
var fade_active := false
var fade_frame := 0
var fade_step := 0
var fade_alpha := 0
var fade_backdrop_alpha := 16
var fade_brightness := 0

func initialize(save_exists: bool) -> void:
	has_save = save_exists
	choice = Choice.CONTINUE if has_save else Choice.NEW_GAME
	overwrite_choice = OverwriteChoice.CANCEL
	overwrite_pending = false
	pulse_phase = 0
	pulse_coefficient = 0
	fade_active = false
	fade_frame = 0
	fade_step = 0
	fade_alpha = 0
	fade_backdrop_alpha = 16
	fade_brightness = 0
	_load_pulse_values()

## Mirrors StepTitlePulse's per-frame table lookup. The table contains the
## native five-bit alpha coefficient; hardware blend registers are replaced
## with an alpha value consumed by the title TextureRect.
func step_title_pulse() -> int:
	if pulse_values.is_empty():
		return pulse_coefficient
	if pulse_phase >= pulse_values.size():
		pulse_phase = 0
	pulse_coefficient = pulse_values[pulse_phase] & 15
	pulse_phase += 1
	return pulse_coefficient

func begin_title_fade() -> void:
	fade_active = true
	fade_frame = 0
	fade_step = 0
	fade_alpha = pulse_coefficient & 31
	fade_backdrop_alpha = 16
	fade_brightness = 0

## Returns true after the sixteenth update and its 61st rendered frame.
func step_title_fade() -> bool:
	if not fade_active:
		return false
	fade_frame += 1
	if (fade_frame - 1) % 4 == 0:
		if fade_alpha > 0:
			fade_alpha -= 1
		if fade_backdrop_alpha > 0:
			fade_backdrop_alpha -= 1
		fade_brightness = fade_step & 31
		fade_step += 1
	if fade_frame >= 61:
		fade_active = false
		return true
	return false

func _load_pulse_values() -> void:
	pulse_values.clear()
	if not FileAccess.file_exists(TITLE_ALPHA_CYCLE_PATH):
		push_warning("Recovered title alpha-cycle table is unavailable.")
		return
	var bytes := FileAccess.get_file_as_bytes(TITLE_ALPHA_CYCLE_PATH)
	if bytes.size() != 60:
		push_warning("Recovered title alpha-cycle table has an unexpected size.")
		return
	for offset in range(0, bytes.size(), 2):
		pulse_values.append(bytes.decode_u16(offset))

func toggle_choice() -> void:
	if has_save:
		choice = Choice.CONTINUE if choice == Choice.NEW_GAME else Choice.NEW_GAME

func move_overwrite_choice(direction: int) -> void:
	if overwrite_pending:
		overwrite_choice = OverwriteChoice.CONFIRM if direction > 0 else OverwriteChoice.CANCEL

func request_confirm() -> Action:
	if choice == Choice.CONTINUE and has_save:
		return Action.CONTINUE_GAME
	if has_save:
		overwrite_pending = true
		overwrite_choice = OverwriteChoice.CANCEL
		return Action.CONFIRM_OVERWRITE
	return Action.START_NEW_GAME

func resolve_overwrite() -> Action:
	if not overwrite_pending:
		return Action.NONE
	overwrite_pending = false
	return Action.START_NEW_GAME if overwrite_choice == OverwriteChoice.CONFIRM else Action.NONE
