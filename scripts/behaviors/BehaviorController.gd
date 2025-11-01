extends "res://scripts/components/EntityComponent.gd"
class_name BehaviorController

const EntityTypes = preload("res://scripts/components/EntityTypes.gd")
const StateMachine = preload("res://scripts/behaviors/state/StateMachine.gd")
const BacteriaStateSeeking = preload("res://scripts/behaviors/bacteria/BacteriaStateSeeking.gd")
const BacteriaStateReproducing = preload("res://scripts/behaviors/bacteria/BacteriaStateReproducing.gd")
const BacteriaStateDying = preload("res://scripts/behaviors/bacteria/BacteriaStateDying.gd")
const SeekNutrient = preload("res://scripts/behaviors/SeekNutrient.gd")
const BacteriaStateIdle = preload("res://scripts/behaviors/bacteria/BacteriaStateIdle.gd")
const BacteriaStateFeeding = preload("res://scripts/behaviors/bacteria/BacteriaStateFeeding.gd")

var sm: StateMachine
var state_seeking: BacteriaStateSeeking
var state_reproducing: BacteriaStateReproducing
var state_dying: BacteriaStateDying
var state_idle: BacteriaStateIdle
var state_feeding: BacteriaStateFeeding

# Cached components
var _be: BaseEntity
var _move: MovementComponent
var _bio: BiologicalComponent
var _id: IdentityComponent
var _phys: PhysicalComponent
var _fx: CPUParticles2D
var _seek: SeekNutrient

# Per-entity reproduction limiter (timestamps in seconds)
var _recent_children_times: Array[float] = []

# State history ring buffer (PHASE 2.3)
var _state_history: Array = []
var _history_capacity: int = 32

func init(entity: Node) -> void:
	_be = entity as BaseEntity
	if _be == null:
		return
	_id = _be.identity
	_phys = _be.physical
	var comps := _be.get_node_or_null("Components")
	if comps:
		for c in comps.get_children():
			if c is MovementComponent:
				_move = c
			elif c is BiologicalComponent:
				_bio = c
			elif c is SeekNutrient:
				_seek = c
	# Optional FX node on the entity
	_fx = _be.get_node_or_null("FissionBurst") as CPUParticles2D

	# States and machine
	sm = StateMachine.new()
	state_seeking = BacteriaStateSeeking.new()
	state_reproducing = BacteriaStateReproducing.new()
	state_dying = BacteriaStateDying.new()
	state_idle = BacteriaStateIdle.new()
	state_feeding = BacteriaStateFeeding.new()
	# Initial state: Seeking (replace semantics on empty stack)
	sm.set_state(self, &"Seeking", state_seeking)
	# Telemetry hook for history
	if sm and not sm.is_connected("state_changed", Callable(self, "_on_sm_state_changed")):
		sm.connect("state_changed", Callable(self, "_on_sm_state_changed"))
	# History capacity from configuration
	if ConfigurationManager != null and "behavior_state_history_capacity" in ConfigurationManager:
		_history_capacity = int(ConfigurationManager.behavior_state_history_capacity)
	# Debug discoverability
	add_to_group("BehaviorControllers")

	# Intercept biological death to drive polished destruction
	if _bio and not _bio.is_connected("died", Callable(self, "_on_bio_died")):
		_bio.connect("died", Callable(self, "_on_bio_died"))

func update(delta: float) -> void:
	if sm:
		sm.update(self, delta)
	# Deterministic prioritized transitions (after state update)
	if sm and not sm.is_in(&"Dying"):
		# 1) Reproducing (replace)
		if _bio and _move and not sm.is_in(&"Reproducing") and can_reproduce_now():
			sm.replace_state(self, &"Reproducing", state_reproducing, "repro_check")
		else:
			# 2) Feeding (push) when target lock + overlap, and not reproducing/dying
			if not sm.is_in(&"Reproducing") and not sm.is_in(&"Feeding"):
				if _seek and _seek.has_target() and _is_overlapping_nutrient():
					if state_feeding == null:
						state_feeding = BacteriaStateFeeding.new()
					# Gate via state internal cooldown
					if state_feeding.can_enter():
						sm.push(self, &"Feeding", state_feeding, "nutrient_overlap")
	# 3) Seeking fallback if stack emptied
	if sm and sm.depth() == 0:
		sm.replace_state(self, &"Seeking", state_seeking, "fallback_seeking")

func cleanup() -> void:
	if _bio and _bio.is_connected("died", Callable(self, "_on_bio_died")):
		_bio.disconnect("died", Callable(self, "_on_bio_died"))
	if sm and sm.is_connected("state_changed", Callable(self, "_on_sm_state_changed")):
		sm.disconnect("state_changed", Callable(self, "_on_sm_state_changed"))
	remove_from_group("BehaviorControllers")
	_be = null
	_move = null
	_bio = null
	_id = null
	_phys = null
	_fx = null
	_seek = null
	sm = null

# --- Transition helpers ---

func can_reproduce_now() -> bool:
	if _bio == null or _id == null:
		return false
	if not _bio.should_reproduce():
		return false
	var now: float = _time_now()
	_prune_child_times(now)
	var max_per_min: int = 20
	if ConfigurationManager != null and "bacteria_max_children_per_min" in ConfigurationManager:
		max_per_min = int(ConfigurationManager.bacteria_max_children_per_min)
	return _recent_children_times.size() < max_per_min

func note_reproduction_occurred() -> void:
	var now: float = _time_now()
	_prune_child_times(now)
	_recent_children_times.append(now)

func _prune_child_times(now_s: float) -> void:
	var cutoff := now_s - 60.0
	var pruned: Array[float] = []
	for t in _recent_children_times:
		if float(t) >= cutoff:
			pruned.append(t)
	_recent_children_times = pruned

func _time_now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

# --- Utilities used by states ---

func zero_accel() -> void:
	if _move:
		_move.acceleration = Vector2.ZERO

func zero_motion() -> void:
	if _move:
		_move.acceleration = Vector2.ZERO
		_move.velocity = Vector2.ZERO

func baseline_size() -> float:
	return _be.size if _be else 8.0

func baseline_color() -> Color:
	return _be.base_color if _be else Color.WHITE

func current_size() -> float:
	return _phys.size if _phys else (_be.size if _be else 8.0)

func set_size(v: float) -> void:
	if _phys:
		_phys.size = v

func set_color(c: Color) -> void:
	if _be:
		_be.base_color = c

func start_fission_burst() -> void:
	if _fx:
		# Match particles to current organism tint for a cohesive look
		_fx.modulate = _be.base_color if _be else Color.WHITE
		_fx.one_shot = true
		# Safely trigger a fresh one-shot burst across pooled instances
		_fx.emitting = false
		_fx.set_deferred("emitting", true)

# Spawns child, applies inheritance and bookkeeping results; returns { "id": StringName, "node": BaseEntity }
func spawn_offspring(child_energy: float) -> Dictionary:
	if _be == null or _phys == null:
		return {}
	var offset_r: float = 10.0
	if ConfigurationManager != null and "bacteria_offspring_offset_radius" in ConfigurationManager:
		offset_r = float(ConfigurationManager.bacteria_offspring_offset_radius)
	var ang: float = randf() * TAU
	var pos: Vector2 = _phys.position + Vector2(cos(ang), sin(ang)) * offset_r
	var child_id: StringName = EntityFactory.create_entity_clamped(EntityTypes.EntityType.BACTERIA, pos, _phys.size, {"size": _be.size})
	var child_node: BaseEntity = EntityRegistry.get_by_id(child_id) as BaseEntity
	if child_node != null and is_instance_valid(child_node):
		# Visual inheritance with slight jitter
		var jitter: float = 0.03
		var parent_c: Color = _be.base_color
		var child_c: Color = Color(
			clamp(parent_c.r + randf_range(-jitter, jitter), 0.0, 1.0),
			clamp(parent_c.g + randf_range(-jitter, jitter), 0.0, 1.0),
			clamp(parent_c.b + randf_range(-jitter, jitter), 0.0, 1.0),
			parent_c.a
		)
		child_node.base_color = child_c

		# Collect child's components
		var c_comps: Node = child_node.get_node_or_null("Components")
		var c_move: MovementComponent
		var c_bio: BiologicalComponent
		var c_phys: PhysicalComponent
		var c_id: IdentityComponent
		if c_comps:
			for c in c_comps.get_children():
				if c is MovementComponent:
					c_move = c
				elif c is BiologicalComponent:
					c_bio = c
				elif c is PhysicalComponent:
					c_phys = c
				elif c is IdentityComponent:
					c_id = c

		# Movement inheritance
		if _move and c_move:
			c_move.max_speed = _move.max_speed

		# Identity genealogy
		if _id and c_id:
			c_id.generation = _id.generation + 1
			c_id.parent_id = _id.uuid

		# Energy assignment
		if c_bio:
			c_bio.energy = clamp(child_energy, 0.0, c_bio.energy_max)
			c_bio.emit_signal("energy_changed", c_bio.energy)

		# Child starts from parent's current size (peak) and will tween back
		if c_phys:
			c_phys.size = _phys.size

	return {"id": child_id, "node": child_node}

# --- Transition queries & helpers (PHASE 2.3) ---

func _is_overlapping_nutrient() -> bool:
	if _be == null:
		return false
	var areas: Array = []
	if _be.has_method("get_overlapping_areas"):
		areas = _be.get_overlapping_areas()
	if areas.is_empty():
		return false
	for a in areas:
		var be := _resolve_base_entity(a)
		if be != null and be.entity_type == EntityTypes.EntityType.NUTRIENT:
			return true
	return false

func _resolve_base_entity(node: Node) -> BaseEntity:
	var n := node
	while n != null:
		var b := n as BaseEntity
		if b != null:
			return b
		n = n.get_parent()
	return null

func get_current_state_name() -> StringName:
	return sm.current_name if sm != null else StringName()

func get_state_history() -> Array:
	return _state_history.duplicate()

# --- Signals ---

func _on_bio_died(reason: StringName) -> void:
	sm.set_state(self, &"Dying", state_dying.set_cause(reason))

func _on_sm_state_changed(prev_name: StringName, new_name: StringName, reason: String) -> void:
	var entry := {
		"timestamp_sec": _time_now(),
		"from_state": prev_name,
		"to_state": new_name,
		"reason": reason
	}
	_state_history.append(entry)
	if _state_history.size() > max(1, _history_capacity):
		_state_history.remove_at(0)