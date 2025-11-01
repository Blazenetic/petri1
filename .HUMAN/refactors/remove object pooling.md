Refactor applied to remove pooling and switch to instantiate/queue_free. Summary of changes and state:

Files updated
- [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd)
  - Removed pooling infrastructure: _pools, _pool_container, _default_pool and any ObjectPool usage.
  - _ready now only resolves root parent and seeds _scene_map from ConfigurationManager.entity_scene_paths.
  - create_entity now loads the scene path, instantiate()’s a BaseEntity, parents to _root_parent before init, ensures IdentityComponent exists, calls init, updates PhysicalComponent, adds SpatialTrackerComponent, logs, registers with EntityRegistry, and emits GlobalEvents.entity_spawned. No pooling paths remain.
  - destroy_entity now deinit() → emit entity_destroyed → EntityRegistry.remove → remove from parent (if any) → queue_free(), maintaining prior ordering without pools.
  - register_entity_scene now only updates _scene_map (no reconfigure behavior).
- [scripts/components/BaseEntity.gd](scripts/components/BaseEntity.gd)
  - Removed unused signal ready_for_pool and the emit_signal call from deinit(). Cleanup loop remains intact.
- [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
  - Removed entity_pool_sizes and get_entity_pool_size(). entity_scene_paths and logging remain.
- [scripts/utils/ObjectPool.gd](scripts/utils/ObjectPool.gd)
  - Added deprecation header comment stating it is not used by the core entity lifecycle after refactor; retained as an optional utility for UI/effects.

Codebase verification
- Performed a project-wide search; no remaining references to:
  - ready_for_pool, ObjectPool in entity lifecycle, entity_pool_sizes, get_entity_pool_size, PoolContainer, acquire(), release(), _pools, or pool reconfigure logic.
- This satisfies the “No pool artifacts” and “No dangling signals” checks from the plan.

Behavior preserved
- Spawn/destroy ordering preserved: parent to tree before init so components attach in _ready, then init, then physical.update.
- Logging and GlobalEvents emissions kept the same to preserve dependent systems and debug flow.
- Identity creation check retained to guarantee ids for fresh instances.

Notes on performance
- As expected with instantiate/queue_free, allocations are now per spawn. MultiMesh RIS optimization remains a later, separate task per architecture v2.

Recommended manual checks (in-editor)
- Launch the game and verify:
  - Nutrient initial population: NutrientManager _ready triggers initial spawn to target_count (see [scripts/systems/NutrientManager.gd](scripts/systems/NutrientManager.gd)).
  - Reconcile and respawn continue to function: _on_reconcile_timeout and _on_respawn_timeout maintain counts and respawn on “consumed”.
  - EntityRegistry count_by_type returns expected values during gameplay.
  - No “PoolContainer” node exists at runtime and no errors referencing ready_for_pool or ObjectPool appear.

Acceptance criteria alignment
- Game should run without pooling errors and with spawn/destroy working under reconcile/respawn.
- No references to pooling remain in [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd) or [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd).
- [scripts/components/BaseEntity.gd](scripts/components/BaseEntity.gd) compiles and runs without ready_for_pool.
- ObjectPool remains available but clearly marked deprecated for core entity lifecycle.

If you want, I can proceed to: 
- capture a quick performance baseline (frame time with current nutrient/bacteria counts), and 
- start the follow-up RIS scaffolding per system_architecture_v2 (renderer registry and a basic MultiMeshInstance2D per species).