Phase 1.2 implemented and verified.

Deliverables created/updated
- Base Entity Scene
  - [scenes/entities/BaseEntity.tscn](scenes/entities/BaseEntity.tscn)
    - Root Area2D “BaseEntity”
    - Children: “Collider” CollisionShape2D with CircleShape2D radius 8, “Components” Node
    - collision_layer = 1, collision_mask = 1

- Components
  - [scripts/components/EntityComponent.gd](scripts/components/EntityComponent.gd)
  - [scripts/components/IdentityComponent.gd](scripts/components/IdentityComponent.gd)
  - [scripts/components/PhysicalComponent.gd](scripts/components/PhysicalComponent.gd)
  - [scripts/components/EntityTypes.gd](scripts/components/EntityTypes.gd)

- BaseEntity script
  - [scripts/components/BaseEntity.gd](scripts/components/BaseEntity.gd)
    - Exports: entity_type, size, base_color
    - Manages components, forwards _process to components, emits ready_for_pool()
    - Renders a visible debug circle via _draw() so entities are visible without sprites
    - Idempotent component setup to support pooling

- Systems and Utilities
  - [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd)
    - Added lifecycle signals: entity_spawned(entity_id, entity_type, position), entity_destroyed(entity_id, entity_type, reason)
  - [scripts/systems/EntityRegistry.gd](scripts/systems/EntityRegistry.gd)
  - [scripts/utils/ObjectPool.gd](scripts/utils/ObjectPool.gd)
    - Prewarm creation, acquire/release, correct CanvasItem visibility toggling
    - Acquire now detaches from the pool container so factory can reparent into live tree
  - [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd)
    - Pools per-entity-type, adds entities under Game/DishContainer
    - Initializes components and position, emits GlobalEvents signals
    - Handles pooling safe reparent and identity initialization for non-prewarmed instances
  - [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
    - entity_pool_sizes = { BACTERIA: 50, NUTRIENT: 200 }
  - [project.godot](project.godot)
    - Autoloads for EntityRegistry and EntityFactory registered
  - [scripts/systems/DebugSpawner.gd](scripts/systems/DebugSpawner.gd)
    - Attached under SystemsContainer in [scenes/Game.tscn](scenes/Game.tscn)
    - Spawns per cycle, waits, destroys, repeats with useful debug logs

Key implementation notes and fixes
- Godot 4 ternary syntax: replaced a ? b : c with b if a else c where needed
- UUID generation: removed randi64 usage; replaced with two 32/16-bit parts from RandomNumberGenerator
- Pooling parenting: acquire() now detaches node from PoolContainer; release() reattaches and hides it
- Factory parent resolution: safe current_scene lookup using find_child; fallback to root
- Type inference warnings-as-errors: added explicit types in EntityFactory
- Visibility: BaseEntity debug _draw ensures visible circles without art; transform applied immediately after init

Acceptance criteria verification
- Spawn/destroy via EntityFactory with pooling
  - Verified 10 cycles end-to-end with zero errors; pooling reuses instances without leaks
- EntityRegistry tracks entities by id and type; counts accurate during cycles
- GlobalEvents signals fire (entity_spawned/entity_destroyed) with correct payloads
- BaseEntity forwards _process to components; PhysicalComponent keeps Area2D transform synced (position/rotation/size)
- Output free of errors or warnings during test
- Entities visible as green circles and appear/disappear per cycle

What changed in scenes and configuration
- [scenes/Game.tscn](scenes/Game.tscn): added DebugSpawner under SystemsContainer, ext_resource for its script
- [project.godot](project.godot): registered EntityRegistry and EntityFactory autoloads; GlobalEvents already present

Mapping to Phase 1.2 checklist
- BaseEntity scene with Area2D and CollisionShape2D → Delivered
- EntityComponent base class → Delivered
- IdentityComponent (UUID/type) → Delivered
- PhysicalComponent (transform sync) → Delivered
- BaseEntity script managing lifecycle/components → Delivered
- EntityTypes enum/type registry → Delivered
- EntityRegistry autoload → Delivered
- ObjectPool utility → Delivered
- EntityFactory autoload → Delivered
- GlobalEvents lifecycle signals → Delivered
- ConfigurationManager pool sizes → Delivered
- Temporary DebugSpawner and in-scene wiring → Delivered
- Verification (spawn/despawn loop works, no errors) → Delivered

Commit guidance
- Message: feat(ems): add BaseEntity, components, registry, factory, pooling and lifecycle signals for Phase 1.2

Next step
- Remove [scripts/systems/DebugSpawner.gd](scripts/systems/DebugSpawner.gd) and its node in [scenes/Game.tscn](scenes/Game.tscn) before Phase 1.3.