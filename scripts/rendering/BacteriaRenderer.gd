extends MultiMeshInstance2D
class_name BacteriaRenderer

# GPU-instanced bacteria renderer for Phase A.
# API:
#   init(max_instances)
#   set_slot(index, position, radius, color, rotation := 0.0, custom := Color(0,0,0,0))
#   hide_slot(index)
#   commit()  # no-op placeholder; kept for future batched paths

var _max_instances: int = 0
var _mm: MultiMesh
var _supports_instance_color: bool = false
var _supports_instance_custom: bool = false
var _capability_logged: bool = false

func _ready() -> void:
	# Allow discovery via group
	add_to_group("BacteriaRenderer")
	# Material/mesh defaults are set in init(); keep _ready() light to avoid work when unused.
	pass

func init(max_instances: int) -> void:
	_max_instances = int(max(0, max_instances))
	# Create MultiMesh configured for 2D
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	# Godot 4.5: configure via properties (no RS format enums available).
	# Must set flags before sizing buffers via instance_count.
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.instance_count = _max_instances
	multimesh = _mm

	# Ensure a simple unit quad mesh (UV 0..1) so shader can SDF a circle
	if _mm.mesh == null:
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_mm.mesh = q

	# Assign shader material if none set
	if material == null:
		var res := load("res://scripts/shaders/bacteria_shader.tres")
		if res is Shader:
			var sm := ShaderMaterial.new()
			sm.shader = res
			material = sm
		elif res is ShaderMaterial:
			material = res

	# Probe per-instance capabilities and configure fallback if needed
	_probe_capabilities()

	# Start hidden
	for i in range(_max_instances):
		_hide_index(i)

func set_slot(index: int, position: Vector2, radius: float, color: Color, rotation: float = 0.0, custom: Color = Color(0, 0, 0, 0)) -> void:
	if _mm == null:
		return
	if index < 0 or index >= _max_instances:
		return
	# Build Transform2D with local scaling by diameter
	var t := Transform2D(rotation, position)
	var sx: float = max(0.0, radius) * 2.0
	var sy: float = max(0.0, radius) * 2.0
	# Apply local (basis) scale without affecting translation
	t.x = t.x * sx
	t.y = t.y * sy
	_mm.set_instance_transform_2d(index, t)
	if _supports_instance_color:
		_mm.set_instance_color(index, color)
	if _supports_instance_custom:
		_mm.set_instance_custom_data(index, custom)

func hide_slot(index: int) -> void:
	if _mm == null:
		return
	_hide_index(index)

func commit() -> void:
	# MultiMesh updates are applied immediately; placeholder for future batched paths.
	pass

func _hide_index(index: int) -> void:
	if index < 0 or index >= _max_instances:
		return
	var t := Transform2D(0.0, Vector2.ZERO)
	# Zero the basis to collapse the instance
	t.x = Vector2.ZERO
	t.y = Vector2.ZERO
	_mm.set_instance_transform_2d(index, t)
	if _supports_instance_color:
		_mm.set_instance_color(index, Color(0, 0, 0, 0))
	if _supports_instance_custom:
		_mm.set_instance_custom_data(index, Color(0, 0, 0, 0))

# Capability probe and helpers

func _probe_capabilities() -> void:
	if _mm == null:
		return
	var log := get_node_or_null("/root/Log")
	var ok_color := false
	var ok_custom := false
	if _max_instances > 0:
		var idx := 0
		var prev_col: Color = _mm.get_instance_color(idx)
		var prev_cus: Color = _mm.get_instance_custom_data(idx)
		var test_col := Color(0.999, 0.0, 0.999, 1.0)
		var test_cus := Color(0.125, 0.25, 0.5, 0.75)
		_mm.set_instance_color(idx, test_col)
		var read_col := _mm.get_instance_color(idx)
		ok_color = (read_col == test_col)
		_mm.set_instance_custom_data(idx, test_cus)
		var read_cus := _mm.get_instance_custom_data(idx)
		ok_custom = (read_cus == test_cus)
		# restore previous
		_mm.set_instance_color(idx, prev_col)
		_mm.set_instance_custom_data(idx, prev_cus)
	# Combine with engine-reported flags
	var using_colors := _mm.is_using_colors()
	var using_custom := _mm.is_using_custom_data()
	_supports_instance_color = ok_color or using_colors
	_supports_instance_custom = ok_custom or using_custom
	if not _capability_logged:
		var parts := [
			"[BacteriaRenderer] caps",
			"instances=", _max_instances,
			"color=", _supports_instance_color,
			"custom=", _supports_instance_custom
		]
		if log != null:
			log.info(log.CAT_SYSTEMS, parts)
		else:
			var sb := []
			for p in parts:
				sb.append(str(p))
			print(" ".join(sb))
		_capability_logged = true
	# Fallback: uniform color via node modulate if per-instance color unsupported
	if not _supports_instance_color:
		modulate = Color(0.3, 0.8, 0.3, 1.0)

func get_capability_summary() -> String:
	return "instances=%d color=%s custom=%s" % [_max_instances, str(_supports_instance_color), str(_supports_instance_custom)]