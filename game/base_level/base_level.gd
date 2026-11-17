class_name BaseLevel
extends Node2D

signal completed(elapsed_time: float, final_score: int)
signal pause_requested
signal restart_requested
signal detection_tick

enum RunState { WAITING, RUNNING, DYING, FINISHING, FINISHED, STOPPED }
const START_ACTIONS: Array[StringName] = [&"Charge Jump", &"Charge Shot", &"Ball Form"]
const DETECTION_INTERVAL: float = 0.5
const ENEMY_INDICATORS = preload("res://game/base_level/enemy_indicators.gd")

const VICTORY_TIME_SCALE: float = 0.3

var state: RunState = RunState.WAITING
var elapsed_time: float = 0.0
var score: int = 0
var is_running: bool = false
var _start_armed: bool = false
var _detection_clock: float = 0.0
var _enemies: Array[Enemy] = []
var _living: Dictionary = {}
var _pending_deaths: Dictionary = {}
var _finish_check_queued: bool = false
var is_completed: bool = false
var _completion_time: float = 0.0
var _completion_score: int = 0
var _previous_time_scale: float = 1.0
var _owns_slow_motion: bool = false
var _death_tween: Tween
var _death_generation: int = 0
var _start_hint: Label
var _enemy_indicators: EnemyIndicators

@onready var _time_label: Label = %TimeLabel
@onready var _enemies_left_label: Label = %EnemiesLeftLabel


func _ready() -> void:
	_configure_collision_freeze(self)
	_collect_enemies($Enemies)
	for enemy in _enemies:
		enemy.setup($Player)
		_living[enemy.get_instance_id()] = true
		enemy.died.connect(_on_enemy_died)
		enemy.death_finished.connect(_on_enemy_death_finished)
	$Player.died.connect(_on_player_died)
	_set_simulation(false)
	_make_enemy_indicators()
	_make_start_hint()
	_update_hud()
	# F6 remains useful when editing a level without the Main shell.
	if not get_parent() is Main:
		arm_start()


func _exit_tree() -> void:
	_cancel_death_fade()
	_restore_time_scale()


func _configure_collision_freeze(node: Node) -> void:
	if node is CollisionObject2D:
		# Pausing script/animation processing must not remove a physics object
		# while Area2D is flushing a body_entered callback.
		node.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	for child in node.get_children():
		_configure_collision_freeze(child)


func _collect_enemies(node: Node) -> void:
	for child in node.get_children():
		if child is Enemy:
			_enemies.append(child)
		else:
			_collect_enemies(child)


func arm_start() -> void:
	if state == RunState.WAITING:
		_start_armed = true
		_start_hint.show()


func _input(event: InputEvent) -> void:
	# Main owns gameplay input in normal runs; this route supports F6.
	if not get_parent() is Main:
		if event.is_action_pressed(&"Respawn"):
			get_viewport().set_input_as_handled()
			get_tree().call_deferred("reload_current_scene")
		elif event.is_action_pressed(&"Reveal Enemies"):
			get_viewport().set_input_as_handled()
			toggle_enemy_reveal()
		else:
			try_start(event)


func try_start(event: InputEvent) -> bool:
	if not _start_armed or state != RunState.WAITING or get_tree().paused:
		return false
	for action in START_ACTIONS:
		if event.is_action_pressed(action):
			start_run()
			return true
	return false


func start_run() -> void:
	if state != RunState.WAITING:
		return
	state = RunState.RUNNING
	is_running = true
	_start_armed = false
	_detection_clock = 0.0
	_start_hint.hide()
	_set_simulation(true)
	$Player.begin_run()


func toggle_enemy_reveal() -> void:
	if can_pause() and not get_tree().paused:
		_enemy_indicators.toggle_reveal()


func stop_run() -> void:
	_cancel_death_fade()
	_restore_time_scale()
	state = RunState.STOPPED
	is_running = false
	_start_armed = false
	_enemy_indicators.set_revealed(false)
	$Player.cancel_attack()
	_set_simulation(false)


func _set_simulation(active: bool) -> void:
	var mode := Node.PROCESS_MODE_PAUSABLE if active else Node.PROCESS_MODE_DISABLED
	$Player.process_mode = mode
	$Enemies.process_mode = mode
	$Objects.process_mode = mode


func can_pause() -> bool:
	return state == RunState.WAITING or state == RunState.RUNNING


func allows_player_damage() -> bool:
	return not get_tree().paused and (state == RunState.RUNNING or state == RunState.FINISHING or state == RunState.FINISHED)


func _physics_process(delta: float) -> void:
	if state != RunState.RUNNING:
		return
	elapsed_time += delta
	_detection_clock += delta
	while _detection_clock + 0.000001 >= DETECTION_INTERVAL:
		_detection_clock -= DETECTION_INTERVAL
		detection_tick.emit()
		for enemy in _enemies:
			if is_instance_valid(enemy) and not enemy.is_dead:
				enemy.detect_player()
	_update_hud()


func add_score(points: int) -> void:
	if state == RunState.RUNNING:
		score += points
		_update_hud()


func _on_enemy_died(enemy: Enemy) -> void:
	if state != RunState.RUNNING and state != RunState.FINISHING:
		return
	var id := enemy.get_instance_id()
	if not _living.has(id):
		return
	_living.erase(id)
	_pending_deaths[id] = true
	score += 1
	_update_hud()
	if _living.is_empty():
		# Lock the result at the final kill, while all background gameplay
		# continues at reduced speed. A later player death cannot undo the win.
		is_completed = true
		_completion_time = elapsed_time
		_completion_score = score
		state = RunState.FINISHING
		is_running = false
		_previous_time_scale = Engine.time_scale
		_owns_slow_motion = true
		Engine.time_scale = VICTORY_TIME_SCALE
		_queue_finish_check()


func _on_enemy_death_finished(enemy: Enemy) -> void:
	_pending_deaths.erase(enemy.get_instance_id())



func _queue_finish_check() -> void:
	if _finish_check_queued:
		return
	_finish_check_queued = true
	# Show results without waiting for slowed enemy death animations.
	call_deferred("_commit_completion")


func _commit_completion() -> void:
	if not is_completed or state != RunState.FINISHING:
		return
	state = RunState.FINISHED
	completed.emit(_completion_time, _completion_score)


func finish_level() -> void:
	# Completion is driven exclusively by lethal damage to the last enemy.
	if is_completed and state == RunState.FINISHING:
		_queue_finish_check()


func _on_player_died() -> void:
	if is_completed and (state == RunState.FINISHING or state == RunState.FINISHED):
		# Keep the result screen and background simulation alive after victory.
		_fade_player(false)
		return
	if state != RunState.RUNNING:
		return
	state = RunState.DYING
	is_running = false
	_enemy_indicators.set_revealed(false)
	_set_simulation(false)
	_fade_player(true)


func _fade_player(restart_after_fade: bool) -> void:
	_cancel_death_fade()
	var generation := _death_generation
	_death_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	_death_tween.tween_property($Player/AnimatedSprite2D, "modulate:a", 0.0, 1.0)
	_death_tween.finished.connect(func() -> void:
		if restart_after_fade and generation == _death_generation and state == RunState.DYING:
			restart_requested.emit()
			if not get_parent() is Main:
				get_tree().call_deferred("reload_current_scene")
	)


func _cancel_death_fade() -> void:
	_death_generation += 1
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null


func _make_enemy_indicators() -> void:
	_enemy_indicators = ENEMY_INDICATORS.new()
	_enemy_indicators.name = "EnemyIndicators"
	$HUD.add_child(_enemy_indicators)
	_enemy_indicators.setup(_enemies)


func _make_start_hint() -> void:
	_start_hint = Label.new()
	_start_hint.text = "Press jump, shot, or ball to start"
	_start_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_hint.add_theme_font_size_override("font_size", 8)
	$HUD.add_child(_start_hint)
	_start_hint.anchor_top = 1.0
	_start_hint.anchor_bottom = 1.0
	_start_hint.anchor_right = 1.0
	_start_hint.offset_left = 4.0
	_start_hint.offset_right = -4.0
	_start_hint.offset_top = -16.0
	_start_hint.offset_bottom = -4.0
	_start_hint.hide()


func _update_hud() -> void:
	_time_label.text = "%.2fs" % elapsed_time
	_enemies_left_label.text = "Enemies left: %d" % _living.size()


func _on_pause_pressed() -> void:
	if can_pause():
		pause_requested.emit()


func _restore_time_scale() -> void:
	if _owns_slow_motion:
		Engine.time_scale = _previous_time_scale
		_owns_slow_motion = false
