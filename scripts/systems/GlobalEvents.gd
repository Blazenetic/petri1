extends Node
signal simulation_started
signal simulation_paused
signal simulation_resumed
signal entity_spawned(entity_id: StringName, entity_type: int, position: Vector2)
signal entity_destroyed(entity_id: StringName, entity_type: int, reason: StringName)

func _ready():
	print("[GlobalEvents] ready")