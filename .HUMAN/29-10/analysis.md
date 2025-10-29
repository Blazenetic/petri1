# Godot 4.5 pooling and prewarming: analysis and recommendations

## Summary
- There is a multi‑second startup stall which correlates with mass pool prewarming executed on frame 0 via [EntityFactory._ready()](scripts/systems/EntityFactory.gd:39)–[EntityFactory._ready()](scripts/systems/EntityFactory.gd:54), which configures large pool sizes from [ConfigurationManager.entity_pool_sizes](scripts/systems/ConfigurationManager.gd:27)–[ConfigurationManager.entity_pool_sizes](scripts/systems/ConfigurationManager.gd:30), and pre‑instantiates synchronously in [ObjectPool.configure()](scripts/utils/ObjectPool.gd:9)–[ObjectPool.configure()](scripts/utils/ObjectPool.gd:20).
- SpatialGrid perf logging is near the stall but not causal: [SpatialGrid._process()](scripts/systems/SpatialGrid.gd:36)–[SpatialGrid._process()](scripts/systems/SpatialGrid.gd:60), with rate limiting via [Log.every()](scripts/systems/Log.gd:83)–[Log.every()](scripts/systems/Log.gd:93).
- Reducing Bacteria/Nutrient pool sizes from 300/200 to 30/20 removes the stall, further implicating synchronous prewarm as the root cost.

## Recommended strategy 

Using `MultiMeshInstance2D` + Custom Shader (GPU-Driven)

Goal: Render thousands of bacteria with individual color, size, and shape using one draw call.

---

### Core Idea
- Do NOT use one `Sprite2D` per bacterium → too many draw calls → lag.
- Use `MultiMeshInstance2D` → draws all bacteria in a single batch.
- Control appearance per instance using:
  - `instance_color` → color
  - `instance_custom_data` → size + shape ID
  - Shader → interprets shape ID and draws circle, oval, spiky, etc.

---

### What to Implement

1. One `MultiMeshInstance2D` node in the scene (e.g., `BacteriaRenderer`).
2. Set `instance_count` to max bacteria (e.g., 10,000).
3. Enable `use_custom_data = true`.
4. Assign a simple base texture (e.g., white circle or square).
5. Create a `canvas_item` shader that:
   - Reads `INSTANCE_CUSTOM.x` → size
   - Reads `INSTANCE_CUSTOM.y` → shape ID (0=circle, 1=oval, 2=spiky, etc.)
   - Computes distance field in `fragment()` to draw the shape
   - Uses `COLOR` for tint
6. CPU-side: Maintain arrays or buffer:
   - Position → `set_instance_transform_2d(id, Transform2D(0, pos))`
   - Color → `set_instance_color(id, col)`
   - Size + Shape → `set_instance_custom_data_0(id, Vector4(size, shape_id, 0, 0))`
7. Update only changed instances each frame (or use dirty flags).
8. For death: Mark as inactive (set alpha=0 or move off-screen), reuse slot.

---

### Benefits
- 1 draw call for 10,000+ bacteria
- Full per-bacterium visual control
- 60+ FPS on PC and mobile
- Scales infinitely (GPU-limited, not CPU)

---

### Do NOT
- Use `Sprite2D`, `Polygon2D`, or `Node2D` per bacterium
- Change texture per instance
- Use `modulate` or `scale` on individual nodes

---

### Summary for Implementation

Replace all `Node2D`-based bacteria rendering with one `MultiMeshInstance2D` + shader. Drive color, size, shape via per-instance data. Update via CPU arrays → GPU buffer. Reuse instance slots on death. This is the only scalable path for thousands of dynamic visuals.