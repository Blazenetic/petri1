extends Node
const EntityTypes = preload("res://scripts/components/EntityTypes.gd")

@export var dish_radius: float = 480.0
@export var grid_cell_size: float = 64.0

var entity_pool_sizes: Dictionary = {
	EntityTypes.EntityType.BACTERIA: 50,
	EntityTypes.EntityType.NUTRIENT: 200
}

func get_entity_pool_size(entity_type: int) -> int:
	return int(entity_pool_sizes.get(entity_type, 20))

func _ready() -> void:
	print("[ConfigurationManager] ready")
	print("[ConfigurationManager] entity_pool_sizes =", entity_pool_sizes)