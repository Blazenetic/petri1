extends Node2D
class_name PetriDishAgar

@export var steps: int = 24

var _inner_color: Color = Color(0.96, 0.92, 0.84, 1.0)
var _outer_color: Color = Color(0.85, 0.80, 0.74, 1.0)
var _radius: float = 480.0

func _ready() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method("get_radius"):
		_radius = float(parent.call("get_radius"))
	if parent and parent.has_signal("radius_changed"):
		parent.connect("radius_changed", Callable(self, "_on_radius_changed"))
	queue_redraw()

func set_colors(inner: Color, outer: Color) -> void:
	_inner_color = inner
	_outer_color = outer
	queue_redraw()

func set_radius(r: float) -> void:
	_radius = float(max(0.0, r))
	queue_redraw()

func _on_radius_changed(new_radius: float) -> void:
	set_radius(new_radius)

func _draw() -> void:
	if _radius <= 0.0:
		return
	var count: int = max(1, int(steps))
	# Radial gradient via concentric filled circles (inner brighter)
	for i in range(count, 0, -1):
		var t: float = float(i) / float(count) # 0..1 (inner at 1)
		var col: Color = _outer_color.lerp(_inner_color, t)
		draw_circle(Vector2.ZERO, _radius * t, col)