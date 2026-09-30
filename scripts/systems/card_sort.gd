extends RefCounted
class_name CardSortSystem

## Hardware independent port of the 54 key builders in card_sort.c.
## Input and output are card IDs; inventory counts remain in model dictionaries.
const KEY_NAMES := ["copy", "number", "name", "attack", "defense", "type", "attribute", "cost", "quantity", "buy_price", "sell_price", "level"]
const INVENTORIES := ["none", "collection", "buy_stock", "sell_collection", "total"]
const METHOD_TABLE := [
	[0,0],[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0],[8,1],[9,2],[10,3],[11,0],
	[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[11,1],
	[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[11,2],
	[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[11,3],
	[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[12,0],[7,0],[11,0],
	[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[8,4],[7,4],[11,4]
]

var database: CardDatabase
var shop: ShopSystem
var deck: Array[int] = []
var language := 0
var name_ranks: Array = []
## Native card_sort.c replaces records with five ROM-backed output orders for
## methods 1 and 3-6. Store those orders as ordinary Godot arrays when the
## exact table data is available; keys are sort method IDs and values are card
## IDs in source table order.
var fixed_output_lists: Dictionary = {}

func _init(card_database: CardDatabase = null, shop_system: ShopSystem = null) -> void:
	database = card_database
	shop = shop_system
	_load_name_ranks()

func _load_name_ranks() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/card_name_ranks.json")) if FileAccess.file_exists("res://resources/card_name_ranks.json") else null
	if parsed is Dictionary:
		name_ranks = parsed.get("languages", [])

func sort_cards(card_ids: Array[int], method: int, collection: Dictionary = {}, buy_stock: Dictionary = {}, sell_collection: Dictionary = {}, totals: Dictionary = {}) -> Array[int]:
	if method < 0 or method >= METHOD_TABLE.size():
		return card_ids.duplicate()
	var rows: Array[Dictionary] = []
	var fixed_order: Array = fixed_output_lists.get(method, [])
	var fixed_zero_key_order := method >= 3 and method <= 6 and fixed_order.size() >= card_ids.size()
	for index in range(card_ids.size()):
		var card_id := card_ids[index]
		var output_id := int(fixed_order[index]) if index < fixed_order.size() else card_id
		var sort_key := 0 if fixed_zero_key_order else _key(card_id, method, collection, buy_stock, sell_collection, totals)
		rows.append({"id": output_id, "key": sort_key})
	_sort_records_descending(rows)
	var result: Array[int] = []
	for row in rows:
		result.append(int(row.id))
	return result

## Accepts recovered ROM orders without retaining their original addresses.
## The arrays are copied and normalized so callers cannot mutate sorter state
## accidentally after configuration.
func set_fixed_output_lists(orders: Dictionary) -> void:
	fixed_output_lists.clear()
	for raw_method: Variant in orders:
		var method := int(raw_method)
		var raw_order: Variant = orders[raw_method]
		if method < 0 or method >= METHOD_TABLE.size() or not raw_order is Array:
			continue
		var order: Array[int] = []
		for raw_card_id: Variant in raw_order:
			order.append(int(raw_card_id))
		fixed_output_lists[method] = order

## Mirrors SortRecords' midpoint-pivot partition and range push order. Equal
## keys swap as the native routine does instead of retaining input order.
func _sort_records_descending(records: Array[Dictionary]) -> void:
	if records.size() < 2:
		return
	var ranges: Array[Vector2i] = [Vector2i(0, records.size() - 1)]
	while not ranges.is_empty():
		var current: Vector2i = ranges.pop_back()
		var first: int = current.x
		var last: int = current.y
		var left: int = first
		var right: int = last
		var pivot := int(records[(left + right) >> 1].get("key", 0))
		while true:
			while int(records[left].get("key", 0)) > pivot:
				left += 1
			while int(records[right].get("key", 0)) < pivot:
				right -= 1
			if right <= left:
				break
			var swapped := records[left]
			records[left] = records[right]
			records[right] = swapped
			left += 1
			right -= 1
		if right + 1 < last:
			ranges.append(Vector2i(right + 1, last))
		if first < left - 1:
			ranges.append(Vector2i(first, left - 1))

func _key(card_id: int, method: int, collection: Dictionary, buy_stock: Dictionary, sell_collection: Dictionary, totals: Dictionary) -> int:
	var spec: Array = METHOD_TABLE[method]
	var kind := int(spec[0])
	var inventory := int(spec[1])
	var counts: Dictionary = {}
	match inventory:
		1: counts = collection
		2: counts = buy_stock
		3: counts = sell_collection
		4: counts = totals
	var count := int(counts.get(card_id, 0))
	var card: CardDefinition = database.get_card(card_id) if database != null else null
	var base := 900 - card_id
	match kind:
		0: return 0
		1:
			return base + (900 if count > 0 and (inventory == 1 or inventory == 4) else 0)
		2:
			var rank := card_id
			if language >= 0 and language < name_ranks.size() and card_id >= 0 and card_id < name_ranks[language].size():
				rank = int(name_ranks[language][card_id])
			return 900 - rank + (900 if count > 0 else 0)
		3: return _packed_key(base, ((card.attack + 1) & 0xffff) if card != null else 1, count)
		4: return _packed_key(base, ((card.defense + 1) & 0xffff) if card != null else 1, count)
		5: return _packed_key(base, 255 - card.card_type if card != null else 255, count)
		6: return _packed_key(base, (256 - card.attribute) & 255 if card != null else 0, count)
		7: return _packed_key(base, card.cost if card != null else 0, count)
		8: return base | (count << 16)
		9: return base | ((shop.buy_price(card_id) if shop != null else 0) << 16)
		10: return _packed_key(base, shop.sell_price(card_id) if shop != null else 0, count)
		11: return _packed_key(base, card.level if card != null else 0, count)
		12:
			var deck_count := 0
			for entry in deck:
				if entry == card_id:
					deck_count += 1
			return base | (deck_count << 16)
	return base

func _packed_key(base: int, value: int, count: int) -> int:
	var key := base | ((value & 0xffffffff) << 16)
	if count > 0:
		key |= 1 << 60
	return key
