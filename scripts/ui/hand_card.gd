extends Button

## One selectable card in the hand. The duel screen owns card rules.

signal card_selected(card_id: int, instance_id: int)
signal card_hovered(card_id: int, source: Control)
signal card_unhovered(source: Control)

@onready var _name: Label = $Content/Column/Header/Name
@onready var _alignment: Label = $Content/Column/Header/Alignment
@onready var _stars: Label = $Content/Column/Stars
@onready var _art_frame: Panel = $Content/Column/ArtFrame
@onready var _art: TextureRect = $Content/Column/ArtFrame/Art
@onready var _art_fallback: Label = $Content/Column/ArtFrame/ArtFallback
@onready var _type: Label = $Content/Column/Type
@onready var _effect: Label = $Content/Column/Effect
@onready var _stats: Label = $Content/Column/Stats

var _card_id: int = -1
var _instance_id: int = 0


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func show_card(definition: Object, instance_id: int, selected: bool) -> void:
	if definition == null:
		push_error("HandCard needs a card definition")
		return
	_card_id = int(definition.get("card_id"))
	_instance_id = instance_id
	var card_type := String(definition.get("card_type"))
	_name.text = String(definition.get("display_name"))
	var alignment_value: Variant = definition.get("alignment")
	_alignment.text = String(alignment_value).to_upper() if alignment_value != null else card_type.to_upper()
	_stars.visible = card_type == "Monster"
	_stars.text = "★".repeat(clampi(int(definition.get("level")), 0, 12)) if card_type == "Monster" else ""
	_type.text = _type_line(definition, card_type)
	_effect.text = String(definition.get("description")).replace("\n", " ").strip_edges()
	_stats.text = "ATK/%d  DEF/%d" % [int(definition.get("attack")), int(definition.get("defense"))] if card_type == "Monster" else ""
	_stats.visible = card_type == "Monster"
	var illustration: Texture2D = definition.call("load_illustration")
	_art.texture = illustration
	_art_fallback.visible = illustration == null
	button_pressed = selected
	var accent := _card_accent(card_type)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("#29292b")
	art_style.border_color = Color("#3f3028")
	art_style.set_border_width_all(3)
	_art_frame.add_theme_stylebox_override("panel", art_style)
	add_theme_stylebox_override("normal", _card_style(accent, false))
	add_theme_stylebox_override("hover", _card_style(accent, true))
	add_theme_stylebox_override("pressed", _card_style(accent, true))
	add_theme_stylebox_override("hover_pressed", _card_style(accent, true))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _type_line(definition: Object, card_type: String) -> String:
	if card_type != "Monster":
		return "[%s CARD]" % card_type.to_upper()
	var family_value: Variant = definition.get("monster_type")
	var subtype_value: Variant = definition.get("monster_subtype")
	var family := String(family_value).to_upper() if family_value != null else "MONSTER"
	var subtype := String(subtype_value).to_upper() if subtype_value != null else ""
	return "[%s / %s]" % [family, subtype] if not subtype.is_empty() else "[%s]" % family


func _on_pressed() -> void:
	card_selected.emit(_card_id, _instance_id)


func _on_mouse_entered() -> void:
	card_hovered.emit(_card_id, self)


func _on_mouse_exited() -> void:
	card_unhovered.emit(self)


func _card_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent.lightened(0.24) if highlighted else accent.lightened(0.12)
	style.border_color = Color("#ffe7aa") if highlighted else accent.darkened(0.34)
	style.set_border_width_all(4 if highlighted else 3)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 7
	return style


func _card_accent(card_type: String) -> Color:
	match card_type:
		"Magic":
			return Color("#4f937d")
		"Trap":
			return Color("#9a6987")
		"Ritual":
			return Color("#7085a8")
		_:
			return Color("#b7835b")
