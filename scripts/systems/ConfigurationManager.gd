extends Node
const EntityTypes = preload("res://scripts/components/EntityTypes.gd")
const LogDefs = preload("res://scripts/systems/Log.gd")

# Environment/dish configuration
@export var dish_radius: float = 480.0
@export var grid_cell_size: float = 64.0
@export var grid_debug_heatmap_default: bool = false
@export var grid_debug_counts_default: bool = false

# Nutrient system configuration (PHASE 2.1)
@export var nutrient_target_count: int = 20
@export var nutrient_spawn_margin: float = 16.0
@export var nutrient_size_min: float = 3.0
@export var nutrient_size_max: float = 8.0
@export var nutrient_energy_min: float = 2.0
@export var nutrient_energy_max: float = 6.0
@export var nutrient_respawn_delay_min: float = 0.5
@export var nutrient_respawn_delay_max: float = 3.0
# Distribution enum { RANDOM = 0, CLUSTERED = 1, UNIFORM = 2 }
@export var nutrient_distribution_mode: int = 0
@export var nutrient_clustered_cluster_count: int = 6
@export var nutrient_clustered_spread: float = 48.0
@export var nutrient_uniform_cell_size: float = 48.0

# Bacteria reproduction configuration (PHASE 2.2b)
@export var bacteria_repro_energy_threshold: float = 10.0
@export var bacteria_repro_cooldown_sec: float = 8.0
@export var bacteria_repro_energy_cost_ratio: float = 0.2
@export var bacteria_offspring_energy_split_ratio: float = 0.5
@export var bacteria_offspring_offset_radius: float = 10.0
@export var bacteria_max_children_per_min: int = 20

# Pool sizes per entity type (existing)
var entity_pool_sizes: Dictionary = {
	EntityTypes.EntityType.BACTERIA: 300,
	EntityTypes.EntityType.NUTRIENT: 200
}

# Optional per-type scene mapping (PHASE 2.1)
# Allows EntityFactory to instance specific scenes for each entity type.
var entity_scene_paths: Dictionary = {
	EntityTypes.EntityType.BACTERIA: "res://scenes/entities/Bacteria.tscn",
	EntityTypes.EntityType.NUTRIENT: "res://scenes/entities/Nutrient.tscn"
}

# Logger autoload handle (resolved in _ready)
var _log

func get_entity_pool_size(entity_type: int) -> int:
	return int(entity_pool_sizes.get(entity_type, 20))

func get_entity_scene_path(entity_type: int) -> String:
	return String(entity_scene_paths.get(entity_type, ""))

func _ready() -> void:
	# Initialize logger defaults based on build mode
	var dev := Engine.is_editor_hint() or OS.is_debug_build()
	_log = get_node_or_null("/root/Log")
	if _log == null:
		# Fallback minimal notice to avoid hard failure if autoload isn't registered yet
		print("[ConfigurationManager] ready (Log autoload missing)")
		return
	# Ensure InputMap contains debug actions (F9 / Shift+F9)
	_ensure_input_actions()
	# Per-category thresholds per proposal
	_log.set_global_enabled(dev)
	if dev:
		_log.set_level(_log.CAT_CORE, _log.LEVEL_INFO)
		_log.set_level(_log.CAT_SYSTEMS, _log.LEVEL_INFO)
		_log.set_level(_log.CAT_PERF, _log.LEVEL_DEBUG)
		_log.set_level(_log.CAT_COMPONENTS, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_AI, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_ENVIRONMENT, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_UI, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_EVENTS, _log.LEVEL_WARN)
	else:
		_log.set_level(_log.CAT_CORE, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_SYSTEMS, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_PERF, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_COMPONENTS, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_AI, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_ENVIRONMENT, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_UI, _log.LEVEL_WARN)
		_log.set_level(_log.CAT_EVENTS, _log.LEVEL_WARN)
	# Single summary line to avoid noise
	_log.info(_log.CAT_SYSTEMS, [
		"[ConfigurationManager] ready",
		"grid_cell_size=", grid_cell_size,
		"heatmap_default=", grid_debug_heatmap_default,
		"counts_default=", grid_debug_counts_default,
		"nutrients_target=", nutrient_target_count,
		"size=[", nutrient_size_min, ",", nutrient_size_max, "]",
		"energy=[", nutrient_energy_min, ",", nutrient_energy_max, "]",
		"respawn_s=[", nutrient_respawn_delay_min, ",", nutrient_respawn_delay_max, "]",
		"dist_mode=", nutrient_distribution_mode
	])

func _ensure_input_actions() -> void:
	# debug_toggle_global: F9 (no shift)
	if not InputMap.has_action("debug_toggle_global"):
		InputMap.add_action("debug_toggle_global")
	if not _has_key_event_for_action(&"debug_toggle_global", Key.KEY_F9, false):
		var ev_toggle := InputEventKey.new()
		ev_toggle.physical_keycode = Key.KEY_F9
		ev_toggle.shift_pressed = false
		ev_toggle.pressed = false
		InputMap.action_add_event("debug_toggle_global", ev_toggle)
	# debug_cycle_perf: Shift+F9
	if not InputMap.has_action("debug_cycle_perf"):
		InputMap.add_action("debug_cycle_perf")
	if not _has_key_event_for_action(&"debug_cycle_perf", Key.KEY_F9, true):
		var ev_cycle := InputEventKey.new()
		ev_cycle.physical_keycode = Key.KEY_F9
		ev_cycle.shift_pressed = true
		ev_cycle.pressed = false
		InputMap.action_add_event("debug_cycle_perf", ev_cycle)

func _has_key_event_for_action(action_name: StringName, keycode: int, shift: bool) -> bool:
	var events := InputMap.action_get_events(action_name)
	for e in events:
		var k := e as InputEventKey
		if k and k.physical_keycode == keycode and k.shift_pressed == shift:
			return true
	return false