extends Node
class_name BacteriaSystem

const EntityTypes = preload("res://scripts/components/EntityTypes.gd")
const LogDefs = preload("res://scripts/systems/Log.gd")
const BacteriaRendererClass = preload("res://scripts/rendering/BacteriaRenderer.gd")
const BacteriaStoreClass = preload("res://scripts/systems/BacteriaStore.gd")

@export var change_interval: float = 0.8
@export var accel_magnitude: float = 160.0
@export_range(0.0, 1.0, 0.01) var damping: float = 0.15
@export var max_speed: float = 120.0
@export var align_rotation: bool = true

var _renderer: Node
var _store: Node
var _grid: SpatialGrid
var _dish: PetriDish
var _log

var _updates: int = 0
var _since_log: float = 0.0

func _ready() -> void:
	_log = get_node_or_null("/root/Log")
	_grid = _get_spatial_grid()
	_dish = _get_dish()
	_renderer = _find_renderer()

	# Respect configuration toggle; disable when not using multimesh.
	if not ConfigurationManager.is_bacteria_multimesh_enabled():
		set_process(false)
		return

	# Initialize renderer and store
	var max_instances: int = int(max(0, ConfigurationManager.bacteria_max_instances))
	if _renderer == null:
		# Create a fallback renderer locally if scene not wired yet
		_renderer = BacteriaRendererClass.new()
		_renderer.name = "BacteriaRenderer"
		get_parent().add_child(_renderer)
	_renderer.init(max_instances)
	# Startup capability summary from renderer
	if _renderer != null and _renderer.has_method("get_capability_summary"):
		var caps: String = String(_renderer.get_capability_summary())
		if _log != null:
			_log.info(_log.CAT_SYSTEMS, ["[BacteriaSystem] renderer_caps", caps])
		else:
			print("[BacteriaSystem] renderer_caps ", caps)

	_store = BacteriaStoreClass.new()
	_store.name = "BacteriaStore"
	add_child(_store)
	_store.init(max_instances)

	# Optional bootstrap
	var initial: int = int(max(0, ConfigurationManager.bacteria_initial_count))
	if initial > 0:
		for i in range(initial):
			var pos := _random_spawn_position(ConfigurationManager.bacteria_default_radius)
			spawn_bacteria(pos, {"size": ConfigurationManager.bacteria_default_radius})

	set_process(true)

func spawn_bacteria(position: Vector2, params := {}) -> StringName:
	if _store == null or _renderer == null:
		return StringName()
	var radius: float = float(params.get("size", ConfigurationManager.bacteria_default_radius))
	var color: Color = Color(0.3, 0.8, 0.3, 1.0)
	if params.has("color"):
		color = params["color"]
	var rec: Dictionary = _store.allocate(position, radius, color, Color(0, 0, 0, 0))
	if rec.is_empty():
		return StringName()
	var idx: int = int(rec["index"])
	var id: StringName = rec["id"]
	_renderer.set_slot(idx, position, radius, color, 0.0, Color(0, 0, 0, 0))
	if _grid != null:
		_grid.add_entity(id, position, radius, EntityTypes.EntityType.BACTERIA)
	var ge := get_node_or_null("/root/GlobalEvents")
	if ge:
		ge.emit_signal("entity_spawned", id, EntityTypes.EntityType.BACTERIA, position)
	return id

func despawn_bacteria(id: StringName, reason: StringName = &"despawn") -> void:
	if _store == null or _renderer == null:
		return
	var idx: int = _store.get_index_by_id(id)
	if idx >= 0:
		_renderer.hide_slot(idx)
	_store.free_by_id(id)
	if _grid != null:
		_grid.remove_entity(id)
	var ge := get_node_or_null("/root/GlobalEvents")
	if ge:
		ge.emit_signal("entity_destroyed", id, EntityTypes.EntityType.BACTERIA, reason)

func _process(delta: float) -> void:
	if delta <= 0.0 or _store == null or _renderer == null:
		return
	_updates += 1
	_since_log += delta

	# Lazy acquire environment references if needed
	if _dish == null:
		_dish = _get_dish()
	if _grid == null:
		_grid = _get_spatial_grid()

	var active: Array[int] = _store.get_active_indices()
	for i in active:
		# Wander timer and direction selection
		_store.change_timer[i] += delta
		if _store.change_timer[i] >= change_interval:
			_store.change_timer[i] = 0.0
			_store.direction[i] = _rand_unit()

		# Integrate velocity
		var v: Vector2 = _store.velocities[i]
		var acc: Vector2 = _store.direction[i] * accel_magnitude
		v += acc * delta

		# Exponential damping
		var damp_base: float = clamp(1.0 - damping, 0.0, 1.0)
		v *= pow(damp_base, delta)

		# Clamp speed
		if max_speed > 0.0:
			var sp := v.length()
			if sp > max_speed:
				v = v * (max_speed / max(sp, 0.000001))

		# Advance position
		var p: Vector2 = _store.positions[i] + v * delta
		var r: float = _store.radii[i]

		# Boundary resolution
		if _dish != null:
			var p_dish := _dish.world_to_dish(p)
			var res := _dish.resolve_boundary_collision(p_dish, v, r)
			var new_p_dish: Vector2 = res.get("pos", p_dish)
			var new_v: Vector2 = res.get("vel", v)
			# Soft restitution consistent with MovementComponent
			var rest := 0.9
			if _is_outside(p_dish, r):
				new_v *= rest
			p = _dish.dish_to_world(new_p_dish)
			v = new_v

		# Write back
		_store.positions[i] = p
		_store.velocities[i] = v

		# Visuals: color/rotation
		var color: Color = _store.colors[i]
		var rot: float = v.angle() if (align_rotation and v.length_squared() > 1e-4) else 0.0
		_renderer.set_slot(i, p, r, color, rot, _store.custom_data[i])

		# Spatial grid update
		if _grid != null:
			var id: StringName = _store.get_id_by_index(i)
			if id != StringName():
				_grid.update_entity_position(id, p, r)

	_renderer.commit()

	# Metrics
	if _log != null:
		_log.every(&"BacteriaSystemPerf", 1.0, LogDefs.CAT_PERF, LogDefs.LEVEL_DEBUG, [
			"[BacteriaSystem]",
			"active=", _store.active_count,
			"upd/s=", _updates / max(_since_log, 0.000001),
			"slots=", _store.max_instances
		])
		if _since_log >= 1.0:
			_since_log = 0.0
			_updates = 0

# Helpers

func _get_spatial_grid() -> SpatialGrid:
	var nodes := get_tree().get_nodes_in_group("Spatial")
	if nodes.size() > 0:
		return nodes[0] as SpatialGrid
	return null

func _get_dish() -> PetriDish:
	var nodes := get_tree().get_nodes_in_group("Dish")
	if nodes.size() > 0:
		return nodes[0] as PetriDish
	return null

func _find_renderer() -> MultiMeshInstance2D:
	# Prefer sibling named node
	var n := get_parent()
	if n:
		var br := n.get_node_or_null("BacteriaRenderer")
		if br and br is BacteriaRendererClass:
			return br
	# Fallback: search by group for reliability
	var all := get_tree().get_nodes_in_group("BacteriaRenderer")
	for node in all:
		if node is BacteriaRendererClass:
			return node
	return null

func _random_spawn_position(radius: float) -> Vector2:
	var dish := _dish if _dish != null else _get_dish()
	if dish == null:
		return Vector2.ZERO
	var local := dish.get_random_point(max(radius, 0.0) + 2.0)
	return dish.dish_to_world(local)

func _rand_unit() -> Vector2:
	var v := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if v.length_squared() < 1e-6:
		return Vector2.RIGHT
	return v.normalized()

func _is_outside(local_pos: Vector2, radius: float) -> bool:
	if _dish == null:
		return false
	return local_pos.length() + max(0.0, radius) > _dish.get_radius()