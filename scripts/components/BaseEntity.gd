extends Area2D
class_name BaseEntity

@export var entity_type: int = 0
@export var size: float = 8.0
@export var base_color: Color = Color(0.3, 0.8, 0.3, 1.0)

signal ready_for_pool()

var _components: Array[EntityComponent] = []
var identity: IdentityComponent
var physical: PhysicalComponent
var _components_container: Node

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_components_container = get_node_or_null("Components")
	if _components_container == null:
		_components_container = Node.new()
		_components_container.name = "Components"
		add_child(_components_container)
	# Attach default components (idempotent)
	if identity == null:
		identity = IdentityComponent.new()
		add_component(identity)
	identity.entity_type = entity_type
	if physical == null:
		physical = PhysicalComponent.new()
		add_component(physical)
	physical.size = size
	# Initialize any pre-attached EntityComponent nodes under Components (editor-added)
	if _components_container:
		for child in _components_container.get_children():
			var comp := child as EntityComponent
			if comp and not _components.has(comp) and comp != identity and comp != physical:
				_components.append(comp)
				comp.init(self)
	# Ensure processing and initial draw
	set_process(true)
	queue_redraw()

func add_component(comp: EntityComponent) -> void:
	_components.append(comp)
	if _components_container:
		_components_container.add_child(comp)
	else:
		add_child(comp)
	comp.init(self)

func init(params := {}) -> void:
	# Position
	if params.has("position"):
		var pos: Vector2 = params["position"]
		if physical != null:
			physical.position = pos
		else:
			global_position = pos
	# Rotation
	if params.has("rotation"):
		var rot: float = float(params["rotation"])
		if physical != null:
			physical.rotation = rot
		else:
			rotation = rot
	# Size
	if params.has("size"):
		size = float(params["size"])
		if physical != null:
			physical.size = size
		else:
			# Update collider radius so collisions roughly match until PhysicalComponent syncs
			var collider := get_node_or_null("Collider") as CollisionShape2D
			if collider and collider.shape is CircleShape2D:
				var circle := collider.shape as CircleShape2D
				if circle:
					circle.radius = size
	# keep identity in sync with entity_type on every init (important for pooled instances)
	if identity:
		identity.entity_type = entity_type
	# Apply transform immediately so it's visible before first _process tick
	if physical:
		physical.update(0.0)
	queue_redraw()

func deinit() -> void:
	for c in _components:
		c.cleanup()
	emit_signal("ready_for_pool")

func _process(delta: float) -> void:
	for c in _components:
		c.update(delta)
	queue_redraw()

func _draw() -> void:
	var r := physical.size if physical != null else size
	draw_circle(Vector2.ZERO, r, base_color)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, base_color.darkened(0.3), 2.0)
