extends RefCounted
class_name ShopSystem

## Port of shop.c inventory/price rules. Counts are keyed by Sacred Cards ID;
## the source's byte arrays and fixed RAM addresses are ordinary dictionaries.

const MAX_OWNED_COPIES := 250
const CardDatabaseScript = preload("res://scripts/data/card_database.gd")

var card_database: CardDatabase
var collection: Dictionary[int, int] = {}
var stock: Dictionary[int, int] = {}

func _init(database: CardDatabase = null) -> void:
	card_database = database

func buy_price(card_id: int) -> int:
	var count := int(stock.get(card_id, 0))
	if count < 1 or count > MAX_OWNED_COPIES:
		return 0
	var card := card_database.get_card(card_id) if card_database != null else null
	if card == null:
		return 0
	return maxi(1, int(card.base_price * (251 - count) / 250))

func sell_price(card_id: int) -> int:
	var count := int(stock.get(card_id, 0))
	var card := card_database.get_card(card_id) if card_database != null else null
	if card == null:
		return 0
	var numerator: int = card.base_price * (250 - count) if count < 250 else card.base_price
	return maxi(1, int(numerator / 500))

func buy(card_id: int, wallet: PlayerWallet) -> bool:
	var count := int(stock.get(card_id, 0))
	var owned := int(collection.get(card_id, 0))
	var price := buy_price(card_id)
	if count <= 0 or price <= 0 or owned >= MAX_OWNED_COPIES or not wallet.can_afford(price):
		return false
	stock[card_id] = count - 1
	collection[card_id] = owned + 1
	wallet.spend(price)
	return true

func sell(card_id: int, wallet: PlayerWallet) -> bool:
	var owned := int(collection.get(card_id, 0))
	if owned <= 0:
		return false
	var payout := sell_price(card_id)
	collection[card_id] = owned - 1
	stock[card_id] = mini(MAX_OWNED_COPIES, int(stock.get(card_id, 0)) + 1)
	wallet.add(payout)
	return true

func set_count(inventory: Dictionary[int, int], card_id: int, count: int) -> void:
	if card_id <= 0:
		return
	inventory[card_id] = clampi(count, 0, MAX_OWNED_COPIES)
