Implemented Phase 2.2a core for Bacteria: scene, biological stats/metabolism, nutrient seeking via SpatialGrid, consumption energy gain, starvation cleanup, configuration mapping, and TestSpawner duplication guard.

Files added
- [scripts/components/BiologicalComponent.gd](scripts/components/BiologicalComponent.gd)
- [scripts/behaviors/SeekNutrient.gd](scripts/behaviors/SeekNutrient.gd)
- [scenes/entities/Bacteria.tscn](scenes/entities/Bacteria.tscn)

Files modified
- [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
- [scripts/utils/TestSpawner.gd](scripts/utils/TestSpawner.gd)

Key behaviors implemented
- Biological stats and metabolism:
  - [scripts/components/BiologicalComponent.gd](scripts/components/BiologicalComponent.gd)
    - Exports: energy_start=6.0, energy_max=12.0, metabolism_rate_per_sec=0.8, health_start=1.0, max_age_sec=180.0, energy_from_nutrient_efficiency=1.0, debug_logging=false.
    - Runtime: energy, health, age_sec.
    - Update: age increments, energy drains per second with clamp to [0, max], starvation or max_age triggers destruction via EntityFactory.
    - Listens to GlobalEvents.nutrient_consumed, resolves nutrient energy via NutrientComponent and applies efficiency, emits energy_changed.
    - Cleanup unsubscribes from signal to avoid leaks.
- Nutrient seeking and steering:
  - [scripts/behaviors/SeekNutrient.gd](scripts/behaviors/SeekNutrient.gd)
    - Exports: sense_radius=160.0, target_refresh_interval=0.25, acceleration_magnitude=220.0, slow_radius=24.0, use_spatial_grid=true, debug_draw_target=false.
    - Queries SpatialGrid.get_entities_in_radius filtered to NUTRIENT, chooses nearest; falls back to scanning EntityRegistry if grid unavailable.
    - On update, computes desired steering and sets MovementComponent.acceleration; reduces acceleration inside slow_radius; leaves acceleration untouched when no target so RandomWander can bias movement.
- Bacteria scene and components:
  - [scenes/entities/Bacteria.tscn](scenes/entities/Bacteria.tscn)
    - Area2D with CircleShape2D (radius=8).
    - entity_type = EntityTypes.BACTERIA, size = 8.0, BaseEntity script for visuals.
    - Components: MovementComponent (align_rotation=true), BiologicalComponent, RandomWander (gentle fallback), SeekNutrient (last so it can override wander when a target is present).
- Configuration and factory mapping:
  - [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd) now maps EntityTypes.BACTERIA -> res://scenes/entities/Bacteria.tscn.
  - Pool size for BACTERIA already present with 300; Nutrients 200. EntityFactory will seed scene mapping from ConfigurationManager on _ready.
- TestSpawner integration and deduplication:
  - [scripts/utils/TestSpawner.gd](scripts/utils/TestSpawner.gd) avoids duplicate MovementComponent and RandomWander by checking existing components on the spawned Bacteria node before adding, and updates their params if present. It still gives an initial nudge to movement.

Tuning pointers (editor exposed)

In scripts/behaviors/SeekNutrient.gd:
- seek_blend (0.4–0.8): raise to prioritize seeking, lower to allow more meandering.
- sense_radius (200–300): higher encourages spotting distant nutrients, broadening travel.
- target_persist_sec (0.5–2.0): higher for fewer retargets and more committed movement.
- min_slow_factor (0.1–0.4): increase to reduce deceleration near nutrients.

In scenes/entities/Bacteria.tscn:
MovementComponent damping (0.05–0.12): lower for more drift.
MovementComponent jitter_strength (20–40): increase for more exploratory variability.
MovementComponent max_speed (140–200): increase for broader range faster.


How to verify
- Open and run [scenes/Main.tscn](scenes/Main.tscn).
- Observe:
  - Bacteria (green circles) spawn and move using RandomWander but actively turn toward nearby nutrients.
  - On touching a nutrient, NutrientComponent emits GlobalEvents.nutrient_consumed; BiologicalComponent increases energy accordingly.
  - Energy drains over time via metabolism; with low nutrient density, bacteria eventually starve and are cleanly removed by EntityFactory (SpatialTrackerComponent ensures SpatialGrid removal).
- Optional quick tests:
  - To force starvation, lower nutrient density using ConfigurationManager or set a low target_count on [scripts/systems/NutrientManager.gd](scripts/systems/NutrientManager.gd) and watch bacteria die over time.
  - To inspect energy changes and death reasons, enable debug_logging on the BiologicalComponent in [scenes/entities/Bacteria.tscn](scenes/entities/Bacteria.tscn) or at runtime via the inspector.

Notes
- The SpatialTrackerComponent is auto-attached by EntityFactory so Bacteria are tracked in [scripts/systems/SpatialGrid.gd](scripts/systems/SpatialGrid.gd) and can be found by SeekNutrient efficiently.
- Collision layers/masks are aligned (both Nutrient and Bacteria set to 1) so Area2D overlaps fire; NutrientComponent handles consumption and destroys the nutrient instance with a short fade/size tween.
- All new parameters are exported for tuning in editor: sense and steering in SeekNutrient, energies/metabolism in BiologicalComponent.

Acceptance criteria alignment
- Bacteria spawn via EntityFactory using the new scene mapping and appear in EntityRegistry. ✔
- Energy decreases over time and increases when consuming a nutrient. ✔
- SeekNutrient selects nearest nutrient in radius via SpatialGrid with fallback. ✔
- Starvation destruction flows through EntityFactory and SpatialGrid removal handled by SpatialTracker cleanup. ✔
- Behavior is parameterized via exported properties; default values set per spec. ✔