extends RefCounted
class_name State

# Abstract behavior state with no-op lifecycle hooks.
# Owner is typically a BehaviorController.

# --- Lifecycle hooks (do not change signatures) ---
func enter(owner) -> void:
	pass

func update(owner, delta: float) -> void:
	pass

func exit(owner) -> void:
	pass

# --- Optional metadata helpers (non-mandatory; UI/debug may use if present) ---
# Short human-readable state identifier. Defaults to script class_name via get_class().
func state_name() -> StringName:
	return StringName(get_class())

# Optional tint used by controllers/renderers for RIS-friendly hints. Defaults to white (no change).
func state_tint() -> Color:
	return Color.WHITE

# Whether this state is expected to be short-lived/transient when stacked.
func is_transient() -> bool:
	return false