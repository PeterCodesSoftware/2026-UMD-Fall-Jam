class_name Main
extends Node

## Ordered catalog shared by level select and level loading.
@export var level_manager: LevelManager

const MENU: PackedScene = preload("uid://cynvxuhs1ov1o")
const LEVEL_SELECT: PackedScene = preload("uid://de7447pwxryl")
const OPTIONS: PackedScene = preload("uid://c7kstde6cb5q8")
const FADE_DURATION: float = 0.1

var progress: LevelProgress = LevelProgress.new()
var _current_screen: Node = null
var _active_level_info: LevelInfo = null
var _transitioning: bool = false
var _level_finished: bool = false

@onready var _fade_rect: ColorRect = %FadeRect
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _finished_menu: FinishedMenu = $FinishedMenu


func _ready() -> void:
	progress.load_progress()
	_pause_menu.resume_requested.connect(_resume_level)
	_pause_menu.level_select_requested.connect(load_level_select)
	_finished_menu.retry_requested.connect(_retry_level)
	_finished_menu.next_level_requested.connect(_load_next_level)
	_finished_menu.level_select_requested.connect(load_level_select)
	_transition_to(MENU)


func _input(event: InputEvent) -> void:
	# Handle Pause before the GUI can consume Tab for focus navigation.
	if event.is_action_pressed(&"Pause") and _current_screen is BaseLevel and not _level_finished:
		get_viewport().set_input_as_handled()
		toggle_pause()


func load_menu() -> void:
	await _transition_to(MENU)


func load_level_select() -> void:
	await _transition_to(LEVEL_SELECT)


func load_options() -> void:
	await _transition_to(OPTIONS)


func load_level(info: LevelInfo) -> void:
	if _transitioning or info == null or info.scene == null:
		return
	if level_manager == null or not level_manager.get_available_levels().has(info):
		push_warning("This level is not in the level catalog.")
		return
	await _transition_to(info.scene, info)


func toggle_pause() -> void:
	if _transitioning or _level_finished or not _current_screen is BaseLevel:
		return
	if get_tree().paused:
		_resume_level()
	elif (_current_screen as BaseLevel).is_running:
		get_tree().paused = true
		_pause_menu.show_menu()


func _resume_level() -> void:
	if _transitioning or _level_finished:
		return
	_pause_menu.hide_menu()
	get_tree().paused = false


func _on_level_completed(elapsed_time: float, score: int) -> void:
	if _active_level_info == null or _transitioning or _level_finished:
		return
	_level_finished = true
	progress.record_completion(_active_level_info.get_uid(), elapsed_time, score)
	_pause_menu.hide_menu()
	get_tree().paused = true
	var next_level := level_manager.get_next_level(_active_level_info.get_uid())
	_finished_menu.show_results(_active_level_info, elapsed_time, next_level != null)


func _retry_level() -> void:
	if _level_finished and _active_level_info != null:
		load_level(_active_level_info)


func _load_next_level() -> void:
	if not _level_finished or _active_level_info == null:
		return
	var next_level := level_manager.get_next_level(_active_level_info.get_uid())
	if next_level != null:
		load_level(next_level)


func _transition_to(scene: PackedScene, info: LevelInfo = null) -> void:
	if _transitioning or scene == null:
		return
	# Validate before discarding the current screen.
	var next_screen := scene.instantiate()
	if info != null and not next_screen is BaseLevel:
		push_warning("Level scenes must inherit from base_level.tscn.")
		next_screen.queue_free()
		return

	_transitioning = true
	_level_finished = false
	if _current_screen is BaseLevel:
		(_current_screen as BaseLevel).stop_run()
	_pause_menu.hide_menu()
	_finished_menu.hide_menu()
	get_tree().paused = false
	_fade_rect.visible = true

	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await fade_out.finished

	if _current_screen != null:
		remove_child(_current_screen)
		_current_screen.queue_free()
	_active_level_info = info
	_current_screen = next_screen
	# Main keeps handling Pause while each screen obeys the paused tree.
	_current_screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	if _current_screen is BaseLevel:
		var level := _current_screen as BaseLevel
		level.completed.connect(_on_level_completed)
		level.pause_requested.connect(toggle_pause)
	add_child(_current_screen)

	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await fade_in.finished
	_fade_rect.visible = false
	_transitioning = false
	
	if _current_screen is BaseLevel:
		(_current_screen as BaseLevel).start_run()
