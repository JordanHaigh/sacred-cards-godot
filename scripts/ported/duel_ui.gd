class_name DuelUiDisplay
extends Control
## Godot-owned duel HUD and card-grid view replacing the tile buffers and OAM
## setup in duel_ui.c. Board state is read from value-owned duel slots.

const SLOT_SIZE := Vector2(24, 24)
const GRID_ORIGIN := Vector2(4, 24)
const COLUMN_STEP := 28.0
const ROW_STEP := 21.0
const ATTRIBUTE_ICON_PATH := "res://art/ui/shop/attribute-%02d.png"
const REQUIREMENT_ICON_PATH := "res://art/ui/shop/requirement-%d.png"
const GOLD := Color("ffdc77")
const PAPER := Color("f5e6c3")
const PANEL := Color("171c20")

signal cell_selected(row: int, column: int)

var duel_state: SacredDuelState
var card_database: CardDatabase
var stat_rules := CardStatRules.new()
var summon_rules := SummonRules.new()
var cursor := Vector2i.ZERO
var detail_card_id := 0

func present(state: SacredDuelState, database: CardDatabase, selected_cell: Vector2i) -> void:
	duel_state = state
	card_database = database
	cursor = Vector2i(clampi(selected_cell.x, 0, 4), clampi(selected_cell.y, 0, 4))
	detail_card_id = int(_cell_record(cursor.y, cursor.x).get("card_id", 0))
	queue_redraw()

func _draw() -> void:
	if duel_state == null or card_database == null: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("10171b"), true)
	_draw_hud()
	_draw_grid()
	_draw_details()

func _draw_hud() -> void:
	var rival := duel_state.side(1 - duel_state.active_side)
	var player := duel_state.side(duel_state.active_side)
	_draw_text("RIVAL  %04d" % rival.life_points, Vector2(5, 14), 8, PAPER)
	_draw_text("YOU  %04d" % player.life_points, Vector2(152, 14), 8, PAPER)
	_draw_text("FIELD  %d" % duel_state.terrain, Vector2(194, 14), 6, GOLD)

func _draw_grid() -> void:
	for row in range(5):
		for column in range(5):
			var rect := _cell_rect(row, column)
			draw_rect(rect.grow(1), Color("7f7558"), false, 1.0)
			var cell := _cell_record(row, column)
			var card_id := int(cell.get("card_id", 0))
			var flags := int(cell.get("flags", 0))
			if card_id > 0:
				var face_hidden := (flags & 16) == 0
				if row < 2 and face_hidden:
					_draw_card_back(rect)
				else:
					_draw_card_miniature(card_id, rect, row, flags, int(cell.get("stage", 0)), face_hidden)
			if (row == 1 or row == 2 or row == 4) and (flags & 1) != 0:
					_draw_text("USED", rect.position + Vector2(1, 7), 4, Color("ff8a74"))
			if cursor == Vector2i(column, row):
				draw_rect(rect.grow(2), GOLD, false, 2.0)

func _draw_card_miniature(card_id: int, rect: Rect2, row: int, flags: int, stage: int, masked: bool) -> void:
	var card := card_database.get_card(card_id)
	if card == null: return
	var color := Color(0.58, 0.58, 0.58, 1.0) if masked else Color.WHITE
	if ResourceLoader.exists(card.miniature_path):
		var texture := load(card.miniature_path) as Texture2D
		draw_texture_rect(texture, rect, false, color)
	else:
		draw_rect(rect, Color("26323a"), true)
	if row == 1 or row == 2:
		_draw_text(("+" if stage > 0 else "") + str(stage), rect.position + Vector2(1, 6), 5, GOLD)
	if card.metadata_1a == 2 and (row == 1 or row == 2 or row == 4):
		var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, duel_state.terrain, stage)
		_draw_text("%02d" % mini(int(stats.attack) / 100, 99), rect.position + Vector2(0, 21), 5, PAPER)
		_draw_text("%02d" % mini(int(stats.defense) / 100, 99), rect.position + Vector2(13, 21), 5, PAPER)
	if row == 1 or row == 4 or row == 2:
		_draw_attribute(card.attribute, rect.position + Vector2(16, 0))
	if row == 3:
		_draw_requirement(summon_rules.card_category_requirement(card_id, card_database), rect.position)
	elif row == 4:
		_draw_requirement(summon_rules.card_tribute_requirement(card_id, card_database), rect.position)
	elif row == 1 or row == 2:
		_draw_requirement(summon_rules.card_tribute_requirement(card_id, card_database), rect.position)
	if masked:
		draw_rect(rect, Color(0.04, 0.05, 0.06, 0.48), true)

func _draw_attribute(attribute: int, at: Vector2) -> void:
	if attribute <= 0 or attribute > 11: return
	var path := ATTRIBUTE_ICON_PATH % attribute
	if ResourceLoader.exists(path):
		draw_texture_rect(load(path) as Texture2D, Rect2(at, Vector2(8, 8)), false)

func _draw_requirement(requirement: int, at: Vector2) -> void:
	if requirement <= 0 or requirement > 3: return
	var path := REQUIREMENT_ICON_PATH % requirement
	if ResourceLoader.exists(path):
		draw_texture_rect(load(path) as Texture2D, Rect2(at, Vector2(8, 8)), false)

func _draw_card_back(rect: Rect2) -> void:
	draw_rect(rect, Color("293d4b"), true)
	draw_rect(rect.grow(-2), Color("758596"), false)
	_draw_text("SC", rect.position + Vector2(6, 14), 7, PAPER)

func _draw_details() -> void:
	var panel_rect := Rect2(148, 23, 88, 110)
	draw_rect(panel_rect, PANEL, true)
	draw_rect(panel_rect, Color("b6a168"), false)
	var card := card_database.get_card(detail_card_id)
	if card == null:
		_draw_text("SELECT A CARD", Vector2(155, 34), 6, GOLD)
		return
	var visible := _metadata_visible(cursor.y, cursor.x)
	if not visible:
		_draw_text("UNKNOWN CARD", Vector2(154, 35), 7, PAPER)
		return
	var public := _card_is_public(cursor.y, cursor.x)
	_draw_text(card.name.left(13).to_upper(), Vector2(153, 34), 6, PAPER)
	if not public:
		_draw_text("FACE DOWN", Vector2(153, 46), 6, GOLD)
	var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, duel_state.terrain, int(_cell_record(cursor.y, cursor.x).get("stage", 0)))
	_draw_text("ATK %04d" % int(stats.attack), Vector2(153, 59), 6, PAPER)
	_draw_text("DEF %04d" % int(stats.defense), Vector2(153, 69), 6, PAPER)
	_draw_text("LV %d  TYPE %d" % [card.level, card.card_type], Vector2(153, 79), 5, GOLD)
	_draw_text("ATTR %d" % card.attribute, Vector2(153, 89), 5, GOLD)
	_draw_text("GRAVE %d" % duel_state.absolute_graveyard_ids[duel_state.active_side], Vector2(153, 101), 5, PAPER)
	_draw_text("DECK %d" % duel_state.side(duel_state.active_side).deck.size(), Vector2(153, 111), 5, PAPER)

func _draw_text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _cell_rect(row: int, column: int) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(column * COLUMN_STEP, row * ROW_STEP), SLOT_SIZE)

func _cell_record(row: int, column: int) -> Dictionary:
	if duel_state == null or column < 0 or column >= 5: return {"card_id": 0, "flags": 0, "stage": 0}
	var own_side := duel_state.side(duel_state.active_side)
	var other_side := duel_state.side(1 - duel_state.active_side)
	var slot: DuelCardSlot
	match row:
		0: slot = other_side.back_row_zones[column]
		1: slot = other_side.monster_zones[column]
		2: slot = own_side.monster_zones[column]
		3: slot = own_side.back_row_zones[column]
		4:
			var hand_index := column
			var card_id := int(own_side.hand[hand_index]) if hand_index < own_side.hand.size() else 0
			var hand_flags := int(own_side.hand_flags[hand_index]) if hand_index < own_side.hand_flags.size() else 0
			return {"card_id": card_id, "flags": hand_flags, "stage": 0}
	return {"card_id": slot.card_id, "flags": slot.persistent_flags, "stage": slot.stage}

func _metadata_visible(row: int, column: int) -> bool:
	var cell := _cell_record(row, column)
	return bool((int(cell.flags) & 16) != 0) if row < 2 else true

func _card_is_public(row: int, column: int) -> bool:
	if row == 0 or row == 1 or row == 4: return true
	return (int(_cell_record(row, column).flags) & 16) != 0

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	var local := event.position - GRID_ORIGIN
	var column := floori(local.x / COLUMN_STEP)
	var row := floori(local.y / ROW_STEP)
	if row >= 0 and row < 5 and column >= 0 and column < 5:
		cell_selected.emit(row, column)
		accept_event()
