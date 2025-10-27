extends "res://scripts/components/EntityComponent.gd"
class_name NutrientComponent

const EntityTypes = preload("res://scripts/components/EntityTypes.gd")

@export var energy_value: float = 3.0
@export var consume_tween_time: float = 0.2
@export var consume_tween_trans: int = Tween.TRANS_QUAD
@export var consume_tween_ease: int = Tween.EASE_OUT

var _entity: BaseEntity
var _identity: IdentityComponent
var _physical: PhysicalComponent
var _consumed: bool = false

func init(entity: Node) -> void:
	_entity = entity as BaseEntity
	if _entity == null:
		return
	_identity = _entity.identity
	_physical = _entity.physical
	if not _entity.is_connected("area_entered", Callable(self, "_on_area_entered")):
		_entity.connect("area_entered", Callable(self, "_on_area_entered"))

func set_energy_value(v: float) -> void:
	energy_value = float(v)

func update(delta: float) -> void:
	# Nutrients are passive; no per-frame work needed.
	pass

func cleanup() -> void:
	if _entity and _entity.is_connected("area_entered", Callable(self, "_on_area_entered")):
		_entity.disconnect("area_entered", Callable(self, "_on_area_entered"))
	_consumed = false
	if _entity and _entity is CanvasItem:
		(_entity as CanvasItem).modulate = Color(1, 1, 1, 1)
	_entity = null
	_identity = null
	_physical = null

func _on_area_entered(area: Area2D) -> void:
	if _consumed:
		return
	var consumer := _resolve_base_entity(area)
	if consumer == null:
		return
	if consumer.entity_type == EntityTypes.EntityType.BACTERIA:
		_consume(consumer)

func _resolve_base_entity(node: Node) -> BaseEntity:
	var n: Node = node
	while n != null:
		var be := n as BaseEntity
		if be != null:
			return be
		n = n.get_parent()
	return null

func _consume(consumer: BaseEntity) -> void:
	if _consumed:
		return
	_consumed = true
	var self_id: StringName = _identity.uuid if _identity else StringName()
	var consumer_id: StringName = consumer.identity.uuid if (consumer and consumer.identity) else StringName()
	GlobalEvents.emit_signal("nutrient_consumed", self_id, consumer_id)
	if _entity:
		var t := _entity.create_tween()
		if _physical:
			t.tween_property(_physical, "size", 0.0, consume_tween_time).set_trans(consume_tween_trans).set_ease(consume_tween_ease)
		t.tween_property(_entity, "modulate:a", 0.0, consume_tween_time).set_trans(consume_tween_trans).set_ease(consume_tween_ease)
		t.connect("finished", Callable(self, "_on_consume_tween_finished"))
	else:
		_on_consume_tween_finished()

func _on_consume_tween_finished() -> void:
	if _identity and not _identity.uuid.is_empty():
		EntityFactory.destroy_entity(_identity.uuid, &"consumed")