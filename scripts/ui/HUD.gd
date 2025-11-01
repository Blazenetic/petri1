extends Control

# HUD.gd
# Minimal debug state display. When ConfigurationManager.debug_show_states is true,
# shows the current state name for a debug-selected entity. Temporary selection policy:
# picks the first BehaviorController in the "BehaviorControllers" group to minimize coupling.

@export var update_interval_sec: float = 0.2

@onready var _label: Label = get_node_or_null("Root/DebugInfo")

var _accum: float = 0.0

func _ready() -> void:
	_update_visibility(false)
	_update_text("")

func _process(delta: float) -> void:
	_accum += delta
	if _accum < update_interval_sec:
		return
	_accum = 0.0

	var debug_enabled := (ConfigurationManager != null and "debug_show_states" in ConfigurationManager and bool(ConfigurationManager.debug_show_states))
	_update_visibility(debug_enabled)
	if not debug_enabled:
		return

	var bc := _get_debug_controller()
	if bc == null:
		_update_text("No entity")
		return

	# Source of truth comes from BehaviorController
	var sname: StringName = bc.get_current_state_name()
	_update_text("State: %s" % [String(sname)])

func _get_debug_controller() -> BehaviorController:
	# Temporary selection: pick the first available controller in the group.
	var arr := get_tree().get_nodes_in_group("BehaviorControllers")
	if arr.size() == 0:
		return null
	var n := arr[0]
	var bc := n as BehaviorController
	return bc

func _update_visibility(show: bool) -> void:
	if _label:
		_label.visible = show

func _update_text(t: String) -> void:
	if _label:
		_label.text = t