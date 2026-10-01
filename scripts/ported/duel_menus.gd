class_name DuelMenus
extends RefCounted
## Value-state for duel context/action menus and temporary inspection overlays.
## Callers render the returned labels and preview data with Godot Controls.

enum Menu { NONE, CONTEXT, MONSTER_ACTION }
enum ContextAction { INSPECT, END_TURN, DISCARD }
enum MonsterAction { ATTACK, DEFENSE, TRIBUTE, EFFECT, CANCEL }

const CONTEXT_LABELS := ["VIEW CARD", "END TURN", "DISCARD CARD"]
const MONSTER_LABELS := ["ATTACK", "DEFENSE", "TRIBUTE", "EFFECT"]
const NAVIGATION_PATH := "res://resources/duel_menu_navigation.json"

enum Direction { UP, DOWN, LEFT, RIGHT }

## These transition tables were read from the matching USA Rev. 00 ROM. The
## menus use directional layouts, so a generic previous/next step is wrong.
var navigation: Dictionary = {}

var menu := Menu.NONE
var choice := 0
var selected_cell := Vector2i.ZERO
var life_points := [8000, 8000]
var deck_counts := [40, 40]
var grave_card_ids := [0, 0]
var opponent_hand: Array[int] = []
var opponent_hand_flags: Array[int] = []
var inspect_stats_held := false

func _init() -> void:
	_load_navigation()

func _load_navigation() -> void:
	if not FileAccess.file_exists(NAVIGATION_PATH):
		push_error("Missing duel menu navigation at %s" % NAVIGATION_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAVIGATION_PATH))
	if not parsed is Dictionary:
		push_error("Invalid duel menu navigation at %s" % NAVIGATION_PATH)
		return
	navigation = parsed
	for menu_key in ["context", "monster_action"]:
		var menu_tables: Variant = navigation.get(menu_key, {})
		var count := 3 if menu_key == "context" else 4
		for direction_key in ["up", "down", "left", "right"]:
			var table: Variant = menu_tables.get(direction_key, []) if menu_tables is Dictionary else []
			if not table is Array or table.size() != count:
				push_error("Invalid %s %s navigation table" % [menu_key, direction_key])
				return
			for destination in table:
				if int(destination) < 0 or int(destination) >= count:
					push_error("Out-of-range %s %s navigation target" % [menu_key, direction_key])
					return

func open_context(cell: Vector2i, player_life: int, rival_life: int, player_deck_count: int, rival_deck_count: int, player_grave_id: int, rival_grave_id: int) -> void:
	menu = Menu.CONTEXT
	choice = 0
	selected_cell = cell
	life_points = [player_life, rival_life]
	deck_counts = [player_deck_count, rival_deck_count]
	grave_card_ids = [player_grave_id, rival_grave_id]

func open_monster_action(cell: Vector2i, _starts_in_defense: bool = false) -> void:
	menu = Menu.MONSTER_ACTION
	choice = int(MonsterAction.ATTACK)
	selected_cell = cell

## Mirrors the recovered live attack/defense pose preview. Tribute/effect menu
## entries keep the last previewed pose, including when the menu is canceled.
func preview_monster_action(duel: SacredDuelState, action_index: int) -> bool:
	if menu != Menu.MONSTER_ACTION or action_index not in [MonsterAction.ATTACK, MonsterAction.DEFENSE]:
		return false
	var side := duel.side(duel.active_side) if duel != null else null
	if side == null or selected_cell.x < 0 or selected_cell.x >= side.monster_zones.size():
		return false
	var slot: DuelCardSlot = side.monster_zones[selected_cell.x]
	if action_index == MonsterAction.ATTACK:
		slot.persistent_flags &= 0xFD
		slot.defense_position = false
	else:
		slot.persistent_flags |= 2
		slot.defense_position = true
	return true

func labels() -> PackedStringArray:
	match menu:
		Menu.CONTEXT: return PackedStringArray(CONTEXT_LABELS)
		Menu.MONSTER_ACTION: return PackedStringArray(MONSTER_LABELS)
	return PackedStringArray()

## Builds display-ready duel status from the captured menu snapshot and card
## records. The returned values own strings and IDs, not references into ROM data.
func context_rows(card_database: CardDatabase) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for side_id in range(2):
		var grave_card_id := int(grave_card_ids[side_id])
		var definition := card_database.get_card(grave_card_id) if card_database != null and grave_card_id > 0 else null
		rows.append({
			"side_id": side_id,
			"label": "YOU" if side_id == 0 else "RIVAL",
			"life_points": int(life_points[side_id]),
			"deck_count": int(deck_counts[side_id]),
			"grave_card_id": grave_card_id,
			"grave_card_name": definition.name if definition != null else "EMPTY",
		})
	return rows

func move(direction: int) -> int:
	var count := labels().size()
	if count > 0:
		choice = posmod(choice + direction, count)
	return choice

## Applies the recovered per-direction transition. Returns whether a direction
## was supported by this menu; navigation can legitimately leave choice fixed.
func navigate(direction: int) -> bool:
	if menu == Menu.NONE or direction < Direction.UP or direction > Direction.RIGHT:
		return false
	var menu_key := "context" if menu == Menu.CONTEXT else "monster_action"
	var direction_names := ["up", "down", "left", "right"]
	var menu_tables: Variant = navigation.get(menu_key, {})
	var table: Variant = menu_tables.get(direction_names[direction], []) if menu_tables is Dictionary else []
	if not table is Array or choice < 0 or choice >= table.size():
		return false
	choice = int(table[choice])
	return true

func confirm() -> Dictionary:
	if menu == Menu.MONSTER_ACTION:
		if choice == MonsterAction.ATTACK:
			return {"action": "attack", "cell": selected_cell}
		if choice == MonsterAction.DEFENSE:
			return {"action": "defense", "cell": selected_cell}
		if choice == MonsterAction.TRIBUTE:
			return {"action": "tribute", "cell": selected_cell}
		if choice == MonsterAction.EFFECT:
			return {"action": "effect", "cell": selected_cell}
		if choice == MonsterAction.CANCEL:
			close()
			return {"action": "cancel"}
	if menu == Menu.CONTEXT:
		var action := String(["inspect", "end_turn", "discard"][choice])
		close()
		return {"action": action, "cell": selected_cell}
	return {"action": "none"}

func set_inspect_stats_held(held: bool) -> bool:
	inspect_stats_held = held
	return inspect_stats_held

func begin_opponent_hand(card_ids: Array[int], hand_flags: Array[int] = []) -> void:
	opponent_hand = card_ids.slice(0, 5)
	opponent_hand.resize(5)
	opponent_hand_flags = hand_flags.slice(0, 5)
	opponent_hand_flags.resize(5)

func opponent_hand_cards() -> Array[int]:
	return opponent_hand.duplicate()

func opponent_hand_visibility_flags() -> Array[int]:
	return opponent_hand_flags.duplicate()

func close() -> void:
	menu = Menu.NONE
	choice = 0
	inspect_stats_held = false
