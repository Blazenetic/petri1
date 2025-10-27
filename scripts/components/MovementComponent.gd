extends "res://scripts/components/EntityComponent.gd"
class_name MovementComponent

# MovementComponent
# Integrates acceleration-based motion, damping, jitter, soft separation, and dish boundary handling.
# Follows Phase 1.4 spec. Exposes tuning parameters for designers.

@export var max_speed: float = 120.0
@export_range(0.0, 1.0, 0.01) var damping: float = 0.15
@export var jitter_strength: float = 20.0
@export var align_rotation: bool = true
@export var separation_strength: float = 120.0
@export var separation_neighbors_max: int = 6
@export_range(0.0, 1.0, 0.01) var bounce_restitution: float = 0.9
@export var use_spatial_grid: bool = true

var velocity: Vector2 = Vector2.ZERO
var acceleration: Vector2 = Vector2.ZERO

var _owner_area: Area2D
var _physical: PhysicalComponent
var _dish: PetriDish
var _identity: IdentityComponent
var _grid: SpatialGrid

func init(entity: Node) -> void:
	_owner_area = entity as Area2D
	# Acquire Physical/Identity via BaseEntity reference or by scanning Components
	var be := entity as BaseEntity
	if be:
		_physical = be.physical
		_identity = be.identity
	elif _owner_area:
		var comps := _owner_area.get_node_or_null("Components")
		if comps:
			for c in comps.get_children():
				if c is PhysicalComponent:
					_physical = c
				if c is IdentityComponent:
					_identity = c
				if _physical != null and _identity != null:
					break
	# Locate PetriDish once (may be null if not yet in tree; we also lazy-acquire in update)
	if _owner_area:
		var found := get_tree().get_first_node_in_group("Dish")
		_dish = found as PetriDish
	# Cache spatial grid if available
	_grid = _get_spatial_grid()

func update(delta: float) -> void:
	if delta <= 0.0:
		return
	# Lazy-acquire PhysicalComponent if not cached yet (e.g., order-of-init)
	if _physical == null and _owner_area:
		var be := _owner_area as BaseEntity
		if be:
			_physical = be.physical
		else:
			var comps := _owner_area.get_node_or_null("Components")
			if comps:
				for c in comps.get_children():
					if c is PhysicalComponent:
						_physical = c
						break
	# Lazy-acquire Identity if not cached yet
	if _identity == null and _owner_area:
		var be2 := _owner_area as BaseEntity
		if be2:
			_identity = be2.identity
		else:
			var comps2 := _owner_area.get_node_or_null("Components")
			if comps2:
				for c2 in comps2.get_children():
					if c2 is IdentityComponent:
						_identity = c2
						break
	# Lazy-acquire SpatialGrid
	if _grid == null:
		_grid = _get_spatial_grid()
	if _physical == null:
		return

	# Soft separation from neighbors (gentle bumping)
	var sep_acc := _compute_separation_accel()

	# Integrate velocity with total acceleration
	var acc_total: Vector2 = acceleration + sep_acc
	velocity += acc_total * delta

	# Exponential damping (per-second factor)
	var damp_base: float = clamp(1.0 - damping, 0.0, 1.0)
	velocity *= pow(damp_base, delta)

	# Clamp speed
	if max_speed > 0.0:
		var sp := velocity.length()
		if sp > max_speed:
			velocity = velocity * (max_speed / sp)

	# Jitter (Brownian-like)
	if jitter_strength > 0.0:
		var j := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		velocity += j * jitter_strength * delta

	# Advance position
	_physical.position += velocity * delta

	# Ensure we have a dish reference
	if _dish == null:
		var found := get_tree().get_first_node_in_group("Dish")
		_dish = found as PetriDish

	# Boundary resolution against Petri dish
	if _dish != null:
		var pos_world := _physical.position
		var pos_dish := _dish.world_to_dish(pos_world)
		var entity_r: float = _physical.size
		var was_outside := pos_dish.length() + entity_r > _dish.get_radius()
		var res := _dish.resolve_boundary_collision(pos_dish, velocity, entity_r)
		var new_pos_dish: Vector2 = res.get("pos", pos_dish)
		var new_vel: Vector2 = res.get("vel", velocity)
		if was_outside:
			new_vel *= clamp(bounce_restitution, 0.0, 1.0)
		_physical.position = _dish.dish_to_world(new_pos_dish)
		velocity = new_vel

	# Align rotation to movement direction
	if align_rotation and velocity.length_squared() > 1e-4:
		_physical.rotation = velocity.angle()

func _get_spatial_grid() -> SpatialGrid:
	var nodes := get_tree().get_nodes_in_group("Spatial")
	if nodes.size() > 0:
		return nodes[0] as SpatialGrid
	return null

func _compute_separation_accel() -> Vector2:
	if _owner_area == null or separation_strength <= 0.0:
		return Vector2.ZERO
	if _physical == null:
		return Vector2.ZERO
	# Prefer SpatialGrid candidates if enabled and present
	if use_spatial_grid and _grid != null:
		var query_r := _physical.size * 2.0
		var ids: Array = _grid.get_entities_in_radius(_physical.position, query_r)
		if not ids.is_empty():
			var result := Vector2.ZERO
			var processed := 0
			var self_id: StringName = _identity.uuid if _identity != null else StringName()
			for id in ids:
				if processed >= separation_neighbors_max:
					break
				if id == self_id:
					continue
				var node := EntityRegistry.get_by_id(id)
				if node == null or !is_instance_valid(node):
					continue
				var other_phys: PhysicalComponent = null
				if node.has_node("Components"):
					var comps := node.get_node("Components")
					for c in comps.get_children():
						if c is PhysicalComponent:
							other_phys = c
							break
				if other_phys == null:
					continue
				processed += 1
				var delta_vec := _physical.position - other_phys.position
				var dist := delta_vec.length()
				var min_dist := float(_physical.size + other_phys.size)
				if dist <= 0.0001:
					delta_vec = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
					dist = 0.0001
				var overlap := min_dist - dist
				if overlap > 0.0:
					var dir := delta_vec / dist
					result += dir * (overlap * separation_strength)
			return result
	# Fallback: use overlapping areas (Area2D broad-phase) if grid missing or empty
	var areas: Array = []
	if _owner_area.has_method("get_overlapping_areas"):
		areas = _owner_area.get_overlapping_areas()
	if areas.is_empty():
		return Vector2.ZERO
	var result2 := Vector2.ZERO
	var processed2 := 0
	for a in areas:
		if processed2 >= separation_neighbors_max:
			break
		var other := a as Area2D
		if other == null or !is_instance_valid(other) or other == _owner_area or other.is_queued_for_deletion():
			continue
		# Attempt to locate a PhysicalComponent on neighbor
		var other_phys2: PhysicalComponent = null
		if other.has_node("Components"):
			var comps2 := other.get_node("Components")
			for c2 in comps2.get_children():
				if c2 is PhysicalComponent:
					other_phys2 = c2
					break
		if other_phys2 == null:
			continue
		processed2 += 1
		var delta_vec2 := _physical.position - other_phys2.position
		var dist2 := delta_vec2.length()
		var min_dist2 := float(_physical.size + other_phys2.size)
		if dist2 <= 0.0001:
			delta_vec2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			dist2 = 0.0001
		var overlap2 := min_dist2 - dist2
		if overlap2 > 0.0:
			var dir2 := delta_vec2 / dist2
			result2 += dir2 * (overlap2 * separation_strength)
	return result2