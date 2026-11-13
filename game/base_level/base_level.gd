class_name BaseLevel
extends Node2D

signal completed(elapsed_time: float, final_score: int)
signal pause_requested

var elapsed_time: float = 0.0
var score: int = 0
var is_running: bool = false

@onready var _time_label: Label = %TimeLabel
@onready var _score_label: Label = %ScoreLabel


func _ready() -> void:
	# Main starts the run once the fade-in finishes.
	set_process(false)
	$Player.set_physics_process(false)
	_update_hud()


func start_run() -> void:
	elapsed_time = 0.0
	score = 0
	is_running = true
	set_process(true)
	$Player.set_physics_process(true)
	_update_hud()


func stop_run() -> void:
	is_running = false
	set_process(false)
	$Player.set_physics_process(false)


func _process(delta: float) -> void:
	elapsed_time += delta
	_update_hud()


func add_score(points: int) -> void:
	if is_running:
		score += points
		_update_hud()


## Call this from a future goal/exit trigger. Abandoning a run does not complete it.
func finish_level() -> void:
	if not is_running:
		return
	stop_run()
	completed.emit(elapsed_time, score)


func _update_hud() -> void:
	_time_label.text = "%.2fs" % elapsed_time
	_score_label.text = "Score: %d" % score


func _on_pause_pressed() -> void:
	pause_requested.emit()
