class_name CardArt
extends RefCounted
## Portable card-art transforms from card_art.c, expressed as owned byte arrays.

const LARGE_ART_BYTES := 6400 # 10 x 10 tiles, each 8 x 8 indexed pixels.
const MINI_ART_BYTES := 576 # 3 x 3 tiles.
const FRAME_BYTES := 1024 # 4 x 4 tiles.
const MINI_BYTES := 1024
const PADDED_SURFACE_BYTES := 4096 # 16-tile row stride, four rows addressed.

## Reverses the per-row delta coding of the 80 x 80 tile-major card art.
## Returns an empty array when the input is not exactly one recovered art block.
static func undo_row_deltas(encoded: PackedByteArray) -> PackedByteArray:
	if encoded.size() != LARGE_ART_BYTES:
		return PackedByteArray()
	var decoded := encoded.duplicate()
	for y in range(80):
		var previous := 0
		for x in range(80):
			var offset := _tile_offset(x, y, 10)
			previous = (previous + int(decoded[offset])) & 0xff
			decoded[offset] = previous
	return decoded

## Composes a 24 x 24 art inset inside a 32 x 32 frame. The padded form
## preserves the original 16-tile destination row stride used by the renderer.
static func compose_padded_mini(art: PackedByteArray, frame: PackedByteArray) -> PackedByteArray:
	if art.size() != MINI_ART_BYTES or frame.size() != FRAME_BYTES:
		return PackedByteArray()
	var destination := PackedByteArray()
	destination.resize(PADDED_SURFACE_BYTES)
	for y in range(32):
		for x in range(32):
			var source := _tile_offset(x, y, 4)
			var color := int(frame[source])
			if x >= 4 and x < 28 and y >= 2 and y < 26:
				color = int(art[_tile_offset(x - 4, y - 2, 3)])
			var target := ((y / 8) * 16 + x / 8) * 64 + (y % 8) * 8 + x % 8
			destination[target] = color
	return destination

## Same inset composition with a tightly packed four-tile-wide output.
static func compose_contiguous_mini(art: PackedByteArray, frame: PackedByteArray) -> PackedByteArray:
	if art.size() != MINI_ART_BYTES or frame.size() != FRAME_BYTES:
		return PackedByteArray()
	var destination := frame.duplicate()
	for y in range(32):
		for x in range(32):
			if x >= 4 and x < 28 and y >= 2 and y < 26:
				var art_offset := _tile_offset(x - 4, y - 2, 3)
				destination[_tile_offset(x, y, 4)] = art[art_offset]
	return destination

static func _tile_offset(x: int, y: int, tile_width: int) -> int:
	return ((y / 8) * tile_width + x / 8) * 64 + (y % 8) * 8 + x % 8
