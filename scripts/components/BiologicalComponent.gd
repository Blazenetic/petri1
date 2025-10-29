extends "res://scripts/components/EntityComponent.gd"
class_name BiologicalComponent

const LogDefs = preload("res://scripts/systems/Log.gd")
var _log
# BiologicalComponent
# Stores and updates biological stats (energy, health, age) and reacts to nutrient consumption.
# - Drains energy via metabolism each frame
# - Gains energy when GlobalEvents.nutrient_consumed is emitted for this entity
# - Requests destruction via EntityFactory on starvation or when max_age_sec is exceeded
# - All values are exported for tuning in the editor

@export var energy_start: float = 6.0
@export var energy_max: float = 12.0
@export var metabolism_rate_per_sec: float = 0.8
@export var health_start: float = 1.0
@export var max_age_sec: float = 180.0 # 0 disables aging death
@export var energy_from_nutrient_efficiency: float = 1.0

signal energy_changed(new_energy: float)
signal died(reason: StringName)

var energy: float = 0.0
var health: float = 0.0
var age_sec: float = 0.0

# Reproduction runtime fields (PHASE 2.2b)
var repro_cooldown_timer: float = 0.0
var pending_repro: bool = false

var _entity: BaseEntity
var _identity: IdentityComponent
var _physical: PhysicalComponent
var _connected: bool = false

func init(entity: Node) -> void:
	_entity = entity as BaseEntity
	if _entity == null:
		return
	_identity = _entity.identity
	_physical = _entity.physical
	_log = get_node_or_null("/root/Log")

	# Initialize runtime fields
	energy = clamp(energy_start, 0.0, energy_max)
	health = max(0.0, health_start)
	age_sec = 0.0

	# Subscribe to nutrient consumption events once
	if not _connected and GlobalEvents and GlobalEvents.has_signal("nutrient_consumed"):
		if not GlobalEvents.is_connected("nutrient_consumed", Callable(self, "_on_nutrient_consumed")):
			GlobalEvents.connect("nutrient_consumed", Callable(self, "_on_nutrient_consumed"))
		_connected = true

	if _log != null and _log.enabled(LogDefs.CAT_COMPONENTS, LogDefs.LEVEL_DEBUG) and _identity:
		_log.debug(LogDefs.CAT_COMPONENTS, [
			"[BiologicalComponent] init",
			"id=", _identity.uuid,
			"energy=", energy, "/", energy_max,
			"max_age=", max_age_sec
		])

func update(delta: float) -> void:
	if delta <= 0.0 or _identity == null:
		return

	# Aging
	age_sec += delta

	# Reproduction cooldown tick down
	if repro_cooldown_timer > 0.0:
		repro_cooldown_timer = max(0.0, repro_cooldown_timer - delta)
	
	# Metabolism energy drain
	if metabolism_rate_per_sec > 0.0:
		energy -= metabolism_rate_per_sec * delta
		energy = clamp(energy, 0.0, energy_max)

	# Death conditions
	if energy <= 0.0:
		_request_death(&"starvation")
		return
	if max_age_sec > 0.0 and age_sec >= max_age_sec:
		_request_death(&"old_age")
		return

# Helper semantics (PHASE 2.2b)
func should_reproduce() -> bool:
	if _identity == null:
		return false
	if pending_repro:
		return false
	# Thresholds read from ConfigurationManager (autoload)
	var threshold: float = 0.0
	var cd: float = repro_cooldown_timer
	if ConfigurationManager != null and "bacteria_repro_energy_threshold" in ConfigurationManager:
		threshold = float(ConfigurationManager.bacteria_repro_energy_threshold)
	return energy >= threshold and cd <= 0.0

# Performs energy cost, computes split, applies cooldown. Returns child energy.
func apply_reproduction_bookkeeping() -> float:
	var cost_ratio: float = 0.2
	var split_ratio: float = 0.5
	var cooldown_s: float = 8.0
	if ConfigurationManager != null:
		if "bacteria_repro_energy_cost_ratio" in ConfigurationManager:
			cost_ratio = clamp(float(ConfigurationManager.bacteria_repro_energy_cost_ratio), 0.0, 1.0)
		if "bacteria_offspring_energy_split_ratio" in ConfigurationManager:
			split_ratio = clamp(float(ConfigurationManager.bacteria_offspring_energy_split_ratio), 0.0, 1.0)
		if "bacteria_repro_cooldown_sec" in ConfigurationManager:
			cooldown_s = max(0.0, float(ConfigurationManager.bacteria_repro_cooldown_sec))
	var e: float = max(0.0, energy)
	var cost: float = e * cost_ratio
	var after_cost: float = max(0.0, e - cost)
	var child_e: float = after_cost * split_ratio
	var parent_e: float = after_cost - child_e
	energy = clamp(parent_e, 0.0, energy_max)
	repro_cooldown_timer = cooldown_s
	emit_signal("energy_changed", energy)
	return child_e

func cleanup() -> void:
	# Unsubscribe to prevent leaks
	if _connected and GlobalEvents and GlobalEvents.has_signal("nutrient_consumed"):
		if GlobalEvents.is_connected("nutrient_consumed", Callable(self, "_on_nutrient_consumed")):
			GlobalEvents.disconnect("nutrient_consumed", Callable(self, "_on_nutrient_consumed"))
	_connected = false
	_entity = null
	_identity = null
	_physical = null

func _on_nutrient_consumed(nutrient_id: StringName, consumer_id: StringName) -> void:
	# Only react if we were the consumer
	if _identity == null or consumer_id != _identity.uuid:
		return

	# Resolve nutrient energy value (if still valid)
	var added_energy: float = 0.0
	var node: Node = EntityRegistry.get_by_id(nutrient_id)
	if node != null and is_instance_valid(node):
		# Try to locate a NutrientComponent to read its energy_value
		var comps: Node = node.get_node_or_null("Components")
		if comps:
			for c in comps.get_children():
				if c is NutrientComponent:
					added_energy = float(c.energy_value)
					break

	# Apply efficiency and clamp
	if added_energy > 0.0:
		var prev: float = energy
		energy = clamp(energy + added_energy * energy_from_nutrient_efficiency, 0.0, energy_max)
		if _log != null and _log.enabled(LogDefs.CAT_COMPONENTS, LogDefs.LEVEL_DEBUG) and _identity:
			_log.debug(LogDefs.CAT_COMPONENTS, [
				"[BiologicalComponent] energy +=",
				added_energy,
				"eff=", energy_from_nutrient_efficiency,
				"=>", energy, "/", energy_max,
				"id=", _identity.uuid
			])
		if not is_equal_approx(prev, energy):
			emit_signal("energy_changed", energy)

func _request_death(reason: StringName) -> void:
	if _identity == null or _identity.uuid.is_empty():
		return
	if _log != null and _log.enabled(LogDefs.CAT_COMPONENTS, LogDefs.LEVEL_INFO):
		_log.info(LogDefs.CAT_COMPONENTS, [
			"[BiologicalComponent] died",
			"reason=", reason,
			"id=", _identity.uuid
		])
	emit_signal("died", reason)
	# If a BehaviorController is present, let it own the destruction flow (PHASE 2.2b)
	var intercepted := false
	if _entity != null:
		var comps := _entity.get_node_or_null("Components")
		if comps:
			var bc := comps.get_node_or_null("BehaviorController")
			if bc != null:
				intercepted = true
	# Fallback to immediate destroy if no controller present
	if not intercepted:
		EntityFactory.destroy_entity(_identity.uuid, reason)