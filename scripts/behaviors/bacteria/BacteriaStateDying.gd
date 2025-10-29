extends State
class_name BacteriaStateDying

var _cause: StringName = &"unknown"
var _running: bool = false

func set_cause(c: StringName) -> BacteriaStateDying:
	_cause = c
	return self

func enter(owner) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if bc == null or bc._be == null or bc._phys == null:
		return
	_running = true
	bc.zero_motion()
	# Optional soft puff
	bc.start_fission_burst()

	# Tween: shrink and fade over ~0.3s
	var be: BaseEntity = bc._be
	var phys: PhysicalComponent = bc._phys
	var s0: float = bc.current_size()
	var s_down: float = max(0.0, s0 * 0.2)
	var c0: Color = be.base_color
	var c_fade: Color = Color(c0.r, c0.g, c0.b, 0.0)

	var tw: Tween = be.create_tween()
	tw.set_parallel(true)
	tw.tween_property(phys, "size", s_down, 0.3)
	tw.tween_property(be, "base_color", c_fade, 0.3)
	tw.finished.connect(Callable(self, "_on_tween_finished").bind(bc))

func _on_tween_finished(owner) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if not _running or bc == null:
		return
	_running = false
	# Emit lifecycle event then destroy via factory
	if GlobalEvents and bc._id and not bc._id.uuid.is_empty():
		GlobalEvents.emit_signal("entity_died", bc._id.uuid, bc._be.entity_type, _cause)
	if bc._id and not bc._id.uuid.is_empty():
		EntityFactory.destroy_entity(bc._id.uuid, _cause)

func update(owner, delta: float) -> void:
	pass

func exit(owner) -> void:
	_running = false