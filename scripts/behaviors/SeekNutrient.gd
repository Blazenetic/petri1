extends "res://scripts/components/EntityComponent.gd"
class_name SeekNutrient

# SeekNutrient
# Steers the owner toward the nearest nutrient within a sense radius.
# Prefers SpatialGrid queries for efficiency and falls back to EntityRegistry scan if needed.
# Blends steering with existing acceleration so RandomWander (or other behaviors) can still influence movement.
# Adds target persistence/hysteresis and a minimum slow factor to avoid stalling near targets.

const EntityTypes = preload("res://scripts/components/EntityTypes.gd")

@export var sense_radius: float = 220.0
@export var target_refresh_interval: float = 0.25
@export var acceleration_magnitude: float = 240.0
@export var slow_radius: float = 16.0
@export var min_slow_factor: float = 0.25
@export_range(0.0, 1.0, 0.01) var seek_blend: float = 0.6
@export var target_persist_sec: float = 1.0
@export var use_spatial_grid: bool = true
@export var debug_draw_target: bool = false

var _move: MovementComponent
var _identity: IdentityComponent
var _physical: PhysicalComponent
var _grid: SpatialGrid

var _accum: float = 0.0
var _persist_elapsed: float = 0.0
var _target_id: StringName = StringName()
var _target_pos: Vector2 = Vector2.ZERO

func init(entity: Node) -> void:
	var be := entity as BaseEntity
	if be:
		_move = _find_movement_component(be)
		_identity = be.identity
		_physical = be.physical
	else:
		_move = _find_movement_component(entity)
		_identity = _find_identity_component(entity)
		_physical = _find_physical_component(entity)
	_grid = _get_spatial_grid()
	_accum = 0.0
	_persist_elapsed = 0.0
	_target_id = StringName()
	_target_pos = Vector2.ZERO

func update(delta: float) -> void:
	if _physical == null or _move == null:
		return

	_accum += delta
	_persist_elapsed += delta

	# Validate current target
	if not _target_id.is_empty():
		var cur := EntityRegistry.get_by_id(_target_id)
		if cur == null or not is_instance_valid(cur):
			_clear_target()
		else:
			var tphys := _extract_physical(cur)
			if tphys == null:
				_clear_target()
			else:
				_target_pos = tphys.position
				# Drop if too far away (hysteresis) to encourage exploration
				if _physical.position.distance_to(_target_pos) > sense_radius * 1.25:
					_clear_target()

	# Refresh search either periodically or when we have no target, throttled by target_persist_sec
	if _target_id.is_empty():
		if _accum >= max(0.01, target_refresh_interval):
			_accum = 0.0
			_pick_target()
	elif _persist_elapsed >= max(0.05, target_persist_sec) and _accum >= max(0.01, target_refresh_interval):
		_accum = 0.0
		_persist_elapsed = 0.0
		_pick_target()

	# If still no target, leave acceleration as-is to let other behaviors act
	if _target_id.is_empty():
		return

	var to_target := _target_pos - _physical.position
	var dist := to_target.length()
	if dist <= 0.001:
		return

	var desired := to_target / dist
	var accel := acceleration_magnitude
	if slow_radius > 0.0 and dist < slow_radius:
		var factor: float = clamp(dist / slow_radius, min_slow_factor, 1.0)
		accel *= factor

	var new_vec := desired * accel
	var prev := _move.acceleration
	var w: float = clamp(seek_blend, 0.0, 1.0)
	_move.acceleration = prev.lerp(new_vec, w)

func _clear_target() -> void:
	_target_id = StringName()
	_target_pos = Vector2.ZERO

func _pick_target() -> void:
	if _physical == null:
		return
	# If we already have a valid target within hysteresis radius, keep it
	if not _target_id.is_empty():
		return

	# Try SpatialGrid
	if use_spatial_grid and _grid == null:
		_grid = _get_spatial_grid()

	var best_id: StringName = StringName()
	var best_d2: float = INF
	if use_spatial_grid and _grid != null:
		var ids: Array = _grid.get_entities_in_radius(_physical.position, sense_radius, [EntityTypes.EntityType.NUTRIENT])
		for id in ids:
			if _identity and id == _identity.uuid:
				continue
			var node := EntityRegistry.get_by_id(id)
			if node == null or not is_instance_valid(node):
				continue
			var tphys := _extract_physical(node)
			if tphys == null:
				continue
			var d2 := _physical.position.distance_squared_to(tphys.position)
			if d2 < best_d2:
				best_d2 = d2
				best_id = id
				_target_pos = tphys.position

	# Fallback O(N) scan
	if best_id.is_empty():
		var arr: Array = EntityRegistry.get_all_by_type(EntityTypes.EntityType.NUTRIENT)
		for n in arr:
			if n == null or not is_instance_valid(n):
				continue
			var tphys_fb := _extract_physical(n)
			if tphys_fb == null:
				continue
			var d2_fb := _physical.position.distance_squared_to(tphys_fb.position)
			if d2_fb <= sense_radius * sense_radius and d2_fb < best_d2:
				best_d2 = d2_fb
				var idc := _extract_identity(n)
				best_id = idc.uuid if idc != null else StringName()
				_target_pos = tphys_fb.position

	_target_id = best_id

func _get_spatial_grid() -> SpatialGrid:
	var nodes := get_tree().get_nodes_in_group("Spatial")
	if nodes.size() > 0:
		return nodes[0] as SpatialGrid
	return null

func _find_movement_component(entity: Node) -> MovementComponent:
	var comps := entity.get_node_or_null("Components")
	if comps:
		for c in comps.get_children():
			if c is MovementComponent:
				return c
	return null

func _find_physical_component(entity: Node) -> PhysicalComponent:
	var comps := entity.get_node_or_null("Components")
	if comps:
		for c in comps.get_children():
			if c is PhysicalComponent:
				return c
	return null

func _find_identity_component(entity: Node) -> IdentityComponent:
	var comps := entity.get_node_or_null("Components")
	if comps:
		for c in comps.get_children():
			if c is IdentityComponent:
				return c
	return null

func _extract_physical(node: Node) -> PhysicalComponent:
	var comps := node.get_node_or_null("Components")
	if comps:
		for c in comps.get_children():
			if c is PhysicalComponent:
				return c
	return null

func _extract_identity(node: Node) -> IdentityComponent:
	var comps := node.get_node_or_null("Components")
	if comps:
		for c in comps.get_children():
			if c is IdentityComponent:
				return c
	return null

# --- Public accessors for BehaviorController / state logic (PHASE 2.3) ---

func has_target() -> bool:
	return not _target_id.is_empty()

func get_current_target_id() -> StringName:
	return _target_id

func get_current_target_pos() -> Vector2:
	return _target_pos