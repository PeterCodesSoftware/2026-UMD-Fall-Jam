class_name Main
extends Node

const MENU: PackedScene = preload("uid://cynvxuhs1ov1o")
const LEVEL_SELECT: PackedScene = preload("uid://de7447pwxryl")
const OPTIONS: PackedScene = preload("uid://c7kstde6cb5q8")

const FADE_DURATION: float = 0.1

var _current_screen: Node = null
@onready var _fade_rect: ColorRect = %FadeRect
var _transitioning: bool = false

func _ready() -> void:
	_transition_to(MENU)

func load_menu() -> void:
	await _transition_to(MENU)

func load_level_select() -> void:
	await _transition_to(LEVEL_SELECT)

func load_options() -> void:
	await _transition_to(OPTIONS)

func _transition_to(scene: PackedScene) -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade_rect.visible = true
	
	var fade_out: Tween = create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await fade_out.finished
	
	if _current_screen:
		remove_child(_current_screen)
		_current_screen.queue_free()
	
	_current_screen = scene.instantiate()
	add_child(_current_screen)
	
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await fade_in.finished
	
	_fade_rect.visible = false
	_transitioning = false

func load_level() -> void:
	pass
