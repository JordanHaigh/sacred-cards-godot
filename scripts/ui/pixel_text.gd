extends Control
class_name PixelText

## Draws with the recovered GBA bitmap glyphs from text.c.
const SMALL_ATLAS: Texture2D = preload("res://art/ui/font-small.png")
const LARGE_ATLAS: Texture2D = preload("res://art/ui/font-large.png")
const FONT_MAPPING_PATH := "res://decompiled/build/assets/ui/font-mapping.json"
const ASCII_GLYPH_CODES_PATH := "res://resources/ascii_glyph_codes.json"

var unicode_glyphs: Dictionary = {}
var ascii_glyphs: Dictionary = {}

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
	ascii_glyphs = load_ascii_glyphs()
	var mapping: Variant = JSON.parse_string(FileAccess.get_file_as_string(FONT_MAPPING_PATH)) if FileAccess.file_exists(FONT_MAPPING_PATH) else null
	if not mapping is Array:
		return
	for entry: Dictionary in mapping:
		var candidate := str(entry.get("unicode_candidate", ""))
		if candidate.length() == 1:
			unicode_glyphs[candidate.unicode_at(0)] = int(entry.get("glyph_index", 31))

static func load_ascii_glyphs() -> Dictionary:
	var result: Dictionary = {}
	var ascii_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASCII_GLYPH_CODES_PATH)) if FileAccess.file_exists(ASCII_GLYPH_CODES_PATH) else null
	if ascii_data is Dictionary:
		var encoded_codes: Variant = ascii_data.get("encoded_codes", [])
		if encoded_codes is Array and encoded_codes.size() == 96:
			for index in range(encoded_codes.size()):
				if encoded_codes[index] == null:
					continue
				var encoded := int(encoded_codes[index]) & 0xffff
				var code := ((encoded << 8) | (encoded >> 8)) & 0xffff
				result[index + 32] = SacredTextRules.bitmap_glyph_index(code)
	return result

func _draw() -> void:
	var atlas: Texture2D = LARGE_ATLAS if use_large_font else SMALL_ATLAS
	var glyph_height := 16 if use_large_font else 8
	var fallback: int = ascii_glyphs.get(63, 31)
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		var glyph: int = ascii_glyphs.get(codepoint, unicode_glyphs.get(codepoint, fallback))
		var source := Rect2((glyph % 32) * 8, (glyph / 32) * glyph_height, 8, glyph_height)
		var target := Rect2(index * 8, 0, 8, glyph_height)
		if shadowed:
			draw_texture_rect_region(atlas, Rect2(target.position + Vector2(1, 1), target.size), source, Color(0.04, 0.04, 0.04, 0.9))
		draw_texture_rect_region(atlas, target, source, font_color)
