extends Node2D
class_name PetriDishDebugDraw

@export var show_grid: bool = true
@export var show_cell_counts: bool = false
@export var show_heatmap: bool = false
@export var outline_color: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var axes_color: Color = Color(0.2, 0.2, 0.2, 0.6)
@export var grid_color: Color = Color(0.15, 0.15, 0.15, 0.25)
@export var line_width: float = 1.0

var _radius: float = 480.0

func _ready() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_signal("radius_changed"):
		parent.connect("radius_changed", Callable(self, "_on_radius_changed"))
	# Initialize debug overlay toggles from configuration defaults
	show_cell_counts = bool(ConfigurationManager.grid_debug_counts_default)
	show_heatmap = bool(ConfigurationManager.grid_debug_heatmap_default)
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
	# Grid clipped to circle (lines are clipped analytically)
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
	# Occupancy overlays (heatmap and counts)
	var grid := _get_grid()
	if grid != null and (show_heatmap or show_cell_counts):
		var cell_size: float = _get_cell_size()
		if cell_size > 1.0:
			var min_cx := int(floor(-r / cell_size))
			var max_cx := int(floor(r / cell_size))
			var min_cy := int(floor(-r / cell_size))
			var max_cy := int(floor(r / cell_size))
			# First pass: find max occupancy for normalization (only if heatmap)
			var max_count: int = 1
			if show_heatmap:
				for cy in range(min_cy, max_cy + 1):
					for cx in range(min_cx, max_cx + 1):
						var rect := Rect2(Vector2(cx * cell_size, cy * cell_size), Vector2(cell_size, cell_size))
						var center := rect.position + rect.size * 0.5
						if center.length() > r + cell_size * 0.5:
							continue
						var cnt := (grid.get_entities_in_cell(Vector2i(cx, cy)) as Array).size()
						if cnt > max_count:
							max_count = cnt
			# Second pass: draw per-cell overlays
			for cy in range(min_cy, max_cy + 1):
				for cx in range(min_cx, max_cx + 1):
					var rect := Rect2(Vector2(cx * cell_size, cy * cell_size), Vector2(cell_size, cell_size))
					var center := rect.position + rect.size * 0.5
					if center.length() > r + cell_size * 0.5:
						continue
					var count := (grid.get_entities_in_cell(Vector2i(cx, cy)) as Array).size()
					# Draw heatmap fill only if the entire cell lies inside the dish to avoid visual bleed
					if show_heatmap and count > 0 and max_count > 0:
						var inside_all := true
						var corners := [
							rect.position,
							rect.position + Vector2(cell_size, 0.0),
							rect.position + Vector2(0.0, cell_size),
							rect.position + Vector2(cell_size, cell_size)
						]
						for c in corners:
							if c.length() > r:
								inside_all = false
								break
						if inside_all:
							var alpha: float = clamp(float(count) / float(max_count), 0.1, 1.0) * 0.5
							var heat_col: Color = Color(1.0, 0.25, 0.25, alpha)
							draw_rect(rect, heat_col, true)
					# Draw counts text at cell center
					if show_cell_counts and count > 0:
						var font := ThemeDB.fallback_font
						var fsize: int = ThemeDB.fallback_font_size
						if font:
							var text: String = str(count)
							var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
							draw_string(font, center - ts * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline_color)

func _get_cell_size() -> float:
	return float(ConfigurationManager.grid_cell_size)

func _get_grid() -> SpatialGrid:
	var nodes := get_tree().get_nodes_in_group("Spatial")
	if nodes.size() > 0:
		return nodes[0] as SpatialGrid
	return null