# Phase 2.1 — Nutrient System Implementation Guide (Godot 4.5)

Purpose
- Implement the Nutrient System per PHASE 2.1 requirements, integrating with existing foundation built in Phase 1.
- Deliver reusable, performant spawning/density control, Area2D-based consumption detection, visual feedback, and multiple distribution patterns.

Primary dependencies
- Base entity and components: [BaseEntity.gd](scripts/components/BaseEntity.gd), [BaseEntity.deinit()](scripts/components/BaseEntity.gd:79)
- Factory/Pooling: [EntityFactory.create_entity()](scripts/systems/EntityFactory.gd:42), [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:72), [ObjectPool.gd](scripts/utils/ObjectPool.gd)
- Registry: [EntityRegistry.count_by_type()](scripts/systems/EntityRegistry.gd:26)
- Spatial queries: [SpatialGrid.get_entities_in_radius()](scripts/systems/SpatialGrid.gd:132)
- Dish geometry/utilities: [PetriDish.get_random_point()](scripts/environments/PetriDish.gd:92), [PetriDish.clamp_to_dish()](scripts/environments/PetriDish.gd:66)
- Types and config: [EntityTypes.gd](scripts/components/EntityTypes.gd), [ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
- Events: [GlobalEvents.gd](scripts/systems/GlobalEvents.gd)

Outcomes mapped to PHASE 2.1 checklist
- Create Nutrient scene inheriting from BaseEntity
- Implement NutrientManager with spawn patterns and density control
- Add nutrient energy value and size variations
- Create nutrient consumption detection via Area2D overlap
- Implement nutrient respawn system with configurable timer
- Add visual feedback for nutrient consumption (shrink/fade)
- Create nutrient distribution patterns (random, clustered, uniform)

High-level decisions
- Scene and pooling
  - Introduce a dedicated Nutrient scene that inherits from BaseEntity for editor clarity and per-type defaults.
  - Extend EntityFactory to support per-entity-type scene mapping so nutrients come from a nutrient-specific pool, not the generic BaseEntity scene.
- Consumption detection
  - Implement on-nutrient Area2D overlap detection to trigger consumption when contacted by a consumer type (initially BACTERIA).
- Density control and respawn
  - Maintain a target active nutrient count; replenish on destroy or on periodic reconciliation.
- Performance
  - Use existing pooling and spatial grid systems; keep per-frame logic minimal and leverage timers for respawn.

Mermaid flow
flowchart TD
  A[Spawn nutrients] --> B[Entities move]
  B --> C{Area2D overlap with consumer}
  C -->|Yes| D[Emit nutrient_consumed event]
  D --> E[Shrink/fade visual]
  E --> F[Destroy entity and return to pool]
  F --> G[Manager schedules respawn]
  C -->|No| B


1. Files and assets to add

1.1 Scene: Nutrient
- Path: scenes/entities/Nutrient.tscn
- Inherits: BaseEntity from [BaseEntity.tscn](scenes/entities/BaseEntity.tscn)
- Defaults:
  - entity_type = EntityTypes.NUTRIENT
  - size = 4.0 to 10.0 (final per manager)
  - base_color = neutral nutrient color (e.g., soft cyan)
- Rationale: Provides per-type defaults and future room for visual polish while reusing [BaseEntity.gd](scripts/components/BaseEntity.gd)

1.2 Component: NutrientComponent
- Path: scripts/components/NutrientComponent.gd
- Extends: EntityComponent (same base used by other components)
- Responsibilities:
  - Store nutrient energy_value (float)
  - Connect to Area2D area_entered signal on host BaseEntity to detect consumer overlap
  - On valid consumer, trigger consumption flow:
    - Emit GlobalEvents.nutrient_consumed
    - Start shrink/fade animation
    - After animation completes, call [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:72) on own identity.uuid with reason "consumed"
- Notes:
  - Do not call destroy before visual feedback completes
  - Avoid heavy processing in update; the component is mostly event-driven

1.3 System: NutrientManager
- Path: scripts/systems/NutrientManager.gd
- Node placement: Child of SystemsContainer in Main scene (scenes/Main.tscn)
- Responsibilities:
  - Maintain target active count of nutrients
  - Spawn initial nutrients on ready
  - Implement distribution patterns: random, clustered, uniform
  - Listen to GlobalEvents.entity_destroyed and schedule respawns when nutrients are consumed
  - Periodically reconcile active count using [EntityRegistry.count_by_type()](scripts/systems/EntityRegistry.gd:26)
- Exported parameters:
  - target_count: int (e.g., 150)
  - spawn_margin: float (e.g., 16.0; consider [PetriDish.spawn_margin_default](scripts/environments/PetriDish.gd:8))
  - size_min/max: float range (e.g., 3.0 to 8.0)
  - energy_min/max: float range (e.g., 2.0 to 6.0)
  - respawn_delay_min/max: float (seconds; e.g., 0.5 to 3.0)
  - distribution_mode: int enum { RANDOM=0, CLUSTERED=1, UNIFORM=2 }
  - clustered_cluster_count: int (e.g., 6)
  - clustered_spread: float (e.g., 48.0)
  - uniform_cell_size: float (e.g., 48.0)
- Public methods (for future tools/tests):
  - spawn_now(count, mode_override?) → spawns immediately following pattern rules
  - set_target_count(n) → adjusts density
  - set_distribution(mode) → switches pattern

1.4 Configuration updates
- Update [ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd) to expose nutrient parameters as exported defaults so designers can tweak:
  - nutrient_target_count: int
  - nutrient_size_min/max: float
  - nutrient_energy_min/max: float
  - nutrient_respawn_delay_min/max: float
  - nutrient_distribution_mode: int
  - nutrient_spawn_margin: float
- Add optional entity_scene_paths: Dictionary mapping entity type to scene paths, e.g.:
  - EntityTypes.NUTRIENT → "res://scenes/entities/Nutrient.tscn"
- Keep existing pool sizes for NUTRIENT already present in [ConfigurationManager.entity_pool_sizes](scripts/systems/ConfigurationManager.gd:9)

1.5 Global events
- Extend [GlobalEvents.gd](scripts/systems/GlobalEvents.gd) with nutrient-specific signals:
  - signal nutrient_spawned(entity_id: StringName, position: Vector2, energy: float)
  - signal nutrient_consumed(entity_id: StringName, consumer_id: StringName)
- Emit from NutrientManager on spawn and from NutrientComponent on consumption.


2. Modifications to existing systems

2.1 EntityFactory per-type scene mapping
- Update [EntityFactory.gd](scripts/systems/EntityFactory.gd) to support scene-per-type pooling:
  - Maintain a _scene_map: Dictionary { entity_type: scene_path }
  - Initialize pools using per-type scene paths if provided; fallback to BASE_ENTITY_SCENE
  - Provide register_entity_scene(entity_type, scene_path) for future extensibility
- Outcome:
  - EntityTypes.NUTRIENT instances are acquired from a pool configured with scenes/entities/Nutrient.tscn
- Keep existing behavior:
  - SpatialTrackerComponent is still added automatically post-spawn at [EntityFactory.create_entity()](scripts/systems/EntityFactory.gd:64)
  - Identity/Physical are still guaranteed prior to initialization

2.2 NutrientManager integration points
- On ready:
  - Spawn initial nutrients up to target_count using active distribution pattern and [PetriDish.get_random_point()](scripts/environments/PetriDish.gd:92) or pattern algorithms below
  - Emit GlobalEvents.nutrient_spawned per instance
- On [GlobalEvents.entity_destroyed](scripts/systems/GlobalEvents.gd:6):
  - If entity_type == EntityTypes.NUTRIENT and reason == "consumed", schedule respawn after random delay in [respawn_delay_min, respawn_delay_max]
- Periodic reconciliation:
  - Every X seconds (e.g., 2s), check [EntityRegistry.count_by_type()](scripts/systems/EntityRegistry.gd:26) for NUTRIENT and top up if below target_count

2.3 Visual feedback for consumption
- Implement a short tween-based effect on the nutrient node:
  - Animate physical.size towards 0 and reduce base_color alpha over ~0.15–0.25s
  - On tween finished, invoke [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:72) with reason "consumed"
- Ensure no lingering references; [BaseEntity.deinit()](scripts/components/BaseEntity.gd:79) already invokes cleanup on components and emits ready_for_pool


3. Distribution pattern specifications

3.1 Random
- For each spawn, sample dish local coordinates with [PetriDish.get_random_point()](scripts/environments/PetriDish.gd:92) using spawn_margin
- Convert to world via [PetriDish.dish_to_world()](scripts/environments/PetriDish.gd:101)
- Size: uniform random in [size_min, size_max]
- Energy: uniform random in [energy_min, energy_max]

3.2 Clustered
- Choose clustered_cluster_count random centers with [PetriDish.get_random_point()](scripts/environments/PetriDish.gd:92)
- For each nutrient, pick a center and add a random offset within a circle of radius clustered_spread; clamp into dish with [PetriDish.clamp_to_dish()](scripts/environments/PetriDish.gd:66)
- Size/Energy ranges as above

3.3 Uniform
- Generate a jittered grid in dish-local space at spacing uniform_cell_size
- For each grid cell, compute its center, jitter slightly, and include only if inside dish via [PetriDish.is_inside_dish()](scripts/environments/PetriDish.gd:61)
- Stop when target_count reached


4. Consumption detection and rules

4.1 Overlap detection
- On NutrientComponent ready, connect the host BaseEntity Area2D area_entered signal
- When invoked, attempt to resolve the other object:
  - If it or its parent chain contains a BaseEntity and entity_type == EntityTypes.BACTERIA, treat as consumer
- Consumption sequence:
  - Emit GlobalEvents.nutrient_consumed(self.identity.uuid, consumer.identity.uuid)
  - Trigger visual tween
  - On tween completed, call [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:72) for this nutrient id with reason "consumed"

4.2 Integration with SpatialGrid
- No additional work required; nutrients are auto-registered via [SpatialTrackerComponent.gd](scripts/components/SpatialTrackerComponent.gd)
- Organisms in Phase 2.2 can still use [SpatialGrid.get_entities_in_radius()](scripts/systems/SpatialGrid.gd:132) to seek nutrients without relying on Area2D events


5. Debugging, testing, and metrics

5.1 Debug prints and counters
- NutrientManager:
  - On spawn/consume, print counts and the action taken
  - Periodically log active nutrient count via [EntityRegistry.count_by_type()](scripts/systems/EntityRegistry.gd:26)
- Spatial metrics: periodically read [SpatialGrid.get_metrics()](scripts/systems/SpatialGrid.gd:185) and print updates/queries when debug flag enabled

5.2 Editor test without organisms
- Create a temporary debug script that spawns:
  - 1 BaseEntity with entity_type = BACTERIA and a larger size at origin
  - Several nutrients near it
- Drag/move the bacteria test node across nutrients to verify Area2D overlaps trigger consumption flow
- Remove this harness after Phase 2.2 is complete

5.3 Acceptance tests
- Density control:
  - Start with target_count N; destroy K nutrients manually via [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:72) and confirm respawn returns to N after delays
- Distribution modes:
  - Switch distribution_mode at runtime and trigger full respawn; visually inspect pattern differences
- Visual feedback:
  - On consumption, nutrient visibly shrinks/fades before disappearing
- Performance:
  - With 200+ nutrients active, frame time remains stable; pooling avoids spikes on bursts

5.4 Optional HUD hook
- For quick verification, add a temporary HUD label that reads and displays current nutrient count and distribution mode; remove when HUD tasks in PHASE 4 land


6. Implementation steps for Code AI agent

6.1 Create scene and scripts
- scenes/entities/Nutrient.tscn inheriting BaseEntity
- scripts/components/NutrientComponent.gd (attach to Nutrient scene via the BaseEntity "Components" container)
- scripts/systems/NutrientManager.gd and add an instance under SystemsContainer in scenes/Main.tscn

6.2 Extend config and events
- Update [ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd) with nutrient exported parameters and optional entity_scene_paths mapping (EntityTypes.NUTRIENT → scenes/entities/Nutrient.tscn)
- Extend [GlobalEvents.gd](scripts/systems/GlobalEvents.gd) with signals nutrient_spawned and nutrient_consumed

6.3 Update factory pooling
- Modify [EntityFactory.gd](scripts/systems/EntityFactory.gd) to:
  - Read per-type scene path mapping (from ConfigurationManager or internal map)
  - Configure a dedicated pool for EntityTypes.NUTRIENT using scenes/entities/Nutrient.tscn
  - Keep fallback to BASE_ENTITY_SCENE for types without specific mapping

6.4 Implement NutrientManager
- On ready:
  - Spawn initial nutrients up to target_count using chosen distribution_mode
- On GlobalEvents.entity_destroyed:
  - If nutrient and reason == "consumed", schedule respawn after random delay
- Periodic reconciliation timer:
  - Ensure active count converges to target_count
- Emit GlobalEvents.nutrient_spawned for each spawn

6.5 Implement NutrientComponent
- Store energy_value per instance
- Connect Area2D area_entered and implement consumer detection (EntityTypes.BACTERIA)
- Emit GlobalEvents.nutrient_consumed then play shrink/fade and call [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:72) post tween

6.6 Wire debug/testing
- Add verbose logging guards
- Optionally add a temporary debug spawner scene for manual QA
- Validate spatial metrics with [SpatialGrid.get_metrics()](scripts/systems/SpatialGrid.gd:185)


7. Acceptance criteria

- Create Nutrient scene inheriting from BaseEntity
  - A dedicated scenes/entities/Nutrient.tscn exists with sensible defaults and attached NutrientComponent
- Implement NutrientManager with spawn patterns and density control
  - NutrientManager maintains target_count in steady state and recovers after artificial depletion
- Add nutrient energy value and size variations
  - New nutrients have randomized size and energy within configured ranges
- Create nutrient consumption detection via Area2D overlap
  - Overlap with an entity of type BACTERIA triggers consumption flow
- Implement nutrient respawn system with configurable timer
  - Consumed nutrients respawn after a randomized delay, restoring counts
- Add visual feedback for nutrient consumption (shrink/fade)
  - Visible shrink/fade occurs prior to removal; no popping
- Create nutrient distribution patterns (random, clustered, uniform)
  - Switching patterns yields clearly distinct spatial distributions


8. Integration and future phases

- Phase 2.2 organisms can:
  - Use [SpatialGrid.get_entities_in_radius()](scripts/systems/SpatialGrid.gd:132) to locate nearby nutrients
  - Rely on the nutrient Area2D overlap to finalize consumption
- Phase 3.1 energy transfer:
  - When present, hook NutrientComponent’s consumption event to EnergyProcessor so that energy_value is transferred to the consumer before destruction


9. Risks and mitigations

- Overlapping many Area2D signals
  - Keep NutrientComponent logic minimal; rely on manager and factory for heavy lifting
- Visual-exit timing
  - Ensure tween completion precedes destroy; guard against double-destroy by tracking a consumed flag
- Per-type scenes migration
  - EntityFactory fallback ensures backward compatibility if mapping is absent


Appendix: Relevant existing APIs and lines

- Base entity lifecycle: [BaseEntity.deinit()](scripts/components/BaseEntity.gd:79)
- Factory spawn and spatial registration: [EntityFactory.create_entity()](scripts/systems/EntityFactory.gd:42), [EntityFactory.create_entity_random()](scripts/systems/EntityFactory.gd:95)
- Factory destroy and pooling: [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:72)
- Registry helpers: [EntityRegistry.count_by_type()](scripts/systems/EntityRegistry.gd:26)
- Spatial queries and metrics: [SpatialGrid.get_entities_in_radius()](scripts/systems/SpatialGrid.gd:132), [SpatialGrid.get_metrics()](scripts/systems/SpatialGrid.gd:185)
- Dish utilities: [PetriDish.get_random_point()](scripts/environments/PetriDish.gd:92), [PetriDish.clamp_to_dish()](scripts/environments/PetriDish.gd:66)
