# Issues — Phase A status: MultiMesh per‑instance color/custom on Godot 4.5

Current status
- Phase A renderer uses a single MultiMeshInstance2D with RenderingServer-backed allocation to restore per-instance rendering.
- Per-instance color/custom are enabled when supported at runtime; otherwise, the renderer falls back to a uniform modulate color.

What changed
1) RenderingServer allocation (authoritative)
- MultiMesh formats allocated in [BacteriaRenderer.init()](scripts/rendering/BacteriaRenderer.gd:23) via [RenderingServer.multimesh_allocate_data()](scripts/rendering/BacteriaRenderer.gd:30).
- Avoids parser errors such as "Cannot find member 'ColorFormat' in base 'MultiMesh'".

2) Capability probe + guarded writes
- One-time probe runs during init in [BacteriaRenderer._probe_capabilities()](scripts/rendering/BacteriaRenderer.gd:104).
- Flags recorded: _supports_instance_color, _supports_instance_custom; logs a concise capability line.
- Color/custom writes in [BacteriaRenderer.set_slot()](scripts/rendering/BacteriaRenderer.gd:62) and clears in [BacteriaRenderer._hide_index()](scripts/rendering/BacteriaRenderer.gd:89) are guarded by these flags.

3) Graceful fallback
- If per-instance color unsupported, the node sets a uniform modulate color during probe (see [BacteriaRenderer._probe_capabilities()](scripts/rendering/BacteriaRenderer.gd:143)) and skips per-instance color writes.
- Per-instance transforms remain active for sizing/placement via [MultiMesh.set_instance_transform_2d()](scripts/rendering/BacteriaRenderer.gd:74).

Where to look in code
- Renderer init: [BacteriaRenderer.init()](scripts/rendering/BacteriaRenderer.gd:23)
- Capability probe: [BacteriaRenderer._probe_capabilities()](scripts/rendering/BacteriaRenderer.gd:104)
- Per-instance writes: [BacteriaRenderer.set_slot()](scripts/rendering/BacteriaRenderer.gd:62)
- Hide/clear path: [BacteriaRenderer._hide_index()](scripts/rendering/BacteriaRenderer.gd:89)
- System summary log on startup: [BacteriaSystem._ready()](scripts/systems/BacteriaSystem.gd:24)
- Fallback toggle: [ConfigurationManager.bacteria_render_mode](scripts/systems/ConfigurationManager.gd:27)

Validation steps
- Open and run [scenes/Main.tscn](scenes/Main.tscn)
- In ConfigurationManager, set bacteria_initial_count to at least 2000, bacteria_max_instances at or above that number.
- Observe logs:
  - "[BacteriaRenderer] caps ..." once from the renderer.
  - "[BacteriaSystem] renderer_caps ..." once from the system.
- Visuals:
  - Thousands of AA circles render smoothly.
  - If instance color is supported: varied colors per instance.
  - If unsupported: uniform material modulate color applies; sizing still driven by instance transform scale.
- Perf:
  - 1 Hz perf line from BacteriaSystem shows active, updates/s, slots.

Known engine notes
- Previous attempts to assign MultiMesh color/custom formats via enum properties caused parser errors on Godot 4.5 (e.g., 'ColorFormat' not found, invalid assignment to color_format).
- Allocating formats via RenderingServer avoids editor/parser symbol mismatches and is resilient across builds.

Regression and rollback
- To restore the node-based renderer path immediately, set [ConfigurationManager.bacteria_render_mode](scripts/systems/ConfigurationManager.gd:27) = 0.
- Existing APIs for spawn/despawn and per-frame updates remain unchanged.

Current outcome
- RS allocation in place; capability probe active; guarded writes prevent runtime errors; uniform fallback ensures visuals even when per-instance channels are not exposed by the build.

Future notes
- INSTANCE_CUSTOM is reserved for later features. The probe records support but no runtime branching depends on it yet.
- If targeting Web export, keep the capability probe; behavior may differ by platform/driver.