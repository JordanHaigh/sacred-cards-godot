class_name DuelMenus
extends RefCounted
## Value-state for duel context/action menus and temporary inspection overlays.
## Callers render the returned labels and preview data with Godot Controls.

enum Menu { NONE, CONTEXT, MONSTER_ACTION }
enum ContextAction { SUMMON, SET, ACTIVATE }
enum MonsterAction { ATTACK, DEFENSE, CHANGE_POSITION, CANCEL }

const CONTEXT_LABELS := ["SUMMON", "SET", "ACTIVATE"]
const MONSTER_LABELS := ["ATTACK", "DEFENSE", "CHANGE POSITION", "CANCEL"]

var menu := Menu.NONE
var choice := 0
var selected_cell := Vector2i.ZERO
var life_points := [8000, 8000]
var deck_counts := [40, 40]
var grave_card_ids := [0, 0]
var opponent_hand: Array[int] = []
var inspect_stats_held := false

func open_context(cell: Vector2i, player_life: int, rival_life: int, player_deck_count: int, rival_deck_count: int, player_grave_id: int, rival_grave_id: int) -> void:
	menu = Menu.CONTEXT
	choice = 0
	selected_cell = cell
	life_points = [player_life, rival_life]
	deck_counts = [player_deck_count, rival_deck_count]
	grave_card_ids = [player_grave_id, rival_grave_id]

func open_monster_action(cell: Vector2i, starts_in_defense: bool = false) -> void:
	menu = Menu.MONSTER_ACTION
	choice = 1 if starts_in_defense else 0
	selected_cell = cell

func labels() -> PackedStringArray:
	match menu:
		Menu.CONTEXT: return PackedStringArray(CONTEXT_LABELS)
		Menu.MONSTER_ACTION: return PackedStringArray(MONSTER_LABELS)
	return PackedStringArray()

func move(direction: int) -> int:
	var count := labels().size()
	if count > 0:
		choice = posmod(choice + direction, count)
	return choice

func confirm() -> Dictionary:
	if menu == Menu.MONSTER_ACTION:
		if choice < 2:
			return {"action": "position", "defense": choice == 1, "cell": selected_cell}
		if choice == int(MonsterAction.CANCEL):
			close()
			return {"action": "cancel"}
		return {"action": "change_position", "cell": selected_cell}
	if menu == Menu.CONTEXT:
		var action := String(["summon", "set", "activate"][choice])
		close()
		return {"action": action, "cell": selected_cell}
	return {"action": "none"}

func set_inspect_stats_held(held: bool) -> bool:
	inspect_stats_held = held
	return inspect_stats_held

func begin_opponent_hand(card_ids: Array[int]) -> void:
	opponent_hand = card_ids.slice(0, 5)

func opponent_hand_cards() -> Array[int]:
	return opponent_hand.duplicate()

func close() -> void:
	menu = Menu.NONE
	choice = 0
	inspect_stats_held = false
