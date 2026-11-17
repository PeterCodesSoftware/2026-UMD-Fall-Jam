class_name Monster
extends Enemy

@export var cling_speed: float = 16.0
@export var edge_reach: float = 26.0

const CONTACT_MARGIN: float = 0.04
const SUPPORT_REACH: float = 3.0

var surface_normal: Vector2 = Vector2.UP
var _attached: bool = false
var _half_size: Vector2
var _body_offset: Vector2
var _travel_direction: Vector2 = Vector2.RIGHT
var _corner_normal: Vector2 = Vector2.ZERO
var _corner_out: Vector2
var _corner_in: Vector2
var _corner_stage: int = 0


func _init() -> void:
	max_health = 12
	move_speed = 34.0
	attack_range = 70.0
	close_attack_range = 32.0


func _ready() -> void:
	super._ready()
	_half_size = $HurtBox.shape.get_rect().size * 0.5
	_body_offset = $HurtBox.position
	# Keep the movement body upright. Rotating its wide rectangle against a
	# wall used to embed it in terrain and trigger large recovery movements.
	rotation = 0.0


func _chase(delta: float) -> void:
	if _corner_stage != 0:
		_advance_corner(delta)
	elif not _attached:
		_fall(delta)
	else:
		var tangent := Vector2(-surface_normal.y, surface_normal.x)
		var along := (player.global_position - global_position).dot(tangent)
		var travel_sign := signf(along) if absf(along) > 2.0 else 0.0
		if travel_sign != 0.0:
			_travel_direction = tangent * travel_sign
		var motion := (tangent * travel_sign * move_speed - surface_normal * cling_speed) * delta
		_move_on_surface(motion)
		if _attached and not _has_support():
			if not _wrap_edge():
				_detach(_travel_direction * move_speed)
	_face_player()
	_play(&"walk")


func _move_on_surface(motion: Vector2) -> void:
	for slide in range(4):
		var hit := move_and_collide(motion, false, CONTACT_MARGIN)
		if hit == null:
			return
		var normal := hit.get_normal()
		if normal.y < 0.1:
			_set_surface(normal)
		else:
			# Ceilings are obstacles, never an attachment surface.
			_detach(Vector2.ZERO)
		motion = hit.get_remainder().slide(normal)
		if motion.is_zero_approx():
			return


func _idle(delta: float) -> void:
	_corner_stage = 0
	if _attached and _has_support():
		velocity = Vector2.ZERO
	else:
		_detach(velocity)
		_fall(delta)
	_face_player()
	_play(&"idle")


func _fall(delta: float) -> void:
	velocity += get_gravity() * delta
	var hit := move_and_collide(velocity * delta, false, CONTACT_MARGIN)
	if hit != null:
		if hit.get_normal().y < 0.1:
			_set_surface(hit.get_normal())
		else:
			velocity = velocity.slide(hit.get_normal())


func _detach(new_velocity: Vector2) -> void:
	_attached = false
	_corner_stage = 0
	velocity = new_velocity


func _set_surface(normal: Vector2) -> void:
	if normal.y >= 0.1 or normal.is_zero_approx():
		return
	_attached = true
	surface_normal = normal.normalized()
	velocity = Vector2.ZERO


func _support_extent(normal: Vector2) -> float:
	return absf(normal.x) * _half_size.x + absf(normal.y) * _half_size.y


func _has_support() -> bool:
	var center := global_position + _body_offset
	var query := PhysicsRayQueryParameters2D.create(center,
		center - surface_normal * (_support_extent(surface_normal) + SUPPORT_REACH), 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.normal.dot(surface_normal) > 0.75


func _wrap_edge() -> bool:
	# Plan two short moves around the outside of a convex corner. Both moves
	# are swept by the real body on subsequent ticks; no destination teleport.
	var next_normal := _travel_direction
	if next_normal.y >= 0.1 or next_normal.is_zero_approx():
		return false
	var center := global_position + _body_offset
	var reach := maxf(edge_reach, _support_extent(surface_normal) + SUPPORT_REACH)
	var origin := center - surface_normal * reach + next_normal * SUPPORT_REACH
	var query := PhysicsRayQueryParameters2D.create(origin, origin - next_normal * reach * 2.0, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(next_normal) < 0.8 or hit.normal.y >= 0.1:
		return false
	_corner_normal = hit.normal
	var clearance := _support_extent(_corner_normal) + CONTACT_MARGIN * 2.0
	var outward := maxf(clearance - (center - hit.position).dot(_corner_normal), 0.0)
	if outward > reach:
		return false
	_corner_out = global_position + _corner_normal * outward
	_corner_in = _corner_out - surface_normal * (_support_extent(surface_normal) + SUPPORT_REACH)
	_corner_stage = 1
	return true


func _advance_corner(delta: float) -> void:
	var budget := move_speed * delta
	for step in range(2):
		var target := _corner_out if _corner_stage == 1 else _corner_in
		var offset := target - global_position
		var motion := offset.limit_length(budget)
		var hit := move_and_collide(motion, false, CONTACT_MARGIN)
		if hit != null:
			if hit.get_normal().dot(_corner_normal) > 0.8 and hit.get_normal().y < 0.1:
				_set_surface(hit.get_normal())
				_corner_stage = 0
			else:
				# An intervening wall blocks the route. Never cross it to reach
				# a valid-looking destination on the other side.
				_detach(Vector2.ZERO)
			return
		budget -= motion.length()
		if _corner_stage == 2:
			var previous_normal := surface_normal
			surface_normal = _corner_normal
			if _has_support():
				_set_surface(_corner_normal)
				_corner_stage = 0
				return
			surface_normal = previous_normal
		if global_position.distance_to(target) > CONTACT_MARGIN:
			return
		if _corner_stage == 1:
			_corner_stage = 2
		else:
			_detach(Vector2.ZERO)
			return
		if budget <= 0.00001:
			return


func _face_player() -> void:
	# Only the art and attack orientation follow the wall. The collision body
	# stays upright; during an attack the hitboxes face the committed world aim.
	var angle := 0.0 if state == State.ATTACK or not _attached else Vector2.UP.angle_to(surface_normal)
	if state != State.ATTACK and is_instance_valid(player):
		var local_target := (player.global_position - global_position).rotated(-angle)
		if absf(local_target.x) > 2.0:
			_facing = signf(local_target.x)
	_sprite.rotation = angle
	_sprite.flip_h = _facing < 0.0
	_sprite.position = Vector2(_sprite_origin.x * _facing, _sprite_origin.y).rotated(angle)
	for area in _attack_areas:
		area.rotation = angle
		area.scale.x = _facing


func _start_attack(distance: float) -> void:
	_corner_stage = 0
	# Set facing once from world-space aim, even if charging from a wall.
	var target := player.global_position - global_position
	if absf(target.x) > 0.1:
		_facing = signf(target.x)
	super._start_attack(distance)
	if _attack_can_leap:
		_detach(_attack_direction * leap_speed + Vector2.UP * leap_speed * 0.35)


func _attack_spec(distance: float) -> Dictionary:
	if distance <= close_attack_range:
		return { "animation": &"slash_attack", "area": "SlashAttackArea", "frame": 4, "dash": false }
	return { "animation": &"bite_attack", "area": "BiteAttackArea", "frame": 6, "dash": true }


func _move_attack(delta: float) -> void:
	# Never dash through the target on an inactive windup frame. Entry-frame
	# damage is checked by Enemy, then this burst stays within the active frame.
	if _attack_is_dash and _sprite.frame == _attack_frame:
		move_and_collide(_attack_direction * dash_speed * delta, false, CONTACT_MARGIN)
	elif not _attached:
		if _attack_elapsed > 0.15:
			velocity.x = move_toward(velocity.x, 0.0, leap_speed * 8.0 * delta)
		_fall(delta)
