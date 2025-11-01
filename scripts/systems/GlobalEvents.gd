extends Node
const LogDefs = preload("res://scripts/systems/Log.gd")
var _log
@export var debug_echo_lifecycle: bool = true

signal simulation_started
signal simulation_paused
signal simulation_resumed
signal entity_spawned(entity_id: StringName, entity_type: int, position: Vector2)
signal entity_destroyed(entity_id: StringName, entity_type: int, reason: StringName)
signal nutrient_spawned(entity_id: StringName, position: Vector2, energy: float)
signal nutrient_consumed(entity_id: StringName, consumer_id: StringName)

# Phase 2.2b lifecycle events
signal bacteria_reproduction_started(entity_id: StringName)
signal bacteria_reproduction_completed(parent_id: StringName, child_id: StringName)
signal entity_died(entity_id: StringName, entity_type: int, cause: StringName)

func _ready():
	_log = get_node_or_null("/root/Log")
	if _log != null:
		_log.debug(LogDefs.CAT_EVENTS, ["[GlobalEvents] ready"])
	else:
		# Fallback if Log autoload not yet available
		print("[GlobalEvents] ready")
	# Optional debug echo wiring for Phase 2.2b lifecycle signals
	if debug_echo_lifecycle:
		if not is_connected("bacteria_reproduction_started", Callable(self, "_dbg_on_repro_started")):
			connect("bacteria_reproduction_started", Callable(self, "_dbg_on_repro_started"))
		if not is_connected("bacteria_reproduction_completed", Callable(self, "_dbg_on_repro_completed")):
			connect("bacteria_reproduction_completed", Callable(self, "_dbg_on_repro_completed"))
		if not is_connected("entity_died", Callable(self, "_dbg_on_entity_died")):
			connect("entity_died", Callable(self, "_dbg_on_entity_died"))

func _dbg_on_repro_started(entity_id: StringName) -> void:
	if _log != null:
		_log.info(LogDefs.CAT_EVENTS, ["[Events] reproduction_started", "id=", entity_id])
	else:
		print("[Events] reproduction_started id=%s" % [String(entity_id)])

func _dbg_on_repro_completed(parent_id: StringName, child_id: StringName) -> void:
	if _log != null:
		_log.info(LogDefs.CAT_EVENTS, ["[Events] reproduction_completed", "parent=", parent_id, "child=", child_id])
	else:
		print("[Events] reproduction_completed parent=%s child=%s" % [String(parent_id), String(child_id)])

func _dbg_on_entity_died(entity_id: StringName, entity_type: int, cause: StringName) -> void:
	if _log != null:
		_log.info(LogDefs.CAT_EVENTS, ["[Events] entity_died", "id=", entity_id, "type=", entity_type, "cause=", cause])
	else:
		print("[Events] entity_died id=%s type=%d cause=%s" % [String(entity_id), int(entity_type), String(cause)])