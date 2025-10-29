Phase 2.2b implemented with additive changes, editor-tunable config, temporary state controller, events, and lightweight VFX.

Files added
- [scripts/behaviors/state/State.gd](scripts/behaviors/state/State.gd)
- [scripts/behaviors/state/StateMachine.gd](scripts/behaviors/state/StateMachine.gd)
- [scripts/behaviors/BehaviorController.gd](scripts/behaviors/BehaviorController.gd)
- [scripts/behaviors/bacteria/BacteriaStateSeeking.gd](scripts/behaviors/bacteria/BacteriaStateSeeking.gd)
- [scripts/behaviors/bacteria/BacteriaStateReproducing.gd](scripts/behaviors/bacteria/BacteriaStateReproducing.gd)
- [scripts/behaviors/bacteria/BacteriaStateDying.gd](scripts/behaviors/bacteria/BacteriaStateDying.gd)

Files modified
- [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd)
- [scripts/components/IdentityComponent.gd](scripts/components/IdentityComponent.gd)
- [scripts/components/BiologicalComponent.gd](scripts/components/BiologicalComponent.gd)
- [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd)
- [scenes/entities/Bacteria.tscn](scenes/entities/Bacteria.tscn)

Key changes summary
1) Reproduction configuration
- Added exports on [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd):
  - bacteria_repro_energy_threshold = 10.0
  - bacteria_repro_cooldown_sec = 8.0
  - bacteria_repro_energy_cost_ratio = 0.2
  - bacteria_offspring_energy_split_ratio = 0.5
  - bacteria_offspring_offset_radius = 10.0
  - bacteria_max_children_per_min = 20
These are editor-tunable and read at runtime.

2) Identity and genealogy
- Added generation:int and parent_id:StringName to [scripts/components/IdentityComponent.gd](scripts/components/IdentityComponent.gd). Existing uuid generation is preserved and generation/parent_id are not reset on pooling.

3) Biological component extensions
- Added runtime fields repro_cooldown_timer and pending_repro to [scripts/components/BiologicalComponent.gd](scripts/components/BiologicalComponent.gd).
- Cooldown decremented in update; helper methods:
  - should_reproduce(): evaluates energy threshold and cooldown using ConfigurationManager.
  - apply_reproduction_bookkeeping(): applies energy cost, computes parent/child energies, sets cooldown, returns child energy.
- Death intercept: still emits died(reason), but defers direct destruction if a BehaviorController node is present, allowing the polished Dying state to own destruction.

4) Global events
- Added bacteria_reproduction_started, bacteria_reproduction_completed, and entity_died signals in [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd). Existing entity_destroyed remains emitted by EntityFactory.

5) Temporary behavior controller and states
- State base and machine:
  - [scripts/behaviors/state/State.gd](scripts/behaviors/state/State.gd)
  - [scripts/behaviors/state/StateMachine.gd](scripts/behaviors/state/StateMachine.gd)
- Controller:
  - [scripts/behaviors/BehaviorController.gd](scripts/behaviors/BehaviorController.gd)
    - Caches BaseEntity, MovementComponent, BiologicalComponent, IdentityComponent, PhysicalComponent, and optional FissionBurst.
    - Subscribes to BiologicalComponent.died to transition to Dying.
    - Transitions to Reproducing when BiologicalComponent.should_reproduce() is true and not already Dying/Reproducing.
    - Enforces bacteria_max_children_per_min with a time-window limiter.
- States:
  - Seeking: [scripts/behaviors/bacteria/BacteriaStateSeeking.gd](scripts/behaviors/bacteria/BacteriaStateSeeking.gd) leaves existing steering free; resets visuals on enter.
  - Reproducing: [scripts/behaviors/bacteria/BacteriaStateReproducing.gd](scripts/behaviors/bacteria/BacteriaStateReproducing.gd)
    - Zeroes movement; emits GlobalEvents.bacteria_reproduction_started.
    - Pre-split tween: Physical.size +15% and brighten BaseEntity.base_color over 0.2 s.
    - Spawns child via EntityFactory.create_entity_clamped, runs a brief FissionBurst, then post-split tween restores parent (and child size) over 0.2 s.
    - Uses BiologicalComponent.apply_reproduction_bookkeeping to split energy and set cooldown, then emits bacteria_reproduction_completed and returns to Seeking.
  - Dying: [scripts/behaviors/bacteria/BacteriaStateDying.gd](scripts/behaviors/bacteria/BacteriaStateDying.gd)
    - Zeroes motion; soft “puff” using FissionBurst.
    - Tween 0.3 s shrinking Physical.size and fading BaseEntity.base_color alpha to 0.
    - Emits GlobalEvents.entity_died, then calls EntityFactory.destroy_entity.

6) Binary fission VFX
- Added CPUParticles2D FissionBurst to [scenes/entities/Bacteria.tscn](scenes/entities/Bacteria.tscn) (one_shot burst, lifetime 0.3s, modest amount). BehaviorController matches particles’ modulate to the organism tint and restarts on fission.
- Pre and post split tween behavior implemented in Reproducing state.
- Bacteria scene now includes a BehaviorController node under Components.

7) Inheritance policy applied on child spawn
- Implemented in BehaviorController.spawn_offspring:
  - size from parent BaseEntity.size,
  - movement speed from parent MovementComponent.max_speed,
  - base_color with tiny jitter,
  - identity genealogy linking child.generation = parent.generation + 1 and child.parent_id = parent.uuid,
  - energy distribution: child energy set from bookkeeping, parent energy updated and cooldown applied in the parent BiologicalComponent.

Design and safety notes
- Additive, decoupled approach using GlobalEvents and signals; no hard coupling across systems.
- BehaviorController degrades gracefully if components are missing; null checks in all states and controller.
- BiologicalComponent no longer double-destroys when BehaviorController is present, mitigating the double destruction risk.
- Visuals are reset on Seeking enter, mitigating pooling residual visuals.

Testing guidance (per plan)
- Adjust thresholds in [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd) for fast reproduction (e.g., bacteria_repro_energy_threshold = 6.0) and increase nutrient_target_count; observe multiple fission events.
- Raise bacteria_repro_cooldown_sec to verify cooldown enforcement; stress with many bacteria to see bacteria_max_children_per_min gate population.
- Reduce nutrients to exercise the death flow; confirm no ghosts remain and entity is removed from SpatialGrid/EntityRegistry as EntityFactory.destroy_entity is called only after Dying tween.
- Optionally log via [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd) signals for bacteria_reproduction_started, bacteria_reproduction_completed, and entity_died.

This completes Phase 2.2b deliverables with reproducible, tunable bacteria reproduction, polished death, and events aligned with the architecture.