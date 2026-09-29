extends RefCounted
class_name PlayerWallet

var gold: int = 0

const MONEY_LIMIT := 9999999999999

func can_afford(amount: int) -> bool:
	return amount >= 0 and gold >= amount

func add(amount: int) -> void:
	gold = mini(gold + amount, MONEY_LIMIT)

func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	return true
