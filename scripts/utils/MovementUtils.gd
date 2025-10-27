extends Object
class_name MovementUtils

# MovementUtils
# Optional helpers for movement math used by components/behaviors.
# Keeps scripts concise and consistent with Phase 1.4 spec.

const EPS: float = 1e-6

static func exp_damp(v: Vector2, damping: float, delta: float) -> Vector2:
	# Exponential damping over time using per-second damping in [0,1]
	var base: float = clamp(1.0 - damping, 0.0, 1.0)
	return v * pow(base, delta)

static func clamp_speed(v: Vector2, max_speed: float) -> Vector2:
	if max_speed <= 0.0:
		return v
	var s := v.length()
	if s > max_speed and s > 0.0:
		return v * (max_speed / s)
	return v

static func random_unit() -> Vector2:
	var v := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if v.length_squared() < EPS:
		return Vector2.RIGHT
	return v.normalized()

static func reflect(v: Vector2, n: Vector2) -> Vector2:
	# Reflect vector v about normal n (n need not be unit; normalize if needed)
	var nn := n
	var len2 := nn.length_squared()
	if len2 > EPS:
		nn /= sqrt(len2)
	else:
		nn = Vector2.RIGHT
	return v - 2.0 * v.dot(nn) * nn

static func safe_normalize(v: Vector2) -> Vector2:
	if v.length_squared() < EPS:
		return Vector2.ZERO
	return v.normalized()

static func soft_separation(dir: Vector2, overlap: float, strength: float) -> Vector2:
	# Returns a small separation impulse along dir scaled by overlap and strength
	return dir * max(overlap, 0.0) * max(strength, 0.0)