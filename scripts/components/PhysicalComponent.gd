extends "res://scripts/components/EntityComponent.gd"
class_name PhysicalComponent

var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var size: float = 8.0
var mass: float = 1.0
var _owner_area: Area2D

func init(entity: Node) -> void:
	_owner_area = entity as Area2D
	if _owner_area:
		position = _owner_area.global_position
		rotation = _owner_area.rotation

func update(delta: float) -> void:
	if _owner_area:
		_owner_area.global_position = position
		_owner_area.rotation = rotation
		var collider := _owner_area.get_node_or_null("Collider") as CollisionShape2D
		if collider and collider.shape is CircleShape2D:
			var circle := collider.shape as CircleShape2D
			if circle:
				circle.radius = size

func cleanup() -> void:
	_owner_area = null