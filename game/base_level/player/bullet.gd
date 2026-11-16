@tool
class_name Bullet
extends "res://game/base_level/player/bullet_appearance.gd"

enum State { PREVIEW, CHARGING, FIRED }

const DAMAGE: Array[int] = [1, 5, 10]
const GROUND_MASK: int = 1
const ENEMY_MASK: int = 4
const CONTACT_MARGIN: float = 0.01
const MAX_CONTACTS_PER_TICK: int = 64

@export var speed: float = 240.0

var player: Node2D
var state: State = State.PREVIEW
var ricochet_count: int = 0
var _spawn: Marker2D
# These are temporary exceptions, only until the shot leaves each hitbox.
var _overlapping_enemies: Array[PhysicsBody2D] = []


func _ready() -> void:
	disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	super._ready()
	collision_layer = 0
	collision_mask = GROUND_MASK | ENEMY_MASK
	$CollisionShape2D.disabled = true
	set_process(false)
	set_physics_process(false)


func _update_appearance() -> void:
	super._update_appearance()
	$CollisionShape2D.shape.radius = CORE_RADII[charge_level - 1]


func begin_charge(source: Node2D, spawn: Marker2D) -> void:
	player = source
	_spawn = spawn
	state = State.CHARGING
	charge_level = 1
	ricochet_count = 0
	global_position = _spawn.global_position
	set_process(true)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or state != State.CHARGING:
		return
	if not is_instance_valid(player) or not is_instance_valid(_spawn):
		queue_free()
		return
	global_position = _spawn.global_position


func fire(direction: Vector2) -> void:
	if state != State.CHARGING or not is_instance_valid(_spawn):
		return
	global_position = _spawn.global_position
	state = State.FIRED
	_spawn = null
	velocity = direction.normalized() * speed
	$CollisionShape2D.disabled = false
	set_process(false)
	set_physics_process(true)
	# Handle a shot born overlapping terrain or an enemy as an actual contact.
	_advance_motion(Vector2.ZERO, true)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or state != State.FIRED or is_queued_for_deletion():
		return
	_advance_motion(velocity * delta)


func _advance_motion(motion: Vector2, recover_overlap: bool = false) -> void:
	_refresh_enemy_exceptions()
	for iteration in range(MAX_CONTACTS_PER_TICK):
		var collision := move_and_collide(motion, false, CONTACT_MARGIN, recover_overlap)
		recover_overlap = false
		if collision == null:
			_refresh_enemy_exceptions()
			return
		var collider := collision.get_collider()
		motion = collision.get_remainder()
		if collider is Enemy:
			var enemy := collider as Enemy
			if not enemy.is_dead:
				enemy.take_damage(DAMAGE[charge_level - 1])
				if charge_level < 3:
					queue_free()
					return
			# Corpses never block shots; living enemies are ignored only for
			# this entry. Re-entering after leaving can damage them again.
			add_collision_exception_with(enemy)
			if not _overlapping_enemies.has(enemy):
				_overlapping_enemies.append(enemy)
		else:
			if charge_level < 3:
				queue_free()
				return
			var normal := collision.get_normal()
			# Recovery while separating is not a second impact on the wall.
			if velocity.dot(normal) < -0.0001:
				if ricochet_count >= 1:
					queue_free()
					return
				ricochet_count += 1
				velocity = velocity.bounce(normal)
				motion = motion.bounce(normal)
			_refresh_enemy_exceptions()
		if motion.is_zero_approx():
			return


func _refresh_enemy_exceptions() -> void:
	if _overlapping_enemies.is_empty():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = $CollisionShape2D.global_transform
	query.collision_mask = ENEMY_MASK
	# Include the tiny separation left by move_and_collide at a fresh hit.
	query.margin = CONTACT_MARGIN * 2.0
	query.exclude = [get_rid()]
	var overlaps: Dictionary = {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
		overlaps[hit.collider_id] = true
	for index in range(_overlapping_enemies.size() - 1, -1, -1):
		var enemy := _overlapping_enemies[index]
		if not is_instance_valid(enemy):
			_overlapping_enemies.remove_at(index)
		elif not overlaps.has(enemy.get_instance_id()):
			remove_collision_exception_with(enemy)
			_overlapping_enemies.remove_at(index)
