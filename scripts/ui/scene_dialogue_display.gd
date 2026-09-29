extends Control
class_name SceneDialogueDisplay

const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")
const LINE_WIDTH := 28

var _glyph_rows: Array = []
var _line_controls: Array[PixelText] = []

func _ready() -> void:
	position = Vector2(0, 104)
	size = Vector2(240, 56)
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph_rows.clear()
	for row in range(2):
		var glyphs: Array[String] = []
		for _index in range(LINE_WIDTH): glyphs.append(" ")
		_glyph_rows.append(glyphs)
	var frame := ColorRect.new()
	frame.position = Vector2(4, 0)
	frame.size = Vector2(232, 56)
	frame.color = Color("101820")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var inset := ColorRect.new()
	inset.position = Vector2(6, 2)
	inset.size = Vector2(228, 54)
	inset.color = Color("26343d")
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inset)
	for row in range(2):
		var line: PixelText = PIXEL_TEXT_SCRIPT.new()
		line.position = Vector2(8, 7 + row * 16)
		line.size = Vector2(LINE_WIDTH * 8, 8)
		line.font_color = Color("fff0c2")
		line.shadowed = true
		add_child(line)
		_line_controls.append(line)
	_render_lines()

func present_text(value: String, glyph_position: int) -> void:
	visible = true
	var position_index := glyph_position
	for character in value:
		if position_index < 1 or position_index > 55:
			continue
		var row := 0 if position_index <= LINE_WIDTH else 1
		var column := position_index - 1 if row == 0 else position_index - LINE_WIDTH - 1
		_glyph_rows[row][column] = character
		position_index += 1
	_render_lines()

func clear_text() -> void:
	for row in range(2):
		for column in range(LINE_WIDTH): _glyph_rows[row][column] = " "
	_render_lines()

func set_window_visible(should_show: bool) -> void:
	visible = should_show

func _render_lines() -> void:
	if _line_controls.size() != 2:
		return
	for row in range(2):
		var value := ""
		for character in _glyph_rows[row]: value += character
		_line_controls[row].text = value
