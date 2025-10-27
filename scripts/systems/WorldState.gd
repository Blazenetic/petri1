extends Node

var total_entities: int = 0
var time_elapsed: float = 0.0

func _process(delta: float) -> void:
	time_elapsed += delta

func _ready() -> void:
	print("[WorldState] ready")