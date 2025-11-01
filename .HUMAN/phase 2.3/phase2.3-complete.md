Phase 2.3 core implementation completed with stack-capable state machine, bacteria state set, prioritized transitions, history/telemetry, and HUD debug state display. Summary of changes:

Core state system
- Updated (scripts/behaviors/state/State.gd) to add optional helpers without changing lifecycle:
  - state_name(), state_tint(), is_transient() for UI/telemetry consumption.
- Extended (scripts/behaviors/state/StateMachine.gd) to a safe, stack-capable machine:
  - Internal stack with O(1) push/pop/replace/clear/peek.
  - Deferred transitions with reentrancy guard; single pending request with priority CLEAR, POP, REPLACE, PUSH applied after current update.
  - Backwards-compatible set_state() now routes to replace semantics.
  - Signals: state_changed(prev, new, reason), stack_changed(depth).
  - No per-frame allocations in update.

Behavior controller
- Enhanced (scripts/behaviors/BehaviorController.gd):
  - Prioritized transitions per design:
    - Dying: replace on BiologicalComponent died callback.
    - Reproducing: replace when can_reproduce_now() and not Dying.
    - Feeding: push when SeekNutrient has target AND overlapping a nutrient; respects internal cooldown.
    - Seeking fallback: ensure at least Seeking when stack is empty.
  - State instances constructed once per entity; reused across lifetime.
  - Added ring-buffer state history (_state_history) with capacity from config; entries store {timestamp_sec, from_state, to_state, reason}. Accessors: get_current_state_name(), get_state_history().
  - Transition hooks connected to StateMachine.state_changed signal.
  - Grouped controllers under "BehaviorControllers" for HUD debug selection.

Species states
- Seeking unchanged in role; it resets visuals on enter. (scripts/behaviors/bacteria/BacteriaStateSeeking.gd)
- New Idle state added at (scripts/behaviors/bacteria/BacteriaStateIdle.gd); low activity, subtle desaturation/alpha, zero acceleration.
- New Feeding state added at (scripts/behaviors/bacteria/BacteriaStateFeeding.gd); transient push with small brighten/size pulse, short duration, and cooldown (respects ConfigurationManager.bacteria_feeding_cooldown_ms), then sm.pop() to resume Seeking.
- Existing Reproducing and Dying states kept; Reproducing returns to Seeking on completion, Dying performs terminal sequence and destruction.

Movement/target integration
- Added public accessors to (scripts/behaviors/SeekNutrient.gd): has_target(), get_current_target_id(), get_current_target_pos() for Feeding eligibility and future telemetry.

Configuration flags
- Extended (scripts/systems/ConfigurationManager.gd):
  - bacteria_feeding_cooldown_ms = 250 (default)
  - debug_show_states = false (default)
  - behavior_state_history_capacity = 32 (default)

HUD debug visualization
- Added debug state display at (scripts/ui/HUD.gd) and bound to (scenes/ui/HUD.tscn). When ConfigurationManager.debug_show_states is true, shows current state of a temporary “first controller in group” selection. Reads current state from BehaviorController; no direct state introspection.

Behavior and safety notes
- Transitions are deterministic and applied post-update, preventing reentrancy/oscillation.
- Stack semantics use exit/enter on push/pop/replace/clear as specified; no pause/resume callbacks introduced.
- Visual hints limited to BaseEntity.base_color and PhysicalComponent.size only, aligned with RIS; no per-frame visual allocations.
- Feeding is only entered with both target lock and physical overlap, and respects a cooldown to avoid thrashing.

Validation checklist to exercise
- Enable debug_show_states in (scripts/systems/ConfigurationManager.gd) and run Game/Main to view state in HUD.
- Confirm:
  - Default Seeking on spawn via BehaviorController initialization.
  - Feeding: occurs only on target lock plus nutrient overlap; returns to Seeking; respects cooldown window.
  - Reproducing: triggers per BiologicalComponent.should_reproduce gate and controller limiter; replaces current state; on completion returns to Seeking.
  - Dying: interrupts any state and performs destruction path.
  - History: BehaviorController.get_state_history() shows recent transitions with timestamps and reasons, bounded by capacity.
- Performance sanity: transitions are O(1), stack operations allocate no arrays per frame; visual changes occur on state boundaries.

Files touched/added
- Updated
  - (scripts/behaviors/state/State.gd)
  - (scripts/behaviors/state/StateMachine.gd)
  - (scripts/behaviors/BehaviorController.gd)
  - (scripts/behaviors/SeekNutrient.gd)
  - (scripts/systems/ConfigurationManager.gd)
  - (scenes/ui/HUD.tscn)
- New
  - (scripts/behaviors/bacteria/BacteriaStateFeeding.gd)
  - (scripts/behaviors/bacteria/BacteriaStateIdle.gd)
  - (scripts/ui/HUD.gd)

This implements the Phase 2.3 decisions and acceptance criteria in AGENTS/phase_2.3.md while keeping the state machine reusable for future species and preserving existing steering behavior integration.