class_name DuelCardView
extends Node3D

## A small, readable 3D card face for the duel board. It renders only card data;
## CardInstance and DuelState remain the source of truth.

const CARD_WIDTH := 1.34
const CARD_LENGTH := 1.82

var _card_body: MeshInstance3D
var _face_panel: MeshInstance3D
var _art_panel: MeshInstance3D
var _art_texture_panel: MeshInstance3D
var _title_label: Label3D
var _type_label: Label3D
var _description_label: Label3D
var _stats_label: Label3D
var _sigil_label: Label3D


func _ready() -> void:
	_build_card_face()


func set_card(card: Object, card_database: Object) -> void:
	if not is_node_ready():
		await ready
	var definition = card.call("resolve_definition", card_database) if card != null else null
	if card == null:
		visible = false
		return
	visible = true
	if String(card.get("face_state")) == "face_down":
		_show_card_back()
		return
	_show_card_front(definition, card)


func _build_card_face() -> void:
	_card_body = _add_box("Card Frame", Vector3(CARD_WIDTH + 0.12, 0.08, CARD_LENGTH + 0.12), Vector3.ZERO, _material(Color("#181c1b"), 0.55, 0.28))
	_face_panel = _add_box("Card Parchment", Vector3(CARD_WIDTH, 0.014, CARD_LENGTH), Vector3(0.0, 0.048, 0.0), _material(Color("#d6c79e"), 0.88))
	_add_box("Top Nameplate", Vector3(CARD_WIDTH - 0.12, 0.014, 0.22), Vector3(0.0, 0.06, -0.75), _material(Color("#343b32"), 0.68, 0.12))
	_art_panel = _add_box("Illustration Window", Vector3(0.98, 0.014, 0.78), Vector3(0.0, 0.065, -0.16), _material(Color("#52634c"), 0.7))
	var art_plane := PlaneMesh.new()
	art_plane.size = Vector2(0.94, 0.74)
	_art_texture_panel = MeshInstance3D.new()
	_art_texture_panel.name = "Card Illustration"
	_art_texture_panel.mesh = art_plane
	_art_texture_panel.position = Vector3(0.0, 0.073, -0.16)
	_art_texture_panel.rotation_degrees.x = -90.0
	add_child(_art_texture_panel)
	_add_box("Description Inlay", Vector3(CARD_WIDTH - 0.16, 0.012, 0.48), Vector3(0.0, 0.064, 0.47), _material(Color("#c4b78f"), 0.95))
	_add_box("Card Footplate", Vector3(CARD_WIDTH - 0.12, 0.018, 0.2), Vector3(0.0, 0.066, 0.78), _material(Color("#343b32"), 0.68, 0.12))
	_add_frame_rails()
	_title_label = _make_label("", Vector3(0.0, 0.074, -0.75), 21, 0.0034, Color("#f1e8ca"))
	_type_label = _make_label("", Vector3(0.0, 0.074, -0.6), 15, 0.003, Color("#ead69a"))
	_sigil_label = _make_label("✦", Vector3(0.0, 0.079, -0.17), 52, 0.0036, Color("#ebd497"))
	_description_label = _make_label("", Vector3(0.0, 0.074, 0.47), 13, 0.0028, Color("#252a24"))
	_stats_label = _make_label("", Vector3(0.0, 0.08, 0.78), 17, 0.003, Color("#f2d488"))
	_show_card_back()


func _add_frame_rails() -> void:
	var gold := _material(Color("#a38b57"), 0.48, 0.52)
	for side in [-1.0, 1.0]:
		_add_box("Card Frame Rail", Vector3(0.035, 0.012, CARD_LENGTH - 0.08), Vector3(side * (CARD_WIDTH * 0.5 - 0.025), 0.056, 0.0), gold)
		_add_box("Card Frame Rail", Vector3(CARD_WIDTH - 0.08, 0.012, 0.035), Vector3(0.0, 0.056, side * (CARD_LENGTH * 0.5 - 0.025)), gold)


func _show_card_front(definition: Object, card: Object) -> void:
	if definition == null:
		_title_label.text = "Unknown Card"
		_type_label.text = "CARD DATA UNAVAILABLE"
		_description_label.text = ""
		_stats_label.text = ""
		return
	var card_type := String(definition.get("card_type"))
	var accent := _type_color(card_type)
	var illustration: Texture2D = definition.call("load_illustration")
	_title_label.text = _shorten(String(definition.get("display_name")), 16)
	_type_label.text = _metadata_line(definition, card_type)
	_description_label.text = _wrap_description(String(definition.get("description")), 33, 3)
	_stats_label.text = "ATK %d   ·   DEF %d" % [int(card.get("current_attack")), int(card.get("current_defense"))] if card_type == "Monster" else card_type.to_upper()
	_sigil_label.text = _sigil_for_type(card_type)
	var art_material := _material(accent.darkened(0.46), 0.56, 0.22)
	art_material.emission_enabled = true
	art_material.emission = accent.darkened(0.72)
	_art_panel.material_override = art_material
	_art_texture_panel.visible = illustration != null
	if illustration != null:
		var image_material := StandardMaterial3D.new()
		image_material.albedo_texture = illustration
		image_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image_material.roughness = 0.86
		_art_texture_panel.material_override = image_material
	_sigil_label.visible = illustration == null
	_title_label.modulate = Color("#f1e8ca")
	_type_label.modulate = accent.lightened(0.2)
	_sigil_label.modulate = accent.lightened(0.34)
	_description_label.visible = true
	_stats_label.visible = true
	_face_panel.material_override = _material(Color("#d6c79e"), 0.88)
	_card_body.material_override = _material(Color("#181c1b"), 0.55, 0.28)


func _show_card_back() -> void:
	_title_label.text = "SACRED CARDS"
	_type_label.text = "SEALED"
	_description_label.text = ""
	_stats_label.text = ""
	_sigil_label.text = "✧"
	_sigil_label.visible = true
	_art_texture_panel.visible = false
	_sigil_label.modulate = Color("#e0cb82")
	_art_panel.material_override = _material(Color("#243a35"), 0.35, 0.35)
	_face_panel.material_override = _material(Color("#263a35"), 0.44, 0.25)
	_card_body.material_override = _material(Color("#141b19"), 0.42, 0.3)
	_description_label.visible = false
	_stats_label.visible = false


func _metadata_line(definition: Object, card_type: String) -> String:
	if card_type != "Monster":
		return card_type.to_upper()
	var alignment_value: Variant = definition.get("alignment")
	var family_value: Variant = definition.get("monster_type")
	var parts := PackedStringArray()
	if family_value != null and not String(family_value).is_empty():
		parts.append(String(family_value))
	if alignment_value != null and not String(alignment_value).is_empty():
		parts.append(String(alignment_value))
	parts.append("LV %d" % int(definition.get("level")))
	return "  ·  ".join(parts)


func _wrap_description(text: String, line_width: int, max_lines: int) -> String:
	var words := text.replace("\n", " ").split(" ", false)
	var lines := PackedStringArray()
	var current_line := ""
	for word in words:
		var candidate := word if current_line.is_empty() else current_line + " " + word
		if candidate.length() > line_width and not current_line.is_empty():
			lines.append(current_line)
			current_line = word
		else:
			current_line = candidate
		if lines.size() == max_lines:
			break
	if lines.size() < max_lines and not current_line.is_empty():
		lines.append(current_line)
	var result := "\n".join(lines)
	if result.length() < text.replace("\n", " ").length():
		result = result.trim_suffix(".") + "…"
	return result


func _shorten(text: String, max_length: int) -> String:
	return text if text.length() <= max_length else text.substr(0, max_length - 1) + "…"


func _sigil_for_type(card_type: String) -> String:
	match card_type:
		"Magic":
			return "✧"
		"Trap":
			return "◈"
		"Ritual":
			return "✥"
		_:
			return "✦"


func _type_color(card_type: String) -> Color:
	match card_type:
		"Magic":
			return Color("#83c4a2")
		"Trap":
			return Color("#d595a7")
		"Ritual":
			return Color("#b8a0de")
		_:
			return Color("#d0b66b")


func _make_label(text: String, position: Vector3, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color("#101411")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.rotation_degrees.x = -90.0
	label.no_depth_test = true
	add_child(label)
	return label


func _add_box(label: String, dimensions: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	add_child(instance)
	return instance


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
