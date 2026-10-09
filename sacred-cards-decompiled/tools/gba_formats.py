"""GBA formats. Huffman facts checked against mGBA's src/gba/bios.c.
Card delta traversal comes from AY7E Thumb routine 0x0800917C.
"""
import struct


def huffman8(data, offset, max_output=1 << 20):
    if offset < 0 or offset + 6 > len(data) or offset % 4 or data[offset] != 0x28:
        raise ValueError("Expected aligned GBA 8-bit Huffman stream")
    size = int.from_bytes(data[offset + 1:offset + 4], "little")
    if not 0 < size <= max_output:
        raise ValueError("Invalid Huffman output length")
    root = offset + 5
    cursor = offset + 4 + 2 * (data[offset + 4] + 1)
    tree_end = cursor
    node_at = root
    output = bytearray()
    while len(output) < size:
        if cursor + 4 > len(data):
            raise ValueError("Truncated Huffman bitstream")
        word = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        for shift in range(31, -1, -1):
            direction = (word >> shift) & 1
            node = data[node_at]
            child = (node_at & ~1) + 2 * ((node & 63) + 1) + direction
            if not root <= child < tree_end:
                raise ValueError("Huffman child outside tree")
            if node & (0x80 >> direction):
                output.append(data[child])
                node_at = root
                if len(output) == size:
                    break
            else:
                node_at = child
    return bytes(output), cursor - offset


def tile_offset(x, y, width):
    return ((y // 8) * (width // 8) + x // 8) * 64 + (y % 8) * 8 + x % 8


def untile4(raw, width, height):
    if width % 8 or height % 8 or len(raw) * 2 != width * height:
        raise ValueError("Invalid 4bpp dimensions")
    pixels = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            offset = ((y // 8) * (width // 8) + x // 8) * 32 + (y % 8) * 4 + (x % 8) // 2
            pixels[y * width + x] = (raw[offset] >> (4 * (x & 1))) & 15
    return bytes(pixels)


def actor_frame_tiles(sheet, tile_offset):
    """Pack four 128-byte tile rows copied by ROM routine 0x08030554."""
    start = tile_offset * 32
    if start < 0 or start + 3 * 512 + 128 > len(sheet):
        raise ValueError("Actor frame outside sheet")
    return b"".join(sheet[start + row * 512:start + row * 512 + 128] for row in range(4))


def untile8(raw, width, height):
    if width % 8 or height % 8 or len(raw) != width * height:
        raise ValueError("Invalid 8bpp dimensions")
    return bytes(raw[tile_offset(x, y, width)] for y in range(height) for x in range(width))


def card_delta_decode(raw):
    if len(raw) != 6400:
        raise ValueError("Card art must be 10x10 8bpp tiles")
    result = bytearray(raw)
    for y in range(80):
        previous = 0
        for x in range(80):
            offset = tile_offset(x, y, 80)
            previous = (previous + raw[offset]) & 255
            result[offset] = previous
    return bytes(result)


def rgb555(raw):
    return [tuple(((v >> s) & 31) * 255 // 31 for s in (0, 5, 10))
            for (v,) in struct.iter_unpack("<H", raw)]


def compose_mini_card(art, frame):
    """Visible 32x32 image from ROM 0x08034B40's frame/art composition."""
    pixels = bytearray(untile8(frame, 32, 32))
    miniature = untile8(art, 24, 24)
    for y in range(24):
        pixels[(y + 2) * 32 + 4:(y + 2) * 32 + 28] = miniature[y * 24:(y + 1) * 24]
    return bytes(pixels)


def tilemap8(tiles, tilemap):
    if len(tilemap) != 2048 or len(tiles) % 64:
        raise ValueError("Expected 32x32 text map and 8bpp tiles")
    image = bytearray(256 * 256)
    for pos, (entry,) in enumerate(struct.iter_unpack("<H", tilemap)):
        base = (entry & 1023) * 64
        if base + 64 > len(tiles):
            raise ValueError("Tilemap refers outside tile data")
        for y in range(8):
            for x in range(8):
                sx, sy = (7 - x if entry & 1024 else x), (7 - y if entry & 2048 else y)
                image[(pos // 32 * 8 + y) * 256 + pos % 32 * 8 + x] = tiles[base + sy * 8 + sx]
    return bytes(image)
