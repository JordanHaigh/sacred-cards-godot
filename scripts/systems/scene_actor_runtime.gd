extends Node2D
class_name SceneActorRuntime

## Godot scene-actor command adapter for script_actors.c.
signal actor_frame_changed(actor_id: int, sprite_id: int, frame_index: int)
signal dialogue_hide_requested
signal scene_faded_to_dark

const DIRECTION_X := [0, -1, 0, 1]
const DIRECTION_Y := [1, 0, -1, 0]
const STEP_TIME := 2.0 / 60.0
const ACTOR_SHADOW_TEXTURE := preload("res://art/scenes/actor-shadow.png")

var animation_database: ActorAnimationDatabase
var scene_grid: SceneGrid
var actors: Dictionary[int, SceneActor] = {}
var actor_nodes: Dictionary[int, Node2D] = {}
var actor_sprites: Dictionary[int, Sprite2D] = {}
var shadow_sprites: Dictionary[int, Sprite2D] = {}
var _fade_layer: CanvasLayer
var _fade_overlay: ColorRect

func load_scene(configuration: SceneConfiguration, graphics: ActorAnimationDatabase, grid: SceneGrid = null) -> void:
	for child in get_children():
		child.queue_free()
	actors.clear()
	actor_nodes.clear()
	actor_sprites.clear()
	shadow_sprites.clear()
	animation_database = graphics
	scene_grid = grid
	if configuration == null or animation_database == null:
		return
	for actor in configuration.actors:
		_update_actor_height(actor)
		add_actor(actor)

func add_actor(actor: SceneActor) -> bool:
	if actor == null or actor.actor_id < 0 or animation_database == null:
		return false
	var node := Node2D.new()
	node.position = Vector2(actor.position)
	var shadow := Sprite2D.new()
	shadow.texture = ACTOR_SHADOW_TEXTURE
	shadow.position = Vector2(8, 24)
	shadow.centered = false
	shadow.z_index = -1
	shadow.visible = false
	node.add_child(shadow)
	var sprite := Sprite2D.new()
	node.add_child(sprite)
	add_child(node)
	actors[actor.actor_id] = actor
	actor_nodes[actor.actor_id] = node
	actor_sprites[actor.actor_id] = sprite
	shadow_sprites[actor.actor_id] = shadow
	_refresh_actor(actor.actor_id)
	return true

func move_actor(actor_id: int, direction: int, step_count: int, keep_flag: int = 0) -> void:
	var actor := _actor(actor_id)
	if actor == null or direction < 0 or direction >= 4:
		return
	dialogue_hide_requested.emit()
	actor.orientation = direction
	for _step in range(maxi(step_count, 0)):
		actor.position.x += DIRECTION_X[direction]
		actor.position.y += DIRECTION_Y[direction]
		_update_actor_height(actor)
		_advance_walking_phase(actor)
		_refresh_actor(actor_id)
		actor_frame_changed.emit(actor_id, actor.sprite_id, _frame_index(actor))
		await get_tree().create_timer(STEP_TIME).timeout
	actor.flags &= 0xFB
	if keep_flag == 1:
		actor.flags |= 4
	actor.animation_state = 19
	_refresh_actor(actor_id)
	actor_frame_changed.emit(actor_id, actor.sprite_id, _frame_index(actor))
	await get_tree().create_timer(1.0 / 60.0).timeout

func place_actor(actor_id: int, x: int, y: int, frame: int) -> void:
	var actor := _actor(actor_id)
	if actor == null:
		return
	actor.position = Vector2i(x, y)
	_update_actor_height(actor)
	actor.flags &= 0xFB
	var sprite := actor_sprites.get(actor_id) as Sprite2D
	var frame_index := actor.orientation * 3 + frame
	if sprite != null:
		sprite.texture = animation_database.get_frame_texture(actor.sprite_id, frame_index, actor.palette_index)
		_refresh_actor(actor_id)
		sprite.texture = animation_database.get_frame_texture(actor.sprite_id, frame_index, actor.palette_index)
	actor_frame_changed.emit(actor_id, actor.sprite_id, frame_index)
	await get_tree().create_timer(1.0 / 60.0).timeout

func position_actor(actor_id: int, x: int, y: int) -> void:
	var actor := _actor(actor_id)
	if actor == null:
		return
	dialogue_hide_requested.emit()
	actor.position = Vector2i(x, y)
	_update_actor_height(actor)
	_refresh_actor(actor_id)
	actor_frame_changed.emit(actor_id, actor.sprite_id, _frame_index(actor))
	await get_tree().create_timer(1.0 / 60.0).timeout

func set_actor_orientation(actor_id: int, orientation: int) -> void:
	var actor := _actor(actor_id)
	if actor == null:
		return
	actor.orientation = orientation

func pose_four(actor_id: int) -> void:
	var actor := _actor(actor_id)
	if actor == null:
		return
	dialogue_hide_requested.emit()
	actor.flags &= 0xF8
	actor.orientation = 4
	actor.animation_state = 0
	_refresh_actor(actor_id)
	actor_frame_changed.emit(actor_id, actor.sprite_id, _frame_index(actor))
	await get_tree().create_timer(1.0 / 60.0).timeout

func fade_to_dark(delay_frames: int) -> void:
	if _fade_layer == null:
		_fade_layer = CanvasLayer.new()
		_fade_overlay = ColorRect.new()
		_fade_overlay.color = Color(0, 0, 0, 0)
		_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_layer.add_child(_fade_overlay)
		add_child(_fade_layer)
	for level in range(16):
		_fade_overlay.color.a = float(level) / 16.0
		if delay_frames > 0:
			await get_tree().create_timer(float(delay_frames) / 60.0).timeout
	scene_faded_to_dark.emit()

func change_sprite(actor_id: int, sprite_id: int) -> void:
	var actor := _actor(actor_id)
	if actor == null:
		return
	dialogue_hide_requested.emit()
	actor.sprite_id = sprite_id
	actor.palette_index = (actor.flags & 0x1F) >> 3
	_refresh_actor(actor_id)
	actor_frame_changed.emit(actor_id, actor.sprite_id, _frame_index(actor))
	await get_tree().create_timer(1.0 / 60.0).timeout

func move_actor_to_x(actor_id: int, x: int) -> void:
	var actor := _actor(actor_id)
	if actor == null:
		return
	var delta := x - actor.position.x
	await move_actor(actor_id, 3 if delta >= 0 else 1, absi(delta), 0)

func move_actor_to_y(actor_id: int, y: int) -> void:
	var actor := _actor(actor_id)
	if actor == null:
		return
	var delta := y - actor.position.y
	await move_actor(actor_id, 0 if delta >= 0 else 2, absi(delta), 0)

func actor(actor_id: int) -> SceneActor:
	return _actor(actor_id)

func _actor(actor_id: int) -> SceneActor:
	return actors.get(actor_id) as SceneActor

func _advance_walking_phase(actor: SceneActor) -> void:
	if actor.animation_state > 20 or actor.animation_state == 0:
		actor.animation_state = 20
	actor.animation_state -= 1

func _frame_index(actor: SceneActor) -> int:
	return animation_database.walking_frame_index(actor.orientation, actor.animation_state) if actor.orientation < 4 else animation_database.special_frame_index(actor.orientation)

func _refresh_actor(actor_id: int) -> void:
	var actor := _actor(actor_id)
	if actor == null or not actor_nodes.has(actor_id):
		return
	var node: Node2D = actor_nodes[actor_id]
	var sprite: Sprite2D = actor_sprites[actor_id]
	var shadow: Sprite2D = shadow_sprites[actor_id]
	node.position = Vector2(actor.position.x * 2 - 16, actor.position.y * 2 - actor.height_offset - 24)
	node.z_index = _actor_priority(actor)
	sprite.centered = false
	sprite.texture = animation_database.get_frame_texture(actor.sprite_id, _frame_index(actor), actor.palette_index)
	sprite.visible = actor.sprite_id >= 0 and actor.position.y > -32 and actor.position.y < 104 and actor.position.x > -16 and actor.position.x < 136
	shadow.visible = sprite.visible and (actor.flags & 1) != 0

func set_scene_grid(grid: SceneGrid) -> void:
	scene_grid = grid
	for actor: SceneActor in actors.values():
		_update_actor_height(actor)
		_refresh_actor(actor.actor_id)

func _update_actor_height(actor: SceneActor) -> void:
	if actor == null:
		return
	actor.height_offset = 0
	if scene_grid == null:
		return
	var x := actor.position.x
	var y := actor.position.y
	if x > 0 and x <= 119 and y > 0 and y <= 79:
		var cell := scene_grid.cell_at(x, y)
		if (cell & 0xFE00) == 0:
			actor.height_offset = (cell & 255) >> 1

func _actor_priority(actor: SceneActor) -> int:
	return actor.position.y
