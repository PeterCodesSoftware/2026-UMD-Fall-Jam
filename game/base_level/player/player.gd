class_name Player
extends CharacterBody2D

signal attack_fired(level: int)

enum Action { NONE, JUMP, SHOT }

const COLLISION_MARGIN: float = 0.08
const MAX_BOUNCES_PER_TICK: int = 6

const MAX_IMPULSE: float = 180.0
const MIN_IMPULSE: float = 50.0
const BOUNCE_RESTITUTION: float = 0.85
const SPIN_SPEED: float = TAU * 1.5

var is_attached: bool = false
var is_ball: bool = false
var surface_normal: Vector2 = Vector2.UP
var _action: Action = Action.NONE
var _charge_time: float = 0.0
var _charge_duration: float = 2.0
var _spin_direction: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _blob_shape: CollisionShape2D = $CollisionShape2D
@onready var _ball_shape: CollisionShape2D = $BallShape


func _ready() -> void:
	_blob_shape.disabled = false
	_ball_shape.disabled = true
	_play_animation(&"air")


func _physics_process(delta: float) -> void:
	_handle_actions(delta)
	if is_attached:
		velocity = Vector2.ZERO
	else:
		_sprite.rotation += SPIN_SPEED * delta * (1 if _spin_direction else -1)
		_move_air(delta)


func _handle_actions(delta: float) -> void:
	var shot_held := Input.is_action_pressed(&"Charge Shot")
	var jump_held := Input.is_action_pressed(&"Charge Jump")
	var ball_held := Input.is_action_pressed(&"Ball Form")

	# An active charge owns all actions until its own button is released.
	if _action == Action.SHOT:
		if shot_held:
			return
		_fire_attack()
	elif _action == Action.JUMP:
		if jump_held:
			_charge_time = minf(_charge_time + delta, _charge_duration)
			return
		_release_jump()

	# Releasing ball changes its physics immediately, even mid-animation.
	if is_ball and not ball_held:
		_set_ball(false)

	# Shot wins when eligible actions are held together. Existing jump charges
	# and ball form must first end before a shot can begin.
	if shot_held and not is_ball:
		_begin_charge(Action.SHOT)
		return

	if not is_attached:
		_set_ball(ball_held)
	elif jump_held:
		_begin_charge(Action.JUMP)


func _begin_charge(action: Action) -> void:
	_action = action
	_charge_time = 0.0
	_play_animation(&"charge_jump" if action == Action.JUMP else &"charge_attack")
	if action == Action.JUMP:
		_charge_duration = _animation_duration(&"charge_jump")


func _animation_duration(animation: StringName) -> float:
	var frames := _sprite.sprite_frames
	var duration := 0.0
	for index in range(frames.get_frame_count(animation)):
		duration += frames.get_frame_duration(animation, index)
	return duration / maxf(frames.get_animation_speed(animation), 0.001)


func _release_jump() -> void:
	var ratio := clampf(_charge_time / _charge_duration, 0.0, 1.0)
	var direction := get_global_mouse_position() - global_position
	_spin_direction = abs(_sprite.rotation - direction.angle()) < (PI / 2)
	if direction.is_zero_approx():
		direction = surface_normal
	velocity = direction.normalized() * ((MAX_IMPULSE - MIN_IMPULSE) * ratio + MIN_IMPULSE)
	is_attached = false
	_action = Action.NONE
	_play_animation(&"air")


func _fire_attack() -> void:
	var level := clampi(_sprite.frame + 1, 1, 3)
	print("attack %d" % level)
	attack_fired.emit(level)
	_action = Action.NONE
	_play_animation(&"idle" if is_attached else &"air")


func _set_ball(enabled: bool) -> void:
	if enabled == is_ball or (enabled and is_attached):
		return
	is_ball = enabled
	_blob_shape.disabled = enabled
	_ball_shape.disabled = not enabled
	_play_animation(&"air_to_ball" if enabled else &"ball_to_air")
	if not enabled:
		# The restored blob can overlap terrain that the smaller ball cleared.
		# Recover that overlap and stick on the same tick as the release.
		var contact_normal := Vector2.ZERO
		# Shape expansion may need several recovery passes; otherwise the
		# newly attached blob could remain partly embedded in the surface.
		for iteration in range(8):
			var contact := move_and_collide(Vector2.ZERO, false, COLLISION_MARGIN, true)
			if contact == null:
				break
			if not contact.get_normal().is_zero_approx():
				contact_normal = contact.get_normal()
		if not contact_normal.is_zero_approx():
			_attach(contact_normal)


func _move_air(delta: float) -> void:
	velocity += get_gravity() * delta
	var motion := velocity * delta
	for iteration in range(MAX_BOUNCES_PER_TICK):
		var collision := move_and_collide(motion, false, COLLISION_MARGIN)
		if collision == null:
			return
		var normal := collision.get_normal()
		if not is_ball:
			_attach(normal)
			return
		# Only reflect incoming velocity, never a separating recovery contact.
		motion = collision.get_remainder()
		if velocity.dot(normal) < 0.0:
			velocity = velocity.bounce(normal) * BOUNCE_RESTITUTION
			motion = motion.bounce(normal) * BOUNCE_RESTITUTION
		if motion.is_zero_approx():
			return


func _attach(normal: Vector2) -> void:
	is_attached = true
	surface_normal = normal.normalized()
	velocity = Vector2.ZERO
	_sprite.rotation = Vector2.UP.angle_to(surface_normal)
	# Landing cannot cancel or rewind an attack charge.
	if _action != Action.SHOT:
		_play_animation(&"idle")


func _play_animation(animation: StringName) -> void:
	_sprite.play(animation)
	_sprite.set_frame_and_progress(0, 0.0)
