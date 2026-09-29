extends RefCounted
class_name PlayerWallet

var gold: int = 0

const MONEY_LIMIT := 9999999999999

func can_afford(amount: int) -> bool:
	return amount >= 0 and gold >= amount

func can_receive(amount: int) -> bool:
	return amount >= 0 and amount <= MONEY_LIMIT - gold

func add(amount: int) -> void:
	if amount < 0 or amount > MONEY_LIMIT - gold:
		gold = MONEY_LIMIT
	else:
		gold += amount

func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	return true
