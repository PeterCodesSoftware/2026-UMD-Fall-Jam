class_name Monster
extends Enemy

@export var cling_speed: float = 16.0
@export var edge_reach: float = 26.0

var surface_normal: Vector2 = Vector2.UP
var _attached: bool = false
var _normal_extent: float = 10.0
var _travel_direction: Vector2 = Vector2.RIGHT


func _init() -> void:
	max_health = 12
	move_speed = 34.0
	attack_range = 70.0
	close_attack_range = 32.0


func _ready() -> void:
	super._ready()
	_normal_extent = $HurtBox.shape.get_rect().size.y * 0.5


func _chase(delta: float) -> void:
	if not _attached:
		_fall(delta)
		_play(&"walk")
		return
	var tangent := Vector2(-surface_normal.y, surface_normal.x)
	var toward := player.global_position - global_position
	var along := toward.dot(tangent)
	var travel_sign := signf(along) if absf(along) > 1.0 else 1.0
	_travel_direction = tangent * travel_sign
	_face_player()
	var motion := (_travel_direction * move_speed - surface_normal * cling_speed) * delta
	# Keep tangential travel after the inward adhesion component hits the
	# support surface; discarding the remainder would stall on flat ground.
	for slide in range(4):
		var hit := move_and_collide(motion)
		if hit == null:
			break
		var normal := hit.get_normal()
		if normal.y < 0.1:
			_set_surface(normal)
		else:
			# Ceiling contact is solid, but never becomes a cling surface.
			_attached = false
			rotation = 0.0
			velocity = Vector2.ZERO
		motion = hit.get_remainder().slide(normal)
		if motion.is_zero_approx():
			break
	if _attached and not _has_support():
		if not _wrap_edge():
			_attached = false
			rotation = 0.0
			velocity = _travel_direction * move_speed
	_play(&"walk")


func _idle(delta: float) -> void:
	if _attached and _has_support():
		velocity = Vector2.ZERO
	else:
		_attached = false
		rotation = 0.0
		_fall(delta)
	_play(&"idle")


func _fall(delta: float) -> void:
	velocity += get_gravity() * delta
	var hit := move_and_collide(velocity * delta)
	if hit != null:
		if hit.get_normal().y < 0.1:
			_set_surface(hit.get_normal())
		velocity = Vector2.ZERO


func _set_surface(normal: Vector2) -> void:
	# Only floors, slopes, and vertical walls can be held.
	if normal.y >= 0.1:
		return
	_attached = true
	surface_normal = normal.normalized()
	rotation = Vector2.UP.angle_to(surface_normal)
	velocity = Vector2.ZERO


func _has_support() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position,
		global_position - surface_normal * (_normal_extent + 3.0), 1, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _wrap_edge() -> bool:
	# At a convex edge, sample the next face around the corner. Turning
	# from a wall onto a ceiling is deliberately rejected.
	var next_normal := _travel_direction
	if next_normal.y >= 0.1:
		return false
	var origin := global_position - surface_normal * edge_reach + _travel_direction * 3.0
	var query := PhysicsRayQueryParameters2D.create(origin, origin - next_normal * edge_reach * 2.0, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(next_normal) < 0.8 or hit.normal.y >= 0.1:
		return false
	var candidate: Vector2 = hit.position + hit.normal * (_normal_extent + 0.15)
	var candidate_transform := Transform2D(Vector2.UP.angle_to(hit.normal), candidate)
	if test_move(candidate_transform, Vector2.ZERO, null, 0.02, true):
		return false
	global_position = candidate
	_set_surface(hit.normal)
	return true


func _start_attack(distance: float) -> void:
	# When leaving a wall for a leap, choose attack facing in the upright
	# frame before the shared attack setup locks its direction.
	if distance > close_attack_range or player.global_position.y < global_position.y - 12.0:
		_attached = false
		rotation = 0.0
	super._start_attack(distance)


func _attack_spec(distance: float) -> Dictionary:
	if distance <= close_attack_range:
		return { "animation": &"slash_attack", "area": "SlashAttackArea", "frame": 4, "dash": false }
	return { "animation": &"bite_attack", "area": "BiteAttackArea", "frame": 6, "dash": true }


func _move_attack(delta: float) -> void:
	# Leaps leave wall adhesion; movement remains committed to the aim
	# selected when this attack began.
	if _attack_can_leap and _attack_elapsed <= 0.15:
		_attached = false
		rotation = 0.0
	super._move_attack(delta)
	if _attack_elapsed > 0.15 and not _attached:
		_fall(delta)
