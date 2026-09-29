extends RefCounted
class_name DuelMessageCatalog

## Pointer-free GDScript view of duel_flow.c's indexed text messages.
const RESOURCE_PATH := "res://resources/duel_messages.json"

var messages: Dictionary[int, Dictionary] = {}
var load_error := ""

func load_default() -> bool:
	var file := FileAccess.open(RESOURCE_PATH, FileAccess.READ)
	if file == null:
		load_error = "Unable to open duel message catalog: %s" % RESOURCE_PATH
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("messages", {}) is Dictionary:
		load_error = "Duel message catalog has an invalid structure."
		return false
	messages.clear()
	for raw_id: Variant in parsed.messages:
		var raw_languages: Variant = parsed.messages[raw_id]
		if raw_languages is Dictionary:
			var languages: Dictionary = {}
			for language_id: Variant in raw_languages:
				languages[int(language_id)] = String(raw_languages[language_id])
			messages[int(raw_id)] = languages
	load_error = ""
	return messages.size() == 23

func get_message(message_id: int, language_id: int = 0) -> String:
	var variants: Dictionary = messages.get(message_id, {})
	if variants.is_empty():
		return ""
	var selected_language := clampi(language_id, 0, 5)
	return String(variants.get(selected_language, variants.get(0, "")))
