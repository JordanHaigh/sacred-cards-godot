extends Control

const CARD_DATABASE_SCRIPT = preload("res://scripts/data/card_database.gd")
const SHOP_SYSTEM_SCRIPT = preload("res://scripts/systems/shop_system.gd")
const DECK_BUILDER_SCRIPT = preload("res://scripts/systems/deck_builder_state.gd")
const DECK_MANAGEMENT_SCRIPT = preload("res://scripts/systems/deck_management.gd")
const DECK_BUILDER_MENU_SCRIPT = preload("res://scripts/systems/deck_builder_menu.gd")
const CARD_SORT_SCRIPT = preload("res://scripts/systems/card_sort.gd")
const PLAYER_WALLET_SCRIPT = preload("res://scripts/state/player_wallet.gd")
const PROGRESSION_SCRIPT = preload("res://scripts/state/player_progression.gd")
const NEW_GAME_SCRIPT = preload("res://scripts/systems/new_game_state.gd")
const SAVE_STORAGE_SCRIPT = preload("res://scripts/systems/save_storage.gd")
const PIXEL_TEXT_SCRIPT = preload("res://scripts/ui/pixel_text.gd")
const TITLE_MENU_SCRIPT = preload("res://scripts/systems/title_menu_state.gd")
const PASSWORD_SYSTEM_SCRIPT = preload("res://scripts/systems/password_system.gd")
const PASSWORD_ENTRY_VIEW_SCRIPT = preload("res://scripts/ui/password_entry_view.gd")
const SCENE_SCRIPT_DATABASE_SCRIPT = preload("res://scripts/data/scene_script_database.gd")
const SCENE_SCRIPT_RUNTIME_SCRIPT = preload("res://scripts/systems/script_runtime.gd")
const SCENE_SCRIPT_EVENTS_SCRIPT = preload("res://scripts/systems/script_events.gd")
const EVENT_FLAGS_SCRIPT = preload("res://scripts/systems/event_flag_bank.gd")
const AUDIO_DISPATCH_SCRIPT = preload("res://scripts/systems/audio_dispatch.gd")
const EFFECT_DISPATCHER_SCRIPT = preload("res://scripts/systems/effect_dispatcher.gd")
const TRAP_EFFECT_RULES_SCRIPT = preload("res://scripts/systems/trap_effect_rules.gd")
const CARD_EFFECT_RULES_SCRIPT = preload("res://scripts/systems/card_effect_rules.gd")
const EFFECT_FAMILY_RULES_SCRIPT = preload("res://scripts/systems/effect_family_rules.gd")
const SPELL_EFFECT_RULES_SCRIPT = preload("res://scripts/systems/spell_effect_rules.gd")
const MONSTER_EFFECT_RULES_SCRIPT = preload("res://scripts/systems/monster_effect_rules.gd")
const AI_VALIDATION_SCRIPT = preload("res://scripts/systems/ai_validation.gd")
const AI_CANDIDATE_DATABASE_SCRIPT = preload("res://scripts/data/ai_candidate_database.gd")
const AI_SCORING_SCRIPT = preload("res://scripts/systems/ai_scoring.gd")
const AI_CARD_SCORING_SCRIPT = preload("res://scripts/systems/ai_card_scoring.gd")
const AI_ACTIONS_SCRIPT = preload("res://scripts/systems/ai_actions.gd")
const AI_TURN_SCRIPT = preload("res://scripts/systems/ai_turn.gd")
const DUEL_SPECIAL_WINS_SCRIPT = preload("res://scripts/systems/duel_special_wins.gd")
const EFFECT_RULE_BINDINGS_SCRIPT = preload("res://scripts/systems/effect_rule_bindings.gd")
const DUEL_GRAPHICS_SCRIPT = preload("res://scripts/systems/duel_graphics.gd")
const CARD_ART_SCRIPT = preload("res://scripts/ported/card_art.gd")
const CARD_PRESENTATION_SCRIPT = preload("res://scripts/ported/card_presentation.gd")
const COLLECTION_DISPLAY_SCRIPT = preload("res://scripts/ported/collection_display.gd")
const SHOP_PANEL_SCRIPT = preload("res://scripts/ported/shop_panel.gd")
const SHOP_DISPLAY_SCRIPT = preload("res://scripts/ported/shop_display.gd")
const SHOP_MENU_SCRIPT = preload("res://scripts/ported/shop_menu.gd")
const PLAYER_DUEL_SCRIPT = preload("res://scripts/ported/duel_player.gd")
const DUEL_TEXT_SCRIPT = preload("res://scripts/ported/duel_text.gd")
const DUEL_UI_SCRIPT = preload("res://scripts/ported/duel_ui.gd")
const MENU_GRAPHICS_SCRIPT = preload("res://scripts/ported/menu_graphics.gd")
const NAME_ENTRY_SCRIPT = preload("res://scripts/ported/name_entry.gd")
const SCENE_GRAPHICS_SCRIPT = preload("res://scripts/ported/scene_graphics.gd")
const ACTOR_ANIMATION_DATABASE_SCRIPT = preload("res://scripts/data/actor_animation_database.gd")
const SCENE_DIALOGUE_DISPLAY_SCRIPT = preload("res://scripts/ui/scene_dialogue_display.gd")
const PRE_DUEL_MENU_SCRIPT = preload("res://scripts/ported/pre_duel_menu.gd")
const PRE_DUEL_DISPLAY_SCRIPT = preload("res://scripts/ported/pre_duel_display.gd")
const SUMMON_RULES_SCRIPT = preload("res://scripts/systems/summon_rules.gd")
## Temporary screen shell for exercising the recovered state and data models.

const SCREEN_SIZE := Vector2(240, 160)
const ART := "res://art/screens/"
const PAPER := Color("f5e6c3")
const GOLD := Color("ffdc77")
const INK := Color("241d18")
const BLUE := Color("23364c")
const GREEN := Color("263d2a")

var screen := "title"
var selected := 0
var shop_selected := 0
var editing_deck := false
var deck_hub_return_screen := "title"
var in_deck_hub_flow := false
var credits := 1240
var player_lp := 8000
var rival_lp := 8000
var title_has_save := false
var title_choice := 0
var field_has_monster := false
var field_card_id := 1
var selling := false
var card_database: CardDatabase
var shop_rules: ShopSystem
var shop_panel: ShopPanel
var shop_display: ShopDisplay
var shop_menu: ShopMenuState
var player_duel_controller: PlayerDuelController
var duel_text_presenter: DuelTextPresenter
var duel_ui: DuelUiDisplay
var active_duel_state: SacredDuelState
var menu_graphics: MenuGraphics
var name_entry_view: NameEntryView
var name_entry_return_screen := "title"
var name_entry_save_after := false
var pre_duel_menu: PreDuelMenuState
var pre_duel_display: PreDuelDisplay
var pre_duel_opponent_id := 0
var duel_summon_rules: SummonRules
var scene_graphics: SceneGraphics
var actor_animation_database: ActorAnimationDatabase
var current_scene_configuration: SceneConfiguration
var current_scene_grid: SceneGrid
var scene_actor_runtime: SceneActorRuntime
var current_scene_id := 0
var current_scene_variant := 0
var current_scene_graphics: Dictionary = {}
var current_scene_portrait_layer: Control
var scene_dialogue_view: SceneDialogueDisplay
var _spell_target_classes: Array[int] = []
var deck_rules: DeckBuilderState
var deck_management: DeckManagement
var deck_builder_menu: DeckBuilderMenu
var card_sorter: CardSortSystem
var wallet: PlayerWallet
var progression: PlayerProgression
var title_menu: TitleMenuState
var password_system: SacredPasswordSystem
var save_storage: SaveStorage
var current_save: PlayerSaveData
var collection: Array[int] = []
var deck: Array[int] = []
var stock: Array[int] = []
var screen_root: Control
var feedback: Label
var scene_script_database: SceneScriptDatabase
var scene_script_runtime: SceneScriptRuntime
var scene_script_events: SceneScriptEvents
var scene_event_flags: EventFlagBank
var audio_dispatch: GameAudioDispatch
var duel_effect_dispatcher: CardEffectDispatcher
var duel_effect_bindings: EffectRuleBindings
var trap_effect_rules: TrapEffectRules
var card_effect_rules: CardEffectRules
var effect_family_rules: EffectFamilyRules
var spell_effect_rules: SpellEffectRules
var monster_effect_rules: MonsterEffectRules
var ai_validation: AiValidation
var ai_candidate_database: AiCandidateDatabase
var ai_scoring: AiScoring
var ai_card_scoring: AiCardScoring
var ai_actions: AiActions
var ai_turn: AiTurn
var duel_special_wins: DuelSpecialWins
var duel_graphics: DuelGraphics
var card_art: CardArt
var card_detail_return_screen := "deck"
var selected_card_detail_id := 0
var collection_display: CollectionDisplay

signal scene_script_text(text: String, language: int, glyph_position: int)
signal scene_script_scene_change(scene_id: int, variant: int, spawn: int)
signal scene_script_service_requested(service: StringName, data: Dictionary)
signal scene_script_motion_requested(event_id: int, actor_ids: Array, choreography_id: StringName)
signal scene_script_motion_path(event_id: int, descriptor: Dictionary, x_steps: Array[int], y_steps: Array[int])
signal scene_script_actor_state(actor_id: int, changes: Dictionary)
signal duel_text_changed(value: String, glyph_position: int, wait_state: bool)
signal duel_text_finished
signal pre_duel_requested(opponent_id: int, wagered_card_id: int)
signal scene_graphics_changed(scene_id: int, variant: int, graphics: Dictionary)
signal scene_shop_closed
signal scene_name_entry_finished
signal scene_password_entry_finished

var scene_shop_active := false
var scene_shop_return_screen := "scene"
var scene_password_entry_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	menu_graphics = MENU_GRAPHICS_SCRIPT.new()
	pre_duel_menu = PRE_DUEL_MENU_SCRIPT.new()
	scene_graphics = SCENE_GRAPHICS_SCRIPT.new()
	var scene_graphics_error: Error = scene_graphics.load_recovered_data()
	if scene_graphics_error != OK:
		push_error("Could not load recovered scene graphics (error %d)." % scene_graphics_error)
	actor_animation_database = ACTOR_ANIMATION_DATABASE_SCRIPT.new()
	var actor_animation_error: Error = actor_animation_database.load_recovered_data()
	if actor_animation_error != OK:
		push_error("Could not load recovered actor animation data (error %d)." % actor_animation_error)
	duel_graphics = DUEL_GRAPHICS_SCRIPT.new()
	duel_graphics.select(0, 0)
	card_art = CARD_ART_SCRIPT.new()
	card_database = CARD_DATABASE_SCRIPT.new()
	var load_result: Error = card_database.load_recovered_data()
	if load_result != OK:
		push_error("Could not load the recovered Sacred Cards database (error %d)." % load_result)
	duel_effect_dispatcher = EFFECT_DISPATCHER_SCRIPT.new(card_database)
	trap_effect_rules = TRAP_EFFECT_RULES_SCRIPT.new(card_database)
	card_effect_rules = CARD_EFFECT_RULES_SCRIPT.new(trap_effect_rules)
	effect_family_rules = EFFECT_FAMILY_RULES_SCRIPT.new(trap_effect_rules)
	spell_effect_rules = SPELL_EFFECT_RULES_SCRIPT.new(card_database, trap_effect_rules)
	monster_effect_rules = MONSTER_EFFECT_RULES_SCRIPT.new(card_database)
	ai_validation = AI_VALIDATION_SCRIPT.new(card_database, null, trap_effect_rules)
	ai_scoring = AI_SCORING_SCRIPT.new(card_database)
	ai_card_scoring = AI_CARD_SCORING_SCRIPT.new(card_database)
	ai_scoring.set_effect_score_handlers(
		Callable(ai_card_scoring, "score_spell_before"),
		Callable(ai_card_scoring, "score_spell_after"),
		Callable(ai_card_scoring, "score_monster_before"),
		Callable(ai_card_scoring, "score_monster_after")
	)
	ai_actions = AI_ACTIONS_SCRIPT.new(card_database, duel_effect_dispatcher, trap_effect_rules)
	duel_special_wins = DUEL_SPECIAL_WINS_SCRIPT.new()
	ai_candidate_database = AI_CANDIDATE_DATABASE_SCRIPT.new()
	var ai_candidates_error: Error = ai_candidate_database.load_recovered_data()
	if ai_candidates_error != OK:
		push_error("Could not load the recovered AI candidate table (error %d)." % ai_candidates_error)
	ai_turn = AI_TURN_SCRIPT.new(ai_candidate_database, ai_validation, ai_scoring, ai_actions, duel_special_wins)
	duel_effect_bindings = EFFECT_RULE_BINDINGS_SCRIPT.new()
	if not duel_effect_bindings.install(duel_effect_dispatcher, card_effect_rules, effect_family_rules, spell_effect_rules, monster_effect_rules):
		push_error("Could not bind recovered duel effect rules to the metadata dispatcher.")
	save_storage = SAVE_STORAGE_SCRIPT.new()
	var saved_state: Dictionary = save_storage.load_game()
	title_has_save = bool(saved_state.found)
	current_save = saved_state.data if title_has_save else NEW_GAME_SCRIPT.initialize()
	title_menu = TITLE_MENU_SCRIPT.new()
	title_menu.initialize(title_has_save)
	shop_rules = SHOP_SYSTEM_SCRIPT.new(card_database)
	shop_panel = SHOP_PANEL_SCRIPT.new(card_database, shop_rules)
	shop_menu = SHOP_MENU_SCRIPT.new()
	shop_menu.begin(false, 7)
	player_duel_controller = PLAYER_DUEL_SCRIPT.new()
	duel_text_presenter = DUEL_TEXT_SCRIPT.new(card_database)
	duel_text_presenter.text_changed.connect(func(value: String, glyph_position: int, wait_state: bool): duel_text_changed.emit(value, glyph_position, wait_state))
	duel_text_presenter.text_finished.connect(func(): duel_text_finished.emit())
	duel_summon_rules = SUMMON_RULES_SCRIPT.new()
	_load_spell_target_classes()
	deck_rules = DECK_BUILDER_SCRIPT.new()
	deck_management = DECK_MANAGEMENT_SCRIPT.new()
	deck_builder_menu = DECK_BUILDER_MENU_SCRIPT.new()
	card_sorter = CARD_SORT_SCRIPT.new(card_database, shop_rules)
	deck_rules.load_copy_limits()
	wallet = PLAYER_WALLET_SCRIPT.new()
	progression = PROGRESSION_SCRIPT.new()
	password_system = PASSWORD_SYSTEM_SCRIPT.new()
	var password_load_error: Error = password_system.load_recovered_data()
	if password_load_error != OK:
		push_error("Could not load the recovered password tables (error %d)." % password_load_error)
	scene_script_database = SCENE_SCRIPT_DATABASE_SCRIPT.new()
	if not scene_script_database.load_default():
		push_error("Could not load recovered scene scripts: %s" % scene_script_database.load_error)
	scene_event_flags = EVENT_FLAGS_SCRIPT.new()
	scene_script_events = SCENE_SCRIPT_EVENTS_SCRIPT.new()
	scene_script_events.event_flags = scene_event_flags
	if not scene_script_events.load_variant_rules():
		push_error("Could not load scene variant rules: %s" % scene_script_events.load_error)
	if not scene_script_events.load_motion_data():
		push_error("Could not load scene script motion data: %s" % scene_script_events.load_error)
	scene_script_runtime = SCENE_SCRIPT_RUNTIME_SCRIPT.new()
	add_child(scene_script_runtime)
	scene_script_runtime.configure(scene_script_database)
	scene_script_runtime.commands.event_flags = scene_event_flags
	audio_dispatch = AUDIO_DISPATCH_SCRIPT.new()
	audio_dispatch.name = "GameAudioDispatch"
	add_child(audio_dispatch)
	scene_script_runtime.text_requested.connect(_on_scene_script_text_requested)
	scene_script_runtime.dialogue_clear_requested.connect(_clear_scene_dialogue_text)
	scene_script_events.scene_change_requested.connect(func(id: int, variant: int, spawn: int, _rules: bool) -> void:
		scene_script_runtime.stop()
		audio_dispatch.play_scene_music(id, variant)
		show_scene(id, variant)
		scene_script_scene_change.emit(id, variant, spawn)
	)
	scene_script_events.service_requested.connect(_on_scene_script_service_requested)
	scene_script_events.actor_motion_requested.connect(func(event_id: int, actors: Array, choreography: StringName) -> void: scene_script_motion_requested.emit(event_id, actors, choreography))
	scene_script_events.actor_motion_path_requested.connect(func(event_id: int, descriptor: Dictionary, x_steps: Array[int], y_steps: Array[int]) -> void: scene_script_motion_path.emit(event_id, descriptor, x_steps, y_steps))
	scene_script_events.actor_state_requested.connect(_apply_scene_script_actor_state)
	scene_script_runtime.script_error.connect(func(message: String) -> void: push_warning(message))
	_apply_save_data(current_save)
	title_choice = 1 if title_has_save else 0
	_build_screen()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if screen == "pre_duel" and pre_duel_menu != null:
			var pre_duel_code := _pre_duel_code_for_key(event.keycode)
			if pre_duel_code != 0:
				var result := process_pre_duel_code(pre_duel_code, pre_duel_opponent_id)
				if result.has("reason"): _toast(str(result.reason))
				_build_screen()
				get_viewport().set_input_as_handled()
				return
		if screen == "duel" and active_duel_state != null:
			var duel_code := _duel_code_for_key(event.keycode)
			if duel_code != PlayerDuelController.InputCode.NONE:
				var result := process_player_duel_code(duel_code, active_duel_state)
				if result.has("reason"): _toast(str(result.reason))
				_build_screen()
				get_viewport().set_input_as_handled()
				return
		if screen == "name_entry" and name_entry_view != null and name_entry_view.handle_key(event.keycode):
			get_viewport().set_input_as_handled()
			return
		if scene_script_runtime != null and scene_script_runtime.running and not scene_shop_active and not scene_password_entry_active:
			var pressed_mask := 0
			if event.keycode == KEY_ENTER: pressed_mask = 1
			elif event.keycode == KEY_SPACE: pressed_mask = 2
			var horizontal := -1 if event.keycode == KEY_LEFT else (1 if event.keycode == KEY_RIGHT else 0)
			var vertical := -1 if event.keycode == KEY_UP else (1 if event.keycode == KEY_DOWN else 0)
			scene_script_runtime.submit_dialogue_input(pressed_mask, horizontal, vertical)
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_ESCAPE:
				if screen == "deck_hub": _handle_deck_hub_buttons(DeckManagement.BUTTON_B)
				elif screen == "player_status": _show("deck_hub")
				elif screen == "card_detail": _show(card_detail_return_screen)
				elif screen == "shop": _handle_shop_escape()
				elif screen == "deck": _handle_deck_builder_key(2)
				else: _show("title")
			KEY_F1: _show("title")
			KEY_F2: _show("duel")
			KEY_F3: _show("shop")
			KEY_F4: _enter_deck_hub()
			KEY_F5: _request_password_entry()
			KEY_LEFT:
				if screen == "card_detail": _card_detail_page(-1)
				elif screen == "shop": _handle_shop_direction(Vector2i(-1, 0))
				elif screen == "deck" and deck_builder_menu.popup in [DeckBuilderMenu.Popup.COLLECTION_SORT, DeckBuilderMenu.Popup.DECK_SORT]: _handle_deck_builder_key(64)
				else: _step_selection(-1)
			KEY_RIGHT:
				if screen == "card_detail": _card_detail_page(1)
				elif screen == "shop": _handle_shop_direction(Vector2i(1, 0))
				elif screen == "deck" and deck_builder_menu.popup in [DeckBuilderMenu.Popup.COLLECTION_SORT, DeckBuilderMenu.Popup.DECK_SORT]: _handle_deck_builder_key(128)
				else: _step_selection(1)
			KEY_UP:
				if screen == "title" and title_has_save: _toggle_title_choice()
				elif screen == "shop": _handle_shop_direction(Vector2i(0, -1))
				elif screen == "deck_hub": _handle_deck_hub_buttons(DeckManagement.BUTTON_UP)
				elif screen == "deck" and deck_builder_menu.popup != DeckBuilderMenu.Popup.NONE: _handle_deck_builder_key(64)
				elif screen == "deck": _move_deck_selection(1, false)
				else: _step_selection(-1)
			KEY_DOWN:
				if screen == "title" and title_has_save: _toggle_title_choice()
				elif screen == "shop": _handle_shop_direction(Vector2i(0, 1))
				elif screen == "deck_hub": _handle_deck_hub_buttons(DeckManagement.BUTTON_DOWN)
				elif screen == "deck" and deck_builder_menu.popup != DeckBuilderMenu.Popup.NONE: _handle_deck_builder_key(128)
				elif screen == "deck": _move_deck_selection(1, true)
				else: _step_selection(1)
			KEY_PAGEUP:
				if screen == "shop": _handle_shop_page(-1)
				elif screen == "deck": _handle_deck_builder_key(0x140)
				else: _step_selection(-10)
			KEY_PAGEDOWN:
				if screen == "shop": _handle_shop_page(1)
				elif screen == "deck": _handle_deck_builder_key(0x180)
				else: _step_selection(10)
			KEY_X:
				if screen == "deck": _handle_deck_builder_key(16)
			KEY_Y:
				if screen == "deck": _handle_deck_builder_key(32)
			KEY_S:
				if screen == "shop": _handle_shop_sort_cycle()
				elif screen == "deck": _handle_deck_builder_key(4)
			KEY_D:
				if screen == "shop": _handle_shop_sort_open()
				elif screen == "deck": _handle_deck_builder_key(8)
			KEY_W:
				if screen == "deck": _handle_deck_builder_key(512)
			KEY_TAB:
				if screen == "shop":
					selling = not selling
					shop_selected = 7
					shop_menu.set_selling(selling)
					shop_menu.select(shop_selected, _visible_shop_cards().size())
					_build_screen()
				elif screen == "deck":
					_set_deck_view(not editing_deck)
				elif screen == "title" and title_has_save:
					_toggle_title_choice()
			KEY_ENTER:
				if screen == "deck_hub": _handle_deck_hub_buttons(DeckManagement.BUTTON_A)
				elif screen == "deck": _handle_deck_builder_key(1)
				elif screen == "shop": _handle_shop_confirm()
				else: _confirm()
			KEY_SPACE:
				if screen == "deck_hub": _handle_deck_hub_buttons(DeckManagement.BUTTON_B)
				elif screen == "player_status": _show("deck_hub")
				elif screen == "deck": _handle_deck_builder_key(2)
				else: _confirm()

## Resolves a card's recovered metadata effect against an explicit duel state.
## The duel screen can consume the returned presentation events through its UI.
func dispatch_duel_effect(card_id: int, duel_state: SacredDuelState, row: int, column: int, source_row: int = -1, source_column: int = -1, monster_effect: bool = false, presentation_suppressed: bool = false, random_service: SacredRandom = null) -> Variant:
	if duel_effect_dispatcher == null:
		return {"resolved": false, "reason": "effect_dispatcher_unavailable"}
	var context := {
		"duel_state": duel_state,
		"acting_side": duel_state.active_side if duel_state != null else 0,
		"row": row,
		"column": column,
		"source_row": source_row,
		"source_column": source_column,
		"presentation_suppressed": presentation_suppressed,
		"random_service": random_service,
	}
	if monster_effect:
		return duel_effect_dispatcher.dispatch_metadata_1b(card_id, context)
	return duel_effect_dispatcher.dispatch_metadata_1a(card_id, context)

func present_duel_text(text: String, card_id: int = 0, other_card_id: int = 0, number: int = 0, other_number: int = 0, language: int = 0, player_name: String = "") -> void:
	if duel_text_presenter == null:
		push_error("Duel text presenter is not initialized.")
		return
	duel_text_presenter.begin(text, card_id, other_card_id, number, other_number, language, player_name)

func advance_duel_text(max_steps: int = 1) -> Dictionary:
	return duel_text_presenter.run_to_next_pause(max_steps) if duel_text_presenter != null else {"finished": true}

func continue_duel_text() -> void:
	if duel_text_presenter != null: duel_text_presenter.advance_input()

## Entry point for player-turn controls. The caller supplies owned duel state
## and normalized input codes; action results are handled by duel systems/UI.
func process_player_duel_code(code: int, duel_state: SacredDuelState) -> Dictionary:
	if player_duel_controller == null or duel_state == null:
		return {"accepted": false, "reason": "duel_not_initialized"}
	var side_id := duel_state.active_side
	match code:
		PlayerDuelController.InputCode.UP: player_duel_controller.move_cursor(Vector2i.UP)
		PlayerDuelController.InputCode.DOWN: player_duel_controller.move_cursor(Vector2i.DOWN)
		PlayerDuelController.InputCode.LEFT: player_duel_controller.move_cursor(Vector2i.LEFT)
		PlayerDuelController.InputCode.RIGHT: player_duel_controller.move_cursor(Vector2i.RIGHT)
		PlayerDuelController.InputCode.CANCEL: return player_duel_controller.cancel_selection()
		PlayerDuelController.InputCode.END_PLAYER_TURN:
			duel_state.auxiliary_flags[side_id] = 2
			player_duel_controller.player_turn_done = true
			return {"accepted": true, "action": "end_turn", "side": side_id}
		PlayerDuelController.InputCode.END_OPPONENT_TURN:
			duel_state.auxiliary_flags[1 - side_id] = 2
			player_duel_controller.player_turn_done = true
			return {"accepted": true, "action": "end_opponent_turn", "side": 1 - side_id}
		PlayerDuelController.InputCode.STATS:
			return {"accepted": true, "action": "show_stats", "cursor": player_duel_controller.cursor}
		PlayerDuelController.InputCode.OPPONENT_HAND:
			duel_state.side(1 - side_id).hand_revealed = true
			return {"accepted": true, "action": "show_opponent_hand", "cards": duel_state.side(1 - side_id).hand.duplicate()}
		PlayerDuelController.InputCode.CONFIRM:
			if player_duel_controller.mode == PlayerDuelController.Mode.PLACE_CARD:
				return player_duel_controller.confirm_placement(duel_state, side_id, duel_summon_rules, card_database)
			if player_duel_controller.mode == PlayerDuelController.Mode.SPELL_TARGET:
				var target_result := player_duel_controller.validate_spell_target(duel_state, side_id, 1)
				if not bool(target_result.get("accepted", false)): return target_result
				var effect_result: Variant = dispatch_duel_effect(int(target_result.card_id), duel_state, int(target_result.target_row), int(target_result.target_column), int(target_result.source_row), int(target_result.source_column))
				if bool(effect_result.get("resolved", false)): player_duel_controller.finish_target_action()
				return effect_result if effect_result is Dictionary else {"resolved": true, "result": effect_result}
			if player_duel_controller.mode == PlayerDuelController.Mode.ATTACK_TARGET:
				var opponent_slot := duel_state.side(1 - side_id).monster_zones[player_duel_controller.cursor.x]
				if opponent_slot.is_empty(): return {"accepted": false, "reason": "empty_attack_target"}
				return {"accepted": true, "action": "attack_target", "attacker": player_duel_controller.saved_cursor, "target": player_duel_controller.cursor, "target_card_id": opponent_slot.card_id}
			return _confirm_player_field_selection(duel_state, side_id)
	return {"accepted": true, "action": "cursor_moved", "cursor": player_duel_controller.cursor, "view_row": player_duel_controller.view_row}

func _confirm_player_field_selection(duel_state: SacredDuelState, side_id: int) -> Dictionary:
	var cell := player_duel_controller.cursor
	var card_id := player_duel_controller.selected_card_id(duel_state, side_id)
	if card_id == 0: return {"accepted": false, "reason": "empty_selection"}
	if cell.y == 2:
		var slot := duel_state.side(side_id).monster_zones[cell.x]
		if (slot.persistent_flags & 1) != 0: return {"accepted": false, "reason": "monster_already_used"}
		return {"accepted": true, "action": "open_monster_action_menu", "card_id": card_id, "cursor": cell}
	if cell.y == 3:
		var definition := card_database.get_card(card_id)
		if definition == null: return {"accepted": false, "reason": "card_metadata_missing"}
		var target_class := int(_spell_target_classes[definition.metadata_1a]) if definition.metadata_1a >= 0 and definition.metadata_1a < _spell_target_classes.size() else 0
		var started := player_duel_controller.begin_spell_target(card_id, target_class)
		if not bool(started.get("accepted", false)): return started
		if target_class == 0:
			var effect_result: Variant = dispatch_duel_effect(card_id, duel_state, cell.y, cell.x)
			return effect_result if effect_result is Dictionary else {"resolved": true, "result": effect_result}
		return started
	if cell.y == 4:
		var needed := duel_summon_rules.remaining_monster_tributes(card_id, duel_state.tributes_committed, card_database)
		if needed > 0: return {"accepted": false, "reason": "tributes_required", "remaining": needed}
		return player_duel_controller.begin_card_placement(duel_state, side_id, card_id, duel_summon_rules, card_database)
	return {"accepted": false, "reason": "invalid_row"}

func _load_spell_target_classes() -> void:
	_spell_target_classes.clear()
	var path := "res://resources/ai_spell_target_classes.json"
	if not FileAccess.file_exists(path):
		push_error("Missing recovered spell target classes at %s" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for value: Variant in parsed.get("metadata_1a_target_classes", []):
			_spell_target_classes.append(int(value))

## Validates a recovered AI candidate using packed row/column operands.
func validate_ai_action(duel_state: SacredDuelState, acting_side: int, action_kind: int, operands: Array[int]) -> Dictionary:
	if ai_validation == null:
		return {"valid": false, "reason": "ai_validation_unavailable"}
	return ai_validation.validate(duel_state, acting_side, action_kind, operands)

## Returns only legal entries from the recovered 616-candidate action table.
func valid_ai_candidates(duel_state: SacredDuelState, acting_side: int) -> Array[Dictionary]:
	var valid_candidates: Array[Dictionary] = []
	if ai_validation == null or ai_candidate_database == null:
		return valid_candidates
	for candidate in ai_candidate_database.get_candidates():
		var result := ai_validation.validate_candidate(duel_state, acting_side, candidate)
		if bool(result.get("valid", false)):
			valid_candidates.append(candidate)
	return valid_candidates

## Scores legal AI candidates before action simulation. Effect-specific callbacks
## remain injectable until the recovered metadata scorer tables are ported.
func score_ai_candidates(duel_state: SacredDuelState, acting_side: int) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	if ai_scoring == null:
		return scored
	for candidate in valid_ai_candidates(duel_state, acting_side):
		var result := ai_scoring.score_before(duel_state, acting_side, candidate)
		if bool(result.get("resolved", false)):
			var entry := candidate.duplicate(true)
			entry["score"] = int(result.score)
			scored.append(entry)
	return scored

func best_ai_candidate(duel_state: SacredDuelState, acting_side: int) -> Dictionary:
	return ai_scoring.best_candidate(score_ai_candidates(duel_state, acting_side)) if ai_scoring != null else {}

## Executes one recovered candidate. Simulated calls should receive an isolated
## duel-state copy from the caller; real calls return presentation/audio events.
func execute_ai_action(duel_state: SacredDuelState, acting_side: int, candidate: Dictionary, simulate: bool = false, random_service: SacredRandom = null) -> Dictionary:
	if ai_actions == null:
		return {"resolved": false, "reason": "ai_actions_unavailable"}
	ai_actions.set_random_service(random_service)
	return ai_actions.execute(duel_state, acting_side, candidate, simulate)

## Runs a full opponent decision loop using independent candidate state copies.
func run_opponent_turn(duel_state: SacredDuelState, acting_side: int, random_service: SacredRandom = null, max_actions: int = 616) -> Dictionary:
	if ai_turn == null:
		return {"completed": false, "reason": "ai_turn_unavailable", "actions": []}
	return ai_turn.run_opponent_turn(duel_state, acting_side, random_service, max_actions)

## Connects a game-owned duel state to the playable Godot battlefield view.
func show_duel_state(duel_state: SacredDuelState) -> void:
	active_duel_state = duel_state
	if player_duel_controller != null: player_duel_controller.reset_turn()
	_show("duel")

func initialize_pre_duel_menu(wagerable_ids: Array[int], special_wager_ids: Array[int]) -> void:
	if pre_duel_menu == null: pre_duel_menu = PRE_DUEL_MENU_SCRIPT.new()
	pre_duel_menu.initialize(shop_rules.collection, deck, wagerable_ids, special_wager_ids)
	pre_duel_menu.apply_sort(card_sorter)

func show_pre_duel_menu(opponent_id: int, wagerable_ids: Array[int], special_wager_ids: Array[int]) -> void:
	pre_duel_opponent_id = opponent_id
	initialize_pre_duel_menu(wagerable_ids, special_wager_ids)
	_show("pre_duel")

func _pre_duel_code_for_key(keycode: int) -> int:
	match keycode:
		KEY_UP: return 64
		KEY_DOWN: return 128
		KEY_LEFT: return 32
		KEY_RIGHT: return 16
		KEY_ENTER, KEY_KP_ENTER: return 1
		KEY_SPACE, KEY_ESCAPE: return 2
		KEY_PAGEUP: return 0x140
		KEY_PAGEDOWN: return 0x180
		KEY_Q: return 512
		KEY_S: return 4
		KEY_D: return 8
	return 0

func process_pre_duel_code(code: int, opponent_id: int) -> Dictionary:
	if pre_duel_menu == null:
		return {"accepted": false, "reason": "pre_duel_menu_not_initialized"}
	if pre_duel_menu.popup != PreDuelMenuState.Popup.NONE:
		if code == 2 or code == 8:
			pre_duel_menu.close_popup()
			if audio_dispatch != null: audio_dispatch.play_game_audio(56)
			return {"accepted": true, "action": "popup_closed"}
		if code in [64, 128, 32, 16]:
			var direction := -1 if code in [64, 32] else 1
			pre_duel_menu.navigate_popup(direction)
			if audio_dispatch != null: audio_dispatch.play_game_audio(54)
			return {"accepted": true, "action": "popup_moved", "choice": pre_duel_menu.choice}
		if code == 1:
			var popup_result := pre_duel_menu.confirm()
			if bool(popup_result.get("apply_sort", false)): pre_duel_menu.apply_sort(card_sorter)
			return _handle_pre_duel_result(popup_result, opponent_id)
		return {"accepted": false, "reason": "unsupported_popup_input"}
	match code:
		64: pre_duel_menu.move(-1)
		128: pre_duel_menu.move(1)
		0x140: pre_duel_menu.page(-1)
		0x180: pre_duel_menu.page(1)
		512: pre_duel_menu.cycle_view()
		4: pre_duel_menu.cycle_sort(card_sorter)
		8: pre_duel_menu.open_sort()
		2: pre_duel_menu.open_no_wager()
		1: return _handle_pre_duel_result(pre_duel_menu.confirm(), opponent_id)
		_: return {"accepted": false, "reason": "unsupported_input"}
	if audio_dispatch != null: audio_dispatch.play_game_audio(55 if code in [4, 8, 2, 512] else 54)
	return {"accepted": true, "action": "list_updated", "selected_card_id": pre_duel_menu.selected_card_id(), "view_mode": pre_duel_menu.view_mode}

func _handle_pre_duel_result(result: Dictionary, opponent_id: int) -> Dictionary:
	var sound := int(result.get("sound", 0))
	if sound != 0 and audio_dispatch != null: audio_dispatch.play_game_audio(sound)
	match int(result.get("action", PreDuelMenuState.Action.NONE)):
		PreDuelMenuState.Action.INSPECT:
			selected_card_detail_id = int(result.get("card_id", 0))
			card_detail_return_screen = "pre_duel"
			_show("card_detail")
			return result
		PreDuelMenuState.Action.START_WITH_WAGER, PreDuelMenuState.Action.START_WITHOUT_WAGER:
			if audio_dispatch != null: audio_dispatch.fade_game_music(2)
			pre_duel_requested.emit(opponent_id, int(result.get("card_id", 0)))
	return result

func _duel_code_for_key(keycode: int) -> int:
	match keycode:
		KEY_UP: return PlayerDuelController.InputCode.UP
		KEY_DOWN: return PlayerDuelController.InputCode.DOWN
		KEY_LEFT: return PlayerDuelController.InputCode.LEFT
		KEY_RIGHT: return PlayerDuelController.InputCode.RIGHT
		KEY_ENTER, KEY_SPACE: return PlayerDuelController.InputCode.CONFIRM
		KEY_ESCAPE: return PlayerDuelController.InputCode.CANCEL
		KEY_Q: return PlayerDuelController.InputCode.STATS
		KEY_W: return PlayerDuelController.InputCode.OPPONENT_HAND
	return PlayerDuelController.InputCode.NONE

func _duel_cell_selected(row: int, column: int) -> void:
	if player_duel_controller == null: return
	player_duel_controller.cursor = Vector2i(column, row)
	_build_screen()

## Starts one of the recovered scene entry scripts by scene/variant role.
## The script graph contains typed node IDs and can be driven by project services.
func start_scene_script(scene_id: int, variant: int, role: StringName = &"scene_script_a", initial_context: Dictionary = {}) -> bool:
	if scene_script_database == null or scene_script_runtime == null:
		return false
	var roots := scene_script_database.roots_for_scene(scene_id, variant)
	var root_id := StringName(roots.get(role, &""))
	if root_id == &"":
		return false
	scene_script_events.scene_id = scene_id
	scene_script_events.scene_variant = variant
	audio_dispatch.play_scene_music(scene_id, variant)
	var scene_configuration: SceneConfiguration
	var scene_configuration_data: Variant = initial_context.get("scene_configuration")
	if scene_configuration_data is SceneConfiguration:
		scene_configuration = scene_configuration_data
	elif scene_configuration_data is Dictionary:
		scene_configuration = SceneConfiguration.from_dictionary(scene_configuration_data)
	var scene_grid := initial_context.get("scene_grid") as SceneGrid
	if scene_grid == null and initial_context.get("scene_grid_cells") is PackedInt32Array:
		scene_grid = SceneGrid.new(initial_context.scene_grid_cells)
	show_scene(scene_id, variant, scene_configuration, scene_grid)
	var context := initial_context.duplicate()
	if not context.has("player_name") and current_save != null:
		context["player_name"] = current_save.player_name
	if scene_grid != null:
		context["scene_grid"] = scene_grid
	context["event"] = func(event_id: int, _runtime: SceneScriptRuntime) -> void:
		await _execute_scene_script_event(event_id, _runtime.state)
	context["condition"] = func(condition_id: int, _runtime: SceneScriptRuntime) -> int:
		if condition_id == 0: return 1 if progression.duelist_level < 80 else 0
		if condition_id == 1: return 1 if _bit_count(scene_script_events.progress_rank & 0x3F) == 6 else 0
		return 0
	context["dialogue_visibility"] = func(visible: bool) -> void: _set_scene_dialogue_visible(visible)
	context["dialogue"] = func(operation: StringName, data: Dictionary, _runtime: SceneScriptRuntime) -> void:
		_handle_scene_dialogue(operation, data)
		scene_script_service_requested.emit(&"dialogue", {"operation": operation, "data": data})
	context["actor"] = func(command: StringName, operands: Array, _runtime: SceneScriptRuntime) -> void:
		await _execute_scene_actor_command(command, operands)
	context["fade"] = func(delay_frames: int) -> void:
		if scene_actor_runtime != null:
			await scene_actor_runtime.fade_to_dark(delay_frames)
		else:
			scene_script_service_requested.emit(&"fade", {"delay_frames": delay_frames})
	context["audio"] = func(audio_id: int) -> void:
		audio_dispatch.play_game_audio(audio_id)
		scene_script_service_requested.emit(&"audio", {"audio_id": audio_id})
	context["music_fade"] = func(frames: int) -> void: audio_dispatch.fade_game_music(frames)
	context["effect_music_stop"] = func() -> void: audio_dispatch.stop_effect_music_player()
	context["save"] = func() -> void: scene_script_service_requested.emit(&"save", {})
	var supplied_duel_service: Callable = initial_context.get("duel_service", Callable())
	if supplied_duel_service.is_valid():
		context["duel"] = func(opponent_id: int, _runtime: SceneScriptRuntime) -> Variant:
			var outcome: Variant = await supplied_duel_service.call(opponent_id)
			if int(outcome) == 1:
				await _restore_scene_display()
				_set_scene_dialogue_visible(true)
			return outcome
	else:
		context["duel"] = func(opponent_id: int, _runtime: SceneScriptRuntime) -> int:
			scene_script_service_requested.emit(&"duel", {"opponent_id": opponent_id})
			return 0
	context["collection_card"] = func(card_id: int, count: int) -> void: scene_script_service_requested.emit(&"collection_card", {"card_id": card_id, "count": count})
	return scene_script_runtime.start(root_id, context)

func _on_scene_script_service_requested(service: StringName, data: Dictionary) -> void:
	if service == &"door_transition":
		audio_dispatch.fade_game_music(int(data.get("music_fade_frames", 0)))
		audio_dispatch.play_game_audio(int(data.get("audio_id", 0)))
	elif service == &"name_entry":
		_start_name_entry(bool(data.get("save_after", false)))
		return
	scene_script_service_requested.emit(service, data)

func _start_name_entry(save_after: bool) -> void:
	name_entry_return_screen = screen
	name_entry_save_after = save_after
	_show("name_entry")

func _finish_name_entry(value: String) -> void:
	if current_save != null:
		current_save.player_name = value
		if name_entry_save_after: _save_current_state()
	_show(name_entry_return_screen)
	scene_name_entry_finished.emit()

func _cancel_name_entry() -> void:
	_show(name_entry_return_screen)
	scene_name_entry_finished.emit()

func _bit_count(value: int) -> int:
	var bits := value
	var total := 0
	while bits != 0:
		total += bits & 1
		bits >>= 1
	return total

func _show(next: String) -> void:
	screen = next
	selected = clampi(selected, 0, maxi(_visible_cards().size() - 1, 0))
	_build_screen()

func _build_screen() -> void:
	var persistent_children: Array = [scene_script_runtime, audio_dispatch]
	screen_root = menu_graphics.begin_screen(self, screen_root, persistent_children, _background_for_screen())
	match screen:
		"title": _draw_title()
		"duel": _draw_duel()
		"shop": _draw_shop()
		"deck": _draw_deck()
		"deck_hub": _draw_deck_hub()
		"player_status": _draw_player_status()
		"card_detail": _draw_card_detail()
		"name_entry": _draw_name_entry()
		"pre_duel": _draw_pre_duel()
		"scene": _draw_scene()
	menu_graphics.upload_menu_graphics(screen_root)

## Presents a recovered scene background in the Godot screen shell.
func show_scene(scene_id: int, variant: int = 0, configuration: SceneConfiguration = null, grid: SceneGrid = null) -> bool:
	if scene_graphics == null:
		return false
	var graphics: Dictionary = scene_graphics.scene_background(scene_id, variant)
	if not bool(graphics.get("ok", false)):
		return false
	current_scene_id = scene_id
	current_scene_variant = variant
	current_scene_graphics = graphics
	current_scene_configuration = configuration
	current_scene_grid = grid
	_show("scene")
	scene_graphics_changed.emit(scene_id, variant, graphics)
	return true

func _draw_scene() -> void:
	var graphics := current_scene_graphics
	if not bool(graphics.get("ok", false)):
		return
	var background := screen_root.get_child(0) as TextureRect if screen_root.get_child_count() > 0 else null
	if background != null:
		background.texture = graphics.texture as Texture2D
		background.z_index = -200
	current_scene_portrait_layer = null
	scene_actor_runtime = null
	if actor_animation_database != null:
		var configuration := current_scene_configuration if current_scene_configuration != null else SceneConfiguration.new()
		scene_actor_runtime = configuration.instantiate_actors(actor_animation_database) as SceneActorRuntime
		scene_actor_runtime.z_index = -100
		if current_scene_grid != null:
			scene_actor_runtime.set_scene_grid(current_scene_grid)
		screen_root.add_child(scene_actor_runtime)
		scene_actor_runtime.dialogue_hide_requested.connect(func() -> void: _set_scene_dialogue_visible(false))
	scene_dialogue_view = SCENE_DIALOGUE_DISPLAY_SCRIPT.new()
	screen_root.add_child(scene_dialogue_view)
	scene_dialogue_view.visible = false

func _execute_scene_actor_command(command: StringName, operands: Array) -> void:
	if scene_actor_runtime != null:
		match command:
			&"@0":
				if operands.size() >= 4:
					await scene_actor_runtime.move_actor(int(operands[0]), int(operands[1]), int(operands[2]), int(operands[3]))
			&"@1":
				if operands.size() >= 4:
					await scene_actor_runtime.place_actor(int(operands[0]), int(operands[1]), int(operands[2]), int(operands[3]))
			&"@4":
				if operands.size() >= 2:
					await scene_actor_runtime.move_actor_to_x(int(operands[0]), int(operands[1]))
			&"@5":
				if operands.size() >= 2:
					await scene_actor_runtime.move_actor_to_y(int(operands[0]), int(operands[1]))
			&"@6":
				if not operands.is_empty(): await scene_actor_runtime.pose_four(int(operands[0]))
			&"^5":
				if operands.size() >= 2: await scene_actor_runtime.change_sprite(int(operands[0]), int(operands[1]))
	scene_script_service_requested.emit(&"actor_command", {"command": command, "operands": operands})

func _execute_scene_script_event(event_id: int, script_state: Dictionary) -> void:
	if event_id == 8 or event_id == 11:
		scene_script_events.dispatch(event_id, script_state, false, true)
		await _run_scene_shop(event_id == 11)
		return
	if event_id == 10:
		scene_script_events.dispatch(event_id, script_state, false, true)
		await _run_scene_name_entry()
		return
	if event_id == 24:
		scene_script_events.dispatch(event_id, script_state, false, true)
		await _run_scene_password_entry()
		return
	if event_id == 57:
		scene_script_events.dispatch(event_id, script_state, false, true)
		await _restore_scene_display()
		return
	if scene_script_events.is_door_event(event_id):
		audio_dispatch.fade_game_music(1)
		await _wait_scene_frames(8)
		audio_dispatch.play_game_audio(92)
		await _wait_scene_frames(50)
		scene_script_events.dispatch(event_id, script_state, true)
		return
	scene_script_events.dispatch(event_id, script_state)
	if not scene_script_events.motion_events.has(event_id):
		return
	var descriptor: Dictionary = scene_script_events.motion_events[event_id]
	var paths: Dictionary = scene_script_events.motion_path_for_event(event_id)
	for entry: Variant in descriptor.get("sequence", []):
		if not entry is Dictionary:
			continue
		match StringName(entry.get("op", "")):
			&"hide_dialogue":
				_set_scene_dialogue_visible(false)
			&"wait":
				await _wait_scene_frames(int(entry.get("frames", 0)))
			&"audio":
				audio_dispatch.play_game_audio(int(entry.get("id", 0)))
			&"stop_effect_music":
				audio_dispatch.stop_effect_music_player()
			&"actor_orientation":
				if scene_actor_runtime != null:
					scene_actor_runtime.set_actor_orientation(int(entry.get("actor", 0)), int(entry.get("value", 0)))
			&"position_actor":
				var actor_id := int(entry.get("actor", descriptor.get("actor", 0)))
				var position: Array = entry.get("position", [0, 0])
				if scene_actor_runtime != null and position.size() >= 2:
					await scene_actor_runtime.position_actor(actor_id, int(position[0]), int(position[1]))
			&"move_actor":
				if scene_actor_runtime != null:
					await scene_actor_runtime.move_actor(int(entry.get("actor", 0)), int(entry.get("direction", 0)), int(entry.get("steps", 0)))
			&"follow_motion":
				await _run_scene_follow_motion(descriptor, paths)
			&"hide_actors":
				for actor_value: Variant in entry.get("actors", []):
					if scene_actor_runtime != null:
						await scene_actor_runtime.position_actor(int(actor_value), 192, 192)
					else:
						await _wait_scene_frames(1)
					await _wait_scene_frames(1)
			_: scene_script_service_requested.emit(&"scene_motion_operation", {"event_id": event_id, "operation": entry})

func _apply_scene_script_actor_state(actor_id: int, changes: Dictionary) -> void:
	if scene_actor_runtime != null:
		scene_actor_runtime.apply_script_state(actor_id, changes)
	scene_script_actor_state.emit(actor_id, changes)

func _run_scene_follow_motion(descriptor: Dictionary, paths: Dictionary) -> void:
	var x_steps: Array = paths.get("x", [])
	var y_steps: Array = paths.get("y", [])
	var actor_id := int(descriptor.get("actor", -1))
	for index in range(mini(x_steps.size(), y_steps.size())):
		var actor := scene_actor_runtime.actor(actor_id) if scene_actor_runtime != null else null
		if actor != null:
			await scene_actor_runtime.position_actor(actor_id, _signed_scene_word(actor.position.x + int(x_steps[index])), _signed_scene_word(actor.position.y + int(y_steps[index])))
		else:
			await _wait_scene_frames(1)
		await _wait_scene_frames(1)

func _signed_scene_word(value: int) -> int:
	var word := value & 0xFFFF
	return word - 0x10000 if word >= 0x8000 else word

func _wait_scene_frames(frame_count: int) -> void:
	if frame_count > 0:
		await get_tree().create_timer(float(frame_count) / 60.0).timeout

func _run_scene_shop(is_selling: bool) -> void:
	scene_shop_return_screen = screen
	scene_shop_active = true
	selling = is_selling
	shop_selected = 0
	shop_menu.begin(is_selling, shop_selected)
	_show("shop")
	await scene_shop_closed

func _leave_scene_shop() -> void:
	scene_shop_active = false
	_show(scene_shop_return_screen)
	if scene_shop_return_screen == "scene":
		_set_scene_dialogue_visible(true)
	scene_shop_closed.emit()

func _run_scene_name_entry() -> void:
	name_entry_return_screen = screen
	name_entry_save_after = false
	_show("name_entry")
	await scene_name_entry_finished
	_save_current_state()
	if screen != "scene":
		_show("scene")
	_set_scene_dialogue_visible(true)

func _run_scene_password_entry() -> void:
	scene_password_entry_active = true
	_request_password_entry()
	await scene_password_entry_finished
	if screen != "scene":
		_show("scene")
	_set_scene_dialogue_visible(true)

func _restore_scene_display() -> void:
	show_scene(current_scene_id, current_scene_variant, current_scene_configuration, current_scene_grid)
	await _wait_scene_frames(1)
	_set_scene_dialogue_visible(true)

func _handle_scene_dialogue(operation: StringName, data: Dictionary) -> void:
	if operation != &"portrait" or screen != "scene" or screen_root == null:
		return
	if is_instance_valid(current_scene_portrait_layer):
		current_scene_portrait_layer.queue_free()
	current_scene_portrait_layer = null
	var portrait_id := int(data.get("portrait", 0))
	if portrait_id > 0 and scene_graphics != null:
		current_scene_portrait_layer = scene_graphics.create_portrait_layer(screen_root, portrait_id, int(data.get("flags", 0)))
	_set_scene_dialogue_visible(true)

func _on_scene_script_text_requested(value: String, language: int, glyph_position: int) -> void:
	scene_script_text.emit(value, language, glyph_position)
	if screen == "scene" and is_instance_valid(scene_dialogue_view):
		scene_dialogue_view.present_text(value, glyph_position)

func _clear_scene_dialogue_text() -> void:
	if is_instance_valid(scene_dialogue_view):
		scene_dialogue_view.clear_text()

func _set_scene_dialogue_visible(should_show: bool) -> void:
	if is_instance_valid(scene_dialogue_view):
		scene_dialogue_view.set_window_visible(should_show)
	if scene_graphics != null:
		scene_graphics.set_dialogue_window_visible(should_show)
	scene_script_service_requested.emit(&"dialogue_visibility", {"visible": should_show})

func _background_for_screen() -> String:
	match screen:
		"title": return ART + "title-background.png"
		"duel": return duel_graphics.current_texture_path() if duel_graphics != null else ART + "duel-field.png"
		"shop": return ART + "shop-backdrop.png"
		"deck": return ART + ("deck-backdrop.png" if editing_deck else "collection-backdrop.png")
		"deck_hub", "player_status": return ART + "deck-backdrop.png"
		"name_entry": return ART + "name-entry-background.png"
		"pre_duel": return ART + "wager-backdrop.png"
	return ART + "title-background.png"

func _draw_pre_duel() -> void:
	pre_duel_display = PRE_DUEL_DISPLAY_SCRIPT.new()
	pre_duel_display.position = Vector2.ZERO
	pre_duel_display.size = SCREEN_SIZE
	pre_duel_display.row_selected.connect(_on_pre_duel_row_selected)
	pre_duel_display.popup_selected.connect(_on_pre_duel_popup_selected)
	screen_root.add_child(pre_duel_display)
	pre_duel_display.present(pre_duel_menu, card_database, deck, progression.capacity, deck_rules.deck_cost(card_database))

func _on_pre_duel_row_selected(row: int) -> void:
	if pre_duel_menu == null or pre_duel_menu.popup != PreDuelMenuState.Popup.NONE: return
	pre_duel_menu.move(row - 2)
	_build_screen()

func _on_pre_duel_popup_selected(choice: int) -> void:
	if pre_duel_menu == null or pre_duel_menu.popup == PreDuelMenuState.Popup.NONE: return
	var max_choice := 9 if pre_duel_menu.popup == PreDuelMenuState.Popup.SORT else 2 if pre_duel_menu.popup == PreDuelMenuState.Popup.ACTION else 1
	pre_duel_menu.choice = clampi(choice, 0, max_choice)
	_build_screen()

func _draw_name_entry() -> void:
	name_entry_view = NAME_ENTRY_SCRIPT.new()
	name_entry_view.position = Vector2.ZERO
	name_entry_view.size = SCREEN_SIZE
	name_entry_view.name_confirmed.connect(_finish_name_entry)
	name_entry_view.cancelled.connect(_cancel_name_entry)
	screen_root.add_child(name_entry_view)
	name_entry_view.begin(current_save.player_name if current_save != null else "")

func set_duel_terrain(terrain: int, view: int) -> bool:
	var selection: Dictionary = duel_graphics.select(terrain, view)
	if not bool(selection.get("ok", false)):
		push_warning("Could not select duel terrain: %s" % selection.get("error", "unknown error"))
		return false
	if screen == "duel":
		_build_screen()
	return true

func scene_actor_draw_records(configuration: SceneConfiguration, grid: SceneGrid) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if configuration == null or scene_graphics == null: return records
	for actor: SceneActor in scene_graphics.sort_actors(configuration.actors):
		var cell := grid.cell_at(actor.position.x, actor.position.y) if grid != null else 0
		records.append(scene_graphics.actor_draw_record(actor, scene_graphics.actor_height(actor, grid), cell))
	return records

func add_scene_portrait(parent: Control, portrait_id: int, portrait_flags: int = 0, frame_indices: Array[int] = []) -> Control:
	return scene_graphics.create_portrait_layer(parent, portrait_id, portrait_flags, frame_indices) if scene_graphics != null else null

func set_scene_dialogue_window_visible(visible: bool) -> Dictionary:
	return scene_graphics.set_dialogue_window_visible(visible) if scene_graphics != null else {"visible": false}

func _draw_title() -> void:
	# The backdrop is the recovered title layer; native choices sit directly over it.
	if title_has_save:
		_text("CONTINUE", Vector2(90, 126), 8, GOLD if title_menu.choice == TITLE_MENU_SCRIPT.Choice.CONTINUE else PAPER)
		_text("NEW GAME", Vector2(90, 137), 8, GOLD if title_menu.choice == TITLE_MENU_SCRIPT.Choice.NEW_GAME else PAPER)
	else:
		_text("NEW GAME", Vector2(90, 132), 8, GOLD)
	_click_area(Rect2(76, 122, 88, 34), _confirm_title)

func _draw_duel() -> void:
	if active_duel_state != null:
		duel_ui = DUEL_UI_SCRIPT.new()
		duel_ui.position = Vector2.ZERO
		duel_ui.size = SCREEN_SIZE
		duel_ui.cell_selected.connect(_duel_cell_selected)
		screen_root.add_child(duel_ui)
		duel_ui.present(active_duel_state, card_database, player_duel_controller.cursor)
		return
	_overlay_rect(Rect2(3, 2, 103, 15), Color(0.04, 0.08, 0.10, 0.9), Color("d7bf82"))
	_text("RIVAL  %04d" % rival_lp, Vector2(7, 5), 9, PAPER)
	_overlay_rect(Rect2(134, 2, 103, 15), Color(0.04, 0.08, 0.10, 0.9), Color("d7bf82"))
	_text("YOU  %04d" % player_lp, Vector2(139, 5), 9, PAPER)
	if field_has_monster:
		_card_panel(Rect2(92, 68, 54, 46), field_card_id, false, false, true)
	_overlay_rect(Rect2(3, 123, 234, 34), Color(0.06, 0.08, 0.10, 0.92), Color("b6a168"))
	_text("HAND", Vector2(7, 125), 7, GOLD)
	for hand_index in range(5):
		var card_index := deck[posmod(selected + hand_index, deck.size())] if not deck.is_empty() else 0
		var x := 7 + hand_index * 45
		_card_panel(Rect2(x + 5, 115, 30, 41), card_index, hand_index == 0)
	_overlay_rect(Rect2(176, 21, 60, 94), Color(0.05, 0.07, 0.07, 0.94), Color("c5aa6d"))
	_button("SUMMON", Rect2(180, 25, 52, 17), func(): _duel_summon())
	_button("ATTACK", Rect2(180, 47, 52, 17), func(): _duel_attack())
	_button("END TURN", Rect2(180, 69, 52, 17), func(): _duel_end())
	_text("TURN 03", Vector2(185, 96), 8, GOLD)
	_text("F2 FIELD", Vector2(190, 106), 6, PAPER)

func _draw_shop() -> void:
	_text("SELL" if selling else "BUY", Vector2(8, 4), 8, GOLD)
	_text("%d" % credits, Vector2(184, 4), 8, PAPER)
	var visible_cards := _visible_shop_cards()
	if visible_cards.is_empty():
		return
	shop_display = SHOP_DISPLAY_SCRIPT.new()
	shop_display.position = Vector2.ZERO
	shop_display.size = SCREEN_SIZE
	shop_display.card_selected.connect(_select_shop_index)
	screen_root.add_child(shop_display)
	shop_display.present(visible_cards, shop_selected, selling, card_database, shop_panel, shop_rules, wallet, deck, shop_menu.popup, shop_menu.choice)

func _draw_deck() -> void:
	_text("%05d" % (progression.capacity if not editing_deck else deck_rules.deck_cost(card_database)), Vector2(78, 8), 8, PAPER)
	_text("%02d" % deck.size(), Vector2(184, 8), 8, PAPER)
	collection_display = COLLECTION_DISPLAY_SCRIPT.new()
	collection_display.position = Vector2.ZERO
	collection_display.size = SCREEN_SIZE
	collection_display.card_selected.connect(_select_deck_card)
	screen_root.add_child(collection_display)
	collection_display.present(deck if editing_deck else collection, selected, card_database, editing_deck, deck_builder_menu.deck_filter if editing_deck else 0)
	_draw_deck_builder_popup()

func _draw_deck_builder_popup() -> void:
	if deck_builder_menu.popup == DeckBuilderMenu.Popup.NONE: return
	_overlay_rect(Rect2(54, 43, 132, 76), Color(0.04, 0.06, 0.06, 0.96), Color("d0b46f"))
	var labels: Array[String] = []
	if deck_builder_menu.popup == DeckBuilderMenu.Popup.COLLECTION_ACTION:
		labels = ["CARD INFO", "ADD TO DECK", "REMOVE FROM DECK"]
	elif deck_builder_menu.popup == DeckBuilderMenu.Popup.DECK_ACTION:
		labels = ["CARD INFO", "REMOVE CARD"]
	else:
		var modes := ["NUMBER", "NAME", "ATTACK", "DEFENSE", "TYPE", "ATTRIBUTE", "COST", "LEVEL", "QUANTITY"]
		labels = modes
		if deck_builder_menu.popup == DeckBuilderMenu.Popup.COLLECTION_SORT:
			labels = ["COPY", "NUMBER", "NAME", "ATTACK", "DEFENSE", "TYPE", "ATTRIBUTE", "COST", "QUANTITY"]
		if deck_builder_menu.popup == DeckBuilderMenu.Popup.DECK_SORT:
			labels = ["NUMBER", "NAME", "ATTACK", "DEFENSE", "TYPE", "ATTRIBUTE", "DECK COUNT", "COST", "LEVEL"]
	var first := maxi(deck_builder_menu.choice - 2, 0)
	for index in range(first, mini(first + 5, labels.size())):
		var line := index - first
		var color := GOLD if index == deck_builder_menu.choice else PAPER
		_text(("> " if index == deck_builder_menu.choice else "  ") + labels[index], Vector2(66, 49 + line * 12), 7, color)

func _draw_deck_hub() -> void:
	_overlay_rect(Rect2(30, 23, 180, 116), Color(0.05, 0.07, 0.07, 0.94), Color("c5aa6d"))
	_text("DECK MANAGEMENT", Vector2(56, 31), 8, GOLD)
	var entries := ["PLAYER STATUS", "COLLECTION", "EDIT DECK"]
	for index in range(entries.size()):
		var color := GOLD if index == deck_management.choice else PAPER
		_text(("> " if index == deck_management.choice else "  ") + entries[index], Vector2(54, 56 + index * 21), 8, color)
	_text("DECK %02d / 40   COST %05d / %05d" % [deck.size(), deck_rules.deck_cost(card_database), progression.capacity], Vector2(31, 119), 6, PAPER)
	_text("ENTER SELECT   SPACE CHECK DECK", Vector2(34, 131), 6, PAPER)

func _draw_player_status() -> void:
	var status := deck_management.player_status(current_save)
	_overlay_rect(Rect2(18, 13, 204, 134), Color(0.05, 0.07, 0.07, 0.94), Color("c5aa6d"))
	_text("PLAYER STATUS", Vector2(72, 21), 8, GOLD)
	_text("NAME  %s" % str(status.get("name", "")), Vector2(32, 43), 7, PAPER)
	_text("DUELIST LEVEL  %04d" % int(status.get("duelist_level", 0)), Vector2(32, 61), 7, PAPER)
	_text("DECK CAPACITY  %05d" % int(status.get("deck_capacity", 0)), Vector2(32, 77), 7, PAPER)
	_text("RANK MARKS  %d" % int(status.get("rank_marks", 0)), Vector2(32, 93), 7, PAPER)
	_text("MONEY  %d" % int(status.get("money", 0)), Vector2(32, 109), 7, PAPER)
	_text("DECK CARDS  %02d / 40" % int(status.get("deck_count", 0)), Vector2(32, 125), 7, PAPER)
	_text("SPACE RETURN", Vector2(88, 137), 6, GOLD)

func _draw_miniature(card_id: int, at: Vector2) -> void:
	var definition := card_database.get_card(card_id)
	if definition == null:
		return
	var miniature := TextureRect.new()
	miniature.texture = load(definition.miniature_path)
	miniature.position = at
	miniature.size = Vector2(24, 24)
	miniature.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	miniature.stretch_mode = TextureRect.STRETCH_SCALE
	miniature.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(miniature)

func _overlay_rect(rect: Rect2, color: Color, border := Color.TRANSPARENT) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	panel.add_theme_stylebox_override("panel", style)
	screen_root.add_child(panel)

func _text(value: String, at: Vector2, size: int, color: Color) -> void:
	var label = PIXEL_TEXT_SCRIPT.new()
	label.position = at
	label.text = value
	label.font_color = color
	label.use_large_font = size > 8
	label.size = Vector2(value.length() * 8, 16 if size > 8 else 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(label)

func _button(caption: String, rect: Rect2, action: Callable) -> void:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = caption
	button.add_theme_font_size_override("font_size", 7)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.13, 0.11, 0.96)))
	button.add_theme_stylebox_override("hover", _button_style(Color("5a4d32")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("806738")))
	button.pressed.connect(action)
	screen_root.add_child(button)

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("d0b46f")
	style.set_border_width_all(1)
	style.set_content_margin_all(1)
	return style

func _click_area(rect: Rect2, action: Callable) -> void:
	var area := Button.new()
	area.position = rect.position
	area.size = rect.size
	area.flat = true
	area.modulate = Color(1, 1, 1, 0)
	area.pressed.connect(action)
	screen_root.add_child(area)

func _card_panel(rect: Rect2, card_id: int, highlight: bool, back := false, show_art := false) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("33291e") if not back else Color("47361c")
	style.border_color = GOLD if highlight else Color("d1ba7b")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	screen_root.add_child(panel)
	if show_art and not back:
		var art_texture := TextureRect.new()
		var definition := card_database.get_card(card_id)
		art_texture.texture = load(definition.art_path) if definition != null else null
		art_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(art_texture)
	elif not back:
		var art := ColorRect.new()
		art.position = Vector2(2, 2)
		art.size = Vector2(maxf(rect.size.x - 4, 1), maxf(rect.size.y * 0.63, 1))
		art.color = [Color("75614a"), Color("546a5d"), Color("765a42"), Color("6d6650")][card_id % 4]
		panel.add_child(art)

func _short_name(card_id: int) -> String:
	var name: String = _card_name(card_id)
	return name.left(7).to_upper()

func _visible_cards() -> Array:
	return deck if screen == "deck" and editing_deck else collection

func _set_deck_view(show_deck: bool) -> void:
	editing_deck = show_deck
	selected = clampi(selected, 0, maxi(_visible_cards().size() - 1, 0))
	_build_screen()

func _step_selection(step: int) -> void:
	if screen == "shop":
		shop_selected = shop_menu.move(step, _visible_shop_cards().size())
	elif screen == "deck":
		if editing_deck:
			selected = clampi(selected + step, 0, maxi(_visible_cards().size() - 1, 0))
		elif not _visible_cards().is_empty():
			selected = posmod(selected + step, _visible_cards().size())
	elif screen == "duel":
		selected = posmod(selected + step, maxi(deck.size(), 1))
	_build_screen()

func _select_shop_index(index: int) -> void:
	shop_selected = shop_menu.select(index, _visible_shop_cards().size())
	_build_screen()

func _visible_shop_cards() -> Array[int]:
	var source: Array[int] = collection if selling else stock
	if card_sorter == null or shop_menu == null:
		return source.duplicate()
	var card_method := shop_menu.sort_method()
	return card_sorter.sort_cards(source, card_method, shop_rules.collection, shop_rules.stock, shop_rules.collection, shop_rules.collection)

func _handle_shop_direction(direction: Vector2i) -> void:
	if shop_menu.popup != ShopMenuState.Popup.NONE:
		shop_menu.navigate_popup(direction)
		if audio_dispatch != null: audio_dispatch.play_game_audio(54)
	else:
		var count := _visible_shop_cards().size()
		var delta := direction.x if direction.x != 0 else direction.y * 7
		shop_selected = shop_menu.move(delta, count)
		if audio_dispatch != null: audio_dispatch.play_game_audio(54)
	_build_screen()

func _handle_shop_page(direction: int) -> void:
	if shop_menu.popup != ShopMenuState.Popup.NONE: return
	shop_selected = shop_menu.page(direction, _visible_shop_cards().size())
	if audio_dispatch != null: audio_dispatch.play_game_audio(54)
	_build_screen()

func _handle_shop_sort_cycle() -> void:
	if shop_menu.popup != ShopMenuState.Popup.NONE: return
	shop_menu.cycle_sort()
	shop_selected = shop_menu.select(shop_selected, _visible_shop_cards().size())
	if audio_dispatch != null: audio_dispatch.play_game_audio(55)
	_build_screen()

func _handle_shop_sort_open() -> void:
	shop_menu.open_sort()
	if audio_dispatch != null: audio_dispatch.play_game_audio(55)
	_build_screen()

func _handle_shop_escape() -> void:
	if shop_menu.popup != ShopMenuState.Popup.NONE:
		shop_menu.close_popup()
		if audio_dispatch != null: audio_dispatch.play_game_audio(56)
		_build_screen()
	else:
		if audio_dispatch != null: audio_dispatch.play_game_audio(56)
		if scene_shop_active:
			_leave_scene_shop()
		else:
			_show("title")

func _handle_shop_confirm() -> void:
	if _visible_shop_cards().is_empty(): return
	if shop_menu.popup == ShopMenuState.Popup.NONE:
		var current_id: int = _visible_shop_cards()[shop_menu.selected_index]
		if current_id in [0, 832, 833, 834]:
			if audio_dispatch != null: audio_dispatch.play_game_audio(57)
			return
	var result := shop_menu.confirm()
	var sound := int(result.get("sound", 0))
	if sound != 0 and audio_dispatch != null: audio_dispatch.play_game_audio(sound)
	match int(result.get("action", ShopMenuState.Action.NONE)):
		ShopMenuState.Action.BUY_OR_SELL:
			var card_id: int = _visible_shop_cards()[shop_menu.selected_index]
			if selling: _sell(card_id)
			else: _buy(card_id)
		ShopMenuState.Action.CARD_INFO:
			selected_card_detail_id = _visible_shop_cards()[shop_menu.selected_index]
			card_detail_return_screen = "shop"
			_show("card_detail")
		ShopMenuState.Action.SORT_SELECTED:
			shop_selected = shop_menu.select(shop_selected, _visible_shop_cards().size())
			_build_screen()
		ShopMenuState.Action.CANCEL, ShopMenuState.Action.SORT_CLOSED:
			_build_screen()

func _select_deck_card(index: int) -> void:
	selected = index
	_build_screen()

func _handle_deck_hub_buttons(buttons: int) -> void:
	if deck_management == null: return
	var result := deck_management.handle_buttons(buttons, deck, deck_rules.deck_cost(card_database), progression.capacity)
	for sound_id in result.get("sounds", []):
		if audio_dispatch != null: audio_dispatch.play_game_audio(int(sound_id))
	match int(result.get("action", DeckManagement.Action.NONE)):
		DeckManagement.Action.PLAYER_STATUS: _show("player_status")
		DeckManagement.Action.COLLECTION_EDITOR:
			editing_deck = false
			selected = 0
			_sort_deck_view(false, deck_builder_menu.collection_sort, false)
			_show("deck")
		DeckManagement.Action.DECK_EDITOR:
			editing_deck = true
			selected = 0
			_sort_deck_view(true, deck_builder_menu.deck_sort, false)
			_show("deck")
		DeckManagement.Action.EXIT: _leave_deck_hub()
		DeckManagement.Action.INVALID_DECK_SIZE: _toast("Your deck must contain exactly 40 cards.")
		DeckManagement.Action.INVALID_DECK_CAPACITY: _toast("Your deck cost exceeds your capacity.")
		DeckManagement.Action.EMPTY_DECK: _toast("Add cards to your deck before editing it.")
		_: _build_screen()

func _handle_deck_builder_key(key: int) -> void:
	if deck_builder_menu == null: return
	if deck_builder_menu.popup == DeckBuilderMenu.Popup.NONE and key in [0x140, 0x180]:
		_move_deck_selection(10 if editing_deck else 50, key == 0x180)
		return
	var result := deck_builder_menu.handle_key(key, editing_deck)
	var sound := int(result.get("sound", 0))
	if sound != 0 and audio_dispatch != null: audio_dispatch.play_game_audio(sound)
	match int(result.get("action", DeckBuilderMenu.Action.NONE)):
		DeckBuilderMenu.Action.EXIT:
			if in_deck_hub_flow: _show("deck_hub")
			else: _show("title")
		DeckBuilderMenu.Action.DESCRIBE: _describe_selected_deck_card()
		DeckBuilderMenu.Action.ADD_TO_DECK: _deck_transfer()
		DeckBuilderMenu.Action.REMOVE_FROM_DECK:
			if editing_deck: _deck_transfer()
			else: _remove_collection_selected_from_deck()
		DeckBuilderMenu.Action.SORT_COLLECTION: _sort_deck_view(false, int(result.get("method", 0)), bool(result.get("reset_selection", false)))
		DeckBuilderMenu.Action.SORT_DECK: _sort_deck_view(true, int(result.get("method", 0)), bool(result.get("reset_selection", false)))
		DeckBuilderMenu.Action.CYCLE_FILTER, DeckBuilderMenu.Action.NONE, DeckBuilderMenu.Action.OPENED, DeckBuilderMenu.Action.CLOSED: _build_screen()
		_: _build_screen()

func _move_deck_selection(amount: int, down: bool) -> void:
	var visible := _visible_cards()
	if visible.is_empty(): return
	if editing_deck:
		var last := visible.size() - 1
		if down:
			if selected == last:
				if audio_dispatch != null: audio_dispatch.play_game_audio(57)
				return
			selected = mini(selected + amount, last)
		else:
			if selected == 0:
				if audio_dispatch != null: audio_dispatch.play_game_audio(57)
				return
			selected = maxi(selected - amount, 0)
		if audio_dispatch != null: audio_dispatch.play_game_audio(54)
	else:
		selected = posmod(selected + (amount if down else -amount), visible.size())
		if audio_dispatch != null: audio_dispatch.play_game_audio(54)
	_build_screen()

func _sort_deck_view(deck_view: bool, method: int, reset_selection: bool) -> void:
	if deck_view:
		card_sorter.deck = deck.duplicate()
		deck = card_sorter.sort_cards(deck, 36 + method, shop_rules.collection, shop_rules.stock, {}, shop_rules.collection)
		deck_rules.deck = deck.duplicate()
	else:
		collection = card_sorter.sort_cards(collection, method, shop_rules.collection, shop_rules.stock, {}, shop_rules.collection)
	if reset_selection: selected = 0
	else: selected = clampi(selected, 0, maxi(_visible_cards().size() - 1, 0))
	_save_current_state()
	_build_screen()

func _remove_collection_selected_from_deck() -> void:
	if collection.is_empty(): return
	var card_id := collection[posmod(selected, collection.size())]
	_sync_deck_collection()
	if not deck_rules.remove_from_collection_view(card_id):
		if audio_dispatch != null: audio_dispatch.play_game_audio(57)
		_toast("That card is not in your deck.")
		return
	if audio_dispatch != null: audio_dispatch.play_game_audio(55)
	deck = deck_rules.deck.duplicate()
	_save_current_state()
	_build_screen()

func _describe_selected_deck_card() -> void:
	var visible := _visible_cards()
	if visible.is_empty(): return
	var card := card_database.get_card(visible[clampi(selected, 0, visible.size() - 1)])
	if card == null: return
	card_detail_return_screen = "deck"
	selected_card_detail_id = card.id
	_show("card_detail")

func _draw_card_detail() -> void:
	var card := card_database.get_card(selected_card_detail_id)
	if card == null:
		_text("CARD DATA UNAVAILABLE", Vector2(20, 70), 8, PAPER)
		return
	var presentation: CardPresentation = CARD_PRESENTATION_SCRIPT.new()
	presentation.present(card)
	screen_root.add_child(presentation)

func _card_detail_page(direction: int) -> void:
	for child in screen_root.get_children():
		if child is CardPresentation:
			if direction < 0: child.previous_page()
			else: child.next_page()
			return

func _enter_deck_hub() -> void:
	deck_hub_return_screen = screen
	in_deck_hub_flow = true
	deck_management.choice = 0
	if audio_dispatch != null:
		audio_dispatch.fade_game_music(1)
		audio_dispatch.play_game_audio(47)
	_show("deck_hub")

func _leave_deck_hub() -> void:
	in_deck_hub_flow = false
	_show(deck_hub_return_screen)

func _confirm() -> void:
	match screen:
		"title": _confirm_title()
		"duel": _duel_summon()
		"shop":
			_handle_shop_confirm()
		"deck": _deck_transfer()

func _confirm_title() -> void:
	var action: int = title_menu.request_confirm()
	if action == TITLE_MENU_SCRIPT.Action.CONFIRM_OVERWRITE:
		var prompt := ConfirmationDialog.new()
		prompt.dialog_text = "Start a new game and overwrite the current save?"
		prompt.confirmed.connect(_resolve_overwrite.bind(true))
		prompt.canceled.connect(_resolve_overwrite.bind(false))
		add_child(prompt)
		prompt.popup_centered()
		prompt.get_cancel_button().grab_focus()
		return
	if action == TITLE_MENU_SCRIPT.Action.START_NEW_GAME:
		_start_new_game()
	elif action == TITLE_MENU_SCRIPT.Action.CONTINUE_GAME:
		_show("duel")

func _request_password_entry() -> void:
	var entry_view: PasswordEntryView = PASSWORD_ENTRY_VIEW_SCRIPT.new()
	entry_view.submitted.connect(_submit_password.bind(entry_view))
	entry_view.canceled.connect(_cancel_password_entry.bind(entry_view))
	add_child(entry_view)

func _cancel_password_entry(entry_view: PasswordEntryView) -> void:
	entry_view.queue_free()
	if scene_password_entry_active:
		scene_password_entry_active = false
		scene_password_entry_finished.emit()

func _submit_password(password: String, entry_view: PasswordEntryView) -> void:
	var result: Dictionary = password_system.apply_password(password, current_save, progression)
	entry_view.queue_free()
	if scene_password_entry_active:
		scene_password_entry_active = false
		scene_password_entry_finished.emit()
	if not bool(result.get("found", false)):
		_toast("That password was not recognized.")
		return
	_apply_save_data(current_save)
	_save_current_state()
	match str(result.get("kind", "")):
		"card": _toast("Card %04d added to the shop." % int(result.get("id", 0)))
		"bonus":
			if bool(result.get("used", false)):
				_toast("That bonus password has already been used.")
			elif bool(result.get("applied", false)):
				_toast("Bonus applied.")
			else:
				_toast("Bonus password recorded.")

func _resolve_overwrite(confirmed: bool) -> void:
	title_menu.overwrite_choice = TITLE_MENU_SCRIPT.OverwriteChoice.CONFIRM if confirmed else TITLE_MENU_SCRIPT.OverwriteChoice.CANCEL
	if title_menu.resolve_overwrite() == TITLE_MENU_SCRIPT.Action.START_NEW_GAME:
		_start_new_game()

func _toggle_title_choice() -> void:
	title_menu.toggle_choice()
	title_choice = title_menu.choice
	_build_screen()

func _start_new_game() -> void:
	current_save = NEW_GAME_SCRIPT.initialize()
	_apply_save_data(current_save)
	title_has_save = true
	title_menu.initialize(true)
	title_choice = TITLE_MENU_SCRIPT.Choice.CONTINUE
	_save_current_state()
	_show("duel")

func _duel_summon() -> void:
	field_has_monster = true
	field_card_id = deck[posmod(selected, deck.size())] if not deck.is_empty() else 0
	selected = posmod(selected + 1, maxi(deck.size(), 1))
	_build_screen()

func _duel_attack() -> void:
	if field_has_monster:
		rival_lp = maxi(0, rival_lp - _card_attack(field_card_id))
	else:
		_toast("Summon a monster before attacking.")
	_build_screen()

func _duel_end() -> void:
	selected = posmod(selected + 1, maxi(deck.size(), 1))
	_build_screen()

func _shop_price(card_id: int) -> int:
	return shop_rules.buy_price(card_id)

func _sell_price(card_id: int) -> int:
	return shop_rules.sell_price(card_id)

func _buy(card_id: int) -> void:
	var price := _shop_price(card_id)
	if not wallet.can_afford(price):
		_toast("Not enough gold.")
		_build_screen()
		return
	if not shop_rules.buy(card_id, wallet):
		_toast("This card cannot be purchased.")
		_build_screen()
		return
	credits = wallet.gold
	if not collection.has(card_id):
		collection.append(card_id)
	if int(shop_rules.stock.get(card_id, 0)) == 0:
		stock.erase(card_id)
		shop_menu.close_popup()
	shop_selected = shop_menu.select(shop_selected, _visible_shop_cards().size())
	_save_current_state()
	_build_screen()

func _sell(card_id: int) -> void:
	var location := collection.find(card_id)
	if location < 0:
		_toast("You do not own this card.")
		return
	if not shop_rules.sell(card_id, wallet):
		return
	if int(shop_rules.collection.get(card_id, 0)) == 0:
		collection.remove_at(location)
	credits = wallet.gold
	if not stock.has(card_id):
		stock.append(card_id)
	shop_selected = shop_menu.select(shop_selected, _visible_shop_cards().size())
	_save_current_state()
	_build_screen()

func _deck_transfer() -> void:
	var source := deck if editing_deck else collection
	if source.is_empty(): return
	selected = clampi(selected, 0, source.size() - 1)
	var card_id: int = source[selected]
	_sync_deck_collection()
	deck_rules.selected_deck_index = selected
	if editing_deck:
		card_id = deck_rules.remove_selected_deck_card()
		if card_id == 0:
			if audio_dispatch != null: audio_dispatch.play_game_audio(57)
			return
		if audio_dispatch != null: audio_dispatch.play_game_audio(55)
		deck = deck_rules.deck.duplicate()
		if not collection.has(card_id):
			collection.append(card_id)
	else:
		var definition := card_database.get_card(card_id)
		if definition == null or not deck_rules.add_selected(card_id, definition.cost, progression.duelist_level):
			if audio_dispatch != null: audio_dispatch.play_game_audio(57)
			_toast("This card cannot be added at the current level or deck limit.")
			return
		if audio_dispatch != null: audio_dispatch.play_game_audio(55)
		deck = deck_rules.deck.duplicate()
		if int(deck_rules.collection.get(card_id, 0)) == 0:
			collection.remove_at(selected)
	selected = clampi(selected, 0, maxi(_visible_cards().size() - 1, 0))
	_save_current_state()
	_build_screen()

func _available_ids(counts: Array[int]) -> Array[int]:
	var card_ids: Array[int] = []
	for card_id in range(1, counts.size()):
		if counts[card_id] > 0:
			card_ids.append(card_id)
	return card_ids

func _nonzero_cards(cards: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for card_id in cards:
		if card_id > 0:
			result.append(card_id)
	return result

func _sync_deck_collection() -> void:
	if deck_rules == null:
		return
	deck_rules.deck = deck.duplicate()
	deck_rules.collection = shop_rules.collection

func _sync_shop_inventories() -> void:
	if shop_rules == null:
		return
	shop_rules.collection.clear()
	shop_rules.stock.clear()
	for card_id in range(1, current_save.collection_counts.size()):
		if current_save.collection_counts[card_id] > 0:
			shop_rules.collection[card_id] = current_save.collection_counts[card_id]
	for card_id in range(1, current_save.shop_stock.size()):
		if current_save.shop_stock[card_id] > 0:
			shop_rules.stock[card_id] = current_save.shop_stock[card_id]

func _apply_save_data(save_data: PlayerSaveData) -> void:
	collection = _available_ids(save_data.collection_counts)
	deck = _nonzero_cards(save_data.deck)
	stock = _available_ids(save_data.shop_stock)
	credits = save_data.money
	wallet.gold = credits
	progression.capacity = save_data.deck_capacity
	progression.duelist_level = save_data.duelist_level
	if scene_event_flags != null:
		scene_event_flags.load_bytes(save_data.event_flags)
	var progress_value: Variant = save_data.extensions.get("progress_rank", 0)
	scene_script_events.progress_rank = int(progress_value)
	deck_rules.deck = deck.duplicate()
	_sync_shop_inventories()
	_sync_deck_collection()
	player_lp = 8000
	rival_lp = 8000

func _save_current_state() -> void:
	if current_save == null:
		return
	current_save.collection_counts = _inventory_to_array(shop_rules.collection)
	current_save.shop_stock = _inventory_to_array(shop_rules.stock)
	current_save.deck = _fixed_deck(deck)
	current_save.money = wallet.gold
	current_save.deck_capacity = progression.capacity
	current_save.duelist_level = progression.duelist_level
	if scene_event_flags != null:
		current_save.event_flags = scene_event_flags.to_bytes()
	if scene_script_events != null:
		current_save.extensions["progress_rank"] = scene_script_events.progress_rank
	var result: Error = save_storage.save_game(current_save)
	if result != OK:
		push_error("Could not write the game save (error %d)." % result)
	title_has_save = true

func _inventory_to_array(inventory: Dictionary[int, int]) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(901)
	for card_id in inventory:
		if card_id > 0 and card_id < counts.size():
			counts[card_id] = int(inventory[card_id])
	return counts

func _fixed_deck(cards: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for index in range(40):
		result.append(cards[index] if index < cards.size() else 0)
	return result

func _toast(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
