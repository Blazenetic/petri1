# Phase 1.3 — Petri Dish Environment Implementation Guide

Purpose: Equip the Code AI agent with precise, atomic tasks to implement the Petri dish environment in Godot 4.5 with clear acceptance criteria and integration points.

References:
- [AGENTS/phased_plan.md](AGENTS/phased_plan.md)
- [AGENTS/proposal.md](AGENTS/proposal.md)
- [AGENTS/system_architecture.md](AGENTS/system_architecture.md)
- Existing scene: [scenes/environments/PetriDish.tscn](scenes/environments/PetriDish.tscn)
- Config: [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd:1)

Scope (Phase 1.3 tasks):
- Create PetriDish scene with circular boundary using StaticBody2D
- Implement dish boundary collision detection and response
- Create visual representation: circular background with agar texture
- Add dish radius configuration and scaling system
- Implement coordinate system with dish center as origin
- Create boundary margin system to prevent entity spawn at edges
- Add debug visualization for dish quadrants and grid cells

Current status snapshot:
- Circle boundary and StaticBody2D exist in [scenes/environments/PetriDish.tscn](scenes/environments/PetriDish.tscn).
- Dish radius parameter exists in config: see [GDScript._ready()](scripts/systems/ConfigurationManager.gd:15) and exported values in [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd:4).

Implementation plan (ordered, atomic tasks)

1) Attach a controller script to PetriDish
- Create [scripts/environments/PetriDish.gd](scripts/environments/PetriDish.gd)
- Attach to the root Node2D of [scenes/environments/PetriDish.tscn](scenes/environments/PetriDish.tscn)
- Responsibilities:
  - Own the canonical dish radius and sync CollisionShape2D
  - Provide coordinate conversion helpers and boundary queries
  - Provide spawn utilities with margin
  - Emit signal on radius change
- Required API (to implement):
  - [GDScript.get_radius()](scripts/environments/PetriDish.gd:1) -> float
  - [GDScript.set_radius()](scripts/environments/PetriDish.gd:1) (r: float) -> void
  - [GDScript.is_inside_dish()](scripts/environments/PetriDish.gd:1) (p: Vector2, margin := 0.0) -> bool
  - [GDScript.clamp_to_dish()](scripts/environments/PetriDish.gd:1) (p: Vector2, margin := 0.0) -> Vector2
  - [GDScript.resolve_boundary_collision()](scripts/environments/PetriDish.gd:1) (pos: Vector2, vel: Vector2, radius: float) -> Dictionary
  - [GDScript.get_random_point()](scripts/environments/PetriDish.gd:1) (margin := 0.0) -> Vector2
  - [GDScript.world_to_dish()](scripts/environments/PetriDish.gd:1) (p: Vector2) -> Vector2
  - [GDScript.dish_to_world()](scripts/environments/PetriDish.gd:1) (p: Vector2) -> Vector2
- Signals:
  - [GDScript.signal radius_changed](scripts/environments/PetriDish.gd:1) (new_radius: float)

2) Sync radius with ConfigurationManager
- On [GDScript._ready()](scripts/environments/PetriDish.gd:1), read starting radius from [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd:4) and apply via [GDScript.set_radius()](scripts/environments/PetriDish.gd:1)
- Update both:
  - CollisionShape2D shape.radius
  - Visuals scale/size
- Provide [GDScript.apply_radius_to_nodes()](scripts/environments/PetriDish.gd:1) helper called whenever radius changes

3) Boundary collision detection and response
- Implement [GDScript.is_inside_dish()](scripts/environments/PetriDish.gd:1): length(p - dish_center) <= (radius - margin)
- Implement [GDScript.resolve_boundary_collision()](scripts/environments/PetriDish.gd:1):
  - If length(pos) + entity_radius <= radius: return unchanged
  - Otherwise:
    - n = pos.normalized()
    - pos = n * max(radius - entity_radius, 0.0)
    - vel = vel - 2.0 * (vel.dot(n)) * n  // reflect
  - Return { "pos": pos, "vel": vel }
- Note: This API is used by future movement systems (Phase 1.4) and can be unit-tested now

4) Visual representation (agar background)
- Under "Visuals" node:
  - Option A (fast): Add [Sprite2D](scenes/environments/PetriDish.tscn) with a simple radial gradient shader at [assets/shaders/agar_circle.gdshader](assets/shaders/agar_circle.gdshader)
  - Option B (minimal): Implement [GDScript._draw()](scripts/environments/PetriDish.gd:1) on a child Node2D to draw a filled circle using draw_circle with a soft edge via multiple rings
- Expose colors via exports on [scripts/environments/PetriDish.gd](scripts/environments/PetriDish.gd)

5) Coordinate system (dish center as origin)
- Ensure PetriDish root is at world origin in [scenes/Game.tscn](scenes/Game.tscn)
- Implement helpers:
  - [GDScript.world_to_dish()](scripts/environments/PetriDish.gd:1): return (p - global_position)
  - [GDScript.dish_to_world()](scripts/environments/PetriDish.gd:1): return (p + global_position)
- Document that all spatial queries will assume dish-local coordinates in future systems

6) Boundary margin system for spawns
- Implement [GDScript.get_random_point()](scripts/environments/PetriDish.gd:1) with margin parameter:
  - r = randf_range(0.0, radius - margin)
  - a = randf_range(0.0, TAU)
  - return Vector2(cos(a), sin(a)) * r
- Use this from [scripts/systems/EntityFactory.gd](scripts/systems/EntityFactory.gd:1) when spawning entities to avoid edge spawns

7) Debug visualization (quadrants and grid cells)
- Add child node "DebugDraw" (Node2D) under PetriDish with [scripts/environments/PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd)
- Toggle via a bool export or a flag in [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd:1)
- Draw:
  - Crosshair axes at 0°, 90°, 180°, 270°
  - Circular outline for dish
  - Optional grid using cell size from [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd:5)
- Re-draw when radius changes (connect [GDScript.radius_changed](scripts/environments/PetriDish.gd:1))

8) Game scene wiring
- Confirm [scenes/Game.tscn](scenes/Game.tscn) positions PetriDish at (0,0) and camera frames the dish
- Expose PetriDish as a group "Dish" or register a reference on a global (e.g., [scripts/systems/WorldState.gd](scripts/systems/WorldState.gd:1)) for easy access by systems

File changes to implement
- Modify: [scenes/environments/PetriDish.tscn](scenes/environments/PetriDish.tscn)
- Attach [scripts/environments/PetriDish.gd](scripts/environments/PetriDish.gd)
- Add child "DebugDraw" with [scripts/environments/PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd)
- Add visuals child content (Sprite2D or custom draw)
- Create: [scripts/environments/PetriDish.gd](scripts/environments/PetriDish.gd)
- Create: [scripts/environments/PetriDishDebugDraw.gd](scripts/environments/PetriDishDebugDraw.gd)
- Optional Create: [assets/shaders/agar_circle.gdshader](assets/shaders/agar_circle.gdshader)

Coding notes
- Use Node2D units as pixels; radius measured in pixels; default from config matches existing shape in [scenes/environments/PetriDish.tscn](scenes/environments/PetriDish.tscn)
- Keep scripts under 300 lines and single-responsibility
- Prefer composition: PetriDish handles data/logic; DebugDraw handles rendering overlays
- Use signals for decoupling: [GDScript.radius_changed](scripts/environments/PetriDish.gd:1)

Acceptance criteria (must all pass)
- Scene loads without errors; Console shows no warnings from dish scripts
- CollisionShape2D radius equals configured radius at runtime (tolerant within 0.1)
- Entities spawned via factory never appear within 16px of boundary when margin=16 is used
- Boundary response reflects a test velocity vector with correct angle of incidence = angle of reflection (±1°)
- Visual agar present and scales correctly when radius changes
- Debug overlay toggles on/off and shows quadrants and a grid using config cell size
- Coordinate helpers return identity round-trip: dish_to_world(world_to_dish(P)) == P (±0.5px)

Manual test procedure
- Run the game; verify dish visible and centered
- Temporarily call [GDScript.set_radius()](scripts/environments/PetriDish.gd:1) at runtime (e.g., via an input key) and confirm boundary and visuals update
- Spawn 20 dummy entities at [GDScript.get_random_point()](scripts/environments/PetriDish.gd:1) with margin=32; visually confirm no spawns near edge
- Toggle debug draw; verify axes, circle outline, and grid are correct
- For boundary response, simulate a point outside the radius and confirm clamping and velocity reflection work

Integration points for upcoming phases
- Phase 1.4 movement will use [GDScript.resolve_boundary_collision()](scripts/environments/PetriDish.gd:1) each update
- Phase 1.5 spatial grid will reuse radius and grid size to compute cell bounds and debug visuals

Definition of Done
- All acceptance criteria met
- Code documented with brief comments per method
- No regressions in existing scenes [scenes/Main.tscn](scenes/Main.tscn) and [scenes/Game.tscn](scenes/Game.tscn)
- Commit includes updated scenes and new scripts/shaders with meaningful names

Notes
- Keep parameters (colors, debug flags) exported for quick tuning in editor
- Defer heavy shaders; prioritize simple visuals to unblock later phases