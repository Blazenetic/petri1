extends Node
class_name ObjectPool
# DEPRECATION: Not used by core entity lifecycle (EMS) after refactor to instantiate/queue_free.
# Retained for UI/effects or other non-simulation pooling. See [system_architecture_v2.md](AGENTS/system_architecture_v2.md:44).
# Safe to keep as an optional utility; remove any core dependencies.

var _scene: PackedScene
var _available: Array[Node] = []
var _in_use: Array[Node] = []
var _container: Node

func configure(scene_path: String, prewarm_count: int, container: Node) -> void:
	_scene = load(scene_path)
	_container = container
	_available.clear()
	_in_use.clear()
	for i in range(prewarm_count):
		var n: Node = _scene.instantiate()
		if n is CanvasItem:
			(n as CanvasItem).visible = false
		_container.add_child(n)
		_available.append(n)

func acquire() -> Node:
	var n: Node = _scene.instantiate() if _available.is_empty() else _available.pop_back()
	_in_use.append(n)
	# Detach from pool container so caller can reparent to live tree
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	if n is CanvasItem:
		(n as CanvasItem).visible = true
	return n

func release(n: Node) -> void:
	if n in _in_use:
		_in_use.erase(n)
	if n.get_parent() != _container:
		if n.get_parent():
			n.get_parent().remove_child(n)
		_container.add_child(n)
	if n is CanvasItem:
		(n as CanvasItem).visible = false
	_available.append(n)