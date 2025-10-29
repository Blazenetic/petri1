extends "res://scripts/components/EntityComponent.gd"
class_name IdentityComponent

var uuid: StringName
var entity_type: int = 0
var generation: int = 0
var parent_id: StringName = StringName()

static func _generate_uuid() -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a: int = rng.randi()
	var b: int = rng.randi() & 0xFFFF
	var c: int = (rng.randi() & 0x0FFF) | 0x4000
	var d: int = (rng.randi() & 0x3FFF) | 0x8000
	# Build the final 12 hex digits from two parts to avoid 64-bit API usage
	var e_hi: int = rng.randi()
	var e_lo: int = rng.randi() & 0xFFFF
	var s := "%08x-%04x-%04x-%04x-%08x%04x" % [a, b, c, d, e_hi, e_lo]
	return StringName(s)

func init(entity: Node) -> void:
	if uuid.is_empty():
		uuid = _generate_uuid()