extends Node2D
class_name PetriDish

signal radius_changed(new_radius: float)

@export var agar_inner_color: Color = Color(0.96, 0.92, 0.84, 1.0)
@export var agar_outer_color: Color = Color(0.85, 0.80, 0.74, 1.0)
@export var spawn_margin_default: float = 16.0
@export var debug_overlay_enabled: bool = false

var _radius: float = 480.0

@onready var _collision_shape: CollisionShape2D = $"Boundary/CollisionShape2D"
@onready var _circle_shape: CircleShape2D = _collision_shape.shape as CircleShape2D

func _ready() -> void:
	add_to_group("Dish")
	# Initialize radius from configuration
	var configured: float = ConfigurationManager.dish_radius
	set_radius(configured)
	# Apply initial visual/debug state
	var dbg: Node = get_node_or_null("DebugDraw")
	if dbg:
		dbg.visible = debug_overlay_enabled
	# Forward initial colors to agar visual if present
	var agar: Node = get_node_or_null("Visuals/Agar")
	if agar and agar.has_method("set_colors"):
		agar.set_colors(agar_inner_color, agar_outer_color)

func get_radius() -> float:
	return _radius

func set_radius(r: float) -> void:
	var new_r: float = float(max(0.0, r))
	if is_equal_approx(new_r, _radius):
		return
	_radius = new_r
	apply_radius_to_nodes()
	emit_signal("radius_changed", _radius)

func apply_radius_to_nodes() -> void:
	# Sync physics boundary
	if is_instance_valid(_circle_shape):
		_circle_shape.radius = _radius
	elif is_instance_valid(_collision_shape) and _collision_shape.shape is CircleShape2D:
		_circle_shape = _collision_shape.shape
		(_circle_shape as CircleShape2D).radius = _radius
	# Update visuals
	var agar: Node = get_node_or_null("Visuals/Agar")
	if agar and agar.has_method("set_radius"):
		agar.set_radius(_radius)
	elif agar and agar.has_method("update"):
		agar.update()
	# Update debug overlay
	var dbg: Node = get_node_or_null("DebugDraw")
	if dbg and dbg.has_method("set_radius"):
		dbg.set_radius(_radius)
	elif dbg and dbg.has_method("update"):
		dbg.update()

func is_inside_dish(p: Vector2, margin: float = 0.0) -> bool:
	var m: float = float(max(0.0, margin))
	var r_eff: float = float(max(0.0, _radius - m))
	return p.length() <= r_eff + 1e-6

func clamp_to_dish(p: Vector2, margin: float = 0.0) -> Vector2:
	var m: float = float(max(0.0, margin))
	var r_eff: float = float(max(0.0, _radius - m))
	var len_val: float = p.length()
	if len_val <= r_eff or is_zero_approx(len_val):
		return p
	return p.normalized() * r_eff

func resolve_boundary_collision(pos: Vector2, vel: Vector2, radius: float) -> Dictionary:
	var res_pos: Vector2 = pos
	var res_vel: Vector2 = vel
	var entity_r: float = float(max(0.0, radius))
	if pos.length() + entity_r <= _radius:
		return {"pos": res_pos, "vel": res_vel}
	# Compute outward normal and clamp position to boundary minus entity radius
	var n: Vector2 = pos
	if n.length() == 0.0:
		n = Vector2.RIGHT
	else:
		n = n.normalized()
	res_pos = n * float(max(_radius - entity_r, 0.0))
	# Reflect velocity about the normal (perfect elastic reflection)
	var vn: float = res_vel.dot(n)
	res_vel = res_vel - 2.0 * vn * n
	return {"pos": res_pos, "vel": res_vel}

func get_random_point(margin: float = 0.0) -> Vector2:
	var m: float = float(clamp(margin, 0.0, _radius))
	var r: float = randf_range(0.0, float(max(_radius - m, 0.0)))
	var a: float = randf_range(0.0, TAU)
	return Vector2(cos(a), sin(a)) * r

func world_to_dish(p: Vector2) -> Vector2:
	return p - global_position

func dish_to_world(p: Vector2) -> Vector2:
	return p + global_position