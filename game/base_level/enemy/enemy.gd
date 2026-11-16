class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)
signal death_finished(enemy: Enemy)

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var max_health: int = 10
@export var detection_range: float = 190.0
@export var move_speed: float = 42.0
@export var attack_range: float = 86.0
@export var close_attack_range: float = 35.0
@export var attack_cooldown: float = 1.1
@export var leap_speed: float = 95.0
@export var dash_speed: float = 150.0

var health: int
var is_dead: bool = false
var player: Node2D
var state: State = State.IDLE
var player_visible: bool = false
var _cooldown: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_direction: Vector2 = Vector2.RIGHT
var _attack_area: Area2D
var _attack_frame: int = -1
var _attack_animation: StringName
var _attack_is_dash: bool = false
var _attack_can_leap: bool = false
var _attack_hit_player: bool = false
var _facing: float = 1.0
var _sprite_origin: Vector2
var _attack_areas: Array[Area2D] = []
var _health_bar: ProgressBar

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	health = maxi(max_health, 1)
	collision_layer = 4
	collision_mask = 1
	_sprite_origin = _sprite.position
	for child in get_children():
		if child is Area2D:
			var area := child as Area2D
			area.collision_layer = 0
			area.collision_mask = 2
			# Monitoring supplies overlap information only. Actual damage is
			# explicitly gated by the exact animation frame below.
			area.monitoring = true
			_attack_areas.append(area)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_attack_frame_changed)
	_play(&"idle")
	_create_health_bar()


func setup(target: Node2D) -> void:
	player = target


## Called exclusively by BaseLevel's shared 0.5-second detection clock.
func detect_player() -> void:
	if is_dead:
		return
	player_visible = false
	if is_instance_valid(player) and not bool(player.get("is_dead")):
		if global_position.distance_to(player.global_position) <= detection_range:
			var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid()])
			player_visible = get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	if state != State.ATTACK:
		state = State.CHASE if player_visible else State.IDLE
		if not player_visible:
			velocity = Vector2.ZERO
			_play(&"idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if state == State.ATTACK:
		_attack_elapsed += delta
		_move_attack(delta)
		_check_attack_damage()
		return
	if player_visible and is_instance_valid(player):
		state = State.CHASE
		var distance := global_position.distance_to(player.global_position)
		if _cooldown <= 0.0 and distance <= attack_range:
			_start_attack(distance)
		else:
			_chase(delta)
	else:
		state = State.IDLE
		_idle(delta)


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_health_bar.value = health
	if health > 0:
		return
	is_dead = true
	_health_bar.hide()
	state = State.DEAD
	player_visible = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_attack_area = null
	for area in _attack_areas:
		area.collision_mask = 0
	set_physics_process(false)
	died.emit(self)
	if _sprite.sprite_frames.has_animation(&"death"):
		_play(&"death")
	else:
		_on_animation_finished()


func _start_attack(distance: float) -> void:
	state = State.ATTACK
	_attack_elapsed = 0.0
	_attack_hit_player = false
	var target_offset := player.global_position - global_position
	_attack_direction = target_offset.normalized() if not target_offset.is_zero_approx() else Vector2.RIGHT
	_face_player()
	var spec := _attack_spec(distance)
	_attack_animation = spec.animation
	_attack_area = get_node(spec.area) as Area2D
	_attack_frame = spec.frame
	_attack_is_dash = spec.dash
	_attack_can_leap = distance > close_attack_range or target_offset.y < -12.0
	velocity = Vector2.ZERO
	_play(_attack_animation)


func _attack_spec(_distance: float) -> Dictionary:
	return { "animation": &"slash_attack", "area": "SlashAttackArea", "frame": 0, "dash": false }


func _move_attack(delta: float) -> void:
	# A short committed pre-attack hop, then a readable windup. Primary
	# attacks burst forward just before their active frame, never home in.
	var motion := Vector2.ZERO
	if _attack_can_leap and _attack_elapsed <= 0.15:
		motion = (_attack_direction * leap_speed + Vector2.UP * leap_speed * 0.35) * delta
	elif _attack_is_dash and _sprite.frame >= _attack_frame - 1 and _sprite.frame <= _attack_frame:
		motion = _attack_direction * dash_speed * delta
	if not motion.is_zero_approx():
		move_and_collide(motion)


func _on_attack_frame_changed() -> void:
	# Physics queries on the entry frame catch a player already inside
	# the area, rather than waiting for another body_entered signal.
	if state == State.ATTACK:
		_check_attack_damage()


func _check_attack_damage() -> void:
	if is_dead or state != State.ATTACK or _attack_hit_player:
		return
	if _sprite.animation != _attack_animation or _sprite.frame != _attack_frame or _attack_area == null:
		return
	if not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	for child in _attack_area.get_children():
		if not child is CollisionShape2D:
			continue
		var hitbox := child as CollisionShape2D
		if hitbox.disabled or hitbox.shape == null:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = hitbox.shape
		query.transform = hitbox.global_transform
		query.collision_mask = 2
		query.collide_with_bodies = true
		query.collide_with_areas = false
		for hit in get_world_2d().direct_space_state.intersect_shape(query):
			if hit.collider == player:
				_attack_hit_player = true
				player.take_damage(1)
				return


func _on_animation_finished() -> void:
	if is_dead:
		death_finished.emit(self)
		queue_free()
	elif state == State.ATTACK:
		_attack_area = null
		_cooldown = attack_cooldown
		velocity = Vector2.ZERO
		state = State.CHASE if player_visible else State.IDLE
		_play(&"idle")


func _face_player() -> void:
	if not is_instance_valid(player):
		return
	var horizontal := to_local(player.global_position).x
	if absf(horizontal) > 0.1:
		_facing = signf(horizontal)
	_sprite.flip_h = _facing < 0.0
	_sprite.position.x = _sprite_origin.x * _facing
	for area in _attack_areas:
		area.scale.x = _facing


func _play(animation: StringName) -> void:
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


func _chase(_delta: float) -> void:
	pass


func _idle(delta: float) -> void:
	velocity += get_gravity() * delta
	move_and_slide()
	_play(&"idle")


func _create_health_bar() -> void:
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.top_level = true
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.show_percentage = false
	_health_bar.max_value = maxi(max_health, 1)
	_health_bar.value = health
	_health_bar.size = Vector2(20, 3)
	_health_bar.z_index = 5
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.2, 1.0)
	_health_bar.add_theme_stylebox_override("background", background)
	_health_bar.add_theme_stylebox_override("fill", fill)
	add_child(_health_bar)
	_update_health_bar_position()


func _process(_delta: float) -> void:
	if not is_dead:
		_update_health_bar_position()


func _update_health_bar_position() -> void:
	# Find the sprite's world-space top edge, so the bar remains upright and
	# above the art even while a Monster rotates onto a wall.
	var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if texture == null:
		return
	var extent := texture.get_size()
	var origin := _sprite.offset - (extent * 0.5 if _sprite.centered else Vector2.ZERO)
	var corners: Array[Vector2] = [
		origin, origin + Vector2(extent.x, 0.0),
		origin + extent, origin + Vector2(0.0, extent.y)]
	var left := INF
	var right := -INF
	var top := INF
	for corner in corners:
		var point := _sprite.global_transform * corner
		left = minf(left, point.x)
		right = maxf(right, point.x)
		top = minf(top, point.y)
	_health_bar.global_position = Vector2((left + right - _health_bar.size.x) * 0.5, top - 6.0)
