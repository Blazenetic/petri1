extends Node
class_name SpatialGrid

const PRINT_INTERVAL_SEC := 5.0

var _cell_size: float = 64.0
var _dish: PetriDish

# Grid: Vector2i -> Array[StringName]
var _cells: Dictionary = {}

# Backrefs: StringName -> {cells: PackedVector2Array, position: Vector2, radius: float, type: int}
var _backrefs: Dictionary = {}

# Metrics
var _updates: int = 0
var _queries: int = 0
var _total_update_time_us: int = 0
var _total_query_time_us: int = 0
var _max_update_time_us: int = 0
var _max_query_time_us: int = 0

var _since_print: float = 0.0

func _ready() -> void:
	add_to_group("Spatial")
	set_process(true)
	# Auto-configure if possible
	var dish: PetriDish = _find_dish()
	if dish != null:
		configure(float(ConfigurationManager.grid_cell_size), dish)

func _process(delta: float) -> void:
	_since_print += delta
	if _since_print >= PRINT_INTERVAL_SEC:
		var avg_upd: float = float(_total_update_time_us) / float(max(_updates, 1))
		var avg_q: float = float(_total_query_time_us) / float(max(_queries, 1))
		print("[SpatialGrid] upd/s=", _updates / _since_print, " q/s=", _queries / _since_print,
			" avg_upd_us=", avg_upd, " avg_q_us=", avg_q,
			" max_upd_us=", _max_update_time_us, " max_q_us=", _max_query_time_us,
			" cells=", _cells.size(), " entities=", _backrefs.size())
		_since_print = 0.0
		_updates = 0
		_queries = 0
		_total_update_time_us = 0
		_total_query_time_us = 0
		_max_update_time_us = 0
		_max_query_time_us = 0

# Public API

func configure(cell_size: float, dish: PetriDish) -> void:
	_cell_size = max(1.0, cell_size)
	_dish = dish

func add_entity(entity_id: StringName, position: Vector2, radius: float, entity_type: int = 0) -> void:
	var t0: int = Time.get_ticks_usec()
	if _backrefs.has(entity_id):
		remove_entity(entity_id)
	var cells: PackedVector2Array = _compute_covering_cells(_to_local(position), radius)
	for c in cells:
		_insert_into_cell(Vector2i(c), entity_id)
	_backrefs[entity_id] = {
		"cells": cells,
		"position": position,
		"radius": float(max(0.0, radius)),
		"type": int(entity_type)
	}
	var dt: int = Time.get_ticks_usec() - t0
	_updates += 1
	_total_update_time_us += dt
	_max_update_time_us = int(max(_max_update_time_us, dt))

func remove_entity(entity_id: StringName) -> void:
	var t0: int = Time.get_ticks_usec()
	var rec: Dictionary = _backrefs.get(entity_id, {})
	if rec.is_empty():
		return
	var cells: PackedVector2Array = rec.get("cells", PackedVector2Array())
	for c in cells:
		_erase_from_cell(Vector2i(c), entity_id)
	_backrefs.erase(entity_id)
	var dt: int = Time.get_ticks_usec() - t0
	_updates += 1
	_total_update_time_us += dt
	_max_update_time_us = int(max(_max_update_time_us, dt))

func update_entity_position(entity_id: StringName, position: Vector2, radius: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var rec: Dictionary = _backrefs.get(entity_id, {})
	var new_cells: PackedVector2Array = _compute_covering_cells(_to_local(position), radius)
	if rec.is_empty():
		# Treat as add
		for c in new_cells:
			_insert_into_cell(Vector2i(c), entity_id)
		_backrefs[entity_id] = {
			"cells": new_cells,
			"position": position,
			"radius": float(max(0.0, radius)),
			"type": 0
		}
	else:
		var old_cells: PackedVector2Array = rec.get("cells", PackedVector2Array())
		var to_remove: PackedVector2Array = _diff_cells(old_cells, new_cells)
		var to_add: PackedVector2Array = _diff_cells(new_cells, old_cells)
		for c in to_remove:
			_erase_from_cell(Vector2i(c), entity_id)
		for c in to_add:
			_insert_into_cell(Vector2i(c), entity_id)
		rec["cells"] = new_cells
		rec["position"] = position
		rec["radius"] = float(max(0.0, radius))
		_backrefs[entity_id] = rec
	var dt: int = Time.get_ticks_usec() - t0
	_updates += 1
	_total_update_time_us += dt
	_max_update_time_us = int(max(_max_update_time_us, dt))

func get_entities_in_cell(cell: Vector2i) -> Array:
	return _cells.get(cell, []).duplicate()

func get_entities_in_adjacent_cells(cell: Vector2i) -> Array:
	var set: Dictionary = {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
			var arr: Array = _cells.get(c, [])
			for id in arr:
				set[id] = true
	return set.keys()

func get_entities_in_radius(center_world: Vector2, radius: float, type_filter: Array = []) -> Array:
	var t0: int = Time.get_ticks_usec()
	var res: Dictionary = {}
	if _dish == null:
		return []
	var local: Vector2 = _dish.world_to_dish(center_world)
	var r: float = float(max(0.0, radius))
	var pad: float = _cell_size # conservative one-cell padding
	var min_cell: Vector2i = Vector2i(floor((local.x - r - pad) / _cell_size), floor((local.y - r - pad) / _cell_size))
	var max_cell: Vector2i = Vector2i(floor((local.x + r + pad) / _cell_size), floor((local.y + r + pad) / _cell_size))
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var cell: Vector2i = Vector2i(cx, cy)
			# quick reject by cell center far outside dish
			var center_local: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size
			if center_local.length() > _dish.get_radius() + 1.5 * _cell_size:
				continue
			var arr: Array = _cells.get(cell, [])
			for id in arr:
				if res.has(id):
					continue
				var rec: Dictionary = _backrefs.get(id, {})
				if rec.is_empty():
					continue
				if not type_filter.is_empty():
					var tval: int = int(rec.get("type", 0))
					if not type_filter.has(tval):
						continue
				var pos: Vector2 = rec.get("position", Vector2.ZERO)
				var dist: float = pos.distance_to(center_world)
				if dist <= r:
					var pos_local: Vector2 = _dish.world_to_dish(pos)
					if _dish.is_inside_dish(pos_local):
						res[id] = true
	var dt: int = Time.get_ticks_usec() - t0
	_queries += 1
	_total_query_time_us += dt
	_max_query_time_us = int(max(_max_query_time_us, dt))
	return res.keys()

func get_cell_at_world(p_world: Vector2) -> Vector2i:
	if _dish == null:
		return Vector2i.ZERO
	var local: Vector2 = _dish.world_to_dish(p_world)
	return Vector2i(floor(local.x / _cell_size), floor(local.y / _cell_size))

func get_cell_bounds(cell: Vector2i) -> Rect2:
	var origin: Vector2 = Vector2(cell.x * _cell_size, cell.y * _cell_size)
	return Rect2(origin, Vector2(_cell_size, _cell_size))

func get_cell_size() -> float:
	return _cell_size

func get_metrics() -> Dictionary:
	return {
		"updates": _updates,
		"queries": _queries,
		"total_update_time_us": _total_update_time_us,
		"total_query_time_us": _total_query_time_us,
		"max_update_time_us": _max_update_time_us,
		"max_query_time_us": _max_query_time_us
	}

# Internal helpers

func _find_dish() -> PetriDish:
	var nodes: Array = get_tree().get_nodes_in_group("Dish")
	if nodes.size() > 0:
		return nodes[0] as PetriDish
	return null

func _to_local(p_world: Vector2) -> Vector2:
	if _dish == null:
		return p_world
	return _dish.world_to_dish(p_world)

func _compute_covering_cells(local_pos: Vector2, radius: float) -> PackedVector2Array:
	var r: float = float(max(0.0, radius))
	var min_x: int = int(floor((local_pos.x - r) / _cell_size))
	var max_x: int = int(floor((local_pos.x + r) / _cell_size))
	var min_y: int = int(floor((local_pos.y - r) / _cell_size))
	var max_y: int = int(floor((local_pos.y + r) / _cell_size))
	var out: PackedVector2Array = PackedVector2Array()
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			out.push_back(Vector2i(x, y))
	return out

func _diff_cells(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var set_b: Dictionary = {}
	for v in b:
		set_b[v] = true
	var out: PackedVector2Array = PackedVector2Array()
	for v in a:
		if not set_b.has(v):
			out.push_back(v)
	return out

func _insert_into_cell(cell: Vector2i, id: StringName) -> void:
	var arr: Array = _cells.get(cell, [])
	# Avoid duplicates
	var present: bool = false
	for existing in arr:
		if existing == id:
			present = true
			break
	if not present:
		arr.append(id)
		_cells[cell] = arr

func _erase_from_cell(cell: Vector2i, id: StringName) -> void:
	if not _cells.has(cell):
		return
	var arr: Array = _cells[cell]
	arr.erase(id)
	if arr.is_empty():
		_cells.erase(cell)
	else:
		_cells[cell] = arr