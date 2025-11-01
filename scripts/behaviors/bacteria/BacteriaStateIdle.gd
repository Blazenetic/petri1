extends State
class_name BacteriaStateIdle

# BacteriaStateIdle
# Minimal low-activity state for bacteria when throttling activity or no stimuli are present.
# Responsibilities:
# - Reduce/zero acceleration (allow gentle drift only)
# - Subtle visual desaturation/alpha to indicate low activity
# - No per-frame allocations, no steering inside state

var _active: bool = false
var _prev_color: Color = Color.WHITE
var _applied_visual: bool = false

func state_name() -> StringName:
	return &"Idle"

func is_transient() -> bool:
	return false

func state_tint() -> Color:
	# Slightly desaturated hint; controller may apply this to RIS-friendly tint
	return Color(0.85, 0.85, 0.85, 0.9)

func enter(owner) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if bc == null:
		return
	_active = true
	# Store prev color and apply a subtle idle modulation
	_prev_color = bc.baseline_color()
	var c := _prev_color
	# Slight desaturation + slight alpha drop
	var avg := (c.r + c.g + c.b) / 3.0
	var desat := Color(lerp(c.r, avg, 0.25), lerp(c.g, avg, 0.25), lerp(c.b, avg, 0.25), clamp(c.a * 0.85, 0.0, 1.0))
	bc.set_color(desat)
	_applied_visual = true
	# Reduce acceleration immediately
	bc.zero_accel()

func update(owner, delta: float) -> void:
	if not _active:
		return
	var bc: BehaviorController = owner as BehaviorController
	if bc == null:
		return
	# Keep acceleration near zero; allow MovementComponent damping/jitter to provide passive drift
	bc.zero_accel()

func exit(owner) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if bc != null and _applied_visual:
		# Restore baseline visuals
		bc.set_color(bc.baseline_color())
	_applied_visual = false
	_active = false