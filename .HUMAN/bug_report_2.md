Bug report 2: Persistent startup stall analysis and next steps

Executive summary
- A multi-second stall still occurs at startup even after reducing logging volume. The stall happens immediately after the first SpatialGrid perf DEBUG line.
- The most likely root cause is heavy scene pre-warming on the main thread. EntityFactory pre-configures ObjectPool instances for each entity type, and ObjectPool pre-instantiates hundreds of nodes synchronously during _ready. With current configuration, this is at least 20 + 200 + 300 instances, which is substantial for editor builds.
  - Prewarm is invoked once in EntityFactory._ready via per-type pool setup, which calls ObjectPool.configure with large prewarm_count values: [EntityFactory._ready()](scripts/systems/EntityFactory.gd:16) through [EntityFactory._ready()](scripts/systems/EntityFactory.gd:54), [ObjectPool.configure()](scripts/utils/ObjectPool.gd:9) through [ObjectPool.configure()](scripts/utils/ObjectPool.gd:20), [ConfigurationManager.entity_pool_sizes](scripts/systems/ConfigurationManager.gd:27) through [ConfigurationManager.entity_pool_sizes](scripts/systems/ConfigurationManager.gd:30).
- Secondary factor: synchronous INFO logs from EntityFactory.destroy_entity during early consumption cascades add noise after the stall, though this is not the primary trigger. See [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:91) through [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:110).
- SpatialGrid perf logging appears temporally near the stall but is not the cause; it is rate-limited using Log.every and does minimal work: [SpatialGrid._process()](scripts/systems/SpatialGrid.gd:36) through [SpatialGrid._process()](scripts/systems/SpatialGrid.gd:60), [Log.every()](scripts/systems/Log.gd:83) through [Log.every()](scripts/systems/Log.gd:93).

Observed reproduction and timeline
- Launch in editor with default settings.
- First 3 lines (user-provided) show:
  - [ConfigurationManager] ready (INFO)
  - [NutrientManager] initial spawn summary (single INFO line)
  - [SpatialGrid] perf (DEBUG, rate-limited)
- Stall occurs right after the first perf line. Subsequent logs resume, including many INFO destroys from EntityFactory (consumption churn).
- Overlay defaults are off; SpatialGrid operations are not heavy by themselves during startup.
  - Overlay defaults source: [PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd:18) through [PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd:21).

Detailed evidence
- Pool pre-warm happens in EntityFactory._ready:
  - Default pool: [EntityFactory._ready()](scripts/systems/EntityFactory.gd:33) through [EntityFactory._ready()](scripts/systems/EntityFactory.gd:38) prewarms 20.
  - Per-type pools: [EntityFactory._ready()](scripts/systems/EntityFactory.gd:39) through [EntityFactory._ready()](scripts/systems/EntityFactory.gd:54) iterate entity types, fetch sizes, and configure pools.
  - Size source: [ConfigurationManager.entity_pool_sizes](scripts/systems/ConfigurationManager.gd:27) through [ConfigurationManager.entity_pool_sizes](scripts/systems/ConfigurationManager.gd:30) with 300 bacteria and 200 nutrients by default.
- ObjectPool.configure pre-instantiates synchronously on main thread:
  - [ObjectPool.configure()](scripts/utils/ObjectPool.gd:9) through [ObjectPool.configure()](scripts/utils/ObjectPool.gd:20) loops prewarm_count, instantiate(), add_child() (to pool container), visible=false for CanvasItem.
- SpatialGrid perf logging is rate-limited and resets counters only when emitted:
  - [SpatialGrid._process()](scripts/systems/SpatialGrid.gd:36) through [SpatialGrid._process()](scripts/systems/SpatialGrid.gd:60)
  - [Log.every()](scripts/systems/Log.gd:83) through [Log.every()](scripts/systems/Log.gd:93)
- Post-stall logging shows frequent INFO destroys:
  - [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:91) through [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:110) includes per-destroy INFO log.

Hypothesis and root cause
- Root cause: synchronous mass instantiation (pool pre-warming) in the editor causes noticeable startup stalls. The work involves scene loading, node instantiation, adding to the scene tree (pool container), and property initialization, all on the main thread. This cost dwarfs logging overhead after our earlier logging reductions.
- Correlation with SpatialGrid perf line is coincidental. The perf line appears because SpatialGrid starts processing early and logs once per second; the stall happens due to concurrent heavy work from pool pre-warm or immediately adjacent system initialization.
- Secondary noise: INFO-level destroy logs can create additional console pressure during early consumption, but they begin after the main stall.

Recommendations (priority-ordered)
P0: Make pool pre-warm incremental and/or lazy
- Add an incremental prewarm API to ObjectPool to spread instantiation over multiple frames with a budget:
  - Proposed: ObjectPool.prewarm_async(total:int, per_frame:int=32) to run in _process until done, yielding each frame.
  - Alternatively: schedule with a Timer or call_deferred in small chunks to avoid blocking a single frame.
- In EntityFactory._ready, replace synchronous prewarm configure with either:
  - Minimal synchronous prewarm (e.g., 0–20 per type), then call prewarm_async with a per-frame budget.
  - Or fully lazy: do not prewarm; first acquire() instantiates on demand, optionally starting prewarm_async in the background after first frame.
- Gate editor/dev vs export:
  - In editor/dev builds, set very small or zero default prewarm counts to prioritize responsiveness.
  - In export, allow larger prewarm if needed for worst-case spikes.
  - Build-awareness via [ConfigurationManager._ready()](scripts/systems/ConfigurationManager.gd:48) through [ConfigurationManager._ready()](scripts/systems/ConfigurationManager.gd:90) or in [Log._apply_build_defaults()](scripts/systems/Log.gd:134) through [Log._apply_build_defaults()](scripts/systems/Log.gd:160).

P1: Instrument and verify
- Add timing around per-type configure/prewarm to confirm cost distribution:
  - Wrap calls in EntityFactory._ready with Time.get_ticks_usec() deltas and a single INFO summary per type (rate-limited or guarded).
  - References: [EntityFactory._ready()](scripts/systems/EntityFactory.gd:39) through [EntityFactory._ready()](scripts/systems/EntityFactory.gd:54).

P2: Reduce noise from destroy logs during early churn
- Downgrade destroy logs to DEBUG or gate with a rate limiter:
  - Change in [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:103) through [EntityFactory.destroy_entity()](scripts/systems/EntityFactory.gd:109).
  - This does not fix the stall but reduces console IO during initial behavior spikes.

P3: Optional: Defer initial batch operations by a frame
- If other systems also do heavy startup work on _ready, consider deferring some operations with call_deferred or a one-shot Timer to avoid piling everything on frame 0.

Proposed implementation outline (deferred; not applied yet)
- ObjectPool
  - Add fields: _prewarm_remaining:int, _prewarm_budget:int, _prewarming:bool
  - Add prewarm_async(total:int, per_frame:int)
  - Implement _process to instantiate min(per_frame, remaining) items, enqueue into pool container
  - Stop processing when done
  - References to change: [ObjectPool.configure()](scripts/utils/ObjectPool.gd:9)
- EntityFactory
  - Compute prewarm counts from config; clamp small in editor (e.g., 0–10)
  - After minimal configure, call pool.prewarm_async(remaining, budget_per_frame) for each type
  - References to change: [EntityFactory._ready()](scripts/systems/EntityFactory.gd:39) through [EntityFactory._ready()](scripts/systems/EntityFactory.gd:54)

Verification plan
1) With logging at CAT_SYSTEMS=INFO and CAT_PERF=DEBUG:
   - Instrument EntityFactory prewarm steps and print a single INFO summary per type with total time.
   - Confirm startup displays no multi-second stall; FPS remains responsive from frame 0–1.
2) Confirm that SpatialGrid perf lines remain rate-limited and are not the stall source: [SpatialGrid._process()](scripts/systems/SpatialGrid.gd:36) through [SpatialGrid._process()](scripts/systems/SpatialGrid.gd:60).
3) Optionally downgrade EntityFactory destroy logs to DEBUG and verify console noise decreases during early consumption.
4) Stress test with higher target counts and pool sizes, and measure delta between synchronous and incremental prewarm.

Notes on F6 fix
- Input event swallowing now uses SceneTree API instead of calling accept on InputEventKey.
  - Updated handler: [Log._unhandled_key_input()](scripts/systems/Log.gd:162) now calls get_tree().set_input_as_handled() for non-editor builds, preventing editor shortcut conflicts while leaving editor behavior untouched.
- Key mapping was remapped to F6/Shift+F6 at runtime defaults and in project settings:
  - Runtime map: [ConfigurationManager._ensure_input_actions()](scripts/systems/ConfigurationManager.gd:91) through [ConfigurationManager._ensure_input_actions()](scripts/systems/ConfigurationManager.gd:110)
  - Project settings updated: [project.godot](project.godot:85) through [project.godot](project.godot:94)

Conclusion
- The remaining stall is most consistent with synchronous pool prewarming. Implementing incremental/lazy prewarm and minimizing editor-time prewarm should eliminate the startup hitch without sacrificing runtime performance. Logging changes reduced IO cost but cannot address the underlying instantiation burst. The outlined plan prioritizes moving heavy work off frame 0 and validating with lightweight instrumentation.