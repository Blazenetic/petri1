extends State
class_name BacteriaStateFeeding

# BacteriaStateFeeding
# Transient state entered when the organism is in contact range with a locked nutrient target.
# Responsibilities:
# - Briefly slow/lock movement while consuming
# - Provide a short visual hint (slight brighten/size pulse) compatible with RIS
# - Pop back to the underlying Seeking state after a short duration
# - Enforce a short cooldown to prevent thrashing (configured via ConfigurationManager.bacteria_feeding_cooldown_ms)

var _active: bool = false
var _enter_time_s: float = 0.0
var _duration_s: float = 0.15
var _cooldown_until_s: float = 0.0

func state_name() -> StringName:
	return &"Feeding"

func is_transient() -> bool:
	return true

func state_tint() -> Color:
	# Slight brighten hint (controller may choose to use this)
	return Color(1.0, 1.0, 1.0, 1.0)

func enter(owner) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if bc == null:
		return
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var cfg_ms: int = 250
	if ConfigurationManager != null and "bacteria_feeding_cooldown_ms" in ConfigurationManager:
		cfg_ms = int(ConfigurationManager.bacteria_feeding_cooldown_ms)
	# Respect cooldown to avoid rapid re-entry
	if now_s < _cooldown_until_s:
		_active = false
		return
	_active = true
	_enter_time_s = now_s
	# Visual hint: brief brighten and a tiny size pulse (RIS-friendly)
	var base_c: Color = bc.baseline_color()
	var bright := Color(
		clamp(base_c.r * 1.10, 0.0, 1.0),
		clamp(base_c.g * 1.10, 0.0, 1.0),
		clamp(base_c.b * 1.10, 0.0, 1.0),
		base_c.a
	)
	bc.set_color(bright)
	var s0: float = bc.current_size()
	var s_up: float = min(s0 * 1.06, bc.baseline_size() * 1.2)
	bc.set_size(s_up)

func update(owner, delta: float) -> void:
	if not _active:
		return
	var bc: BehaviorController = owner as BehaviorController
	if bc == null:
		return
	# While feeding, sharply reduce acceleration to stay on target
	bc.zero_accel()
	# Time-bound feeding; return control to underlying Seeking quickly
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	if (now_s - _enter_time_s) >= _duration_s:
		# Defer to StateMachine; it will re-enter the underlying state
		if bc.sm:
			bc.sm.pop(bc, "feeding_complete")

func exit(owner) -> void:
	var bc: BehaviorController = owner as BehaviorController
	if bc != null:
		# Restore visuals to baseline
		bc.set_color(bc.baseline_color())
		bc.set_size(bc.baseline_size())
	# Apply cooldown window to prevent immediate re-entry
	var cfg_ms: int = 250
	if ConfigurationManager != null and "bacteria_feeding_cooldown_ms" in ConfigurationManager:
		cfg_ms = int(ConfigurationManager.bacteria_feeding_cooldown_ms)
	_cooldown_until_s = float(Time.get_ticks_msec()) / 1000.0 + (float(cfg_ms) / 1000.0)
	_active = false

# Gate for controller to query before requesting entry (prevents thrash)
func can_enter() -> bool:
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	return now_s >= _cooldown_until_s

func get_cooldown_remaining_ms() -> int:
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var rem: float = max(0.0, _cooldown_until_s - now_s)
	return int(rem * 1000.0)