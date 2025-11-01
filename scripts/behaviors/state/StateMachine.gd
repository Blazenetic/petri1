extends RefCounted
class_name StateMachine

signal state_changed(prev_name: StringName, new_name: StringName, reason: String)
signal stack_changed(depth: int)

var current: State = null
var current_name: StringName = StringName()

var _stack: Array[Dictionary] = [] # each entry: { "name": StringName, "state": State }

const OP_NONE := 0
const OP_PUSH := 1
const OP_REPLACE := 2
const OP_POP := 3
const OP_CLEAR := 4

var _pending_op: int = OP_NONE
var _pending_payload: Dictionary = {}
var _in_update: bool = false

func depth() -> int:
	return _stack.size()

func peek() -> Dictionary:
	if _stack.is_empty():
		return {}
	return _stack[_stack.size() - 1]

func is_in(name: StringName) -> bool:
	return current != null and current_name == name

# Backwards compatible: set_state acts as replace on the stack top
func set_state(owner, name: StringName, state: State) -> void:
	replace_state(owner, name, state, "set_state")

func push(owner, name: StringName, state: State, reason: String = "push") -> void:
	if state == null:
		_print_warn("push rejected: null state for %s" % [String(name)])
		return
	# Disallow consecutive duplicates by name (can be relaxed later via a flag)
	if not _stack.is_empty():
		var top: Dictionary = _stack.back()
		if top.get("name", StringName()) == name:
			return
	_request_transition(owner, OP_PUSH, {"name": name, "state": state, "reason": reason})

func replace_state(owner, name: StringName, state: State, reason: String = "replace") -> void:
	if state == null:
		_print_warn("replace rejected: null state for %s" % [String(name)])
		return
	_request_transition(owner, OP_REPLACE, {"name": name, "state": state, "reason": reason})

func pop(owner, reason: String = "pop") -> void:
	if _stack.is_empty():
		return
	_request_transition(owner, OP_POP, {"reason": reason})

func clear(owner, reason: String = "clear", default_name: StringName = StringName(), default_state: State = null) -> void:
	_request_transition(owner, OP_CLEAR, {"reason": reason, "default_name": default_name, "default_state": default_state})

func update(owner, delta: float) -> void:
	_in_update = true
	if current != null:
		current.update(owner, delta)
	_in_update = false
	if _pending_op != OP_NONE:
		_apply_pending(owner)

# --- Internal ---

func _request_transition(owner, op: int, payload: Dictionary) -> void:
	if _in_update:
		# Priority: CLEAR > POP > REPLACE > PUSH (lower number = higher priority for comparison)
		if _pending_op == OP_NONE or _priority(op) < _priority(_pending_op):
			_pending_op = op
			_pending_payload = payload
	else:
		_pending_op = op
		_pending_payload = payload
		_apply_pending(owner)

func _apply_pending(owner) -> void:
	if _pending_op == OP_NONE:
		return
	var op := _pending_op
	var payload := _pending_payload
	_pending_op = OP_NONE
	_pending_payload = {}
	_apply_transition(owner, op, payload)

func _apply_transition(owner, op: int, payload: Dictionary) -> void:
	var prev_name: StringName = current_name
	match op:
		OP_PUSH:
			# Exit current then push and enter new
			if current != null:
				current.exit(owner)
			var entry: Dictionary = {"name": payload.get("name", StringName()), "state": payload.get("state", null)}
			var entry_state: State = entry.get("state", null)
			var entry_name: StringName = entry.get("name", StringName())
			if entry_state == null:
				return
			_stack.append(entry)
			current = entry_state
			current_name = entry_name
			if current != null:
				current.enter(owner)
		OP_REPLACE:
			# Exit current, replace top (or push if empty), then enter
			if current != null:
				current.exit(owner)
			var name: StringName = payload.get("name", StringName())
			var state: State = payload.get("state", null)
			if state == null:
				return
			if _stack.is_empty():
				_stack.append({"name": name, "state": state})
			else:
				_stack[_stack.size() - 1] = {"name": name, "state": state}
			current = state
			current_name = name
			if current != null:
				current.enter(owner)
		OP_POP:
			# Exit current, pop, then re-enter previous (if any)
			if _stack.is_empty():
				return
			if current != null:
				current.exit(owner)
			_stack.remove_at(_stack.size() - 1)
			if _stack.is_empty():
				current = null
				current_name = StringName()
			else:
				var top: Dictionary = _stack.back()
				var s: State = top.get("state", null)
				var n: StringName = top.get("name", StringName())
				current = s
				current_name = n
				if current != null:
					current.enter(owner)
		OP_CLEAR:
			# Exit current, clear all, optionally enter default
			if current != null:
				current.exit(owner)
			_stack.clear()
			current = null
			current_name = StringName()
			var def_state: State = payload.get("default_state", null)
			var def_name: StringName = payload.get("default_name", StringName())
			if def_state != null:
				_stack.append({"name": def_name, "state": def_state})
				current = def_state
				current_name = def_name
				current.enter(owner)
		_:
			# No-op
			return
	# Emit telemetry signals (debug listeners may attach)
	emit_signal("state_changed", prev_name, current_name, String(payload.get("reason", "")))
	emit_signal("stack_changed", _stack.size())

func _priority(op: int) -> int:
	# lower number means higher priority
	match op:
		OP_CLEAR:
			return 0
		OP_POP:
			return 1
		OP_REPLACE:
			return 2
		OP_PUSH:
			return 3
		_:
			return 4

func _print_warn(msg: String) -> void:
	# Lightweight logging to avoid hard dependency on Log.gd
	print("[StateMachine] %s" % msg)