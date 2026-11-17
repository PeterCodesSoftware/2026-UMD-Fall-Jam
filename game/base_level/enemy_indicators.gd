class_name EnemyIndicators
extends Control

## Passive HUD overlay. It never captures mouse input or keyboard focus.
@export var arrow_color: Color = Color(1.0, 0.15, 0.12, 0.95)
@export var edge_margin: float = 9.0
@export var top_margin: float = 26.0

var revealed: bool = false
var _targets: Array[Enemy] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = revealed


func setup(enemies: Array[Enemy]) -> void:
	_targets = enemies.duplicate()
	queue_redraw()


func toggle_reveal() -> void:
	set_revealed(not revealed)


func set_revealed(value: bool) -> void:
	revealed = value
	visible = value
	queue_redraw()


func _process(_delta: float) -> void:
	if revealed:
		# Rebuild from the actual canvas transforms each rendered frame. This
		# includes camera movement/zoom and remains consistent with canvas_items.
		queue_redraw()


func _draw() -> void:
	for polygon in _build_arrows():
		draw_colored_polygon(polygon, arrow_color)


func _build_arrows() -> Array[PackedVector2Array]:
	var arrows: Array[PackedVector2Array] = []
	if not revealed or size.x <= edge_margin * 2.0 or size.y <= top_margin + edge_margin:
		return arrows
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var center := size * 0.5
	var canvas_to_local := get_global_transform_with_canvas().affine_inverse()
	for enemy in _targets:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_dead:
			continue
		if viewport_rect.intersects(_enemy_bounds(enemy, canvas_to_local), true):
			continue
		var target := canvas_to_local * enemy.get_global_transform_with_canvas().origin
		var direction := (target - center).normalized()
		if direction.is_zero_approx():
			continue
		var tip := _edge_tip(center, direction)
		arrows.append(_arrow_polygon(tip, direction))
	return arrows


func _enemy_bounds(enemy: Enemy, canvas_to_local: Transform2D) -> Rect2:
	# Wait until the entire sprite is off screen, rather than drawing an
	# arrow while a visible part of the enemy still crosses the viewport edge.
	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return Rect2(canvas_to_local * enemy.get_global_transform_with_canvas().origin, Vector2.ONE)
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2(canvas_to_local * enemy.get_global_transform_with_canvas().origin, Vector2.ONE)
	var extent := texture.get_size()
	var origin := sprite.offset - (extent * 0.5 if sprite.centered else Vector2.ZERO)
	var transform_to_local := canvas_to_local * sprite.get_global_transform_with_canvas()
	var bounds := Rect2(transform_to_local * origin, Vector2.ZERO)
	for corner in [origin + Vector2(extent.x, 0.0), origin + extent, origin + Vector2(0.0, extent.y)]:
		bounds = bounds.expand(transform_to_local * corner)
	return bounds


func _edge_tip(center: Vector2, direction: Vector2) -> Vector2:
	var distance_to_edge := INF
	if direction.x > 0.0001:
		distance_to_edge = minf(distance_to_edge, (size.x - edge_margin - center.x) / direction.x)
	elif direction.x < -0.0001:
		distance_to_edge = minf(distance_to_edge, (edge_margin - center.x) / direction.x)
	if direction.y > 0.0001:
		distance_to_edge = minf(distance_to_edge, (size.y - edge_margin - center.y) / direction.y)
	elif direction.y < -0.0001:
		distance_to_edge = minf(distance_to_edge, (top_margin - center.y) / direction.y)
	return center + direction * distance_to_edge


func _arrow_polygon(tip: Vector2, direction: Vector2) -> PackedVector2Array:
	var side := Vector2(-direction.y, direction.x)
	var polygon := PackedVector2Array()
	# Arrowhead plus a short stem, measured in the HUD's logical pixels.
	for point in [Vector2.ZERO, Vector2(-5, -3), Vector2(-5, -1), Vector2(-8, -1), Vector2(-8, 1), Vector2(-5, 1), Vector2(-5, 3)]:
		polygon.append(tip + direction * point.x + side * point.y)
	return polygon
