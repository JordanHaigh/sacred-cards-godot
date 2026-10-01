class_name ShopDisplay
extends Control
## Godot rendering surface for the shop list, summary panel and recovered popup labels.
## Controls and resources replace the original BG-buffer transfers and palette uploads.

const PIXEL_TEXT_SCRIPT := preload("res://scripts/ui/pixel_text.gd")
const SHOP_GRAPHICS_SCRIPT := preload("res://scripts/ported/shop_graphics.gd")
const SUMMON_RULES_SCRIPT := preload("res://scripts/systems/summon_rules.gd")
const FRAMED_MINIATURE_PATH := "res://decompiled/build/assets/cards/%04d.framed.png"
const GOLD := Color("ffdc77")
const PAPER := Color("f5e6c3")

enum PopupMode { NONE, ACTION, SORT }

signal card_selected(index: int)
signal popup_choice(index: int)
signal display_refreshed(scope: StringName, revision: int)

var card_database: CardDatabase
var panel_model: ShopPanel
var shop_rules: ShopSystem
var wallet: PlayerWallet
var deck_cards: Array[int] = []
var visible_cards: Array[int] = []
var selected_index := 0
var selling := false
var popup_mode := PopupMode.NONE
var popup_choice_index := 0
var revision := 0
var graphics_model: ShopGraphics

func present(cards: Array[int], selection: int, is_selling: bool, database: CardDatabase, panel: ShopPanel, shop: ShopSystem, player_wallet: PlayerWallet, deck: Array[int], popup: int = PopupMode.NONE, popup_choice: int = 0) -> void:
	visible_cards = cards.duplicate()
	selected_index = clampi(selection, 0, maxi(visible_cards.size() - 1, 0))
	selling = is_selling
	card_database = database
	panel_model = panel
	shop_rules = shop
	wallet = player_wallet
	deck_cards = deck.duplicate()
	popup_mode = popup
	popup_choice_index = popup_choice
	graphics_model = SHOP_GRAPHICS_SCRIPT.new(card_database, SUMMON_RULES_SCRIPT.new())
	_render()
	_refresh(&"all_rows")

func open_action_popup() -> void:
	popup_mode = PopupMode.ACTION
	popup_choice_index = 0
	_render()
	_refresh(&"action_popup")

func open_sort_popup(initial_choice: int) -> void:
	popup_mode = PopupMode.SORT
	popup_choice_index = clampi(initial_choice, 0, 9)
	_render()
	_refresh(&"sort_popup")

func close_popup() -> void:
	popup_mode = PopupMode.NONE
	popup_choice_index = 0
	_render()
	_refresh(&"restore_list")

func refresh_transaction(row: int) -> void:
	_render()
	_refresh(&"transaction_row_%d" % row)

func refresh_sort_results() -> void:
	_render()
	_refresh(&"sort_results")

func refresh_row(row: int, offsets_first: bool) -> void:
	_render()
	_refresh(StringName("offsets_then_row_%d" % row if offsets_first else "row_then_offsets_%d" % row))

func move_popup_choice(step: int) -> void:
	var last_choice := 2 if popup_mode == PopupMode.ACTION else 9
	popup_choice_index = posmod(popup_choice_index + step, last_choice + 1)
	_render()
	_refresh(&"popup_choice")

func confirm_popup_choice() -> void:
	popup_choice.emit(popup_choice_index)

func _refresh(scope: StringName) -> void:
	revision += 1
	display_refreshed.emit(scope, revision)
	queue_redraw()

func _render() -> void:
	for child in get_children():
		child.queue_free()
	if visible_cards.is_empty():
		_add_text("NO CARDS AVAILABLE", Vector2(54, 74), GOLD, 8)
		return
	var first_visible := clampi(selected_index - 17, 0, maxi(visible_cards.size() - 35, 0))
	for row in range(5):
		for column in range(7):
			var inventory_index := first_visible + row * 7 + column
			if inventory_index >= visible_cards.size():
				continue
			var card_id := visible_cards[inventory_index]
			var definition := card_database.get_card(card_id) if card_database != null else null
			var at := Vector2(8 + column * 32, row * 32)
			if card_id == 0:
				var empty_slot := ColorRect.new()
				empty_slot.position = at
				empty_slot.size = Vector2(32, 32)
				empty_slot.color = Color.BLACK
				empty_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(empty_slot)
			if definition != null and ResourceLoader.exists(definition.miniature_path):
				var miniature := TextureRect.new()
				var framed_path := FRAMED_MINIATURE_PATH % card_id
				miniature.texture = load(framed_path if ResourceLoader.exists(framed_path) else definition.miniature_path) as Texture2D
				miniature.position = at
				miniature.size = Vector2(32, 32) if miniature.texture.get_size() == Vector2i(32, 32) else Vector2(24, 24)
				if miniature.texture.get_size() == Vector2i(24, 24):
					miniature.position += Vector2(4, 4)
				miniature.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				miniature.stretch_mode = TextureRect.STRETCH_SCALE
				miniature.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(miniature)
				_draw_miniature_overlays(card_id, at)
			if inventory_index == selected_index:
				_add_frame(Rect2(at - Vector2(2, 2), Vector2(28, 28)))
			var pick := Button.new()
			pick.position = at - Vector2(4, 4)
			pick.size = Vector2(32, 32)
			pick.flat = true
			pick.modulate = Color(1, 1, 1, 0)
			pick.pressed.connect(_emit_card_selected.bind(inventory_index))
			add_child(pick)
	_draw_selected_summary()
	_draw_scrollbar()
	_draw_popup()

func _draw_miniature_overlays(card_id: int, at: Vector2) -> void:
	var layers: Dictionary = graphics_model.miniature_layers(card_id)
	var attribute_path := str(layers.get("attribute_path", ""))
	if not attribute_path.is_empty() and ResourceLoader.exists(attribute_path):
		_add_icon(attribute_path, at + Vector2(16, 0))
	var requirement_path := str(layers.get("requirement_path", ""))
	if not requirement_path.is_empty() and ResourceLoader.exists(requirement_path):
		_add_icon(requirement_path, at)
	if int(layers.get("attack_value", -1)) >= 0:
		_add_text("%02d" % int(layers.attack_value), at + Vector2(0, 15), GOLD, 4)
		_add_text("%02d" % int(layers.defense_value), at + Vector2(14, 15), GOLD, 4)

func _add_icon(path: String, at: Vector2) -> void:
	var icon := TextureRect.new()
	icon.texture = load(path) as Texture2D
	icon.position = at
	icon.size = Vector2(8, 8)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

func _draw_scrollbar() -> void:
	var track := ColorRect.new()
	track.position = Vector2(234, 8)
	track.size = Vector2(2, 128)
	track.color = Color("51452f")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	var thumb := ColorRect.new()
	thumb.position = Vector2(233, 8 + graphics_model.scrollbar_y(selected_index, visible_cards.size()))
	thumb.size = Vector2(4, 8)
	thumb.color = GOLD
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(thumb)

func _draw_selected_summary() -> void:
	var card_id := visible_cards[selected_index]
	var info := panel_model.describe(card_id, selling, wallet, deck_cards)
	var shortfall := int(info.get("shortfall", 0))
	_add_panel(Rect2(3, 140, 234, 20), Color(0.04, 0.06, 0.06, 0.97))
	var identity := "%s LV%d" % [str(info.get("name", "CARD")).left(15).to_upper(), int(info.get("level", 0))]
	_add_text(identity, Vector2(5, 141), PAPER, 4)
	_add_shop_type_icon(int(info.get("type", 0)), Vector2(145, 140))
	var attribute_path := "res://art/ui/shop/attribute-%02d.png" % int(info.get("attribute", 0))
	if ResourceLoader.exists(attribute_path):
		_add_icon(attribute_path, Vector2(163, 148))
	var stat_fields: Array[String] = []
	var attack := int(info.get("attack", 0))
	var defense := int(info.get("defense", 0))
	if attack != 65535:
		stat_fields.append("ATK%d" % attack)
	if defense != 65535:
		stat_fields.append("DEF%d" % defense)
	stat_fields.append("COST%d" % int(info.get("cost", 0)))
	var stats := " ".join(stat_fields)
	_add_text(stats, Vector2(5, 146), PAPER, 4)
	var price_key := "sell_price" if selling else "buy_price"
	var balance := "SHORT %d" % shortfall if shortfall > 0 else "AFTER %d" % int(info.get("balance_after", wallet.gold))
	var transaction := "%s$%d STK%d OWN%d DK%d %s" % ["S" if selling else "B", int(info.get(price_key, 0)), int(info.get("stock", 0)), int(info.get("owned", 0)), int(info.get("deck_copies", 0)), balance]
	_add_text(transaction, Vector2(5, 156), GOLD if shortfall > 0 else PAPER, 4)

func _add_shop_type_icon(type_id: int, at: Vector2) -> void:
	var texture_path := "res://decompiled/build/assets/ui/type-%02d.png" % type_id
	if not ResourceLoader.exists(texture_path):
		return
	var icon := TextureRect.new()
	icon.texture = load(texture_path) as Texture2D
	icon.position = at
	icon.size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

func _draw_popup() -> void:
	if popup_mode == PopupMode.NONE:
		return
	_add_panel(Rect2(58, 39, 124, 82), Color("101412", 0.97))
	var labels: Array[String] = ["BUY CARD" if not selling else "SELL CARD", "CARD INFO", "CANCEL"]
	if popup_mode == PopupMode.SORT:
		labels = ["NUMBER", "NAME", "ATTACK", "DEFENSE", "TYPE", "ATTRIBUTE", "COST", "PRICE", "QUANTITY", "CLOSE"]
	var first := maxi(popup_choice_index - 2, 0)
	for row in range(mini(5, labels.size() - first)):
		var index := first + row
		_add_text(("> " if index == popup_choice_index else "  ") + labels[index], Vector2(67, 45 + row * 14), GOLD if index == popup_choice_index else PAPER, 7)

func _emit_card_selected(index: int) -> void:
	card_selected.emit(index)

func _add_text(value: String, at: Vector2, color: Color, nominal_size: int) -> void:
	var label: PixelText = PIXEL_TEXT_SCRIPT.new()
	label.position = at
	label.text = value
	label.font_color = color
	var factor := float(nominal_size) / 8.0
	label.scale = Vector2(factor, factor)
	add_child(label)

func _add_frame(rect: Rect2) -> void:
	var frame := Panel.new()
	frame.position = rect.position
	frame.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = GOLD
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

func _add_panel(rect: Rect2, color: Color) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c5aa6d")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
