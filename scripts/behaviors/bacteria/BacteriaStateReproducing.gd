extends State
class_name BacteriaStateReproducing

var _running: bool = false

func enter(owner) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if bc == null or bc._bio == null or bc._be == null or bc._phys == null:
		return
	_running = true
	bc._bio.pending_repro = true

	# Announce start
	if GlobalEvents and bc._id and not bc._id.uuid.is_empty():
		GlobalEvents.emit_signal("bacteria_reproduction_started", bc._id.uuid)

	# Pause motion during reproduction
	bc.zero_motion()

	# Pre-split tween: scale up and brighten slightly
	var be: BaseEntity = bc._be
	var phys: PhysicalComponent = bc._phys
	var s0: float = bc.baseline_size()
	var s_up: float = s0 * 1.15
	var c0: Color = bc.baseline_color()
	var c_up: Color = Color(clamp(c0.r * 1.10, 0.0, 1.0), clamp(c0.g * 1.10, 0.0, 1.0), clamp(c0.b * 1.10, 0.0, 1.0), c0.a)

	var tw: Tween = be.create_tween()
	tw.set_parallel(true)
	tw.tween_property(phys, "size", s_up, 0.2)
	tw.tween_property(be, "base_color", c_up, 0.2)
	tw.finished.connect(Callable(self, "_after_pre_tween").bind(bc))

func _after_pre_tween(owner: BehaviorController) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if not _running or bc == null or bc._bio == null or bc._be == null or bc._phys == null:
		return

	# Apply energy bookkeeping and determine child energy
	var child_energy: float = bc._bio.apply_reproduction_bookkeeping()

	# Spawn offspring near parent and brief burst
	var res: Dictionary = bc.spawn_offspring(child_energy)
	var child_id: StringName = res.get("id", StringName())
	var child_node: BaseEntity = res.get("node", null) as BaseEntity
	bc.start_fission_burst()

	# Post-split tween: return size/color to baseline on parent (and child size to its baseline)
	var be: BaseEntity = bc._be
	var phys: PhysicalComponent = bc._phys
	var s0: float = bc.baseline_size()
	var c0: Color = bc.baseline_color()

	var tw: Tween = be.create_tween()
	tw.set_parallel(true)
	tw.tween_property(phys, "size", s0, 0.2)
	tw.tween_property(be, "base_color", c0, 0.2)
	if child_node != null and is_instance_valid(child_node):
		if child_node.physical:
			tw.tween_property(child_node.physical, "size", s0, 0.2)
	tw.finished.connect(Callable(self, "_finish_reproduction").bind(bc, child_id))

func _finish_reproduction(owner, child_id: StringName) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if bc == null:
		return
	bc._bio.pending_repro = false
	bc.note_reproduction_occurred()
	# Emit completed event
	if GlobalEvents and bc._id and not bc._id.uuid.is_empty() and not String(child_id).is_empty():
		GlobalEvents.emit_signal("bacteria_reproduction_completed", bc._id.uuid, child_id)
	# Return to Seeking
	if bc.sm:
		bc.sm.set_state(bc, &"Seeking", bc.state_seeking)

func update(owner, delta: float) -> void:
	# No per-frame logic; sequence is tween-driven
	pass

func exit(owner) -> void:
	_running = false