extends Control
class_name PixelText

## Draws with the recovered GBA bitmap glyphs from text.c.
const SMALL_ATLAS: Texture2D = preload("res://art/ui/font-small.png")
const LARGE_ATLAS: Texture2D = preload("res://art/ui/font-large.png")
const FONT_MAPPING_PATH := "res://decompiled/build/assets/ui/font-mapping.json"
const GLYPHS := {
	32: 0,
	33: 9,
	34: 0,
	37: 3,
	39: 38,
	44: 3,
	45: 60,
	46: 4,
	58: 6,
	59: 7,
	63: 8,
	65: 220,
	66: 221,
	67: 222,
	68: 223,
	69: 224,
	70: 225,
	71: 226,
	72: 227,
	73: 228,
	74: 229,
	75: 230,
	76: 231,
	77: 232,
	78: 233,
	79: 234,
	80: 235,
	81: 236,
	82: 237,
	83: 238,
	84: 239,
	85: 240,
	86: 241,
	87: 242,
	88: 243,
	89: 244,
	90: 245,
	97: 252,
	98: 253,
	99: 254,
	100: 255,
	101: 256,
	102: 257,
	103: 258,
	104: 259,
	105: 260,
	106: 261,
	107: 262,
	108: 263,
	109: 264,
	110: 265,
	111: 266,
	112: 267,
	113: 268,
	114: 269,
	115: 270,
	116: 271,
	117: 272,
	118: 273,
	119: 274,
	120: 275,
	121: 276,
	122: 277,
}

var unicode_glyphs: Dictionary = {}

@export var text: String = "":
	set(value):
		text = value
		queue_redraw()
@export var font_color: Color = Color.WHITE:
	set(value):
		font_color = value
		queue_redraw()
@export var use_large_font: bool = false:
	set(value):
		use_large_font = value
		queue_redraw()
@export var shadowed: bool = true

func _ready() -> void:
	var mapping: Variant = JSON.parse_string(FileAccess.get_file_as_string(FONT_MAPPING_PATH)) if FileAccess.file_exists(FONT_MAPPING_PATH) else null
	if not mapping is Array:
		return
	for entry: Dictionary in mapping:
		var candidate := str(entry.get("unicode_candidate", ""))
		if candidate.length() == 1:
			unicode_glyphs[candidate.unicode_at(0)] = int(entry.get("glyph_index", GLYPHS.get(63, 31)))

func _draw() -> void:
	var atlas: Texture2D = LARGE_ATLAS if use_large_font else SMALL_ATLAS
	var glyph_height := 16 if use_large_font else 8
	var fallback: int = GLYPHS.get(63, 31)
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		var glyph: int = unicode_glyphs.get(codepoint, GLYPHS.get(codepoint, fallback))
		var source := Rect2((glyph % 32) * 8, (glyph / 32) * glyph_height, 8, glyph_height)
		var target := Rect2(index * 8, 0, 8, glyph_height)
		if shadowed:
			draw_texture_rect_region(atlas, target.translated(Vector2(1, 1)), source, Color(0.04, 0.04, 0.04, 0.9))
		draw_texture_rect_region(atlas, target, source, font_color)
