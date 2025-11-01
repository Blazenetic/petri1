extends Node
const EntityTypes = preload("res://scripts/components/EntityTypes.gd")

const BASE_ENTITY_SCENE := "res://scenes/entities/BaseEntity.tscn"
const LogDefs = preload("res://scripts/systems/Log.gd")
var _log

# Per-type scene mapping (PHASE 2.1)
var _scene_map: Dictionary = {}
 
var _root_parent: Node
var _pool_container: Node
var _default_pool: ObjectPool
var _bacteria_system: Node

func _ready() -> void:
	_log = get_node_or_null("/root/Log")
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
	# Guardrail: bacteria pooling must be disabled when multimesh is active
	if ConfigurationManager.is_bacteria_multimesh_enabled():
		assert(not sizes_dict.has(EntityTypes.EntityType.BACTERIA), "Bacteria pool must be disabled in multimesh mode")
		if _log != null and sizes_dict.has(EntityTypes.EntityType.BACTERIA):
			_log.warn(LogDefs.CAT_SYSTEMS, ["[EntityFactory] bacteria pooling entry present with multimesh; assertion in dev, ignored in release"])

	# Seed internal scene map from configuration if present
	if "entity_scene_paths" in ConfigurationManager:
		for k in ConfigurationManager.entity_scene_paths.keys():
			_scene_map[int(k)] = String(ConfigurationManager.entity_scene_paths[k])

	# Cache BacteriaSystem when multimesh is active (pooling for bacteria is disabled)
	if ConfigurationManager.is_bacteria_multimesh_enabled():
		_bacteria_system = null
		var scene_root2: Node = get_tree().current_scene
		if scene_root2:
			_bacteria_system = scene_root2.find_child("BacteriaSystem", true, false)
		if _bacteria_system == null and _log != null:
			_log.warn(LogDefs.CAT_SYSTEMS, ["[EntityFactory] multimesh enabled but BacteriaSystem not found"])

func create_entity(entity_type: int, position: Vector2, params := {}) -> StringName:
	# Multimesh path for bacteria: route to BacteriaSystem, do not instance nodes/components
	if ConfigurationManager.is_bacteria_multimesh_enabled() and int(entity_type) == EntityTypes.EntityType.BACTERIA:
		if _bacteria_system != null and _bacteria_system.has_method("spawn_bacteria"):
			return _bacteria_system.spawn_bacteria(position, params)
		return StringName()

	var pool: ObjectPool = _pools.get(entity_type, _default_pool)
	var node: BaseEntity = pool.acquire() as BaseEntity
	if node == null:
		return StringName()
	# Prepare instance
	node.entity_type = entity_type
	var merged: Dictionary = {"position": position}
	for k in params.keys():
		merged[k] = params[k]
	# Move into live scene tree first so _ready runs and components are attached
	_root_parent.add_child(node)
	# Ensure identity exists even if this is a freshly instantiated node
	if node.identity == null:
		var ident: IdentityComponent = IdentityComponent.new()
		node.add_component(ident)
	# Now safe to initialize with params (PhysicalComponent present)
	node.init(merged)
	# Ensure transform is applied after entering the tree
	if node.physical != null:
		node.physical.update(0.0)
	# Attach spatial tracker so entities register with SpatialGrid
	var tracker: SpatialTrackerComponent = SpatialTrackerComponent.new()
	node.add_component(tracker)
	var id: StringName = node.identity.uuid
	if _log != null and _log.enabled(LogDefs.CAT_SYSTEMS, LogDefs.LEVEL_DEBUG):
		_log.debug(LogDefs.CAT_SYSTEMS, [
			"[EntityFactory] spawned",
			"id=", id,
			"type=", entity_type,
			"pos=", position
		])
	EntityRegistry.add(id, node, entity_type)
	GlobalEvents.emit_signal("entity_spawned", id, entity_type, position)
	return id

func destroy_entity(entity_id: StringName, reason: StringName = &"despawn") -> void:
	var node: BaseEntity = EntityRegistry.get_by_id(entity_id) as BaseEntity
	if node == null:
		# Multimesh path: delegate to BacteriaSystem (EntityRegistry won't have bacteria entries)
		if ConfigurationManager.is_bacteria_multimesh_enabled() and _bacteria_system != null and _bacteria_system.has_method("despawn_bacteria"):
			_bacteria_system.despawn_bacteria(entity_id, reason)
		return
	node.deinit()
	GlobalEvents.emit_signal("entity_destroyed", entity_id, node.entity_type, reason)
	EntityRegistry.remove(entity_id)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()
	if _log != null:
		_log.info(LogDefs.CAT_SYSTEMS, [
			"[EntityFactory] destroyed",
			"id=", entity_id,
			"type=", node.entity_type,
			"reason=", reason
		])

# Convenience spawn helpers using PetriDish boundary and coordinate utilities

func _get_dish() -> PetriDish:
	var nodes: Array = get_tree().get_nodes_in_group("Dish")
	if nodes.size() > 0:
		return nodes[0] as PetriDish
	return null

# Spawns an entity at a random point inside the dish, respecting a margin from the boundary
func create_entity_random(entity_type: int, margin: float = 0.0, params := {}) -> StringName:
	var dish: PetriDish = _get_dish()
	var pos_world: Vector2 = Vector2.ZERO
	if dish:
		var local: Vector2 = dish.get_random_point(margin)
		pos_world = dish.dish_to_world(local)
	return create_entity(entity_type, pos_world, params)

# Spawns an entity at the requested position but clamped to be inside the dish by entity_radius
func create_entity_clamped(entity_type: int, position: Vector2, entity_radius: float, params := {}) -> StringName:
	var pos_world: Vector2 = position
	var dish: PetriDish = _get_dish()
	if dish:
		var local: Vector2 = dish.world_to_dish(position)
		var clamped_local: Vector2 = dish.clamp_to_dish(local, entity_radius)
		pos_world = dish.dish_to_world(clamped_local)
	return create_entity(entity_type, pos_world, params)

# Register/override a scene path for a specific entity type (PHASE 2.1)
func register_entity_scene(entity_type: int, scene_path: String) -> void:
	_scene_map[int(entity_type)] = scene_path

func get_scene_path_for_type(entity_type: int) -> String:
	return String(_scene_map.get(int(entity_type), BASE_ENTITY_SCENE))