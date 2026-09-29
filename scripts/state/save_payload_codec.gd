extends RefCounted
class_name SavePayloadCodec

## Portable equivalent of decompiled/src/save_data.c. Callers provide each
## recovered region by name; unknown regions stay ordinary byte arrays.
const REGION_SIZES := {
	"player_name_17_bytes": 17,
	"unknown_02020770": 901,
	"player_deck_40_u16": 80,
	"deck_capacity_u32": 4,
	"duelist_level_u32": 4,
	"unknown_02020CB0": 4,
	"unknown_02020CB4": 100,
	"unknown_02020DA8": 1,
	"unknown_02020DB0": 901,
	"money_u64": 8,
	"event_flags_first_32_bytes": 32,
	"unknown_020237CC": 4,
	"unknown_020237C4": 2,
}
const REGION_ORDER := [
	"player_name_17_bytes",
	"unknown_02020770",
	"player_deck_40_u16",
	"deck_capacity_u32",
	"duelist_level_u32",
	"unknown_02020CB0",
	"unknown_02020CB4",
	"unknown_02020DA8",
	"unknown_02020DB0",
	"money_u64",
	"event_flags_first_32_bytes",
	"unknown_020237CC",
	"unknown_020237C4",
]
const PAYLOAD_SIZE := 2058

static func pack_regions(regions: Dictionary) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(PAYLOAD_SIZE)
	var offset := 0
	for region_name: String in REGION_ORDER:
		var size: int = REGION_SIZES[region_name]
		var bytes: Variant = regions.get(region_name, PackedByteArray())
		if not bytes is PackedByteArray or bytes.size() != size:
			push_error("Save region '%s' must contain exactly %d bytes." % [region_name, size])
			return PackedByteArray()
		for value: int in bytes:
			payload[offset] = value
			offset += 1
	return payload

static func unpack_regions(payload: PackedByteArray) -> Dictionary:
	if payload.size() != PAYLOAD_SIZE:
		push_error("Save payload must contain exactly %d bytes." % PAYLOAD_SIZE)
		return {}
	var regions: Dictionary = {}
	var offset := 0
	for region_name: String in REGION_ORDER:
		var size: int = REGION_SIZES[region_name]
		var bytes := PackedByteArray()
		bytes.resize(size)
		for index in range(size):
			bytes[index] = payload[offset]
			offset += 1
		regions[region_name] = bytes
	return regions

static func checksum(payload: PackedByteArray) -> int:
	if payload.size() != PAYLOAD_SIZE:
		push_error("Save payload must contain exactly %d bytes." % PAYLOAD_SIZE)
		return -1
	var total := 0
	for value: int in payload:
		total = (total + value) & 0xFFFF
	return total
