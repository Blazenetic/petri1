extends Node2D
class_name PetriDishDebugDraw

@export var show_grid: bool = true
@export var outline_color: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var axes_color: Color = Color(0.2, 0.2, 0.2, 0.6)
@export var grid_color: Color = Color(0.15, 0.15, 0.15, 0.25)
@export var line_width: float = 1.0

var _radius: float = 480.0

func _ready() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_signal("radius_changed"):
		parent.connect("radius_changed", Callable(self, "_on_radius_changed"))
	queue_redraw()

func set_radius(r: float) -> void:
	_radius = max(0.0, r)
	queue_redraw()

func _on_radius_changed(new_radius: float) -> void:
	set_radius(new_radius)

func _draw() -> void:
	if _radius <= 0.0:
		return
	var r: float = _radius
	# Crosshair axes
	draw_line(Vector2(-r, 0.0), Vector2(r, 0.0), axes_color, line_width)
	draw_line(Vector2(0.0, -r), Vector2(0.0, r), axes_color, line_width)
	# Circular outline
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 128, outline_color, line_width, false)
	# Grid clipped to circle
	if show_grid:
		var cell: float = _get_cell_size()
		if cell > 1.0:
			var x: float = -r
			while x <= r:
				var y_max: float = sqrt(max(r * r - x * x, 0.0))
				draw_line(Vector2(x, -y_max), Vector2(x, y_max), grid_color, line_width)
				x += cell
			var y: float = -r
			while y <= r:
				var x_max: float = sqrt(max(r * r - y * y, 0.0))
				draw_line(Vector2(-x_max, y), Vector2(x_max, y), grid_color, line_width)
				y += cell

func _get_cell_size() -> float:
	return float(ConfigurationManager.grid_cell_size)