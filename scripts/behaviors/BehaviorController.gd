extends "res://scripts/components/EntityComponent.gd"
class_name BehaviorController

const EntityTypes = preload("res://scripts/components/EntityTypes.gd")
const StateMachine = preload("res://scripts/behaviors/state/StateMachine.gd")
const BacteriaStateSeeking = preload("res://scripts/behaviors/bacteria/BacteriaStateSeeking.gd")
const BacteriaStateReproducing = preload("res://scripts/behaviors/bacteria/BacteriaStateReproducing.gd")
const BacteriaStateDying = preload("res://scripts/behaviors/bacteria/BacteriaStateDying.gd")

var sm: StateMachine
var state_seeking: BacteriaStateSeeking
var state_reproducing: BacteriaStateReproducing
var state_dying: BacteriaStateDying

# Cached components
var _be: BaseEntity
var _move: MovementComponent
var _bio: BiologicalComponent
var _id: IdentityComponent
var _phys: PhysicalComponent
var _fx: CPUParticles2D

# Per-entity reproduction limiter (timestamps in seconds)
var _recent_children_times: Array[float] = []

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
	# Optional FX node on the entity
	_fx = _be.get_node_or_null("FissionBurst") as CPUParticles2D

	# States and machine
	sm = StateMachine.new()
	state_seeking = BacteriaStateSeeking.new()
	state_reproducing = BacteriaStateReproducing.new()
	state_dying = BacteriaStateDying.new()
	sm.set_state(self, &"Seeking", state_seeking)

	# Intercept biological death to drive polished destruction
	if _bio and not _bio.is_connected("died", Callable(self, "_on_bio_died")):
		_bio.connect("died", Callable(self, "_on_bio_died"))

func update(delta: float) -> void:
	if sm:
		sm.update(self, delta)
	# Transition to Reproducing if eligible and not already reproducing or dying
	if _bio and _move and sm and not sm.is_in(&"Dying") and not sm.is_in(&"Reproducing"):
		if can_reproduce_now():
			sm.set_state(self, &"Reproducing", state_reproducing)

func cleanup() -> void:
	if _bio and _bio.is_connected("died", Callable(self, "_on_bio_died")):
		_bio.disconnect("died", Callable(self, "_on_bio_died"))
	_be = null
	_move = null
	_bio = null
	_id = null
	_phys = null
	_fx = null
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

# --- Signals ---

func _on_bio_died(reason: StringName) -> void:
	sm.set_state(self, &"Dying", state_dying.set_cause(reason))