class_name Player
extends CharacterBody2D

signal attack_fired(level: int)
signal died

enum Action { NONE, JUMP, SHOT }

const BULLET: PackedScene = preload("res://game/base_level/player/bullet.tscn")

const COLLISION_MARGIN: float = 0.08
const MAX_BOUNCES_PER_TICK: int = 6

const MAX_IMPULSE: float = 180.0
const MIN_IMPULSE: float = 50.0
const BOUNCE_RESTITUTION: float = 0.85

var max_spin_speed: float = TAU
var spin_response: float = 6.0

var small_recoil: float = 10.0
var medium_recoil: float = 60.0
var large_recoil: float = 100.0

var is_attached: bool = false
var is_ball: bool = false
var surface_normal: Vector2 = Vector2.UP
var _action: Action = Action.NONE
var _charge_time: float = 0.0
var _charge_duration: float = 2.0
var is_dead: bool = false
var _spin_velocity: float = 0.0
var _spin_sign: float = 1.0
var _charging_bullet: Bullet

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _blob_shape: CollisionShape2D = $CollisionShape2D
@onready var _ball_shape: CollisionShape2D = $BallShape
@onready var _bullet_spawn: Marker2D = $AnimatedSprite2D/BulletSpawn


func _ready() -> void:
	_blob_shape.disabled = false
	_ball_shape.disabled = true
	_play_animation(&"air")
	_sprite.frame_changed.connect(_on_attack_frame_changed)


func _exit_tree() -> void:
	if is_instance_valid(_charging_bullet):
		_charging_bullet.queue_free()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_actions(delta)
	if is_attached:
		velocity = Vector2.ZERO
	else:
		_move_air(delta)
		if not is_attached:
			_update_spin(delta)


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
	else:
		_spawn_charging_bullet()


func _animation_duration(animation: StringName) -> float:
	var frames := _sprite.sprite_frames
	var duration := 0.0
	for index in range(frames.get_frame_count(animation)):
		duration += frames.get_frame_duration(animation, index)
	return duration / maxf(frames.get_animation_speed(animation), 0.001)


func _release_jump() -> void:
	var ratio := clampf(_charge_time / _charge_duration, 0.0, 1.0)
	var direction := get_global_mouse_position() - global_position
	if direction.is_zero_approx():
		direction = surface_normal
	velocity = direction.normalized() * ((MAX_IMPULSE - MIN_IMPULSE) * ratio + MIN_IMPULSE)
	is_attached = false
	_action = Action.NONE
	_play_animation(&"air")


func _fire_attack() -> void:
	var level := clampi(_sprite.frame + 1, 1, 3)
	if is_instance_valid(_charging_bullet):
		_charging_bullet.charge_level = level
		var direction := get_global_mouse_position() - global_position
		if direction.is_zero_approx():
			direction = surface_normal
		_charging_bullet.fire(direction)
		if not is_attached:
			var recoil: float = [small_recoil, medium_recoil, large_recoil][level - 1]
			velocity -= direction.normalized() * recoil
	_charging_bullet = null
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
	_spin_velocity = 0.0
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


func _spawn_charging_bullet() -> void:
	var objects := get_parent().get_node_or_null("Objects")
	if objects == null:
		push_warning("Player needs a level Objects container to spawn a bullet.")
		return
	_charging_bullet = BULLET.instantiate() as Bullet
	objects.add_child(_charging_bullet)
	_charging_bullet.begin_charge(self, _bullet_spawn)
	_on_attack_frame_changed()


func _on_attack_frame_changed() -> void:
	if _action == Action.SHOT and is_instance_valid(_charging_bullet):
		_charging_bullet.charge_level = clampi(_sprite.frame + 1, 1, 3)


func cancel_attack() -> void:
	if is_instance_valid(_charging_bullet):
		_charging_bullet.queue_free()
	_charging_bullet = null
	if _action == Action.SHOT:
		_action = Action.NONE
		_play_animation(&"idle" if is_attached else &"air")


func begin_run() -> void:
	# Resolve an initial touching/overlapping surface before the first input.
	var contact := move_and_collide(Vector2.ZERO, false, COLLISION_MARGIN, true)
	if contact != null and not contact.get_normal().is_zero_approx():
		_attach(contact.get_normal())
	# Start the qualifying action immediately, even for a tap released before
	# the next physics tick; the regular tick will handle its release.
	_handle_actions(0.0)


func _update_spin(delta: float) -> void:
	# Preserve a stable direction near vertical movement, while smoothing
	# reversals and letting rotation settle as total movement slows.
	if absf(velocity.x) > 5.0:
		_spin_sign = signf(velocity.x)
	var target := _spin_sign * max_spin_speed * clampf(velocity.length() / MAX_IMPULSE, 0.0, 1.0)
	_spin_velocity = lerpf(_spin_velocity, target, 1.0 - exp(-spin_response * delta))
	_sprite.rotation += _spin_velocity * delta


func can_take_damage() -> bool:
	if is_dead:
		return false
	var level := get_parent()
	return not level.has_method("allows_player_damage") or level.allows_player_damage()


func take_damage(amount: int = 1) -> void:
	if amount <= 0 or not can_take_damage():
		return
	is_dead = true
	velocity = Vector2.ZERO
	_spin_velocity = 0.0
	cancel_attack()
	_action = Action.NONE
	_sprite.pause()
	set_physics_process(false)
	died.emit()
