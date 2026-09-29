extends RefCounted
class_name PlayerSaveData

## Named save model based on the recovered payload regions. Unidentified source
## regions are retained as named extension data rather than raw RAM slices.

var player_name: String = ""
var collection_counts: Array[int] = []
var deck: Array[int] = []
var deck_capacity: int = 1600
var duelist_level: int = 72
var event_flags: PackedByteArray = PackedByteArray()
var shop_stock: Array[int] = []
var money: int = 500
var random_state: int = 1
var extensions: Dictionary = {}

func _init() -> void:
	collection_counts.resize(901)
	shop_stock.resize(901)
	event_flags.resize(50)
	deck.resize(40)

func to_dictionary() -> Dictionary:
	return {
		"version": 1,
		"player_name": player_name,
		"collection_counts": Array(collection_counts),
		"deck": deck.duplicate(),
		"deck_capacity": deck_capacity,
		"duelist_level": duelist_level,
		"event_flags": Array(event_flags),
		"shop_stock": Array(shop_stock),
		"money": money,
		"random_state": random_state,
		"extensions": extensions.duplicate(true),
	}

static func from_dictionary(data: Dictionary) -> PlayerSaveData:
	var save := PlayerSaveData.new()
	save.player_name = str(data.get("player_name", ""))
	save.collection_counts = _int_array(data.get("collection_counts", []), 901)
	save.deck = _int_array(data.get("deck", []), 40)
	save.deck_capacity = int(data.get("deck_capacity", 1600))
	save.duelist_level = int(data.get("duelist_level", 72))
	save.event_flags = _byte_array(data.get("event_flags", []), 50)
	save.shop_stock = _int_array(data.get("shop_stock", []), 901)
	save.money = int(data.get("money", 500))
	save.random_state = int(data.get("random_state", 1)) & 0xFFFFFFFF
	var extensions: Variant = data.get("extensions", {})
	save.extensions = extensions.duplicate(true) if extensions is Dictionary else {}
	return save

static func _int_array(values: Variant, size: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(size):
		result.append(int(values[index]) if values is Array and index < values.size() else 0)
	return result

static func _byte_array(values: Variant, size: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(size)
	for index in range(size):
		result[index] = clampi(int(values[index]), 0, 255) if values is Array and index < values.size() else 0
	return result
