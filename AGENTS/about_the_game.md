# Proposal for Petri Dish Simulation Game in Godot

## Executive Summary

This proposal outlines the development of a 2D simulation game titled Petri Pandemonium, built using the Godot engine. The game simulates a virtual Petri dish where players can observe and interact with microorganisms in a sandbox environment, emphasizing emergent behaviors, biological interactions, and educational elements. The target is an MVP+ (Minimum Viable Product with select enhancements) to ensure a polished core experience while allowing for future expansions.

The audience for this document is an AI chatbot specialized in generating system architecture design documents, technical specifications, and implementation guides. These outputs will enable a team of coders to prototype and develop the game efficiently. Key focuses include modularity, performance for handling numerous entities, and leveraging Godot's strengths in 2D physics and node-based architecture.

Project goals:
- Create an engaging, relaxing simulation that mimics real microbiology.
- Prioritize emergent gameplay over scripted events.
- Keep development lightweight: Simple 2D graphics, no 3D or complex assets.
- Educational value through optional tooltips and logs.
- MVP+ scope: Core simulation + basic player tools + one challenge mode + evolution mechanics.

Estimated development effort: 4-6 weeks for MVP+ with a small team (2-3 coders), assuming familiarity with Godot and GDScript.

## Project Overview

### Concept
Petri Pandemonium places players in the role of a scientist observing and experimenting on a microscopic ecosystem within a Petri dish. The simulation runs in real-time, with organisms exhibiting autonomous behaviors driven by simple AI and physics. Players can passively watch ecosystems evolve or actively intervene to create chaos or achieve goals. Inspired by games like *The Bibites* or *Spore*'s cell stage, but simplified for accessibility.

### Target Platform
- Primary: Desktop (Windows, macOS, Linux) via Godot export.

### Art Style
- Visuals: Minimalist 2D – circles/ellipses for organisms, particle effects for actions (e.g., division, death). Petri dish as a circular boundary with subtle agar texture.

## Scope: MVP+ Features

### MVP Core Features
These form the essential playable build.

1. **Simulation Environment**
   - Circular Petri dish arena (Node2D with collision boundaries).
   - Nutrient particles: Randomly spawned, consumable dots that organisms seek.
   - Basic physics: Godot's 2D physics engine for movement, collisions, and Brownian-like jitter.

2. **Organism Types and Behaviors**
   - **Bacteria**: Basic entities (Area2D nodes) that move randomly, consume nutrients, and reproduce asexually when energy threshold met. Traits: Speed, size (affecting collision/rate).
   - **Amoebas (Protists)**: Predators that detect and chase bacteria via simple pathfinding (e.g., move_toward_vector). Engulf prey on contact, gaining energy.
   - **Viruses**: Infect bacteria on contact, converting them into replicators after a delay. Non-motile or slow-drifting.
   - Behaviors implemented as state machines in GDScript: Wander, Feed, Reproduce, Flee (for prey).
   - Population cap: Soft limit via resource scarcity to prevent lag (e.g., max 500 entities).

3. **Emergent Interactions**
   - Predator-prey dynamics: Modeled with basic equations (e.g., growth rates adjusted in _process()).
   - Reproduction and death: Instancing new nodes on division; queue_free() on death with particle burst.
   - Simple ecosystem balance: Nutrients deplete/respawn; overpopulation leads to starvation.

4. **Player Observation**
   - Camera controls: Zoom/pan with mouse/wheel (Camera2D node).
   - UI overlays: Real-time stats (population count, species breakdown) using Control nodes.

### + Enhancements (Beyond MVP)
These add polish and replayability without overcomplicating the core.

1. **Player Intervention Tools**
   - Toolbar UI: Drop organisms/nutrients/hazards via mouse clicks (e.g., antibiotic zones as temporary Area2D killers).
   - Stir tool: Drag to apply force vectors, mixing the dish.
   - Time manipulation: Speed up/slow down global simulation speed.

2. **Evolution Mechanics**
   - Random mutations on reproduction: Slight trait variations (e.g., +10% speed) passed to offspring.
   - Survival of the fittest: Track generations; immune strains emerge after hazards.

3. **Game Modes**
   - **Sandbox**: Free experimentation.
   - **Challenge Mode**: One scenario, e.g., "Balance Ecosystem" – Maintain stable populations for X time; unlock new tools on success.

4. **Educational Elements**
   - Hover tooltips: Explain behaviors (e.g., "Binary fission: Asexual reproduction in bacteria").
   - Event log: Scrollable panel logging key events (infections, extinctions).

### Out of Scope for MVP+
- Multiplayer/co-op.
- Advanced AI (e.g., neural networks).
- 3D graphics or complex shaders.
- Full modding system (though design for extensibility).

## Technical Requirements and Guidelines

### Engine and Tools
- Godot 4.5+ for its improved 2D features and performance.
- Language: GDScript for rapid prototyping
- Dependencies: None external; use built-in nodes (Area2D, RigidBody2D, ParticleSystem2D).

### High-Level Architecture
- **Scene Structure**:
  - MainScene: Root with DishNode (simulation container), UILayer, Camera.
  - Organism scenes: BaseOrganism (inherited script) with variants for each type.
  - Manager scripts: SimulationManager (handles spawning, updates), UIManager.
- **Performance Considerations**:
  - Use MultiMeshInstance or EntityComponentSystem pattern for large populations.
  - Optimize _process() loops; use signals for events (e.g., on_body_entered for collisions).
- **Data Handling**:
  - Traits as dictionaries or custom resources.
  - Save/load states: Serialize ecosystem for resuming experiments (Godot's ResourceSaver).
- **Testing**:
  - Playtesting focus: Balance emergence without frustration.