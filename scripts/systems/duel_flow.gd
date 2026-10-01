extends RefCounted
class_name DuelFlow

## Port of the recovered duel setup/turn-state portion of duel_flow.c. Visual
## presentation and reward callbacks are owned by their separate systems.

const DECK_DRAW_SCRIPT = preload("res://scripts/systems/duel_deck.gd")
const GROWING_MONSTER_TABLE_PATH := "res://resources/growing_monster_pairs.json"

signal card_transformed(side_id: int, column: int, previous_card_id: int, new_card_id: int)
signal duel_message_requested(message_id: int, number: int)
signal duel_audio_requested(audio_id: int)
signal duel_music_fade_requested(step_interval: int)
var growing_monster_pairs: Array[Vector2i] = []

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GROWING_MONSTER_TABLE_PATH)) if FileAccess.file_exists(GROWING_MONSTER_TABLE_PATH) else null
	if not parsed is Dictionary or not parsed.get("pairs", []) is Array:
		push_error("Missing recovered growing-monster pair table.")
		return
	for raw_pair: Variant in parsed.pairs:
		if raw_pair is Dictionary:
			growing_monster_pairs.append(Vector2i(int(raw_pair.get("from_card_id", 0)), int(raw_pair.get("to_card_id", 0))))
	if growing_monster_pairs.size() != 4:
		push_error("Growing-monster pair table must contain four source pairs.")

func initialize_duel(duel: SacredDuelState, player_deck: Array[int], opponent_deck: Array[int], terrain: int, player_lp: int, opponent_lp: int, random: SacredRandom) -> void:
	for side in duel.sides:
		# InitializeDuelBoard clears native side-state bits 0..2 while
		# preserving the higher persistent bits in the packed flag byte.
		side.duel_flags &= 0xF8
		side.deck.clear()
		side.deck_remaining_count = 0
		side.clear_hand()
		for slot in side.monster_zones:
			slot.clear()
		for slot in side.back_row_zones:
			slot.clear()
	duel.sides[0].deck = _fixed_deck(player_deck)
	duel.sides[1].deck = _fixed_deck(opponent_deck)
	duel.sides[0].deck_remaining_count = _count_deck(duel.sides[0].deck)
	duel.sides[1].deck_remaining_count = _count_deck(duel.sides[1].deck)
	_shuffle(duel.sides[0].deck, random)
	_shuffle(duel.sides[1].deck, random)
	duel.active_side = random.byte_inclusive(0, 1)
	# RunDuel clears gDuelSideState[0] before the first OrientDuelBoard call;
	# InitializeDuelBoard has left that alias pointed at absolute side zero.
	duel.sides[0].duel_flags &= 0xF7
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
			DECK_DRAW_SCRIPT.draw_card(side, duel)
		for side_index in range(duel.sides.size()):
			if duel.sides[side_index].deck_out:
				duel.auxiliary_flags[side_index] = 2
		if duel.auxiliary_flags[0] == 2 or duel.auxiliary_flags[1] == 2:
			duel.status = SacredDuelState.Status.PLAYER_TWO_WON if duel.auxiliary_flags[0] == 2 else SacredDuelState.Status.PLAYER_ONE_WON

func finish_turn(duel: SacredDuelState) -> void:
	if duel.status != SacredDuelState.Status.ACTIVE:
		return
	_return_borrowed_monsters(duel)
	var outgoing_side := duel.sides[duel.active_side]
	for side_index in range(duel.auxiliary_flags.size()):
		if duel.auxiliary_flags[side_index] == 0:
			duel.auxiliary_flags[side_index] = 1
	for slot in outgoing_side.monster_zones:
		if slot.card_id != 0 and (slot.persistent_flags & 2) == 0:
			slot.persistent_flags |= 16
	duel.active_side = 1 - duel.active_side
	duel.turn_number += 1
	duel.phase = SacredDuelState.Phase.DRAW
	duel.tributes_committed = 0
	# The native board still has the outgoing side oriented at side index 0 here.
	# FinishDuelTurn clears its defense-restriction bit, attack countdown, and used bits.
	outgoing_side.duel_flags &= 0xFB
	if outgoing_side.duel_flags & 3:
		outgoing_side.duel_flags = (outgoing_side.duel_flags & 0xFC) | ((outgoing_side.duel_flags - 1) & 3)
	for slot in outgoing_side.monster_zones:
		if slot.card_id != 0:
			slot.persistent_flags &= 0xFE
			slot.has_attacked = false
	for hand_index in range(outgoing_side.hand_flags.size()):
		if outgoing_side.hand[hand_index] != 0:
			outgoing_side.hand_flags[hand_index] &= 0xFE
	# FinishDuelTurn toggles active_side but keeps native row pointers in the
	# outgoing orientation until the next loop's OrientDuelBoard call. Its
	# gDuelSideState[0] bit-3 clear therefore belongs to the outgoing side.
	outgoing_side.duel_flags &= 0xF7

## Emits the recovered player-facing turn line; opponent speech uses a
## separate opponent-indexed ROM pointer table that is not yet extracted.
func request_turn_opening_message(side_id: int) -> void:
	if side_id == 0:
		duel_message_requested.emit(0, 0)

## Applies the four recovered-ID pairs to the active side before it acts.
## Pair IDs are isolated in a Godot resource because their ROM data table was
## not included in the extracted payloads; see that resource's provenance.
func transform_growing_monsters(duel: SacredDuelState) -> Array[Dictionary]:
	var transformed: Array[Dictionary] = []
	if duel == null or duel.active_side < 0 or duel.active_side >= duel.sides.size():
		return transformed
	for column in range(duel.sides[duel.active_side].monster_zones.size()):
		var slot: DuelCardSlot = duel.sides[duel.active_side].monster_zones[column]
		for pair in growing_monster_pairs:
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
		var money_words := reward_system.award_money(save_data, opponent_id, random)
		report.capacity_reward = capacity_reward
		report.card_rewards = card_rewards
		report.money_reward = save_data.money - money_before
		report.money_reward_words = money_words
		if duel.sides[1].life_points <= 0:
			_push_message(report, 19, 0)
		elif duel.sides[1].deck_out:
			_push_message(report, 21, 0)
		if show_results:
			_push_message(report, 2, 0)
			_push_message(report, 6, capacity_reward)
			_push_money_reward_message(report, int(money_words.get("high", 0)), int(money_words.get("low", 0)))
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
		var message_id := int(item.message_id)
		if message_id in [19, 20, 21, 22]:
			duel_music_fade_requested.emit(4)
		# The native result cue follows any LP/deck-out text and precedes the
		# result message. The UI queues this audio event alongside the messages.
		if show_results and message_id == (2 if player_won else 3):
			duel_audio_requested.emit(43 if player_won else 44)
		duel_message_requested.emit(message_id, int(item.number))
	return report

func _push_message(report: Dictionary, message_id: int, number: int) -> void:
	var messages: Array = report.messages
	messages.append({"message_id": message_id, "number": number})
	report.messages = messages

func _push_money_reward_message(report: Dictionary, high: int, low: int) -> void:
	var message_id := 8
	var divisor := 1
	if high == 0 and low < 10000:
		message_id = 8
	elif high == 0 and low < 100000000:
		message_id = 9
		divisor = 10000
	elif high < 232 or (high == 232 and low < 3567587328):
		message_id = 10
		divisor = 100000000
	else:
		message_id = 11
		divisor = 1000000000000
	if high == 0 and low == 0:
		message_id = 12
		divisor = 1
	var number := _divide_u64_words(high, low, divisor) & 0xFFFF
	_push_message(report, message_id, number)

## The selected divisors keep the quotient in a signed 32-bit range. Long
## division keeps the input as two uint32 words, including values above int64.
func _divide_u64_words(high: int, low: int, divisor: int) -> int:
	var quotient := 0
	var remainder := 0
	for bit_index in range(63, -1, -1):
		var bit_value := ((high >> (bit_index - 32)) & 1) if bit_index >= 32 else ((low >> bit_index) & 1)
		remainder = remainder * 2 + bit_value
		if remainder >= divisor:
			remainder -= divisor
			if bit_index < 31:
				quotient |= 1 << bit_index
	return quotient

func _shuffle(cards: Array[int], random: SacredRandom) -> void:
	for _swap_index in range(200):
		var a := random.byte_inclusive(0, 39)
		var b := random.byte_inclusive(0, 39)
		var value := cards[a]
		cards[a] = cards[b]
		cards[b] = value

func _fixed_deck(cards: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for index in range(40):
		result.append(int(cards[index]) if index < cards.size() else 0)
	return result

func _count_deck(cards: Array[int]) -> int:
	var count := 0
	while count < 40 and cards[count] != 0:
		count += 1
	return count

func _return_borrowed_monsters(duel: SacredDuelState) -> void:
	var source_side := duel.sides[duel.active_side]
	var relative_opponent_monsters := duel.relative_board_row(duel.active_side, 1)
	for source in source_side.monster_zones:
		if source.card_id == 0 or (source.persistent_flags & 0x20) == 0:
			continue
		var destination: DuelCardSlot
		for relative_column in range(relative_opponent_monsters.size() - 1, -1, -1):
			if relative_opponent_monsters[relative_column].is_empty():
				destination = relative_opponent_monsters[relative_column]
				break
		if destination != null:
			destination.card_id = source.card_id
			destination.controller = 1 - duel.active_side
			destination.face_down = false
			destination.defense_position = (source.persistent_flags & 4) != 0
			destination.has_attacked = false
			destination.persistent_flags = ((destination.persistent_flags | 16) & 0xD8) | (source.persistent_flags & 4)
			destination.zone_mode = 2
			destination.stage = source.stage
		source.clear()
