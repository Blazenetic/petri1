extends Node
const EntityTypes = preload("res://scripts/components/EntityTypes.gd")

const BASE_ENTITY_SCENE := "res://scenes/entities/BaseEntity.tscn"

var _pools: Dictionary = {}
var _root_parent: Node
var _pool_container: Node
var _default_pool: ObjectPool

func _ready() -> void:
	# Locate simulation attach point (compatible with Godot 4)
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		_root_parent = scene_root.find_child("DishContainer", true, false)
	if _root_parent == null:
		if scene_root:
			_root_parent = scene_root
		else:
			_root_parent = get_tree().get_root()
	
	# Container to hold pooled instances when inactive
	_pool_container = Node.new()
	_pool_container.name = "PoolContainer"
	add_child(_pool_container)
	
	# Default/fallback pool
	_default_pool = ObjectPool.new()
	add_child(_default_pool)
	_default_pool.configure(BASE_ENTITY_SCENE, 20, _pool_container)
	_pools[EntityTypes.EntityType.UNKNOWN] = _default_pool
	
	# Configure per-type pools (fallback safe if not defined yet)
	var sizes_dict: Dictionary = ConfigurationManager.entity_pool_sizes
	for t in sizes_dict.keys():
		var prewarm: int = int(sizes_dict[t])
		var pool := ObjectPool.new()
		add_child(pool)
		pool.configure(BASE_ENTITY_SCENE, prewarm, _pool_container)
		_pools[int(t)] = pool

func create_entity(entity_type: int, position: Vector2, params := {}) -> StringName:
	var pool: ObjectPool = _pools.get(entity_type, _default_pool)
	var node: BaseEntity = pool.acquire() as BaseEntity
	if node == null:
		return StringName()
	# Prepare instance
	node.entity_type = entity_type
	var merged: Dictionary = {"position": position}
	for k in params.keys():
		merged[k] = params[k]
	node.init(merged)
	# Ensure identity exists even if this is a freshly instantiated (non-prewarmed) node
	if node.identity == null:
		var ident := IdentityComponent.new()
		node.add_component(ident)
	# Move into live scene tree (now safe; node was detached from pool container on acquire)
	_root_parent.add_child(node)
	# Ensure transform is applied after entering the tree
	if node.physical != null:
		node.physical.update(0.0)
	var id: StringName = node.identity.uuid
	print("[EntityFactory] spawned ", id, " type=", entity_type, " pos=", position)
	EntityRegistry.add(id, node, entity_type)
	GlobalEvents.emit_signal("entity_spawned", id, entity_type, position)
	return id

func destroy_entity(entity_id: StringName, reason: StringName = &"despawn") -> void:
	var node: BaseEntity = EntityRegistry.get_by_id(entity_id) as BaseEntity
	if node == null:
		return
	node.deinit()
	GlobalEvents.emit_signal("entity_destroyed", entity_id, node.entity_type, reason)
	EntityRegistry.remove(entity_id)
	
	var pool: ObjectPool = _pools.get(node.entity_type, _default_pool)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	pool.release(node)
	print("[EntityFactory] destroyed id=", entity_id, " type=", node.entity_type, " reason=", reason)

# Convenience spawn helpers using PetriDish boundary and coordinate utilities

func _get_dish() -> PetriDish:
	var nodes := get_tree().get_nodes_in_group("Dish")
	if nodes.size() > 0:
		return nodes[0] as PetriDish
	return null

# Spawns an entity at a random point inside the dish, respecting a margin from the boundary
func create_entity_random(entity_type: int, margin: float = 0.0, params := {}) -> StringName:
	var dish := _get_dish()
	var pos_world := Vector2.ZERO
	if dish:
		var local := dish.get_random_point(margin)
		pos_world = dish.dish_to_world(local)
	return create_entity(entity_type, pos_world, params)

# Spawns an entity at the requested position but clamped to be inside the dish by entity_radius
func create_entity_clamped(entity_type: int, position: Vector2, entity_radius: float, params := {}) -> StringName:
	var pos_world := position
	var dish := _get_dish()
	if dish:
		var local := dish.world_to_dish(position)
		var clamped_local := dish.clamp_to_dish(local, entity_radius)
		pos_world = dish.dish_to_world(clamped_local)
	return create_entity(entity_type, pos_world, params)