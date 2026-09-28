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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
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
	scene_script_runtime.text_requested.connect(func(text: String, language: int, position: int) -> void: scene_script_text.emit(text, language, position))
	scene_script_events.scene_change_requested.connect(func(id: int, variant: int, spawn: int, _rules: bool) -> void:
		scene_script_runtime.stop()
		audio_dispatch.play_scene_music(id, variant)
		scene_script_scene_change.emit(id, variant, spawn)
	)
	scene_script_events.service_requested.connect(_on_scene_script_service_requested)
	scene_script_events.actor_motion_requested.connect(func(event_id: int, actors: Array, choreography: StringName) -> void: scene_script_motion_requested.emit(event_id, actors, choreography))
	scene_script_events.actor_motion_path_requested.connect(func(event_id: int, descriptor: Dictionary, x_steps: Array[int], y_steps: Array[int]) -> void: scene_script_motion_path.emit(event_id, descriptor, x_steps, y_steps))
	scene_script_events.actor_state_requested.connect(func(actor_id: int, changes: Dictionary) -> void: scene_script_actor_state.emit(actor_id, changes))
	scene_script_runtime.script_error.connect(func(message: String) -> void: push_warning(message))
	_apply_save_data(current_save)
	title_choice = 1 if title_has_save else 0
	_build_screen()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if scene_script_runtime != null and scene_script_runtime.running:
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
	var context := initial_context.duplicate()
	context["event"] = func(event_id: int, _runtime: SceneScriptRuntime) -> void: scene_script_events.dispatch(event_id, scene_script_runtime.state)
	context["condition"] = func(condition_id: int, _runtime: SceneScriptRuntime) -> int:
		if condition_id == 0: return 1 if progression.duelist_level < 80 else 0
		if condition_id == 1: return 1 if _bit_count(scene_script_events.progress_rank & 0x3F) == 6 else 0
		return 0
	context["dialogue_visibility"] = func(visible: bool) -> void: scene_script_service_requested.emit(&"dialogue_visibility", {"visible": visible})
	context["dialogue"] = func(operation: StringName, data: Dictionary, _runtime: SceneScriptRuntime) -> void: scene_script_service_requested.emit(&"dialogue", {"operation": operation, "data": data})
	context["actor"] = func(command: StringName, operands: Array, _runtime: SceneScriptRuntime) -> void: scene_script_service_requested.emit(&"actor_command", {"command": command, "operands": operands})
	context["audio"] = func(audio_id: int) -> void:
		audio_dispatch.play_game_audio(audio_id)
		scene_script_service_requested.emit(&"audio", {"audio_id": audio_id})
	context["music_fade"] = func(frames: int) -> void: audio_dispatch.fade_game_music(frames)
	context["effect_music_stop"] = func() -> void: audio_dispatch.stop_effect_music_player()
	context["save"] = func() -> void: scene_script_service_requested.emit(&"save", {})
	context["duel"] = func(opponent_id: int) -> int:
		scene_script_service_requested.emit(&"duel", {"opponent_id": opponent_id})
		return 0
	context["collection_card"] = func(card_id: int, count: int) -> void: scene_script_service_requested.emit(&"collection_card", {"card_id": card_id, "count": count})
	return scene_script_runtime.start(root_id, context)

func _on_scene_script_service_requested(service: StringName, data: Dictionary) -> void:
	if service == &"door_transition":
		audio_dispatch.fade_game_music(int(data.get("music_fade_frames", 0)))
		audio_dispatch.play_game_audio(int(data.get("audio_id", 0)))
	scene_script_service_requested.emit(service, data)

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
	for child in get_children():
		if child == scene_script_runtime or child == audio_dispatch:
			continue
		child.queue_free()
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)
	var texture := TextureRect.new()
	texture.texture = load(_background_for_screen())
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	screen_root.add_child(texture)
	match screen:
		"title": _draw_title()
		"duel": _draw_duel()
		"shop": _draw_shop()
		"deck": _draw_deck()
		"deck_hub": _draw_deck_hub()
		"player_status": _draw_player_status()
		"card_detail": _draw_card_detail()

func _background_for_screen() -> String:
	match screen:
		"title": return ART + "title-background.png"
		"duel": return duel_graphics.current_texture_path() if duel_graphics != null else ART + "duel-field.png"
		"shop": return ART + "shop-backdrop.png"
		"deck": return ART + ("deck-backdrop.png" if editing_deck else "collection-backdrop.png")
		"deck_hub", "player_status": return ART + "deck-backdrop.png"
	return ART + "title-background.png"

func set_duel_terrain(terrain: int, view: int) -> bool:
	var selection: Dictionary = duel_graphics.select(terrain, view)
	if not bool(selection.get("ok", false)):
		push_warning("Could not select duel terrain: %s" % selection.get("error", "unknown error"))
		return false
	if screen == "duel":
		_build_screen()
	return true

func _draw_title() -> void:
	# The backdrop is the recovered title layer; native choices sit directly over it.
	if title_has_save:
		_text("CONTINUE", Vector2(90, 126), 8, GOLD if title_menu.choice == TITLE_MENU_SCRIPT.Choice.CONTINUE else PAPER)
		_text("NEW GAME", Vector2(90, 137), 8, GOLD if title_menu.choice == TITLE_MENU_SCRIPT.Choice.NEW_GAME else PAPER)
	else:
		_text("NEW GAME", Vector2(90, 132), 8, GOLD)
	_click_area(Rect2(76, 122, 88, 34), _confirm_title)

func _draw_duel() -> void:
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
	entry_view.canceled.connect(entry_view.queue_free)
	add_child(entry_view)

func _submit_password(password: String, entry_view: PasswordEntryView) -> void:
	var result: Dictionary = password_system.apply_password(password, current_save, progression)
	entry_view.queue_free()
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
