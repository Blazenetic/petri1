extends "res://scripts/components/EntityComponent.gd"
class_name RandomWander

# RandomWander
# Picks a direction every interval and biases MovementComponent acceleration toward it.
# Optional smoothing via turn_lerp for gentler turns.

@export var change_interval: float = 0.8
@export var magnitude: float = 160.0
@export_range(0.0, 1.0, 0.01) var turn_lerp: float = 0.25

var elapsed: float = 0.0

var _move: MovementComponent
var _dir: Vector2 = Vector2.ZERO
var _target_dir: Vector2 = Vector2.ZERO

func init(entity: Node) -> void:
	_move = _find_movement_component(entity)
	_target_dir = _rand_unit()
	_dir = _target_dir

func update(delta: float) -> void:
	if _move == null:
		return
	elapsed += delta
	if elapsed >= change_interval:
		elapsed = 0.0
		_target_dir = _rand_unit()
	# Smoothly turn toward target
	if turn_lerp > 0.0 and turn_lerp < 1.0:
		_dir = _dir.lerp(_target_dir, turn_lerp)
	else:
		_dir = _target_dir
	# Apply acceleration bias
	_move.acceleration = _dir * magnitude

func _find_movement_component(entity: Node) -> MovementComponent:
	# Look for MovementComponent among child components
	var comps := entity.get_node_or_null("Components")
	if comps:
		for c in comps.get_children():
			if c is MovementComponent:
				return c
	return null

func _rand_unit() -> Vector2:
	var x := randf_range(-1.0, 1.0)
	var y := randf_range(-1.0, 1.0)
	var v := Vector2(x, y)
	if v.length_squared() < 1e-6:
		return Vector2.RIGHT
	return v.normalized()