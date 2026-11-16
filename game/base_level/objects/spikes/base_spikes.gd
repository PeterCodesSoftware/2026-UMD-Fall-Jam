@tool
class_name Spike
extends Area2D

@export_enum("Up:0", "Down:2", "Left:1", "Right:3") var direction: int = 0:
	set(value):
		direction = value
		if is_node_ready():
			_apply_direction()

func _ready() -> void:
	_apply_direction()
	if not Engine.is_editor_hint():
		collision_layer = 0
		collision_mask = 2
		body_entered.connect(_on_body_entered)


func _apply_direction() -> void:
	# Rotate the whole hazard so all authored shapes and offsets follow it.
	# Absolute rotation avoids accumulating turns when an editor scene reloads.
	rotation = direction * PI / 2.0


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Also catch a body already overlapping when input starts the simulation.
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and body is CollisionObject2D and (body.collision_layer & 2) != 0:
		body.take_damage(1)
