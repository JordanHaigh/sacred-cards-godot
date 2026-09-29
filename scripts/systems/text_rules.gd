extends RefCounted
class_name SacredTextRules

## Numeric, glyph-index and language-segment rules from text.c. PixelText uses
## the recovered glyph atlas for visible English UI.

const BLANK_DIGIT := 10
const SMALL_FONT_PATH := "res://decompiled/build/assets/ui/font-small.bin"
const LARGE_FONT_PATH := "res://decompiled/build/assets/ui/font-large.bin"
const ASCII_GLYPH_CODES_PATH := "res://resources/ascii_glyph_codes.json"

## Reproduces RenderBitmapGlyph as owned bytes. The returned data uses the
## source's little-endian packed rows; unsupported modes and truncated glyph
## records return valid=false instead of reading outside a ROM address range.
static func render_bitmap_glyph(encoded: int, mode: int) -> Dictionary:
	return _render_bitmap_glyph_from_fonts(encoded, mode, FileAccess.get_file_as_bytes(SMALL_FONT_PATH), FileAccess.get_file_as_bytes(LARGE_FONT_PATH))

static func _render_bitmap_glyph_from_fonts(encoded: int, mode: int, small_font: PackedByteArray, large_font: PackedByteArray) -> Dictionary:
	var format := mode & 0x1f00
	if format not in [0x0000, 0x0100, 0x0400, 0x0500, 0x0800, 0x0900, 0x1800]:
		return {"valid": false, "reason": "unsupported_format", "pixels": PackedByteArray()}
	var pixels := PackedByteArray()
	if format == 0x0500:
		pixels.resize(128)
		return {"valid": true, "glyph_index": bitmap_glyph_index(_swap_bytes(encoded)), "format": format, "pixels": pixels}
	var code := _swap_bytes(encoded)
	var glyph_index := bitmap_glyph_index(code)
	var uses_large := format in [0x0100, 0x0900]
	var source := large_font if uses_large else small_font
	var source_stride := 18 if uses_large else 10
	var blocks := 2 if uses_large else 1
	var output_size := 64 * blocks
	if format == 0x0400:
		output_size = 64
	pixels.resize(output_size)
	var source_start := glyph_index * source_stride
	var source_bytes := blocks * 8
	if source_start < 0 or source_start + source_bytes > source.size():
		return {"valid": false, "reason": "glyph_data_unavailable", "glyph_index": glyph_index, "format": format, "pixels": PackedByteArray()}
	if format == 0x0400:
		for y in range(8):
			for x in range(7):
				pixels[y * 8 + x] = (int(source[source_start + y]) >> (6 - x) & 1) * (mode & 0xff)
		return {"valid": true, "glyph_index": glyph_index, "format": format, "pixels": pixels}
	for block in range(blocks):
		for y in range(8):
			var bits := int(source[source_start + block * 8 + y])
			var row := 0
			for x in range(7):
				row |= ((bits >> (6 - x)) & 1) << (x * 4)
			var word_index := block * 16 + y
			pixels.encode_u32(word_index * 4, row)
	if format == 0x1800:
		for y in range(7):
			var row := pixels.decode_u32(y * 4)
			pixels.encode_u32(y * 4, (row | (row << 4)) & 0xffffffff)
	if format in [0x0800, 0x0900, 0x1800]:
		_shadow_packed_rows(pixels, blocks)
	return {"valid": true, "glyph_index": glyph_index, "format": format, "pixels": pixels}

## Ports RenderBitmapString using owned little-endian glyph codes. Callers can
## supply an override table; the default is the portable recovered mapping.
static func render_bitmap_string(encoded_text: PackedByteArray, mode: int, language: int, ascii_codes: PackedByteArray = PackedByteArray()) -> Dictionary:
	var segment := select_language_segment(encoded_text, language)
	var text_bytes: PackedByteArray = segment.bytes
	var ascii_supported := PackedByteArray()
	if ascii_codes.is_empty():
		var default_table := _load_ascii_glyph_codes()
		ascii_codes = default_table.get("codes", PackedByteArray())
		ascii_supported = default_table.get("supported", PackedByteArray())
		if ascii_codes.is_empty():
			return {"valid": false, "reason": "ascii_glyph_table_unavailable", "pixels": PackedByteArray(), "glyph_count": 0}
	var format := mode & 0x1f00
	if format not in [0x0000, 0x0100, 0x0400, 0x0500, 0x0800, 0x0900, 0x1000, 0x1800]:
		return {"valid": false, "reason": "unsupported_format", "pixels": PackedByteArray(), "glyph_count": 0}
	var rendered := PackedByteArray()
	var small_font := FileAccess.get_file_as_bytes(SMALL_FONT_PATH)
	var large_font := FileAccess.get_file_as_bytes(LARGE_FONT_PATH)
	var cursor := 0
	var glyph_count := 0
	var odd := false
	while cursor < text_bytes.size() and text_bytes[cursor] != 0 and text_bytes[cursor] != 36:
		var encoded: int
		if (text_bytes[cursor] & 0x80) != 0:
			if cursor + 1 >= text_bytes.size():
				return {"valid": false, "reason": "truncated_multibyte_character", "pixels": PackedByteArray(), "glyph_count": glyph_count}
			encoded = int(text_bytes[cursor]) | (int(text_bytes[cursor + 1]) << 8)
			cursor += 2
		else:
			var ascii_index := int(text_bytes[cursor]) - 32
			var table_offset := ascii_index * 2
			if ascii_index < 0 or table_offset + 1 >= ascii_codes.size() or (not ascii_supported.is_empty() and (ascii_index >= ascii_supported.size() or ascii_supported[ascii_index] == 0)):
				return {"valid": false, "reason": "ascii_glyph_mapping_unavailable", "pixels": PackedByteArray(), "glyph_count": glyph_count}
			encoded = int(ascii_codes[table_offset]) | (int(ascii_codes[table_offset + 1]) << 8)
			cursor += 1
		var glyph_mode := 0 if format == 0x1000 else mode
		var glyph := _render_bitmap_glyph_from_fonts(encoded, glyph_mode, small_font, large_font)
		if not bool(glyph.get("valid", false)):
			return {"valid": false, "reason": str(glyph.get("reason", "glyph_render_failed")), "glyph_index": int(glyph.get("glyph_index", -1)), "pixels": PackedByteArray(), "glyph_count": glyph_count}
		var glyph_pixels: PackedByteArray = glyph.pixels
		if format == 0x1000:
			for row in range(7):
				var word := glyph_pixels.decode_u32(row * 4)
				glyph_pixels.encode_u32(row * 4, (word | (word << 4)) & 0xffffffff)
		var destination_offset := rendered.size()
		if format in [0x0100, 0x0900]:
			destination_offset = _bitmap_string_offset(glyph_count, odd, 32, 96)
			odd = not odd
		elif format == 0x0500:
			destination_offset = _bitmap_string_offset(glyph_count, odd, 64, 192)
			odd = not odd
		elif format == 0x0400:
			destination_offset = glyph_count * 64
		else:
			destination_offset = glyph_count * 32
		var end_offset := destination_offset + glyph_pixels.size()
		if rendered.size() < end_offset:
			rendered.resize(end_offset)
		for byte_index in range(glyph_pixels.size()):
			rendered[destination_offset + byte_index] = glyph_pixels[byte_index]
		glyph_count += 1
	return {"valid": true, "language_offset": int(segment.offset), "glyph_count": glyph_count, "pixels": rendered}

static func _load_ascii_glyph_codes() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASCII_GLYPH_CODES_PATH)) if FileAccess.file_exists(ASCII_GLYPH_CODES_PATH) else null
	if not parsed is Dictionary or int(parsed.get("ascii_start", -1)) != 32:
		return {}
	var raw_codes: Variant = parsed.get("encoded_codes", [])
	if not raw_codes is Array or raw_codes.size() != 96:
		return {}
	var codes := PackedByteArray()
	var supported := PackedByteArray()
	codes.resize(96 * 2)
	codes.fill(0)
	supported.resize(96)
	supported.fill(0)
	for index in range(raw_codes.size()):
		var encoded: Variant = raw_codes[index]
		if encoded == null:
			continue
		var value := int(encoded) & 0xffff
		codes[index * 2] = value & 0xff
		codes[index * 2 + 1] = (value >> 8) & 0xff
		supported[index] = 1
	return {"codes": codes, "supported": supported}

static func _bitmap_string_offset(glyph_count: int, odd: bool, first_stride: int, second_stride: int) -> int:
	return (glyph_count >> 1) * (first_stride + second_stride) + (first_stride if odd else 0)

static func _swap_bytes(value: int) -> int:
	return ((value << 8) | (value >> 8)) & 0xffff

static func _shadow_packed_rows(pixels: PackedByteArray, blocks: int) -> void:
	var previous := pixels.decode_u32(0)
	for block in range(blocks):
		for y in range(8):
			if block == 0 and y == 0:
				continue
			var offset := (block * 16 + y) * 4
			var current := pixels.decode_u32(offset)
			var shadow := (((previous << 4) & (~current & 0xffffffff)) << 1 | current) & 0xffffffff
			pixels.encode_u32(offset, shadow)
			previous = current

static func select_language_segment(bytes: PackedByteArray, language: int) -> Dictionary:
	if bytes.is_empty() or bytes[0] != 36:
		return {"offset": 0, "bytes": bytes}
	var cursor := 0
	var offset := 0
	while cursor < bytes.size():
		cursor += 1
		offset = (offset + 1) & 0xFFFF
		if cursor >= bytes.size():
			break
		var tag: int = bytes[cursor]
		if tag >= 48 and tag <= 53:
			if language == tag - 48:
				cursor += 1
				offset = (offset + 1) & 0xFFFF
				return {"offset": offset, "bytes": bytes.slice(cursor)}
			while cursor < bytes.size() and bytes[cursor] != 36:
				var width := 2 if (bytes[cursor] & 0x80) != 0 else 1
				cursor += width
				offset = (offset + width) & 0xFFFF
		elif tag == 54:
			cursor += 1
			offset = (offset + 1) & 0xFFFF
			return {"offset": offset, "bytes": bytes.slice(cursor)}
	return {"offset": offset, "bytes": PackedByteArray()}

static func bitmap_glyph_index(code: int) -> int:
	code &= 0xFFFF
	if code < 0x8140:
		code = 0x8140
	var original := code - 0x8140
	var value := original
	if original > 0x400:
		value -= 0x200
	if original > 0x700:
		value -= 0x100
	if original > 0x5F00:
		value -= 0x4000
	var index := value - (value >> 8) * 68
	if (value & 0xFF) > 0x3F:
		index -= 1
	return index & 0xFFFF

static func format_decimal_digits(number: int, flags: int = 0) -> Array[int]:
	var digits: Array[int] = [BLANK_DIGIT, BLANK_DIGIT, BLANK_DIGIT, BLANK_DIGIT, BLANK_DIGIT]
	if number != 65535:
		var compact := (flags & 1) != 0
		var position := 0
		var divisor := 10000
		if compact:
			digits[0] = 0
		for _index in range(5):
			var digit := int(number / divisor)
			if digit != 0 or (position > 0 and digits[position - 1] != BLANK_DIGIT):
				digits[position] = digit
			elif position == 4:
				digits[4] = 0
			if digit != 0:
				position += 1
			elif position == 0:
				if not compact:
					position = 1
			elif digits[position - 1] != BLANK_DIGIT or not compact:
				position += 1
			number -= divisor * digit
			divisor = int(divisor / 10)
	if flags & 2:
		for index in range(5):
			if digits[index] == BLANK_DIGIT:
				digits[index] = 0
	return digits

static func format_money_digits(number: int, flags: int = 0) -> Array[int]:
	var digits: Array[int] = []
	digits.resize(19)
	digits.fill(BLANK_DIGIT)
	var compact := (flags & 1) != 0
	var position := 0
	var divisor := 1000000000000000000
	if compact:
		digits[0] = 0
	for _index in range(19):
		var digit := int(number / divisor)
		if digit != 0 or (position > 0 and digits[position - 1] != BLANK_DIGIT):
			digits[position] = digit & 0xFF
		elif position == 18:
			digits[18] = 0
		if digit != 0:
			position += 1
		elif position == 0:
			if not compact:
				position = 1
		elif digits[position - 1] != BLANK_DIGIT or not compact:
			position += 1
		number -= divisor * digit
		divisor = int(divisor / 10)
	if flags & 2:
		for index in range(19):
			if digits[index] == BLANK_DIGIT:
				digits[index] = 0
	return digits
