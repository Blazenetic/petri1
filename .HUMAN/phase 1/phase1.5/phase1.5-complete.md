Implemented Phase 1.5 Spatial Partitioning System and integrated it across the project.

Summary of changes
- Added spatial grid system:
  - [scripts/systems/SpatialGrid.gd](scripts/systems/SpatialGrid.gd)
    - Provides public API: configure(), add_entity(), remove_entity(), update_entity_position(), get_entities_in_cell(), get_entities_in_adjacent_cells(), get_entities_in_radius(), get_cell_at_world(), get_cell_bounds(), get_cell_size(), get_metrics()
    - Uses cell dictionary keyed by Vector2i and backrefs for entity lookups
    - Multi-cell coverage via AABB around circle position ± radius
    - Neighbor/radius query searches only the minimal cell range and filters by exact distance and dish bounds
    - Performance metrics accumulated with Time.get_ticks_usec() and periodic debug prints every 5s
    - Auto-configure in _ready() by discovering [scripts/environments/PetriDish.gd](scripts/environments/PetriDish.gd) and using [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd).grid_cell_size
    - Added to group "Spatial" for discovery by other systems
- Added entity tracking component:
  - [scripts/components/SpatialTrackerComponent.gd](scripts/components/SpatialTrackerComponent.gd)
    - Attaches to BaseEntity, caches IdentityComponent and PhysicalComponent, discovers SpatialGrid by group, and registers entity
    - Pushes updates when crossing cell boundaries or when radius changes; also updates cached position for accurate queries
    - Cleanly deregisters on cleanup()
- Movement integration with optional grid-based neighbor candidates:
  - [scripts/components/MovementComponent.gd](scripts/components/MovementComponent.gd)
    - Added export use_spatial_grid: bool = true
    - _compute_separation_accel() now prefers SpatialGrid.get_entities_in_radius() when available and falls back to Area2D overlaps
    - Respects separation_neighbors_max and keeps previous logic for safety/regression
- Debug visualization overlays:
  - [scripts/environments/PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd)
    - Added exports show_cell_counts and show_heatmap, initialized from [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
    - Reuses existing grid line drawing; draws per-cell counts and heatmap (translucent rect fill) clipped to dish
- Factory integration to ensure automatic tracking:
  - [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd)
    - After node.init(), attaches [scripts/components/SpatialTrackerComponent.gd](scripts/components/SpatialTrackerComponent.gd) so each entity is registered in SpatialGrid automatically once identity is set
- Configuration toggles:
  - [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
    - Added @export var grid_debug_heatmap_default and grid_debug_counts_default
    - grid_cell_size already exists and is used by both grid drawing and SpatialGrid configuration
- Scene wiring:
  - [scenes/Main.tscn](scenes/Main.tscn)
    - Added SpatialGrid node under SystemsContainer with [scripts/systems/SpatialGrid.gd](scripts/systems/SpatialGrid.gd) script
  - [scenes/Game.tscn](scenes/Game.tscn)
    - Ensured no duplicate SpatialGrid instance to avoid double registration

Key APIs (entry points)
- [GDScript.SpatialGrid.configure(cell_size: float, dish: PetriDish)](scripts/systems/SpatialGrid.gd:52)
- [GDScript.SpatialGrid.add_entity(entity_id: StringName, position: Vector2, radius: float, entity_type: int = 0)](scripts/systems/SpatialGrid.gd:56)
- [GDScript.SpatialGrid.update_entity_position(entity_id: StringName, position: Vector2, radius: float)](scripts/systems/SpatialGrid.gd:88)
- [GDScript.SpatialGrid.get_entities_in_radius(center_world: Vector2, radius: float, type_filter: Array = [])](scripts/systems/SpatialGrid.gd:132)
- [GDScript.SpatialGrid.get_entities_in_cell(cell: Vector2i)](scripts/systems/SpatialGrid.gd:119)
- [GDScript.SpatialGrid.get_metrics()](scripts/systems/SpatialGrid.gd:185)

How it operates at runtime
- SpatialGrid auto-configures in _ready() by discovering the dish and reading grid_cell_size. It adds itself to group "Spatial" for easy lookup.
- EntityFactory attaches SpatialTrackerComponent on spawn; the tracker registers the entity with SpatialGrid and pushes updates on movement or radius changes.
- MovementComponent queries nearby candidates via SpatialGrid when use_spatial_grid is true, otherwise falls back to Area2D overlaps.
- PetriDishDebugDraw renders grid lines; when enabled, it queries SpatialGrid cell occupancy to draw per-cell counts and a heatmap overlay, clipped to the dish.

Performance metrics
- SpatialGrid collects updates, queries, total and max microsecond timings for updates and queries, and prints a summary every 5 seconds.
- Consumers can call [GDScript.SpatialGrid.get_metrics()](scripts/systems/SpatialGrid.gd:185) to retrieve counters for HUD or logs.

Testing and validation guidance
- Immediate in-game tests using existing TestSpawner:
  - Run [scenes/Main.tscn](scenes/Main.tscn). TestSpawner spawns entities and they will be registered in SpatialGrid via the tracker.
  - Toggle PetriDishDebugDraw show_cell_counts/show_heatmap in editor or via [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd) defaults.
- Entity count consistency:
  - Pick a visible cell range and sum counts from [GDScript.SpatialGrid.get_entities_in_cell()](scripts/systems/SpatialGrid.gd:119) across that range; compare with tracked entities where applicable.
- Cell boundary movement:
  - Focus a single entity and move it across grid lines; verify its id disappears from old cell and appears in new cell via get_entities_in_cell.
- Query correctness:
  - Call [GDScript.SpatialGrid.get_entities_in_radius()](scripts/systems/SpatialGrid.gd:132) from a known point and verify distances against [scripts/components/PhysicalComponent.gd](scripts/components/PhysicalComponent.gd) positions/sizes.
- Stress:
  - For higher load, increase [scripts/utils/TestSpawner.gd](scripts/utils/TestSpawner.gd) spawn_count (e.g., 500). Observe SpatialGrid periodic debug prints for queries/sec and avg_us values, and ensure framerate stability.

Notes and compatibility
- Movement separation retains Area2D overlap fallback to preserve behavior if SpatialGrid is absent or disabled.
- Query and update code is compatible with Godot 4.x loop syntax; range() is used where required.
- SpatialGrid instance is scene-local (under SystemsContainer), supporting multiple dish scenes if needed. Metrics are exposed on the grid itself; mirroring to [scripts/systems/WorldState.gd](scripts/systems/WorldState.gd) can be added later if desired.

This completes Phase 1.5 scope: grid system, tracker, movement integration, debug overlays, metrics, configuration, and scene wiring are implemented and ready for runtime validation.