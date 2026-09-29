extends RefCounted
class_name DuelFlow

## Port of the recovered duel setup/turn-state portion of duel_flow.c. Visual
## presentation and reward callbacks are owned by their separate systems.

const DECK_DRAW_SCRIPT = preload("res://scripts/systems/duel_deck.gd")

signal card_transformed(side_id: int, column: int, previous_card_id: int, new_card_id: int)
signal duel_message_requested(message_id: int, number: int)

func initialize_duel(duel: SacredDuelState, player_deck: Array[int], opponent_deck: Array[int], terrain: int, player_lp: int, opponent_lp: int, random: SacredRandom) -> void:
	for side in duel.sides:
		side.deck.clear()
		side.hand.clear()
		side.hand_flags.clear()
		for slot in side.monster_zones:
			slot.clear()
		for slot in side.back_row_zones:
			slot.clear()
	duel.sides[0].deck = _compact_deck(player_deck)
	duel.sides[1].deck = _compact_deck(opponent_deck)
	_shuffle(duel.sides[0].deck, random)
	_shuffle(duel.sides[1].deck, random)
	duel.active_side = random.byte_inclusive(0, 1)
	duel.turn_number = 1
	duel.phase = SacredDuelState.Phase.DRAW
	duel.status = SacredDuelState.Status.ACTIVE
	duel.auxiliary_flags = [0, 0]
	duel.terrain = terrain
	duel.tributes_committed = 0
	duel.sides[0].life_points = player_lp
	duel.sides[1].life_points = opponent_lp
	duel.sides[0].deck_out = false
	duel.sides[1].deck_out = false
	for side in duel.sides:
		for _draw_index in range(5):
			DECK_DRAW_SCRIPT.draw_card(side)

func finish_turn(duel: SacredDuelState) -> void:
	if duel.status != SacredDuelState.Status.ACTIVE:
		return
	_return_borrowed_monsters(duel)
	var outgoing_side := duel.sides[duel.active_side]
	outgoing_side.duel_flags &= 0xF7
	for hand_index in range(outgoing_side.hand_flags.size()):
		outgoing_side.hand_flags[hand_index] &= 0xFE
	for side_index in range(duel.auxiliary_flags.size()):
		if duel.auxiliary_flags[side_index] != 2:
			duel.auxiliary_flags[side_index] = 1
	for slot in outgoing_side.monster_zones:
		if slot.card_id != 0 and (slot.persistent_flags & 2) == 0:
			slot.persistent_flags |= 16
	duel.active_side = 1 - duel.active_side
	duel.turn_number += 1
	duel.phase = SacredDuelState.Phase.DRAW
	duel.tributes_committed = 0
	var next_side := duel.sides[duel.active_side]
	next_side.duel_flags &= 0xF7
	for hand_index in range(next_side.hand_flags.size()):
		next_side.hand_flags[hand_index] &= 0xFE
	if next_side.attack_restriction_turns & 3:
		next_side.attack_restriction_turns = (next_side.attack_restriction_turns - 1) & 3
	for slot in next_side.monster_zones:
		slot.persistent_flags &= 0xFE
		slot.has_attacked = false
	for slot in next_side.back_row_zones:
		slot.persistent_flags &= 0xFE

## Applies the four source-defined growing-monster pairs to the active side.
## The recovered ROM pair table is supplied as data instead of read by address.
func transform_growing_monsters(duel: SacredDuelState, card_pairs: Array[Vector2i]) -> Array[Dictionary]:
	var transformed: Array[Dictionary] = []
	if duel == null or duel.active_side < 0 or duel.active_side >= duel.sides.size():
		return transformed
	for column in range(duel.sides[duel.active_side].monster_zones.size()):
		var slot: DuelCardSlot = duel.sides[duel.active_side].monster_zones[column]
		for pair in card_pairs:
			if slot.card_id == pair.x:
				var previous_id := slot.card_id
				slot.card_id = pair.y
				var record := {"side": duel.active_side, "column": column, "previous_card_id": previous_id, "card_id": pair.y}
				transformed.append(record)
				card_transformed.emit(duel.active_side, column, previous_id, pair.y)
				duel_message_requested.emit(14, 0)
				break
	return transformed

## Applies the persistent win/loss effects. UI/audio consumes the returned report
## and message signal; rules mutate only the owned save/progression models.
func resolve_outcome(duel: SacredDuelState, save_data: PlayerSaveData, opponent_id: int, wagered_card_id: int, reward_count: int, progression: PlayerProgression, random: SacredRandom, reward_system: DuelRewards, show_results: bool = true) -> Dictionary:
	if duel == null or save_data == null or progression == null or random == null or reward_system == null:
		return {}
	var player_won := duel.auxiliary_flags.size() > 1 and duel.auxiliary_flags[1] == 2
	var opponent: Dictionary = reward_system.opponent_database.get_opponent(opponent_id)
	if opponent.is_empty():
		return {}
	var report := {"won": player_won, "capacity_reward": 0, "card_rewards": [], "money_reward": 0, "messages": []}
	if player_won:
		var capacity_reward := int(opponent.get("capacity_reward", 0))
		progression.add_capacity(capacity_reward)
		save_data.deck_capacity = progression.capacity
		save_data.duelist_level = progression.duelist_level
		var card_rewards := reward_system.award_duel_cards(save_data, opponent_id, wagered_card_id, reward_count, random)
		reward_system.restock_shop(save_data, opponent_id, random)
		var money_before := save_data.money
		reward_system.award_money(save_data, opponent_id, random)
		report.capacity_reward = capacity_reward
		report.card_rewards = card_rewards
		report.money_reward = save_data.money - money_before
		if duel.sides[1].life_points <= 0:
			_push_message(report, 19, 0)
		elif duel.sides[1].deck_out:
			_push_message(report, 21, 0)
		if show_results:
			_push_message(report, 2, 0)
			_push_message(report, 6, capacity_reward)
			for card_id in card_rewards:
				_push_message(report, 5, card_id)
	else:
		if wagered_card_id > 0 and wagered_card_id < save_data.collection_counts.size():
			save_data.collection_counts[wagered_card_id] = maxi(0, save_data.collection_counts[wagered_card_id] - 1)
		if duel.sides[0].life_points <= 0:
			_push_message(report, 20, 0)
		elif duel.sides[0].deck_out:
			_push_message(report, 22, 0)
		if show_results:
			_push_message(report, 3, 0)
	for item: Dictionary in report.messages:
		duel_message_requested.emit(int(item.message_id), int(item.number))
	return report

func _push_message(report: Dictionary, message_id: int, number: int) -> void:
	var messages: Array = report.messages
	messages.append({"message_id": message_id, "number": number})
	report.messages = messages

func _shuffle(cards: Array[int], random: SacredRandom) -> void:
	if cards.is_empty():
		return
	for _swap_index in range(200):
		var a := random.byte_inclusive(0, 39)
		var b := random.byte_inclusive(0, 39)
		if a >= cards.size() or b >= cards.size():
			continue
		var value := cards[a]
		cards[a] = cards[b]
		cards[b] = value

func _compact_deck(cards: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for card_id in cards:
		if card_id == 0:
			break
		result.append(card_id)
		if result.size() == 40:
			break
	return result

func _return_borrowed_monsters(duel: SacredDuelState) -> void:
	var source_side := duel.sides[duel.active_side]
	var destination_side := duel.sides[1 - duel.active_side]
	for source in source_side.monster_zones:
		if source.card_id == 0 or (source.persistent_flags & 0x20) == 0:
			continue
		var destination_index := -1
		for index in range(destination_side.monster_zones.size() - 1, -1, -1):
			if destination_side.monster_zones[index].is_empty():
				destination_index = index
				break
		if destination_index >= 0:
			var destination := destination_side.monster_zones[destination_index]
			destination.card_id = source.card_id
			destination.persistent_flags = ((destination.persistent_flags | 16) & 0xD8) | (source.persistent_flags & 4)
			destination.zone_mode = 2
			destination.stage = source.stage
		source.clear()
