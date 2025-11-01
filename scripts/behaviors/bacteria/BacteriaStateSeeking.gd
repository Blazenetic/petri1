extends State
class_name BacteriaStateSeeking

# Minimal passive state: allows existing steering components to run.
# Resets any transient visual overrides when entering from other states.

var _entered: bool = false

func enter(owner) -> void:
	_entered = true
	# Defensive: reset visuals in case a prior state left them altered
	if owner == null:
		return
	var bc: BehaviorController = owner as BehaviorController
	if bc and bc._be:
		# Ensure alpha fully visible
		var be: BaseEntity = bc._be
		var c: Color = be.base_color
		c.a = 1.0
		be.base_color = c
		# Ensure PhysicalComponent size is consistent with BaseEntity.size
		if bc._phys:
			bc._phys.size = be.size
	# No other side-effects; Seeking lets existing components act

func update(owner, delta: float) -> void:
	# Intentionally no-op; SeekNutrient/RandomWander drive motion
	pass

func exit(owner) -> void:
	_entered = false