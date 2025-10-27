extends Node

var _by_id: Dictionary = {}
var _by_type: Dictionary = {}

func add(id: StringName, entity: Node, entity_type: int) -> void:
	_by_id[id] = entity
	if not _by_type.has(entity_type):
		_by_type[entity_type] = []
	_by_type[entity_type].append(entity)

func remove(id: StringName) -> void:
	if not _by_id.has(id):
		return
	var ent: Node = _by_id[id]
	_by_id.erase(id)
	for t in _by_type.keys():
		_by_type[t].erase(ent)

func get_by_id(id: StringName) -> Node:
	return _by_id.get(id, null)

func get_all_by_type(entity_type: int) -> Array:
	return _by_type.get(entity_type, [])

func count_by_type(entity_type: int) -> int:
	return get_all_by_type(entity_type).size()