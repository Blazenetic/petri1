extends Node
class_name BacteriaStore

signal spawned(id: StringName, index: int)
signal destroyed(id: StringName, index: int)

var max_instances: int = 0
var active_count: int = 0

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var radii: PackedFloat32Array = PackedFloat32Array()
var colors: PackedColorArray = PackedColorArray()
var custom_data: PackedColorArray = PackedColorArray()
var alive: PackedInt32Array = PackedInt32Array()

# Simple wander support (Phase A)
var change_timer: PackedFloat32Array = PackedFloat32Array()
var direction: PackedVector2Array = PackedVector2Array()

# Indexing
var id_by_index: Array[StringName] = []
var index_by_id: Dictionary = {}
var free_list: Array[int] = []

# O(1) active traversal
var active_indices: Array[int] = []
var pos_in_active: PackedInt32Array = PackedInt32Array()

var _seq: int = 0

func init(count: int) -> void:
	max_instances = int(max(0, count))
	active_count = 0

	positions.resize(max_instances)
	velocities.resize(max_instances)
	radii.resize(max_instances)
	colors.resize(max_instances)
	custom_data.resize(max_instances)
	alive.resize(max_instances)
	change_timer.resize(max_instances)
	direction.resize(max_instances)
	pos_in_active.resize(max_instances)

	id_by_index.resize(max_instances)
	index_by_id.clear()
	free_list.clear()
	active_indices.clear()

	for i in range(max_instances):
		positions[i] = Vector2.ZERO
		velocities[i] = Vector2.ZERO
		radii[i] = 0.0
		colors[i] = Color(0, 0, 0, 0)
		custom_data[i] = Color(0, 0, 0, 0)
		alive[i] = 0
		change_timer[i] = 0.0
		direction[i] = Vector2.ZERO
		id_by_index[i] = StringName()
		pos_in_active[i] = -1
		# reverse fill so pop_back yields 0..N-1 order
		free_list.append(max_instances - 1 - i)

func allocate(initial_pos: Vector2, radius: float, color: Color, custom: Color = Color(0, 0, 0, 0)) -> Dictionary:
	if free_list.is_empty():
		return {}
	var idx: int = free_list.pop_back()
	var id := StringName("bact_" + str(_seq))
	_seq += 1

	positions[idx] = initial_pos
	velocities[idx] = Vector2.ZERO
	radii[idx] = float(max(0.0, radius))
	colors[idx] = color
	custom_data[idx] = custom
	alive[idx] = 1
	change_timer[idx] = 0.0
	direction[idx] = Vector2.ZERO

	id_by_index[idx] = id
	index_by_id[id] = idx

	# Track active
	pos_in_active[idx] = active_indices.size()
	active_indices.append(idx)
	active_count = active_indices.size()

	emit_signal("spawned", id, idx)
	return {"id": id, "index": idx}

func free_by_id(id: StringName) -> void:
	var idx: int = int(index_by_id.get(id, -1))
	if idx >= 0:
		free_by_index(idx)

func free_by_index(idx: int) -> void:
	if idx < 0 or idx >= max_instances:
		return
	if alive[idx] == 0:
		return
	var id: StringName = id_by_index[idx]

	alive[idx] = 0
	positions[idx] = Vector2.ZERO
	velocities[idx] = Vector2.ZERO
	radii[idx] = 0.0
	colors[idx] = Color(0, 0, 0, 0)
	custom_data[idx] = Color(0, 0, 0, 0)
	change_timer[idx] = 0.0
	direction[idx] = Vector2.ZERO

	index_by_id.erase(id)
	id_by_index[idx] = StringName()

	# Return to free list
	free_list.append(idx)

	# Remove from active_indices in O(1)
	var pos := int(pos_in_active[idx])
	if pos >= 0:
		var last_idx: int = active_indices[active_indices.size() - 1]
		active_indices[pos] = last_idx
		pos_in_active[last_idx] = pos
		active_indices.pop_back()
		pos_in_active[idx] = -1
	active_count = active_indices.size()

	emit_signal("destroyed", id, idx)

func is_alive_index(idx: int) -> bool:
	return idx >= 0 and idx < max_instances and alive[idx] != 0

func get_index_by_id(id: StringName) -> int:
	return int(index_by_id.get(id, -1))

func get_id_by_index(idx: int) -> StringName:
	if idx < 0 or idx >= max_instances:
		return StringName()
	return id_by_index[idx]

func get_active_indices() -> Array[int]:
	return active_indices

# Convenience mutators

func set_color(idx: int, c: Color) -> void:
	if is_alive_index(idx):
		colors[idx] = c

func set_radius(idx: int, r: float) -> void:
	if is_alive_index(idx):
		radii[idx] = float(max(0.0, r))

func set_custom(idx: int, c: Color) -> void:
	if is_alive_index(idx):
		custom_data[idx] = c