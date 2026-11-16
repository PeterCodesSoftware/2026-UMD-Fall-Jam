class_name Demon
extends Enemy

var _has_flown: bool = false


func _init() -> void:
	max_health = 8
	move_speed = 46.0
	attack_range = 88.0
	close_attack_range = 36.0


func _chase(delta: float) -> void:
	_has_flown = true
	_face_player()
	velocity = (player.global_position - global_position).normalized() * move_speed
	move_and_collide(velocity * delta)
	_play(&"fly")


func _idle(delta: float) -> void:
	if not _has_flown:
		super._idle(delta)
	else:
		velocity = Vector2.ZERO
		_play(&"idle")


func _start_attack(distance: float) -> void:
	super._start_attack(distance)
	if _attack_can_leap:
		_has_flown = true


func _attack_spec(distance: float) -> Dictionary:
	if distance <= close_attack_range:
		return { "animation": &"slash_attack", "area": "SlashAttackArea", "frame": 3, "dash": false }
	_has_flown = true
	return { "animation": &"dash_attack", "area": "DashAttackArea", "frame": 5, "dash": true }
