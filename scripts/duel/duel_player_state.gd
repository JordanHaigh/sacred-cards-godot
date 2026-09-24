class_name DuelPlayerState
extends RefCounted

## UI-independent state for one duelist during a duel.
##
## Cards are moved between the deck, hand, graveyard, and field through this
## object so a card instance is not accidentally owned by two zones at once.

const ZONE_MONSTER := "monster"
const ZONE_SPELL_TRAP := "spell_trap"
const ZONE_FIELD := "field"

var _player_id: String
var _life_points: int
var _deck: Array[RefCounted] = []
var _hand: Array[RefCounted] = []
var _graveyard: Array[RefCounted] = []
var _monster_zones: Array[RefCounted] = []
var _spell_trap_zones: Array[RefCounted] = []
var _field_zone: RefCounted = null
var _field_zone_enabled: bool = true

var player_id: String:
	get:
		return _player_id

var life_points: int:
	get:
		return _life_points
	set(value):
		_life_points = maxi(0, value)


func _init(
		initial_player_id: String = "",
		initial_life_points: int = 8000,
		monster_zone_count: int = 5,
		spell_trap_zone_count: int = 5,
		field_zone_count: int = 1,
	) -> void:
	_player_id = initial_player_id
	_life_points = maxi(0, initial_life_points)
	_monster_zones.resize(maxi(0, monster_zone_count))
	_spell_trap_zones.resize(maxi(0, spell_trap_zone_count))
	_field_zone_enabled = field_zone_count > 0


func load_deck(cards: Array) -> int:
	_deck.clear()
	for card in cards:
		if card is RefCounted and not _contains_card(card):
			_deck.append(card)
			_assign_owner(card)
	return _deck.size()


func add_to_deck(card: RefCounted, to_top: bool = false) -> bool:
	if card == null:
		return false
	_remove_card_from_all_zones(card)
	if to_top:
		_deck.push_front(card)
	else:
		_deck.append(card)
	_assign_owner(card)
	return true


func add_to_hand(card: RefCounted) -> bool:
	if card == null:
		return false
	_remove_card_from_all_zones(card)
	_hand.append(card)
	_assign_owner(card)
	return true


func send_to_graveyard(card: RefCounted) -> bool:
	if card == null:
		return false
	_remove_card_from_all_zones(card)
	_graveyard.append(card)
	_assign_owner(card)
	return true


func draw_card() -> RefCounted:
	if _deck.is_empty():
		return null
	var card: RefCounted = _deck.pop_front()
	_hand.append(card)
	_assign_owner(card)
	return card


func draw_cards(count: int) -> Array[RefCounted]:
	var drawn: Array[RefCounted] = []
	for _index in range(maxi(0, count)):
		var card := draw_card()
		if card == null:
			break
		drawn.append(card)
	return drawn


func take_damage(amount: int) -> int:
	var applied_damage := maxi(0, amount)
	var actual_damage := mini(applied_damage, _life_points)
	_life_points -= actual_damage
	return actual_damage


func heal(amount: int) -> int:
	var applied_healing := maxi(0, amount)
	_life_points += applied_healing
	return applied_healing


func is_defeated() -> bool:
	return _life_points <= 0


func get_deck() -> Array[RefCounted]:
	return _deck.duplicate()


func get_hand() -> Array[RefCounted]:
	return _hand.duplicate()


func get_graveyard() -> Array[RefCounted]:
	return _graveyard.duplicate()


func remove_from_graveyard(card: RefCounted) -> bool:
	var card_index := _graveyard.find(card)
	if card_index < 0:
		return false
	_graveyard.remove_at(card_index)
	return true


func deck_size() -> int:
	return _deck.size()


func hand_size() -> int:
	return _hand.size()


func graveyard_size() -> int:
	return _graveyard.size()


func get_open_zone_index(zone_type: String) -> int:
	if zone_type == ZONE_MONSTER:
		return get_open_monster_zone_index()
	if zone_type == ZONE_SPELL_TRAP:
		return get_open_spell_trap_zone_index()
	if zone_type == ZONE_FIELD:
		return 0 if is_field_zone_open() else -1
	return -1


func get_open_monster_zone_index() -> int:
	return _find_open_zone(_monster_zones)


func get_open_spell_trap_zone_index() -> int:
	return _find_open_zone(_spell_trap_zones)


func is_field_zone_open() -> bool:
	return _field_zone_enabled and _field_zone == null


func place_monster(card: RefCounted, zone_index: int = -1) -> int:
	var target_index := _resolve_zone_index(_monster_zones, zone_index)
	if card == null or target_index < 0:
		return -1
	_remove_card_from_all_zones(card)
	_monster_zones[target_index] = card
	_assign_owner(card)
	return target_index


func place_spell_trap(card: RefCounted, zone_index: int = -1) -> int:
	var target_index := _resolve_zone_index(_spell_trap_zones, zone_index)
	if card == null or target_index < 0:
		return -1
	_remove_card_from_all_zones(card)
	_spell_trap_zones[target_index] = card
	_assign_owner(card)
	return target_index


func place_field(card: RefCounted) -> bool:
	if card == null or not is_field_zone_open():
		return false
	_remove_card_from_all_zones(card)
	_field_zone = card
	_assign_owner(card)
	return true


func remove_monster(zone_index: int) -> RefCounted:
	if not _is_valid_zone_index(_monster_zones, zone_index):
		return null
	var card: RefCounted = _monster_zones[zone_index]
	_monster_zones[zone_index] = null
	return card


func remove_spell_trap(zone_index: int) -> RefCounted:
	if not _is_valid_zone_index(_spell_trap_zones, zone_index):
		return null
	var card: RefCounted = _spell_trap_zones[zone_index]
	_spell_trap_zones[zone_index] = null
	return card


func remove_field() -> RefCounted:
	var card := _field_zone
	_field_zone = null
	return card


func get_monster_zone(zone_index: int) -> RefCounted:
	if not _is_valid_zone_index(_monster_zones, zone_index):
		return null
	return _monster_zones[zone_index]


func get_spell_trap_zone(zone_index: int) -> RefCounted:
	if not _is_valid_zone_index(_spell_trap_zones, zone_index):
		return null
	return _spell_trap_zones[zone_index]


func get_field_zone() -> RefCounted:
	return _field_zone


func monster_zone_count() -> int:
	return _monster_zones.size()


func spell_trap_zone_count() -> int:
	return _spell_trap_zones.size()


func _find_open_zone(zones: Array[RefCounted]) -> int:
	for index in range(zones.size()):
		if zones[index] == null:
			return index
	return -1


func _resolve_zone_index(zones: Array[RefCounted], requested_index: int) -> int:
	if requested_index == -1:
		return _find_open_zone(zones)
	if not _is_valid_zone_index(zones, requested_index) or zones[requested_index] != null:
		return -1
	return requested_index


func _is_valid_zone_index(zones: Array[RefCounted], zone_index: int) -> bool:
	return zone_index >= 0 and zone_index < zones.size()


func _contains_card(card: RefCounted) -> bool:
	return _deck.has(card) or _hand.has(card) or _graveyard.has(card) or _monster_zones.has(card) or _spell_trap_zones.has(card) or _field_zone == card


func _remove_card_from_all_zones(card: RefCounted) -> void:
	_deck.erase(card)
	_hand.erase(card)
	_graveyard.erase(card)
	for index in range(_monster_zones.size()):
		if _monster_zones[index] == card:
			_monster_zones[index] = null
	for index in range(_spell_trap_zones.size()):
		if _spell_trap_zones[index] == card:
			_spell_trap_zones[index] = null
	if _field_zone == card:
		_field_zone = null


func _assign_owner(card: RefCounted) -> void:
	if card.has_method("to_serialized"):
		card.set("owner_id", _player_id)
