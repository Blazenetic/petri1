extends RefCounted
class_name StateMachine

var current: State = null
var current_name: StringName = StringName()

func set_state(owner, name: StringName, state: State) -> void:
	if current != null:
		current.exit(owner)
	current = state
	current_name = name
	if current != null:
		current.enter(owner)

func update(owner, delta: float) -> void:
	if current != null:
		current.update(owner, delta)

func is_in(name: StringName) -> bool:
	return current != null and current_name == name