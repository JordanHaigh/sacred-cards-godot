extends RefCounted
class_name DeckBuilderState

## Hardware independent port of deck_builder_state.c constraints and transfer
## rules. The 40 card list and collection counts own their data directly.

const DECK_LIMIT := 40
const COLLECTION_LIMIT := 250

var deck: Array[int] = []
var collection: Dictionary[int, int] = {}
var selected_collection_card_id: int = 0
var selected_deck_index: int = 0
var one_copy_ids: Dictionary[int, bool] = {}
var two_copy_ids: Dictionary[int, bool] = {}

func load_copy_limits(path: String = "res://resources/copy_limits.json") -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	one_copy_ids.clear()
	two_copy_ids.clear()
	var lists: Dictionary = data.get("lists", {})
	for card_id: Variant in lists.get("one-copy", []):
		one_copy_ids[int(card_id)] = true
	for card_id: Variant in lists.get("two-copy", []):
		two_copy_ids[int(card_id)] = true
	return OK

func can_add(card_id: int, card_cost: int, duelist_level: int) -> bool:
	return card_id > 0 \
		and (int(collection.get(card_id, 0)) & 0xff) > 0 \
		and deck.size() < DECK_LIMIT \
		and count_in_deck(card_id) < copy_limit(card_id) \
		and card_cost <= duelist_level

func add_selected(card_id: int, card_cost: int, duelist_level: int) -> bool:
	if not can_add(card_id, card_cost, duelist_level):
		return false
	collection[card_id] = (int(collection[card_id]) - 1) & 0xff
	deck.append(card_id)
	selected_deck_index = deck.size() - 1
	return true

func remove_from_collection_view(card_id: int) -> bool:
	var index := deck.find(card_id)
	if index < 0:
		return false
	deck.remove_at(index)
	# Native gCardCollection is a byte here and this collection-view path
	# deliberately increments without the deck-view 250-card saturation.
	collection[card_id] = (int(collection.get(card_id, 0)) + 1) & 0xff
	selected_deck_index = clampi(selected_deck_index, 0, maxi(deck.size() - 1, 0))
	return true

func remove_selected_deck_card() -> int:
	if deck.is_empty():
		return 0
	selected_deck_index = clampi(selected_deck_index, 0, deck.size() - 1)
	var card_id: int = deck.pop_at(selected_deck_index)
	collection[card_id] = mini(COLLECTION_LIMIT, (int(collection.get(card_id, 0)) & 0xff) + 1)
	selected_deck_index = clampi(selected_deck_index, 0, maxi(deck.size() - 1, 0))
	return card_id

func count_in_deck(card_id: int) -> int:
	var count := 0
	for entry in deck:
		if entry == card_id:
			count += 1
	return count

func copy_limit(card_id: int) -> int:
	if one_copy_ids.has(card_id):
		return 1
	if two_copy_ids.has(card_id):
		return 2
	return 3

func deck_cost(database: CardDatabase) -> int:
	var total := 0
	for card_id in deck:
		var card := database.get_card(card_id)
		if card != null:
			total += card.cost
	return total
