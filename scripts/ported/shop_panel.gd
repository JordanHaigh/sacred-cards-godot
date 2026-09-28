class_name ShopPanel
extends RefCounted
## Hardware-independent model of the selected-card panel in shop_panel.c.

const PlayerWalletScript = preload("res://scripts/state/player_wallet.gd")

var card_database: CardDatabase
var shop_rules: ShopSystem

func _init(database: CardDatabase, shop: ShopSystem) -> void:
	card_database = database
	shop_rules = shop

func describe(card_id: int, selling: bool, wallet: PlayerWallet, deck: Array[int]) -> Dictionary:
	var card := card_database.get_card(card_id) if card_database != null else null
	if card == null:
		return {"available": false, "card_id": card_id, "name": "UNKNOWN CARD"}
	var buy_cost := shop_rules.buy_price(card_id)
	var payout := shop_rules.sell_price(card_id)
	var balance_after := wallet.gold
	var shortfall := 0
	if selling:
		balance_after = mini(PlayerWalletScript.MONEY_LIMIT, wallet.gold + payout)
	else:
		shortfall = maxi(buy_cost - wallet.gold, 0)
		if shortfall == 0:
			balance_after = wallet.gold - buy_cost
	var deck_copies := 0
	for deck_card in deck:
		if deck_card == card_id:
			deck_copies += 1
	return {
		"available": true,
		"card_id": card.id,
		"name": card.name,
		"attack": card.attack,
		"defense": card.defense,
		"attribute": card.attribute,
		"type": card.card_type,
		"level": card.level,
		"cost": card.cost,
		"stock": int(shop_rules.stock.get(card_id, 0)),
		"owned": int(shop_rules.collection.get(card_id, 0)),
		"deck_copies": deck_copies,
		"buy_price": buy_cost,
		"sell_price": payout,
		"transaction_price": payout if selling else buy_cost,
		"balance_after": balance_after,
		"shortfall": shortfall,
		"can_receive_payout": wallet.gold + payout <= PlayerWalletScript.MONEY_LIMIT,
		"selling": selling,
	}
