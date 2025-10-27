extends "res://scripts/components/EntityComponent.gd"
class_name SpatialTrackerComponent

@export var enabled: bool = true

var _entity: BaseEntity
var _physical: PhysicalComponent
var _identity: IdentityComponent
var _id: StringName
var _grid: SpatialGrid

var _last_cell: Vector2i = Vector2i(2147483647, 2147483647)
var _last_radius: float = -1.0
var _last_pos: Vector2 = Vector2.INF

func init(entity: Node) -> void:
	_entity = entity as BaseEntity
	if _entity:
		_physical = _entity.physical
		_identity = _entity.identity
		if _identity:
			_id = _identity.uuid
	_grid = _find_grid()
	# Register immediately if we have everything
	_try_register()

func update(delta: float) -> void:
	if not enabled:
		return
	# Lazy acquire in case of order-of-init
	if _grid == null:
		_grid = _find_grid()
	if _entity == null or _physical == null:
		return
	if _id.is_empty() and _identity:
		_id = _identity.uuid
	if _grid == null or _id.is_empty():
		return
	# Detect boundary crossing or radius change
	var pos := _physical.position
	var radius := float(max(0.0, _physical.size))
	var current_cell := _grid.get_cell_at_world(pos)
	var pos_changed := (_last_pos == Vector2.INF) or (pos.distance_squared_to(_last_pos) > 0.0001)
	var cell_changed := current_cell != _last_cell
	var radius_changed := not is_equal_approx(radius, _last_radius)
	if cell_changed or radius_changed:
		_grid.update_entity_position(_id, pos, radius)
		_last_cell = current_cell
		_last_radius = radius
		_last_pos = pos
	elif pos_changed:
		# Small movement that didn't cross cells; just cache position so queries use fresh position
		_grid.update_entity_position(_id, pos, radius)
		_last_pos = pos

func cleanup() -> void:
	if _grid and not _id.is_empty():
		_grid.remove_entity(_id)
	# Clear references
	_entity = null
	_physical = null
	_identity = null
	_grid = null
	_id = StringName()
	_last_cell = Vector2i(2147483647, 2147483647)
	_last_radius = -1.0
	_last_pos = Vector2.INF

func _try_register() -> void:
	if _grid == null:
		_grid = _find_grid()
	if _entity == null or _physical == null:
		return
	if _identity and _id.is_empty():
		_id = _identity.uuid
	if _grid and not _id.is_empty():
		_grid.add_entity(_id, _physical.position, float(max(0.0, _physical.size)), int(_entity.entity_type))
		_last_cell = _grid.get_cell_at_world(_physical.position)
		_last_radius = float(max(0.0, _physical.size))
		_last_pos = _physical.position

func _find_grid() -> SpatialGrid:
	var nodes := get_tree().get_nodes_in_group("Spatial")
	if nodes.size() > 0:
		return nodes[0] as SpatialGrid
	return null