# Debug and Logging Cleanup Proposal for Petri Pandemonium

Purpose: unify and control all debug and console output, reduce noise, and keep near-zero overhead in release builds, while retaining rich diagnostics in editor.

Scope
- Replace scattered prints and ad-hoc flags with a central logger.
- Unify overlay toggles under a single settings source.
- Add runtime controls: F9 to toggle global debug; Shift+F9 to cycle perf log level.
- Migrate existing scripts to use the logger and remove legacy flags.

Files and systems impacted
- Logger AutoLoad: [scripts/systems/Log.gd](scripts/systems/Log.gd)
- Settings owner: [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
- Visual overlays: [scripts/environments/PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd)
- High-noise systems/components: [scripts/systems/NutrientManager.gd](scripts/systems/NutrientManager.gd), [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd), [scripts/components/BiologicalComponent.gd](scripts/components/BiologicalComponent.gd), [scripts/systems/SpatialGrid.gd](scripts/systems/SpatialGrid.gd)
- Other affected: [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd), [scripts/systems/WorldState.gd](scripts/systems/WorldState.gd), [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd), [scripts/components/NutrientComponent.gd](scripts/components/NutrientComponent.gd), [scripts/environments/PetriDish.gd](scripts/environments/PetriDish.gd)

Design overview
- Central logger singleton with categories and levels.
- Early-out checks to avoid string allocation when disabled.
- Optional rate limiting for hot paths (perf).
- Console sink by default; later, optional file or overlay sink.
- Build-aware defaults (editor vs export).

Categories and levels
- Categories: core, systems, components, ai, environment, ui, perf, events.
- Levels: trace, debug, info, warn, error.
- Suggested defaults:
  - Editor/dev: core/info+, systems/info+, perf/debug, others/warn+.
  - Release/export: warn+ for all categories.

Runtime controls
- F9 toggles global logging enabled/disabled.
- Shift+F9 cycles perf category level (debug → info → warn → error → debug).
- InputMap actions to add in project settings:
  - debug_toggle_global: F9
  - debug_cycle_perf: Shift+F9

Logger AutoLoad specification
- Location and loading:
  - Create [scripts/systems/Log.gd](scripts/systems/Log.gd) and register as AutoLoad (singleton) in Project Settings.
  - Script extends Node to receive input callbacks.
- Configuration state:
  - global_enabled: bool
  - level_by_category: Dictionary<StringName, int> mapping to level enum
  - editor_defaults_applied: bool
- Level enum mapping (low→high): trace=0, debug=1, info=2, warn=3, error=4.
- Public API (names only; implement in GDScript):
  - set_global_enabled(enabled: bool)
  - is_global_enabled() -> bool
  - set_level(category: StringName, level: int)
  - get_level(category: StringName) -> int
  - enabled(category: StringName, level: int) -> bool  (returns global_enabled and level gating)
  - log(category: StringName, level: int, parts: Array)  (builds and emits)
  - trace/debug/info/warn/error shortcuts with varargs
  - every(key: StringName, interval_sec: float, category: StringName, level: int, parts: Array)  (rate-limited log)
- Performance considerations:
  - In each shortcut, first check enabled(category, level) and return immediately if false.
  - Accept message parts as an array of values; join only when emitting.
  - Avoid string interpolation when disabled.
- Formatting guidelines:
  - Prefix: [Category] LEVEL
  - Optional tick/time: frames=Engine.get_frames_drawn(), ms=Time.get_ticks_msec().
  - Entity context: include id=... when relevant.
- Sinks:
  - Console: use print for info and below; push_warning for warn; push_error for error.
  - Overlay sink: optional future; keep the interface but no-op for now.
- Input handling:
  - Implement _unhandled_input to listen for debug_toggle_global and debug_cycle_perf.
  - When cycling perf level, update only the perf category threshold.

ConfigurationManager integration
- Extend [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd) to initialize logger defaults:
  - On ready, detect build mode: editor via Engine.is_editor_hint() or OS.is_debug_build().
  - Set Log.global_enabled true in editor, false in export.
  - Apply per-category thresholds listed above.
- Move overlay defaults here and expose via simple getters:
  - grid_debug_heatmap_default, grid_debug_counts_default already exist; ensure they are read by PetriDishDebugDraw.
- Reduce startup noise:
  - Replace multiple prints with a single systems/info summary via the logger, or remove entirely.

InputMap updates
- Add actions in Project Settings:
  - debug_toggle_global bound to F9.
  - debug_cycle_perf bound to Shift+F9 (modifier).
- If storing under version control, update [project.godot](project.godot) input map accordingly.

Migration guidelines by file
- [scripts/systems/NutrientManager.gd](scripts/systems/NutrientManager.gd)
  - Remove local debug_logging flag.
  - Reconcile and respawn scheduling → systems/debug.
  - Spawn confirmations → systems/info.
- [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd)
  - Spawn and destroy messages → systems/info.
- [scripts/components/BiologicalComponent.gd](scripts/components/BiologicalComponent.gd)
  - Remove local debug_logging flag.
  - Init and energy deltas → components/debug (rate-limit large bursts if needed).
  - Death events → components/info.
- [scripts/systems/SpatialGrid.gd](scripts/systems/SpatialGrid.gd)
  - Move periodic performance prints to perf category using Log.every with 1.0s interval.
- [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
  - Demote startup prints to systems/debug or collapse into one systems/info line.
- [scripts/systems/WorldState.gd](scripts/systems/WorldState.gd), [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd)
  - Either silence or log as systems/debug on ready.
- [scripts/components/NutrientComponent.gd](scripts/components/NutrientComponent.gd)
  - Consumption lifecycle → components/debug (start/finish), components/info for notable outcomes if needed.
- [scripts/environments/PetriDish.gd](scripts/environments/PetriDish.gd), [scripts/environments/PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd)
  - Ensure overlay toggles are driven by ConfigurationManager values; do not print per frame.

Message templates (examples; adapt as needed)
- Spawn: [EntityFactory] systems/info id=<uuid> type=<type> pos=<x,y>
- Destroy: [EntityFactory] systems/info id=<uuid> type=<type> reason=<text>
- Nutrient reconcile: [NutrientManager] systems/debug current=<n> target=<n> spawning=<n>
- Perf sample: [SpatialGrid] perf/debug upd_s=<n> q_s=<n> avg_upd_us=<n> avg_q_us=<n>

Acceptance criteria
- Console output is quiet by default in editor (no spam), and warn+ in release.
- F9 toggles global logger; Shift+F9 cycles perf category thresholds live.
- No lingering print/push_warning/push_error calls in the migrated files; all go through Log.
- NutrientManager and BiologicalComponent no longer reference debug_logging flags.
- SpatialGrid perf logs are rate-limited to ~1s.
- Debug overlay toggles are read from ConfigurationManager defaults.

Rollout plan
1. Implement [scripts/systems/Log.gd](scripts/systems/Log.gd) and register AutoLoad.
2. Update InputMap for F9 and Shift+F9 in [project.godot](project.godot).
3. Initialize logger thresholds in [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd).
4. Migrate high-noise files: NutrientManager, EntityFactory, BiologicalComponent, SpatialGrid.
5. Migrate remaining files: ConfigurationManager, WorldState, GlobalEvents, NutrientComponent, PetriDish, PetriDishDebugDraw.
6. Remove legacy flags and stray prints.
7. Sanity test in editor and exported build; verify acceptance criteria.

Notes and guidance for contributors
- Prefer Log.enabled(category, level) checks before building complex messages.
- Use Log.every for periodic statistics; do not implement your own timers for logging.
- Warn and error are for actionable issues; info should be occasional, not per-frame.
- For entity-scoped logs, include id=<uuid> in the message parts.

Mermaid overview
mermaid
flowchart LR
  A[Game code] --> B[Log singleton]
  B --> C[Console sink]
  B --> D[Overlay sink future]
  E[ConfigurationManager defaults] --> B
  F[InputMap F9/Shift+F9] --> B

Implementation ownership
- Code agent to implement logger and migrations per this document.
- Architect to review PR for adherence to categories/levels and acceptance criteria.