extends RefCounted
class_name DuelRewards

## Port of duel_rewards.c against named opponent and reward-table data.

const MONEY_LIMIT := 9999999999999
var opponent_database: OpponentDatabase

func _init(database: OpponentDatabase) -> void:
	opponent_database = database

func uses_normal_reward_table(wagered_card_id: int) -> bool:
	return not opponent_database.special_wager_cards.has(wagered_card_id)

func pick_duel_reward_card(opponent_id: int, wagered_card_id: int, random: SacredRandom) -> int:
	var table_type := "normal" if uses_normal_reward_table(wagered_card_id) else "special"
	var roll := random.halfword_inclusive(0, 2047)
	return _pick_reward(_selected_table(opponent_id, table_type), roll)

func award_duel_cards(save_data: PlayerSaveData, opponent_id: int, wagered_card_id: int, reward_count: int, random: SacredRandom) -> Array[int]:
	var rewards: Array[int] = []
	if wagered_card_id == 0 or reward_count <= 0:
		return rewards
	for _index in range(mini(reward_count, 10)):
		var card_id := pick_duel_reward_card(opponent_id, wagered_card_id, random)
		rewards.append(card_id)
		if card_id >= 0 and card_id < save_data.collection_counts.size():
			save_data.collection_counts[card_id] = mini(250, save_data.collection_counts[card_id] + 1)
	return rewards

func restock_shop(save_data: PlayerSaveData, opponent_id: int, random: SacredRandom) -> void:
	for _index in range(50):
		var card_id := _pick_reward(_selected_table(opponent_id, "shop"), random.halfword_inclusive(0, 29999))
		if card_id >= 1 and card_id < save_data.shop_stock.size():
			save_data.shop_stock[card_id] = mini(250, save_data.shop_stock[card_id] + 1)

func award_money(save_data: PlayerSaveData, opponent_id: int, random: SacredRandom) -> Dictionary:
	var opponent := opponent_database.get_opponent(opponent_id)
	if opponent.is_empty():
		return {"high": 0, "low": 0}
	var roll := random.halfword_inclusive(int(opponent.money_min), int(opponent.money_max))
	var scale := 1
	var scale_power := int(opponent.money_scale)
	if scale_power >= 1 and scale_power <= 15:
		for _index in range(scale_power):
			scale *= 10
	var low_product := roll * (scale & 0xFFFFFFFF)
	var high_product := roll * (scale >> 32)
	var low := low_product & 0xFFFFFFFF
	var high := ((high_product + (low_product >> 32)) & 0xFFFFFFFF)
	var available := MONEY_LIMIT - save_data.money
	var available_high := available >> 32
	var available_low := available & 0xFFFFFFFF
	if high > available_high or (high == available_high and low > available_low):
		save_data.money = MONEY_LIMIT
	else:
		save_data.money += high * 4294967296 + low
	return {"high": high, "low": low}

func _selected_table(opponent_id: int, table_type: String) -> Array:
	var opponent := opponent_database.get_opponent(opponent_id)
	if opponent.is_empty():
		return []
	var table_key: String = opponent.reward_tables.get(table_type, "")
	var table: Variant = opponent_database.reward_tables.get(table_key, [])
	return table if table is Array else []

func _pick_reward(entries: Array, roll: int) -> int:
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var card_id := int(entry.get("card", 0))
		if card_id == 0 or int(entry.get("threshold", 0)) > roll:
			return card_id
	return 0
