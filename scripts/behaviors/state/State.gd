extends RefCounted
class_name State

# Abstract behavior state with no-op lifecycle hooks.
# Owner is typically a BehaviorController.
func enter(owner) -> void:
	pass

func update(owner, delta: float) -> void:
	pass

func exit(owner) -> void:
	pass