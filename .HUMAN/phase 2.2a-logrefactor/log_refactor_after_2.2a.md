Implemented the centralized logging system and migrated high-noise systems to use it, per the debug proposal.

What’s included
- Logger singleton
  - New AutoLoad: [scripts/systems/Log.gd](scripts/systems/Log.gd)
  - Levels: trace, debug, info, warn, error (0..4)
  - Categories: core, systems, components, ai, environment, ui, perf, events
  - Early-out gating to avoid string allocations when disabled
  - Rate-limited logging via every(key, interval_sec, category, level, parts)
  - Build-aware defaults and runtime input controls (F9 toggle, Shift+F9 cycle perf)
- Project configuration
  - Registered AutoLoad and input actions in [project.godot](project.godot)
    - [autoload] now includes Log
    - [input] added debug_toggle_global and debug_cycle_perf
- Configuration initialization
  - [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
    - Sets Log global_enabled by build mode
    - Applies category thresholds matching the proposal
    - Ensures input actions exist at runtime (safety)
    - Collapses startup prints into one systems/info summary through Log
- Migrations to Log
  - [scripts/systems/SpatialGrid.gd](scripts/systems/SpatialGrid.gd)
    - Replaced periodic print with Log.every at ~1.0s
    - Resets counters only on emission, suppresses spam
  - [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd)
    - Spawn/destroy messages now systems/info via Log
  - [scripts/systems/NutrientManager.gd](scripts/systems/NutrientManager.gd)
    - Removed debug_logging flag and all prints
    - Reconcile/respawn logs -> systems/debug; spawn confirms -> systems/info
  - [scripts/components/BiologicalComponent.gd](scripts/components/BiologicalComponent.gd)
    - Removed debug_logging flag and all prints
    - Init/energy deltas -> components/debug; deaths -> components/info
  - [scripts/components/NutrientComponent.gd](scripts/components/NutrientComponent.gd)
    - Removed debug_logging export and all prints
    - Consume lifecycle logs -> components/debug
  - [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd)
    - Ready log -> events/debug (fallback print only if Log not yet ready)
  - [scripts/systems/WorldState.gd](scripts/systems/WorldState.gd)
    - Ready log -> systems/debug (fallback print only if Log not yet ready)
- PetriDish debug overlay
  - [scripts/environments/PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd) already reads grid_debug_counts_default and grid_debug_heatmap_default from ConfigurationManager, so no changes were needed.

Runtime controls
- F9 toggles Log.global_enabled on/off.
- Shift+F9 cycles the perf category threshold Debug → Info → Warn → Error → Debug.
- ConfigurationManager also ensures these InputMap entries at startup, even if project.godot was not updated manually.

Developer usage examples
- Check if a log would emit before building strings:
  - Use the singleton handle (recommended): resolve once via get_node("/root/Log") and call:
    - _log.debug(&"systems", ["Reconciled ", count, " entities"])
  - Direct helper in code (if needed):
    - Log.info(&"perf", ["Frame=", Engine.get_frames_drawn()])
- Periodic logging for hot paths:
  - _log.every(&"MyKey", 1.0, &"perf", LogDefs.LEVEL_DEBUG, ["samples=", samples])

Acceptance criteria status
- Console quiet by default in editor (info+ systems, debug perf), warn+ in export: configured in ConfigurationManager and Log defaults.
- F9 toggles global logger; Shift+F9 cycles perf level: implemented in Log and initialized in ConfigurationManager and project.godot.
- Migrated files no longer use print/push_warning/push_error directly; they call Log instead. Any remaining prints are fallbacks only when Log is unavailable early in boot.
- NutrientManager and BiologicalComponent no longer reference debug_logging flags.
- SpatialGrid perf logs are rate-limited to ~1s using Log.every.
- Debug overlay toggles read from ConfigurationManager defaults (pre-existing and verified).

Files changed
- Added: [scripts/systems/Log.gd](scripts/systems/Log.gd)
- Modified:
  - [project.godot](project.godot)
  - [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
  - [scripts/systems/SpatialGrid.gd](scripts/systems/SpatialGrid.gd)
  - [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd)
  - [scripts/systems/NutrientManager.gd](scripts/systems/NutrientManager.gd)
  - [scripts/components/BiologicalComponent.gd](scripts/components/BiologicalComponent.gd)
  - [scripts/components/NutrientComponent.gd](scripts/components/NutrientComponent.gd)
  - [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd)
  - [scripts/systems/WorldState.gd](scripts/systems/WorldState.gd)

Post-merge checklist
- Open the project in the Godot editor at least once so project.godot changes are recognized and autoload is registered.
- In the editor, verify in Project Settings:
  - AutoLoad contains “Log” pointing to scripts/systems/Log.gd
  - InputMap lists “debug_toggle_global” (F9) and “debug_cycle_perf” (Shift+F9)
- Run the scene and confirm:
  - Console is not spamming every frame
  - Press F9: see “[Log] global_enabled=…” feedback
  - Press Shift+F9: see “perf threshold -> …” feedback once per press
  - SpatialGrid logs appear roughly once per second with perf/debug when enabled
  - Entity spawns/despawns and nutrient spawning use systems/info logs occasionally

This implements the debug and logging cleanup per the proposal and establishes a maintainable, low-overhead logging foundation with runtime controls.