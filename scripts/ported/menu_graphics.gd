class_name MenuGraphics
extends RefCounted
## Godot scene-tree replacement for menu_graphics.c's buffer clears and DMA
## uploads. Menu Controls own their content and the renderer redraws it.

signal menu_graphics_cleared(revision: int)
signal menu_graphics_uploaded(revision: int)

var revision := 0

func begin_screen(parent: Node, previous_layer: Control, persistent_children: Array, background_path: String) -> Control:
	for child in parent.get_children():
		if persistent_children.has(child):
			continue
		parent.remove_child(child)
		child.queue_free()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(root)
	var background := TextureRect.new()
	background.texture = load(background_path) as Texture2D if ResourceLoader.exists(background_path) else null
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(background)
	if previous_layer != null and previous_layer.get_parent() == parent:
		parent.remove_child(previous_layer)
		previous_layer.queue_free()
	revision += 1
	menu_graphics_cleared.emit(revision)
	return root

func upload_menu_graphics(root: CanvasItem) -> void:
	if root == null: return
	_redraw_tree(root)
	revision += 1
	menu_graphics_uploaded.emit(revision)

func _redraw_tree(item: CanvasItem) -> void:
	item.queue_redraw()
	if item is Node:
		for child in item.get_children():
			if child is CanvasItem:
				_redraw_tree(child)
