extends RefCounted
class_name SacredPasswordSystem

## Ordered password lookup and reward behavior from password.c.
const DATA_PATH := "res://resources/password_records.json"
const FOUND := 10
const NOT_FOUND := 11
const MONEY_BONUS := 50000
const CAPACITY_BONUS := 100

var _card_records: Array = []
var _bonus_records: Array = []

func load_recovered_data() -> Error:
	if not FileAccess.file_exists(DATA_PATH):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	_card_records = parsed.get("card_records", [])
	_bonus_records = parsed.get("bonus_records", [])
	if _card_records.size() != 902 or _bonus_records.size() != 4:
		return ERR_INVALID_DATA
	return OK

func compare_passwords(first: String, second: String) -> int:
	return FOUND if first.length() == 8 and second.length() == 8 and first == second else NOT_FOUND

func find_card_password(password: String) -> Dictionary:
	return _find_in_records(password, _card_records)

func find_bonus_password(password: String) -> Dictionary:
	return _find_in_records(password, _bonus_records)

func apply_password(password: String, save_data: PlayerSaveData, progression: PlayerProgression) -> Dictionary:
	if not _is_eight_digits(password) or save_data == null:
		return {"found": false, "kind": "invalid"}
	var card_result := find_card_password(password)
	if int(card_result.status) == FOUND:
		var card_id := int(card_result.id)
		if card_id <= 0 or card_id >= save_data.shop_stock.size():
			return {"found": true, "kind": "card", "id": card_id, "added": false}
		var count := save_data.shop_stock[card_id]
		save_data.shop_stock[card_id] = mini(250, count + 1)
		return {"found": true, "kind": "card", "id": card_id, "added": true}
	var bonus_result := find_bonus_password(password)
	if int(bonus_result.status) != FOUND:
		return {"found": false, "kind": "unknown"}
	var bonus_id := int(bonus_result.id)
	if _bonus_was_used(save_data, bonus_id):
		return {"found": true, "kind": "bonus", "id": bonus_id, "used": true, "applied": false}
	_mark_bonus_used(save_data, bonus_id)
	match bonus_id:
		1:
			save_data.money = mini(save_data.money + MONEY_BONUS, PlayerWallet.MONEY_LIMIT)
			return {"found": true, "kind": "bonus", "id": bonus_id, "used": false, "applied": true, "money": MONEY_BONUS}
		2:
			if progression == null:
				return {"found": true, "kind": "bonus", "id": bonus_id, "used": false, "applied": false}
			progression.add_capacity(CAPACITY_BONUS)
			save_data.deck_capacity = progression.capacity
			save_data.duelist_level = progression.duelist_level
			return {"found": true, "kind": "bonus", "id": bonus_id, "used": false, "applied": true, "capacity": CAPACITY_BONUS}
		_:
			return {"found": true, "kind": "bonus", "id": bonus_id, "used": false, "applied": false}

func _find_in_records(password: String, records: Array) -> Dictionary:
	if not _is_eight_digits(password):
		return {"status": NOT_FOUND, "id": -1}
	for record: Variant in records:
		if not record is Dictionary:
			continue
		var kind := str(record.get("kind", "end"))
		if kind == "end":
			break
		if kind != "skip" and compare_passwords(password, str(record.get("password", ""))) == FOUND:
			return {"status": FOUND, "id": int(record.get("index", -1))}
	return {"status": NOT_FOUND, "id": -1}

func _bonus_was_used(save_data: PlayerSaveData, bonus_id: int) -> bool:
	if bonus_id < 0 or bonus_id >= 10:
		return false
	var bits: Variant = save_data.extensions.get("used_bonus_passwords", [0, 0])
	return bits is Array and bits.size() >= 2 and (int(bits[bonus_id >> 3]) & (1 << (bonus_id & 7))) != 0

func _mark_bonus_used(save_data: PlayerSaveData, bonus_id: int) -> void:
	if bonus_id < 0 or bonus_id >= 10:
		return
	var bits: Variant = save_data.extensions.get("used_bonus_passwords", [0, 0])
	var normalized: Array[int] = [0, 0]
	if bits is Array:
		for index in range(mini(2, bits.size())):
			normalized[index] = int(bits[index]) & 255
	normalized[bonus_id >> 3] |= 1 << (bonus_id & 7)
	save_data.extensions["used_bonus_passwords"] = normalized

func _is_eight_digits(password: String) -> bool:
	if password.length() != 8:
		return false
	for index in range(8):
		var code := password.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true
