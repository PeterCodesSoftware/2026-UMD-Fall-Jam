extends Node2D

@onready var parallax_2d: Parallax2D = $Parallax2D

const ROTATE_SPEED: float = 0.02

func _process(delta: float) -> void:
	parallax_2d.rotate(ROTATE_SPEED * delta)
