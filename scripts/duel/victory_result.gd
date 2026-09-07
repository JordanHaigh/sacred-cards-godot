class_name VictoryResult
extends RefCounted

## Result returned by VictoryResolver when checking terminal conditions.

var success: bool = false
var terminal: bool = false
var winner_id: String = ""
var loser_id: String = ""
var reason: String = ""
var error: String = ""


func to_dictionary() -> Dictionary:
	return {
		"success": success,
		"terminal": terminal,
		"winner_id": winner_id,
		"loser_id": loser_id,
		"reason": reason,
		"error": error,
	}
