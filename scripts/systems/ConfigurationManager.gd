extends Node
const EntityTypes = preload("res://scripts/components/EntityTypes.gd")

# Environment/dish configuration
@export var dish_radius: float = 480.0
@export var grid_cell_size: float = 64.0
@export var grid_debug_heatmap_default: bool = false
@export var grid_debug_counts_default: bool = false

# Nutrient system configuration (PHASE 2.1)
@export var nutrient_target_count: int = 20
@export var nutrient_spawn_margin: float = 16.0
@export var nutrient_size_min: float = 3.0
@export var nutrient_size_max: float = 8.0
@export var nutrient_energy_min: float = 2.0
@export var nutrient_energy_max: float = 6.0
@export var nutrient_respawn_delay_min: float = 0.5
@export var nutrient_respawn_delay_max: float = 3.0
# Distribution enum { RANDOM = 0, CLUSTERED = 1, UNIFORM = 2 }
@export var nutrient_distribution_mode: int = 0
@export var nutrient_clustered_cluster_count: int = 6
@export var nutrient_clustered_spread: float = 48.0
@export var nutrient_uniform_cell_size: float = 48.0

# Pool sizes per entity type (existing)
var entity_pool_sizes: Dictionary = {
	EntityTypes.EntityType.BACTERIA: 300,
	EntityTypes.EntityType.NUTRIENT: 200
}

# Optional per-type scene mapping (PHASE 2.1)
# Allows EntityFactory to instance specific scenes for each entity type.
var entity_scene_paths: Dictionary = {
	EntityTypes.EntityType.BACTERIA: "res://scenes/entities/Bacteria.tscn",
	EntityTypes.EntityType.NUTRIENT: "res://scenes/entities/Nutrient.tscn"
}

func get_entity_pool_size(entity_type: int) -> int:
	return int(entity_pool_sizes.get(entity_type, 20))

func get_entity_scene_path(entity_type: int) -> String:
	return String(entity_scene_paths.get(entity_type, ""))

func _ready() -> void:
	print("[ConfigurationManager] ready")
	print("[ConfigurationManager] entity_pool_sizes =", entity_pool_sizes)
	print("[ConfigurationManager] grid_cell_size =", grid_cell_size, " heatmap_default=", grid_debug_heatmap_default, " counts_default=", grid_debug_counts_default)
	print("[ConfigurationManager] nutrient_target_count =", nutrient_target_count,
		" size=[", nutrient_size_min, ",", nutrient_size_max, "]",
		" energy=[", nutrient_energy_min, ",", nutrient_energy_max, "]",
		" respawn_s=[", nutrient_respawn_delay_min, ",", nutrient_respawn_delay_max, "]",
		" dist_mode=", nutrient_distribution_mode)
	print("[ConfigurationManager] entity_scene_paths =", entity_scene_paths)