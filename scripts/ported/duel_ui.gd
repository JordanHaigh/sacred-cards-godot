class_name DuelUiDisplay
extends Control
## Godot-owned duel HUD and card-grid view replacing the tile buffers and OAM
## setup in duel_ui.c. Board state is read from value-owned duel slots.

const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")
const SMALL_FONT_ATLAS: Texture2D = preload("res://art/ui/font-small.png")
const FONT_MAPPING_PATH := "res://decompiled/build/assets/ui/font-mapping.json"
const SLOT_SIZE := Vector2(24, 24)
const GRID_ORIGIN := Vector2(4, 24)
const COLUMN_STEP := 28.0
const ROW_STEP := 21.0
const MINIATURE_BACK_PATH := "res://decompiled/build/assets/duel/miniature-back.png"
const MINIATURE_ATTRIBUTE_PATH := "res://decompiled/build/assets/duel/miniature-attribute-%d.png"
const MINIATURE_REQUIREMENT_PATH := "res://decompiled/build/assets/duel/miniature-requirement-%d.png"
const MINIATURE_HIDDEN_PATH := "res://decompiled/build/assets/duel/miniature-hidden.png"
const MINIATURE_USED_PATH := "res://decompiled/build/assets/duel/miniature-used.png"
const MINIATURE_STAGE_PATH := "res://decompiled/build/assets/duel/stage-%d.png"
const MINIATURE_STAGE_MINUS_PATH := "res://decompiled/build/assets/duel/stage-minus.png"
const FRAMED_CARD_PATH := "res://decompiled/build/assets/cards/%04d.framed.png"
const GOLD := Color("ffdc77")
const PAPER := Color("f5e6c3")
const PANEL := Color("171c20")

signal cell_selected(row: int, column: int)

var duel_state: SacredDuelState
var card_database: CardDatabase
var terrain_background_path := ""
var stat_rules := CardStatRules.new()
var summon_rules := SummonRules.new()
var cursor := Vector2i.ZERO
var detail_card_id := 0
var stats_overlay_visible := false
var opponent_hand_overlay: Array[int] = []
var opponent_hand_visibility: Array[int] = []
var opponent_hand_overlay_visible := false
var effect_card_overlay: Array[int] = []
var effect_overlay_until_msec := 0
var ascii_glyphs: Dictionary = {}
var unicode_glyphs: Dictionary = {}

func _ready() -> void:
	ascii_glyphs = PIXEL_TEXT_SCRIPT.load_ascii_glyphs()
	if not FileAccess.file_exists(FONT_MAPPING_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FONT_MAPPING_PATH))
	if not parsed is Array:
		return
	for entry: Variant in parsed:
		if not entry is Dictionary:
			continue
		var candidate := str(entry.get("unicode_candidate", ""))
		if candidate.length() == 1:
			unicode_glyphs[candidate.unicode_at(0)] = int(entry.get("glyph_index", 31))

func present(state: SacredDuelState, database: CardDatabase, selected_cell: Vector2i) -> void:
	duel_state = state
	card_database = database
	cursor = Vector2i(clampi(selected_cell.x, 0, 4), clampi(selected_cell.y, 0, 4))
	detail_card_id = int(_cell_record(cursor.y, cursor.x).get("card_id", 0))
	queue_redraw()

func set_inspection_overlays(show_stats: bool, opponent_hand: Array[int], show_hand: bool = false, hand_visibility: Array[int] = []) -> void:
	stats_overlay_visible = show_stats
	opponent_hand_overlay = opponent_hand.duplicate()
	opponent_hand_visibility = hand_visibility.duplicate()
	opponent_hand_overlay_visible = show_hand
	queue_redraw()

func present_effect_cards(card_ids: Array[int], duration_msec: int = 1200) -> void:
	effect_card_overlay = card_ids.duplicate()
	effect_overlay_until_msec = Time.get_ticks_msec() + maxi(duration_msec, 1)
	queue_redraw()

func _process(_delta: float) -> void:
	if effect_overlay_until_msec == 0:
		return
	queue_redraw()
	if Time.get_ticks_msec() >= effect_overlay_until_msec:
		effect_overlay_until_msec = 0
		effect_card_overlay.clear()

func _draw() -> void:
	if duel_state == null or card_database == null: return
	if opponent_hand_overlay_visible:
		if ResourceLoader.exists(terrain_background_path):
			draw_texture_rect(load(terrain_background_path) as Texture2D, Rect2(Vector2.ZERO, size), false)
	else:
		_draw_hud()
		_draw_grid()
		_draw_details()
		if stats_overlay_visible:
			_draw_stats_overlay()
	if opponent_hand_overlay_visible:
		_draw_opponent_hand_overlay()
		return
	if effect_overlay_until_msec > 0:
		_draw_effect_cards_overlay()

func _draw_stats_overlay() -> void:
	var panel := Rect2(3, 23, 234, 101)
	draw_rect(panel, Color(0.035, 0.05, 0.055, 0.98), true)
	draw_rect(panel, Color("d0b46f"), false)
	_draw_text("FIELD STATS (HOLD Q)", Vector2(9, 33), 7, GOLD)
	for row in range(5):
		for column in range(5):
			var cell := _cell_record(row, column)
			var card_id := int(cell.card_id)
			var at := Vector2(9 + column * 45, 40 + row * 15)
			if card_id <= 0 or not _metadata_visible(row, column):
				_draw_text("--", at, 6, PAPER)
				continue
			var card := card_database.get_card(card_id)
			if card == null:
				_draw_text("%03d" % card_id, at, 6, PAPER)
				continue
			var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, duel_state.terrain, int(cell.stage))
			_draw_text("%s %d/%d" % [card.name.left(5).to_upper(), int(stats.attack), int(stats.defense)], at, 5, PAPER)

func _draw_opponent_hand_overlay() -> void:
	var span := 5 * 42.0
	var start_x := (size.x - span) * 0.5
	for index in range(5):
		var card_id := int(opponent_hand_overlay[index]) if index < opponent_hand_overlay.size() else 0
		var rect := Rect2(Vector2(start_x + index * 42.0, 24), Vector2(32, 32))
		if card_id == 0:
			continue
		var revealed := index < opponent_hand_visibility.size() and (int(opponent_hand_visibility[index]) & 0x10) != 0
		if not revealed:
			if ResourceLoader.exists(MINIATURE_BACK_PATH):
				draw_texture_rect(load(MINIATURE_BACK_PATH) as Texture2D, rect, false)
			continue
		var card := card_database.get_card(card_id)
		var framed_path := FRAMED_CARD_PATH % card_id
		if ResourceLoader.exists(framed_path):
			draw_texture_rect(load(framed_path) as Texture2D, rect, false)
		elif card != null and ResourceLoader.exists(card.miniature_path):
			draw_texture_rect(load(card.miniature_path) as Texture2D, Rect2(rect.position + Vector2(4, 2), Vector2(24, 24)), false)
		else:
			draw_rect(rect, Color("293d4b"), true)
			draw_rect(rect, Color("758596"), false)
		if card != null:
			_draw_duel_miniature_attribute(card.attribute, rect.position + Vector2(24, 0))
			_draw_duel_miniature_requirement(summon_rules.card_tribute_requirement(card_id, card_database), rect.position)
			if card.metadata_1a == 2:
				var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, duel_state.terrain, 0)
				_draw_text("%02d" % mini(int(stats.attack) / 100, 99), rect.position + Vector2(0, 31), 4, PAPER)
				_draw_text("%02d" % mini(int(stats.defense) / 100, 99), rect.position + Vector2(16, 31), 4, PAPER)

func _draw_duel_miniature_attribute(attribute: int, at: Vector2) -> void:
	if attribute < 1 or attribute > 11: return
	var path := MINIATURE_ATTRIBUTE_PATH % attribute
	if ResourceLoader.exists(path):
		draw_texture_rect(load(path) as Texture2D, Rect2(at, Vector2(8, 8)), false)

func _draw_duel_miniature_requirement(requirement: int, at: Vector2) -> void:
	if requirement < 1 or requirement > 3: return
	var path := MINIATURE_REQUIREMENT_PATH % requirement
	if ResourceLoader.exists(path):
		draw_texture_rect(load(path) as Texture2D, Rect2(at, Vector2(8, 8)), false)

func _draw_effect_cards_overlay() -> void:
	var count := mini(effect_card_overlay.size(), 3)
	if count == 0:
		return
	var card_width := 48.0
	var card_height := 68.0
	var gap := 8.0
	var start_x := (size.x - count * card_width - (count - 1) * gap) * 0.5
	var top := maxf((size.y - card_height) * 0.5, 54.0)
	var panel := Rect2(start_x - 5, top - 16, count * card_width + (count - 1) * gap + 10, card_height + 24)
	draw_rect(panel, Color(0.035, 0.05, 0.055, 0.98), true)
	draw_rect(panel, Color("d0b46f"), false)
	_draw_text("EFFECT", Vector2(panel.position.x + 4, panel.position.y + 11), 6, GOLD)
	for index in range(count):
		var card_id := effect_card_overlay[index]
		var rect := Rect2(Vector2(start_x + index * (card_width + gap), top), Vector2(card_width, card_height))
		var card := card_database.get_card(card_id)
		if card != null and ResourceLoader.exists(card.miniature_path):
			draw_texture_rect(load(card.miniature_path) as Texture2D, rect, false)
		else:
			draw_rect(rect, Color("293d4b"), true)
			draw_rect(rect, Color("758596"), false)
		_draw_text(card.name.left(10).to_upper() if card != null else "CARD", rect.position + Vector2(0, card_height + 8), 5, PAPER)

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
				var visibility_hidden := (flags & 16) == 0
				if row < 2 and visibility_hidden:
					if ResourceLoader.exists(MINIATURE_BACK_PATH):
						draw_texture_rect(load(MINIATURE_BACK_PATH) as Texture2D, Rect2(rect.position - Vector2(4, 4), Vector2(32, 32)), false)
					if row == 1 and (flags & 1) != 0:
						_draw_miniature_badge(MINIATURE_USED_PATH, rect.position + Vector2(20, 20))
				else:
					_draw_card_miniature(card_id, rect, row, int(cell.get("stage", 0)), flags)
			if cursor == Vector2i(column, row):
				draw_rect(rect.grow(2), GOLD, false, 2.0)

func _draw_card_miniature(card_id: int, rect: Rect2, row: int, stage: int, flags: int) -> void:
	var card := card_database.get_card(card_id)
	if card == null: return
	var framed_path := FRAMED_CARD_PATH % card_id
	var framed_rect := Rect2(rect.position - Vector2(4, 4), Vector2(32, 32))
	if ResourceLoader.exists(framed_path):
		draw_texture_rect(load(framed_path) as Texture2D, framed_rect, false)
	elif ResourceLoader.exists(card.miniature_path):
		draw_texture_rect(load(card.miniature_path) as Texture2D, Rect2(framed_rect.position + Vector2(4, 2), Vector2(24, 24)), false)
	else:
		draw_rect(framed_rect, Color("26323a"), true)
	if row == 1 or row == 2:
		_draw_stage_badges(stage, framed_rect.position + Vector2(0, 24))
	if card.metadata_1a == 2 and (row == 1 or row == 2 or row == 4):
		var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, duel_state.terrain, stage)
		_draw_text("%02d" % mini(int(stats.attack) / 100, 99), rect.position + Vector2(0, 21), 5, PAPER)
		_draw_text("%02d" % mini(int(stats.defense) / 100, 99), rect.position + Vector2(13, 21), 5, PAPER)
	if row == 1 or row == 4 or row == 2:
		_draw_duel_miniature_attribute(card.attribute, framed_rect.position + Vector2(24, 0))
	if row == 3:
		_draw_duel_miniature_requirement(summon_rules.card_category_requirement(card_id, card_database), framed_rect.position)
	elif row == 4:
		_draw_duel_miniature_requirement(summon_rules.card_tribute_requirement(card_id, card_database), framed_rect.position)
	elif row == 1 or row == 2:
		_draw_duel_miniature_requirement(summon_rules.card_tribute_requirement(card_id, card_database), framed_rect.position)
	if row == 2 and (flags & 1) != 0:
		_draw_miniature_badge(MINIATURE_USED_PATH, framed_rect.position + Vector2(24, 24))
	if (row == 1 or row == 4) and (flags & 1) != 0:
		_draw_miniature_badge(MINIATURE_USED_PATH, framed_rect.position + Vector2(24, 24))
	if row >= 2 and (flags & 16) == 0:
		_draw_miniature_badge(MINIATURE_HIDDEN_PATH, framed_rect.position + Vector2(16, 24))

func _draw_stage_badges(stage: int, at: Vector2) -> void:
	# The 16-tile source row stride puts C offsets 0xC00..0xCC0 in
	# the 32x32 sprite's bottom row at x=0, 8, 16 and 24.
	var signed_stage := stage & 0xff
	if signed_stage >= 128:
		signed_stage -= 256
	if signed_stage == 0:
		return
	var magnitude := abs(signed_stage)
	if signed_stage < 0:
		_draw_miniature_badge(MINIATURE_STAGE_MINUS_PATH, at)
		if magnitude == 128:
			return
		at.x += 8
	var stage_path := MINIATURE_STAGE_PATH % mini(magnitude, 10)
	_draw_miniature_badge(stage_path, at)

func _draw_miniature_badge(path: String, at: Vector2) -> void:
	if ResourceLoader.exists(path):
		draw_texture_rect(load(path) as Texture2D, Rect2(at, Vector2(8, 8)), false)

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
	_draw_text("DECK %d" % duel_state.side(duel_state.active_side).deck_remaining_count, Vector2(153, 111), 5, PAPER)

func _draw_text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	var glyph_size := float(font_size)
	var fallback := int(ascii_glyphs.get(63, 31))
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		var glyph := int(ascii_glyphs.get(codepoint, unicode_glyphs.get(codepoint, fallback)))
		var source := Rect2(Vector2((glyph % 32) * 8, (glyph / 32) * 8), Vector2(8, 8))
		var target := Rect2(at + Vector2(index * glyph_size, 0), Vector2(glyph_size, glyph_size))
		draw_texture_rect_region(SMALL_FONT_ATLAS, Rect2(target.position + Vector2(glyph_size / 8.0, glyph_size / 8.0), target.size), source, Color(0.04, 0.04, 0.04, 0.9))
		draw_texture_rect_region(SMALL_FONT_ATLAS, target, source, color)

func _cell_rect(row: int, column: int) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(column * COLUMN_STEP, row * ROW_STEP), SLOT_SIZE)

func _cell_record(row: int, column: int) -> Dictionary:
	if duel_state == null or column < 0 or column >= 5: return {"card_id": 0, "flags": 0, "stage": 0}
	var own_side := duel_state.side(duel_state.active_side)
	var other_side := duel_state.side(1 - duel_state.active_side)
	var slot: DuelCardSlot
	match row:
		0: slot = other_side.back_row_zones[4 - column]
		1: slot = other_side.monster_zones[4 - column]
		2: slot = own_side.monster_zones[column]
		3: slot = own_side.back_row_zones[column]
		4:
			var hand_index := column
			var card_id := int(own_side.hand[hand_index]) if hand_index < own_side.hand.size() else 0
			var hand_flags := int(own_side.hand_flags[hand_index]) if hand_index < own_side.hand_flags.size() else 0
			var hand_stage := int(own_side.hand_stages[hand_index]) if hand_index < own_side.hand_stages.size() else 0
			return {"card_id": card_id, "flags": hand_flags, "stage": hand_stage}
	return {"card_id": slot.card_id, "flags": slot.persistent_flags, "stage": slot.stage}

func _metadata_visible(row: int, column: int) -> bool:
	var cell := _cell_record(row, column)
	return bool((int(cell.flags) & 16) != 0) if row < 2 else true

func _card_is_public(row: int, column: int) -> bool:
	if row == 0 or row == 1 or row == 4: return true
	return (int(_cell_record(row, column).flags) & 16) != 0

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	var local: Vector2 = event.position - GRID_ORIGIN
	var column := floori(local.x / COLUMN_STEP)
	var row := floori(local.y / ROW_STEP)
	if row >= 0 and row < 5 and column >= 0 and column < 5:
		cell_selected.emit(row, column)
		accept_event()
