extends RefCounted
class_name PlayerWallet

var gold: int = 0

const MONEY_LIMIT := 9999999999999

func initialize_money() -> void:
	gold = 500

func can_afford(amount: int) -> bool:
	return amount >= 0 and gold >= amount

func can_receive(amount: int) -> bool:
	return amount >= 0 and amount <= MONEY_LIMIT - gold

func add(amount: int) -> void:
	if amount < 0 or amount > MONEY_LIMIT - gold:
		gold = MONEY_LIMIT
	else:
		gold += amount

func subtract(amount: int) -> void:
	if amount < 0 or amount > gold:
		gold = 0
	else:
		gold -= amount

func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	subtract(amount)
	return true
