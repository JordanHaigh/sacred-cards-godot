class_name DeckBuilderGraphics
extends RefCounted
## Display model recovered from deck_builder_graphics.c.
## Tile IDs, OAM entries and VRAM pointers become card records and UI values.

## Mode 0 draws fixed row-specific tile art; card level is drawn with the row.
const DETAIL_DEFAULT_ART := 0
const DETAIL_ATTACK_DEFENSE := 1
const DETAIL_ATTRIBUTE_TYPE := 2
const DETAIL_COST := 3
const SCROLLBAR_TRAVEL := 124

func detail_text(card: CardDefinition, mode: int) -> String:
	if card == null:
		return ""
	match mode:
		DETAIL_ATTACK_DEFENSE:
			return "ATK %04d  DEF %04d" % [card.attack, card.defense]
		DETAIL_ATTRIBUTE_TYPE:
			return "ATTRIBUTE %02d  TYPE %02d" % [card.attribute, card.card_type]
		DETAIL_COST:
			return "COST %05d" % card.cost
		_:
			return ""

func scrollbar_offset(position: int, card_count: int) -> int:
	var limit := maxi(card_count - 1, 0)
	if limit == 0 or position < 0 or position > limit:
		return 0
	return floori(float(position * SCROLLBAR_TRAVEL) / float(limit))

## Ordered high-level work represented by each recovered graphics stage.
func stage_operations(stage: int) -> Array[StringName]:
	match stage:
		0:
			return [&"initialize_sprites"]
		2:
			return [&"initialize_layout", &"draw_cards", &"draw_details", &"draw_sort_icon", &"initialize_sprites"]
		3:
			return [&"draw_cards", &"draw_details", &"initialize_sprites"]
		4:
			return [&"draw_details", &"initialize_sprites"]
		5:
			return [&"initialize_sprites"]
		6, 7:
			return [&"draw_cards", &"draw_details", &"draw_sort_icon", &"initialize_sprites"]
	return []
