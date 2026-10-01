extends RefCounted
class_name CardDefinition

## Immutable, hardware independent view of one recovered Sacred Cards record.

var id: int
var name: String
var attack: int
var defense: int
var cost: int
var base_price: int
var description: String
var frame_type: int
var frame_index: int
var attribute: int
var level: int
var card_type: int
var type_name: String
var summon_name: String
var metadata_1a: int
var metadata_1b: int
var metadata_1c: int
var metadata_1d: int
var art_path: String
var miniature_path: String

static func from_dictionary(data: Dictionary) -> CardDefinition:
	var definition := CardDefinition.new()
	definition.id = int(data.get("id", 0))
	definition.name = str(data.get("name", ""))
	definition.attack = int(data.get("attack", 0))
	definition.defense = int(data.get("defense", 0))
	definition.cost = int(data.get("cost", 0))
	definition.base_price = int(data.get("base_price", 0))
	definition.description = str(data.get("description", ""))
	definition.frame_type = int(data.get("frame_type", 0))
	definition.frame_index = int(data.get("frame", 0))
	definition.attribute = int(data.get("attribute", 0))
	definition.level = int(data.get("level", 0))
	definition.card_type = int(data.get("type", 0))
	definition.type_name = str(data.get("type_name", ""))
	definition.summon_name = str(data.get("summon_name", ""))
	definition.metadata_1a = int(data.get("metadata_1a", 0))
	definition.metadata_1b = int(data.get("metadata_1b", 0))
	definition.metadata_1c = int(data.get("metadata_1c", 0))
	definition.metadata_1d = int(data.get("metadata_1d", 0))
	definition.art_path = str(data.get("art", ""))
	definition.miniature_path = str(data.get("miniature", ""))
	return definition
