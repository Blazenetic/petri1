extends Node
class_name TestSpawner

const EntityTypes = preload("res://scripts/components/EntityTypes.gd")

@export var spawn_count: int = 20
@export var spawn_margin: float = 24.0
@export var initial_speed_variation: float = 0.4
@export var align_rotation: bool = true
@export var change_interval: float = 0.8
@export var accel_magnitude: float = 160.0
@export var entity_size: float = 8.0
@export var entity_size_jitter: float = 2.0

func _ready() -> void:
	# Seed RNG once for test runs to ensure wander/jitter use non-deterministic values
	randomize()
	_spawn_entities()

func _spawn_entities() -> void:
	if spawn_count <= 0:
		return
	var dish := _get_dish()
	for i in range(spawn_count):
		var pos := Vector2.ZERO
		if dish:
			pos = dish.dish_to_world(dish.get_random_point(spawn_margin))
		var id := EntityFactory.create_entity(EntityTypes.EntityType.BACTERIA, pos, {"size": _rand_size()})
		if id == StringName():
			continue
		var node := EntityRegistry.get_by_id(id) as BaseEntity
		if node == null:
			continue
		# Ensure MovementComponent exists (avoid duplicates if scene already provides it)
		var move: MovementComponent = null
		var comps := node.get_node_or_null("Components")
		if comps:
			for c in comps.get_children():
				if c is MovementComponent:
					move = c
					break
		if move == null:
			move = MovementComponent.new()
			node.add_component(move)
		move.align_rotation = align_rotation

		# Ensure RandomWander exists or update its params (avoid duplicates)
		var wander: RandomWander = null
		if comps:
			for c2 in comps.get_children():
				if c2 is RandomWander:
					wander = c2
					break
		if wander == null:
			wander = RandomWander.new()
			node.add_component(wander)
		wander.change_interval = change_interval
		wander.magnitude = accel_magnitude

		# Give a small initial nudge so entities start moving immediately
		move.velocity = _rand_unit() * move.max_speed * initial_speed_variation

func _get_dish() -> PetriDish:
	var nodes := get_tree().get_nodes_in_group("Dish")
	if nodes.size() > 0:
		return nodes[0] as PetriDish
	return null

func _rand_unit() -> Vector2:
	var v := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if v.length_squared() < 1e-6:
		return Vector2.RIGHT
	return v.normalized()

func _rand_size() -> float:
	return max(1.0, entity_size + randf_range(-entity_size_jitter, entity_size_jitter))