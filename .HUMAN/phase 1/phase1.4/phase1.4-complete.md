Phase 1.4 is implemented, integrated, and validated. Summary of what was done:

What we added
- Movement component: [scripts/components/MovementComponent.gd](scripts/components/MovementComponent.gd)
  - Acceleration integration and damping in [MovementComponent.update()](scripts/components/MovementComponent.gd:41)
  - Speed clamping, Brownian-style jitter, and rotation alignment
  - Soft separation via Area2D overlaps to create gentle bumping
  - Boundary resolution using dish helpers with restitution (bounce) and world/local space conversion
  - Lazy acquisition of PhysicalComponent and PetriDish to avoid order-of-init issues
- Wander behavior: [scripts/behaviors/RandomWander.gd](scripts/behaviors/RandomWander.gd)
  - Periodic direction changes and optional smoothing in [RandomWander.update()](scripts/behaviors/RandomWander.gd:23)
  - Writes a bias acceleration vector into MovementComponent each frame
- Movement helpers (optional): [scripts/utils/MovementUtils.gd](scripts/utils/MovementUtils.gd)
  - Utility functions for damping, clamping, safe normalization and reflection
- Temporary test spawner: [scripts/utils/TestSpawner.gd](scripts/utils/TestSpawner.gd)
  - Spawns BaseEntity instances, attaches MovementComponent and RandomWander, seeds RNG once, and gives a small initial velocity nudge
- Scene wiring: [scenes/Game.tscn](scenes/Game.tscn)
  - Added TestSpawner under SystemsContainer so running [scenes/Main.tscn](scenes/Main.tscn) immediately exercises Phase 1.4 movement

Key implementation points
- Movement pipeline
  - In [MovementComponent.update()](scripts/components/MovementComponent.gd:41), acceleration and soft separation are accumulated, velocity is integrated, exponentially damped, clamped to max_speed, jitter added, and position advanced through [PhysicalComponent](scripts/components/PhysicalComponent.gd)
  - If align_rotation is true and speed is above a threshold, facing is updated from velocity
- Soft separation (entity bumping)
  - Queries neighbors via Area2D.get_overlapping_areas and computes a limited repulsive adjustment; the neighbor cap avoids oscillation and cost blowups
- Boundary enforcement
  - Uses [PetriDish.resolve_boundary_collision()](scripts/environments/PetriDish.gd:74) to clamp within the dish and reflect velocity, and applies a restitution factor for slight energy loss
  - Uses [PetriDish.world_to_dish()](scripts/environments/PetriDish.gd:98) and [PetriDish.dish_to_world()](scripts/environments/PetriDish.gd:101) to switch spaces correctly
- BaseEntity loop unchanged
  - The per-frame component loop remains as designed in [BaseEntity._process()](scripts/components/BaseEntity.gd:65), ensuring MovementComponent participates cleanly in the update chain
- Warnings-as-errors hardened
  - Local variables that inferred Variant types were converted to explicitly typed floats to satisfy strict compilation

Designer-tunable exports
- [MovementComponent.gd](scripts/components/MovementComponent.gd)
  - max_speed, damping (0..1 per second), jitter_strength, align_rotation
  - separation_strength, separation_neighbors_max, bounce_restitution
- [RandomWander.gd](scripts/behaviors/RandomWander.gd)
  - change_interval, magnitude, turn_lerp
- [TestSpawner.gd](scripts/utils/TestSpawner.gd)
  - spawn_count, spawn_margin, initial_speed_variation, align_rotation, change_interval, accel_magnitude, entity_size, entity_size_jitter

Verification against acceptance criteria
- Smooth acceleration-based motion with damping and clamping: [MovementComponent.update()](scripts/components/MovementComponent.gd:41)
- Meandering paths with direction changes and jitter: [RandomWander.update()](scripts/behaviors/RandomWander.gd:23), [MovementComponent.gd](scripts/components/MovementComponent.gd)
- Entities remain within dish and bounce off the boundary: [PetriDish.resolve_boundary_collision()](scripts/environments/PetriDish.gd:74) integration in [MovementComponent.update()](scripts/components/MovementComponent.gd:41)
- Gentle bumping separation using local overlaps: [MovementComponent._compute_separation_accel()](scripts/components/MovementComponent.gd:107)
- Rotation aligns to travel direction when enabled: [MovementComponent.update()](scripts/components/MovementComponent.gd:41)
- Clean component update loop without errors: [BaseEntity._process()](scripts/components/BaseEntity.gd:65)

How to observe and tune
- Run [scenes/Main.tscn](scenes/Main.tscn); TestSpawner populates the dish automatically
- Adjust MovementComponent and RandomWander exports on an instance while running to tune feel
- Increase [TestSpawner.spawn_count](scripts/utils/TestSpawner.gd) to stress the system (e.g., 200) and confirm stability and neighbor cap effectiveness

This completes and finalizes Phase 1.4: Basic Movement System. The code is modular, parameterized for designer iteration, and ready to serve as the foundation for subsequent behavior and spatial optimizations planned in Phase 1.5.