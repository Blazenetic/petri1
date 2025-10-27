Phase 2.1 Nutrient System implemented and integrated.

What was added/modified
- New scene: [scenes/entities/Nutrient.tscn](scenes/entities/Nutrient.tscn) inheriting BaseEntity with defaults (entity_type=NUTRIENT, size/color) and pre-attached NutrientComponent.
- New component: [scripts/components/NutrientComponent.gd](scripts/components/NutrientComponent.gd)
  - Listens for Area2D overlaps on its host, detects BACTERIA, emits GlobalEvents.nutrient_consumed, plays shrink/fade tween, then calls [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:82) with reason "consumed".
- New system: [scripts/systems/NutrientManager.gd](scripts/systems/NutrientManager.gd)
  - Maintains target density, handles initial spawn, respawn on consumption, and periodic reconciliation. Provides Random, Clustered, and Uniform distributions using PetriDish utilities: [PetriDish.get_random_point()](scripts/environments/PetriDish.gd:92), [PetriDish.clamp_to_dish()](scripts/environments/PetriDish.gd:66), [PetriDish.is_inside_dish()](scripts/environments/PetriDish.gd:61).
  - Emits GlobalEvents.nutrient_spawned on each spawn; listens for entity_destroyed(consumed) to schedule respawns.
- Configuration: [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
  - Added exported nutrient parameters (target count, size/energy ranges, respawn delays, distribution settings) and an optional per-type scene mapping that points NUTRIENT to Nutrient.tscn.
- Global events: [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd)
  - Added signals: nutrient_spawned(entity_id, position, energy) and nutrient_consumed(entity_id, consumer_id).
- Factory pooling: [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd)
  - Per-type scene mapping support with _scene_map and register_entity_scene(). Pools now prewarm using the mapped scene when present. Keeps existing behavior including SpatialTracker attach.
- Base entity: [scripts/components/BaseEntity.gd](scripts/components/BaseEntity.gd)
  - Now initializes any editor-attached EntityComponent children under the “Components” node to support NutrientComponent being pre-attached in the Nutrient scene.
- Main scene wiring: [scenes/Main.tscn](scenes/Main.tscn)
  - Added NutrientManager under SystemsContainer so it runs at startup.

Key behaviors and flow
- Spawn
  - NutrientManager spawns up to target_count using distribution_mode. On each spawn, size and energy are randomized within configured ranges. Emits nutrient_spawned and registers entity via factory ([EntityFactory.create_entity()](scripts/systems/EntityFactory.gd:52)).
- Consumption
  - When a BACTERIA overlaps a nutrient, NutrientComponent emits nutrient_consumed, plays a brief tween (size to 0, fade out), then destroys itself via factory ([EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:82)).
- Respawn and density control
  - NutrientManager listens for entity_destroyed with reason "consumed" and schedules a respawn after a randomized delay. A periodic reconcile timer checks [EntityRegistry.count_by_type()](scripts/systems/EntityRegistry.gd:26) and tops up if under target density.

Distribution details
- Random: uniform sampling inside dish with margin via [PetriDish.get_random_point()](scripts/environments/PetriDish.gd:92).
- Clustered: picks random cluster centers, offsets points within clustered_spread, clamps via [PetriDish.clamp_to_dish()](scripts/environments/PetriDish.gd:66).
- Uniform: jittered grid across dish-local space, filtered by [PetriDish.is_inside_dish()](scripts/environments/PetriDish.gd:61).

Editor/Config usage
- Parameters appear on ConfigurationManager and NutrientManager. Designer defaults are in [ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd) and can be tweaked at runtime on the NutrientManager node in [scenes/Main.tscn](scenes/Main.tscn).
- Per-type scene mapping included for NUTRIENT → Nutrient.tscn, enabling a dedicated pool.

Testing suggestions
- Run the project; NutrientManager should auto-spawn nutrients. Bacteria from [scripts/utils/TestSpawner.gd](scripts/utils/TestSpawner.gd) can be moved or will wander to overlap nutrients; consumption should shrink/fade before removal.
- Change distribution at runtime by editing NutrientManager.distribution_mode in the editor or by updating [ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd) defaults and restarting.
- Verify counts/logs
  - Spawns/destroys are logged. Registry counts rely on [EntityRegistry.count_by_type()](scripts/systems/EntityRegistry.gd:26).
- SpatialGrid integration remains automatic via SpatialTrackerComponent.

Notes and considerations
- Pools reconfigured via register_entity_scene() will reuse the same ObjectPool instance; existing pooled instances are not freed to avoid spikes. If later needed, a migration step can clean old instances.
- Tween duration defaults are short (0.2s) for responsiveness; adjust on [NutrientComponent.gd](scripts/components/NutrientComponent.gd) if you want slower feedback.
- Collision layers/masks remain 1 for Area2D interactions consistent with BaseEntity and existing bacteria.

This completes the Phase 2.1 tasks outlined in [AGENTS/phase_2.1.md](AGENTS/phase_2.1.md) including scene, component, manager, config, events, factory pooling, overlap consumption, visual feedback, respawn logic, and distribution patterns.