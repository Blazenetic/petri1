extends Node
const LogDefs = preload("res://scripts/systems/Log.gd")
var _log

var total_entities: int = 0
var time_elapsed: float = 0.0

func _process(delta: float) -> void:
	time_elapsed += delta

func _ready() -> void:
	_log = get_node_or_null("/root/Log")
	if _log != null:
		_log.debug(LogDefs.CAT_SYSTEMS, ["[WorldState] ready"])
	else:
		print("[WorldState] ready")