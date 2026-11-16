@tool
class_name BulletAppearance
extends CharacterBody2D

## Shared shader appearance. Runtime projectile behavior extends this script.
@export_enum("Small:1", "Medium:2", "Large:3") var charge_level: int = 1:
	set(value):
		charge_level = clampi(value, 1, 3)
		if is_node_ready():
			_update_appearance()

const CORE_RADII: Array[float] = [1.0, 2.0, 3.0]

func _ready() -> void:
	_update_appearance()


func _update_appearance() -> void:
	$Light.set_instance_shader_parameter(&"core_radius", CORE_RADII[charge_level - 1])
