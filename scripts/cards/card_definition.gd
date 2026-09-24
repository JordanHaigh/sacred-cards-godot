class_name CardDefinition
extends Resource

## Immutable canonical card data loaded from the supplied JSON schema.
##
## Duel state such as ownership, face-up state, battle position, temporary
## ATK/DEF, and active effects must be stored in a separate CardInstance.

const VALID_CARD_TYPES: PackedStringArray = ["Monster", "Magic", "Trap", "Ritual"]
const REQUIRED_SOURCE_KEYS: PackedStringArray = [
	"id",
	"card",
	"link",
	"dc",
	"card_type",
	"monsterType",
	"type",
	"alignment",
	"level",
	"atk",
	"def",
	"password",
	"description",
]

var _card_id: int
var _display_name: String
var _source_link: String
var _source_dc: int
var _card_type: String
var _monster_subtype: Variant
var _monster_type: Variant
var _alignment: Variant
var _level: int
var _attack: int
var _defense: int
var _password: Variant
var _description: String
var _effect_ids: PackedStringArray = []
var _source_record: Dictionary = {}

var card_id: int:
	get:
		return _card_id

var display_name: String:
	get:
		return _display_name

var source_link: String:
	get:
		return _source_link

var source_dc: int:
	get:
		return _source_dc

var card_type: String:
	get:
		return _card_type

var monster_subtype: Variant:
	get:
		return _monster_subtype

var monster_type: Variant:
	get:
		return _monster_type

var alignment: Variant:
	get:
		return _alignment

var level: int:
	get:
		return _level

var attack: int:
	get:
		return _attack

var defense: int:
	get:
		return _defense

var password: Variant:
	get:
		return _password

var description: String:
	get:
		return _description

var effect_ids: PackedStringArray:
	get:
		return _effect_ids.duplicate()

var source_metadata: Dictionary:
	get:
		return _source_record.duplicate(true)


static func validate_source_record(record: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for key in REQUIRED_SOURCE_KEYS:
		if not record.has(key):
			errors.append("Missing required source field '%s'." % key)

	if not record.has("id") or not _is_integer_number(record.get("id")) or int(record.get("id")) <= 0:
		errors.append("'id' must be a positive integer.")
	if not record.has("card") or typeof(record.get("card")) != TYPE_STRING or String(record.get("card")).is_empty():
		errors.append("'card' must be a non-empty string.")
	if not record.has("link") or typeof(record.get("link")) != TYPE_STRING:
		errors.append("'link' must be a string.")
	if not record.has("dc") or not _is_integer_number(record.get("dc")) or int(record.get("dc")) < 0:
		errors.append("'dc' must be a non-negative integer.")
	if not record.has("card_type") or typeof(record.get("card_type")) != TYPE_STRING or not VALID_CARD_TYPES.has(String(record.get("card_type"))):
		errors.append("'card_type' must be one of: %s." % ", ".join(VALID_CARD_TYPES))
	if not _is_nullable_string(record.get("monsterType")):
		errors.append("'monsterType' must be a string or null.")
	if not _is_nullable_string(record.get("type")):
		errors.append("'type' must be a string or null.")
	if not _is_nullable_string(record.get("alignment")):
		errors.append("'alignment' must be a string or null.")
	if not record.has("level") or not _is_integer_number(record.get("level")) or int(record.get("level")) < 0:
		errors.append("'level' must be a non-negative integer.")
	if not record.has("atk") or not _is_integer_number(record.get("atk")) or int(record.get("atk")) < 0:
		errors.append("'atk' must be a non-negative integer.")
	if not record.has("def") or not _is_integer_number(record.get("def")) or int(record.get("def")) < 0:
		errors.append("'def' must be a non-negative integer.")
	if not _is_nullable_integer(record.get("password")):
		errors.append("'password' must be an integer or null.")
	if not record.has("description") or typeof(record.get("description")) != TYPE_STRING or String(record.get("description")).is_empty():
		errors.append("'description' must be a non-empty string.")
	if record.has("effect_ids"):
		if not record.get("effect_ids") is Array:
			errors.append("'effect_ids' must be an array of non-empty strings when supplied.")
		else:
			var seen_effect_ids: Dictionary = {}
			for effect_id in record.get("effect_ids"):
				if typeof(effect_id) != TYPE_STRING or String(effect_id).strip_edges().is_empty():
					errors.append("Every 'effect_ids' entry must be a non-empty string.")
				elif seen_effect_ids.has(String(effect_id)):
					errors.append("'effect_ids' entries must be unique.")
				else:
					seen_effect_ids[String(effect_id)] = true

	return errors


static func from_source_record(record: Dictionary) -> Resource:
	var errors := validate_source_record(record)
	if not errors.is_empty():
		for error in errors:
			push_error("CardDefinition: %s" % error)
		return null

	var definition = load("res://scripts/cards/card_definition.gd").new()
	definition._card_id = int(record["id"])
	definition._display_name = String(record["card"])
	definition._source_link = String(record["link"])
	definition._source_dc = int(record["dc"])
	definition._card_type = String(record["card_type"])
	definition._monster_subtype = record["monsterType"]
	definition._monster_type = record["type"]
	definition._alignment = record["alignment"]
	definition._level = int(record["level"])
	definition._attack = int(record["atk"])
	definition._defense = int(record["def"])
	definition._password = record["password"]
	definition._description = String(record["description"])
	for effect_id in record.get("effect_ids", []):
		definition._effect_ids.append(String(effect_id))
	definition._source_record = record.duplicate(true)
	return definition


func is_monster() -> bool:
	return card_type == "Monster"


func to_source_record() -> Dictionary:
	return _source_record.duplicate(true)


static func _is_nullable_string(value: Variant) -> bool:
	return value == null or typeof(value) == TYPE_STRING


static func _is_nullable_integer(value: Variant) -> bool:
	return value == null or _is_integer_number(value)


static func _is_integer_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(float(value), round(float(value)))
	return false
