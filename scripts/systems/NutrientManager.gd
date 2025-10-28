extends Node
class_name NutrientManager

const EntityTypes = preload("res://scripts/components/EntityTypes.gd")

enum DistributionMode { RANDOM = 0, CLUSTERED = 1, UNIFORM = 2 }
const LogDefs = preload("res://scripts/systems/Log.gd")
var _log

@export var target_count: int = 150
@export var spawn_margin: float = 16.0
@export var size_min: float = 3.0
@export var size_max: float = 8.0
@export var energy_min: float = 2.0
@export var energy_max: float = 6.0
@export var respawn_delay_min: float = 0.5
@export var respawn_delay_max: float = 3.0
@export var distribution_mode: int = DistributionMode.RANDOM
@export var clustered_cluster_count: int = 6
@export var clustered_spread: float = 48.0
@export var uniform_cell_size: float = 48.0
@export var reconcile_interval_sec: float = 2.0

var _dish: PetriDish
var _reconcile_timer: Timer
var _cluster_centers_local: Array[Vector2] = []

func _ready() -> void:
	_log = get_node_or_null("/root/Log")
	# Load defaults from configuration (PHASE 2.1)
	_load_defaults_from_config()
	_dish = _get_dish()
	# Connect destruction events to schedule respawns
	if not GlobalEvents.is_connected("entity_destroyed", Callable(self, "_on_entity_destroyed")):
		GlobalEvents.connect("entity_destroyed", Callable(self, "_on_entity_destroyed"))
	# Periodic reconciliation to maintain density
	_reconcile_timer = Timer.new()
	_reconcile_timer.wait_time = max(0.1, reconcile_interval_sec)
	_reconcile_timer.one_shot = false
	add_child(_reconcile_timer)
	_reconcile_timer.connect("timeout", Callable(self, "_on_reconcile_timeout"))
	_reconcile_timer.start()
	# Initial spawn
	var current: int = EntityRegistry.count_by_type(EntityTypes.EntityType.NUTRIENT)
	var missing: int = max(0, target_count - current)
	if missing > 0:
		_spawn_now(missing, distribution_mode)

func _load_defaults_from_config() -> void:
	# Always mirror current configuration values into exported fields for now
	if "nutrient_target_count" in ConfigurationManager:
		target_count = int(ConfigurationManager.nutrient_target_count)
	if "nutrient_spawn_margin" in ConfigurationManager:
		spawn_margin = float(ConfigurationManager.nutrient_spawn_margin)
	if "nutrient_size_min" in ConfigurationManager:
		size_min = float(ConfigurationManager.nutrient_size_min)
	if "nutrient_size_max" in ConfigurationManager:
		size_max = float(ConfigurationManager.nutrient_size_max)
	if "nutrient_energy_min" in ConfigurationManager:
		energy_min = float(ConfigurationManager.nutrient_energy_min)
	if "nutrient_energy_max" in ConfigurationManager:
		energy_max = float(ConfigurationManager.nutrient_energy_max)
	if "nutrient_respawn_delay_min" in ConfigurationManager:
		respawn_delay_min = float(ConfigurationManager.nutrient_respawn_delay_min)
	if "nutrient_respawn_delay_max" in ConfigurationManager:
		respawn_delay_max = float(ConfigurationManager.nutrient_respawn_delay_max)
	if "nutrient_distribution_mode" in ConfigurationManager:
		distribution_mode = int(ConfigurationManager.nutrient_distribution_mode)
	if "nutrient_clustered_cluster_count" in ConfigurationManager:
		clustered_cluster_count = int(ConfigurationManager.nutrient_clustered_cluster_count)
	if "nutrient_clustered_spread" in ConfigurationManager:
		clustered_spread = float(ConfigurationManager.nutrient_clustered_spread)
	if "nutrient_uniform_cell_size" in ConfigurationManager:
		uniform_cell_size = float(ConfigurationManager.nutrient_uniform_cell_size)

# Public API

func spawn_now(count: int, mode_override: int = -1) -> void:
	_spawn_now(count, mode_override)

func set_target_count(n: int) -> void:
	target_count = max(0, n)

func set_distribution(mode: int) -> void:
	distribution_mode = int(clamp(mode, 0, 2))

# Internals

func _on_reconcile_timeout() -> void:
	var current: int = EntityRegistry.count_by_type(EntityTypes.EntityType.NUTRIENT)
	if current < target_count:
		var need: int = target_count - current
		if _log != null and _log.enabled(LogDefs.CAT_SYSTEMS, LogDefs.LEVEL_DEBUG):
			_log.debug(LogDefs.CAT_SYSTEMS, [
				"[NutrientManager] reconcile:",
				"current=", current,
				"target=", target_count,
				"spawning=+", need
			])
		_spawn_now(need, distribution_mode)
	elif _log != null and _log.enabled(LogDefs.CAT_SYSTEMS, LogDefs.LEVEL_DEBUG):
		_log.debug(LogDefs.CAT_SYSTEMS, [
			"[NutrientManager] reconcile:",
			"current=", current,
			"ok"
		])

func _on_entity_destroyed(entity_id: StringName, entity_type: int, reason: StringName) -> void:
	if entity_type != EntityTypes.EntityType.NUTRIENT:
		return
	if reason != &"consumed":
		return
	var delay: float = randf_range(respawn_delay_min, respawn_delay_max)
	if _log != null and _log.enabled(LogDefs.CAT_SYSTEMS, LogDefs.LEVEL_DEBUG):
		_log.debug(LogDefs.CAT_SYSTEMS, [
			"[NutrientManager] schedule respawn",
			"delay_s=", delay
		])
	var timer: SceneTreeTimer = get_tree().create_timer(max(0.01, delay))
	timer.timeout.connect(Callable(self, "_on_respawn_timeout"))

func _on_respawn_timeout() -> void:
	_spawn_now(1, distribution_mode)

func _spawn_now(count: int, mode_override: int = -1) -> void:
	var mode: int = distribution_mode if mode_override < 0 else int(clamp(mode_override, 0, 2))
	if count <= 0:
		return
	match mode:
		DistributionMode.RANDOM:
			_spawn_random(count)
		DistributionMode.CLUSTERED:
			_spawn_clustered(count)
		DistributionMode.UNIFORM:
			_spawn_uniform(count)
		_:
			_spawn_random(count)

func _spawn_random(count: int) -> void:
	for i in range(count):
		var pos_world: Vector2 = _sample_world_point_random()
		var sz: float = randf_range(size_min, size_max)
		var energy: float = randf_range(energy_min, energy_max)
		_spawn_nutrient_instance(pos_world, sz, energy)

func _spawn_clustered(count: int) -> void:
	if _dish == null:
		return
	# Establish cluster centers in dish-local space
	_cluster_centers_local.clear()
	var cluster_count: int = max(1, clustered_cluster_count)
	for i in range(cluster_count):
		_cluster_centers_local.append(_dish.get_random_point(spawn_margin))
	for i in range(count):
		var center_local: Vector2 = _cluster_centers_local[randi() % _cluster_centers_local.size()]
		var offset: Vector2 = _rand_point_in_circle(clustered_spread)
		var local: Vector2 = _dish.clamp_to_dish(center_local + offset, spawn_margin)
		var pos_world: Vector2 = _dish.dish_to_world(local)
		var sz: float = randf_range(size_min, size_max)
		var energy: float = randf_range(energy_min, energy_max)
		_spawn_nutrient_instance(pos_world, sz, energy)

func _spawn_uniform(count: int) -> void:
	if _dish == null:
		return
	var positions: Array[Vector2] = []
	var cs: float = max(1.0, uniform_cell_size)
	var r: float = _dish.get_radius()
	# Iterate a grid over bounding square [-r, r] and keep points inside dish with slight jitter
	var y: float = -r
	while y <= r and positions.size() < count:
		var x: float = -r
		while x <= r and positions.size() < count:
			var center: Vector2 = Vector2(x + cs * 0.5, y + cs * 0.5)
			if center.length() <= (r - spawn_margin):
				var jitter: Vector2 = Vector2(randf_range(-cs * 0.25, cs * 0.25), randf_range(-cs * 0.25, cs * 0.25))
				var local: Vector2 = _dish.clamp_to_dish(center + jitter, spawn_margin)
				positions.append(_dish.dish_to_world(local))
			x += cs
		y += cs
	# Fallback if not enough positions accumulated due to small radius
	while positions.size() < count:
		positions.append(_sample_world_point_random())
	# Spawn
	for i in range(min(count, positions.size())):
		var sz: float = randf_range(size_min, size_max)
		var energy: float = randf_range(energy_min, energy_max)
		_spawn_nutrient_instance(positions[i], sz, energy)

func _spawn_nutrient_instance(pos_world: Vector2, size_value: float, energy_value: float) -> void:
	var id: StringName = EntityFactory.create_entity(EntityTypes.EntityType.NUTRIENT, pos_world, {"size": size_value})
	if id == StringName():
		return
	var node: BaseEntity = EntityRegistry.get_by_id(id) as BaseEntity
	if node:
		# Assign energy to attached component if present
		var comp: NutrientComponent = null
		var comps: Node = node.get_node_or_null("Components")
		if comps:
			for c in comps.get_children():
				comp = c as NutrientComponent
				if comp:
					break
		if comp:
			comp.set_energy_value(energy_value)
	GlobalEvents.emit_signal("nutrient_spawned", id, pos_world, energy_value)
	if _log != null and _log.enabled(LogDefs.CAT_SYSTEMS, LogDefs.LEVEL_INFO):
		var c: int = EntityRegistry.count_by_type(EntityTypes.EntityType.NUTRIENT)
		_log.info(LogDefs.CAT_SYSTEMS, [
			"[NutrientManager] spawned nutrient",
			"id=", id,
			"pos=", pos_world,
			"size=", size_value,
			"energy=", energy_value,
			"active=", c
		])

func _sample_world_point_random() -> Vector2:
	if _dish == null:
		return Vector2.ZERO
	var local: Vector2 = _dish.get_random_point(spawn_margin)
	return _dish.dish_to_world(local)

func _rand_point_in_circle(radius: float) -> Vector2:
	var r: float = randf() * radius
	var a: float = randf() * TAU
	return Vector2(cos(a), sin(a)) * r

func _get_dish() -> PetriDish:
	var nodes: Array = get_tree().get_nodes_in_group("Dish")
	if nodes.size() > 0:
		return nodes[0] as PetriDish
	return null