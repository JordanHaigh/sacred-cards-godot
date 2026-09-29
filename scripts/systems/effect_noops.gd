extends RefCounted
class_name CardEffectNoops

## Metadata-1A native entries that are literally empty handlers in effect_noops.c.
const METADATA_1A_EMPTY_INDICES := [0, 1, 2, 47, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 114, 117, 120, 126, 127, 128, 129, 130, 131]

static func is_empty_metadata_1a_handler(handler_index: int) -> bool:
	return handler_index in METADATA_1A_EMPTY_INDICES

static func invoke(_card: CardDefinition, _context: Dictionary = {}) -> Dictionary:
	return {}
