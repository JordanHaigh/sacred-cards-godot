extends Node3D

## Small standalone viewer for the locally exported M13144 attack animation.

const ANIMATION_NAME := "M13144_c"

@onready var preview_camera: Camera3D = $Camera3D
@onready var model_root: Node3D = $Model/ImportedM13144
@onready var status_label: Label = $Overlay/Status


func _ready() -> void:
	preview_camera.look_at(Vector3(0.0, 3.0, 0.0))
	var animation_player := model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		status_label.text = "AnimationPlayer was not created from the GLB import."
		push_error("M13144 preview GLB has no AnimationPlayer")
		return
	if not animation_player.has_animation(ANIMATION_NAME):
		status_label.text = "Imported clip not found: %s" % ANIMATION_NAME
		push_error("M13144 preview could not find animation '%s'" % ANIMATION_NAME)
		return
	var attack_animation := animation_player.get_animation(ANIMATION_NAME)
	attack_animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(ANIMATION_NAME)
