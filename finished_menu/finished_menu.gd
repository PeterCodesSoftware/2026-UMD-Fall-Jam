class_name FinishedMenu
extends CanvasLayer

signal retry_requested
signal next_level_requested
signal level_select_requested

var _fade_tween: Tween

@onready var _time_label: Label = %TimeLabel
@onready var _stars_label: Label = %StarsLabel
@onready var _next_star_label: Label = %NextStarLabel
@onready var _next_level_button: Button = %NextLevelButton


func show_results(info: LevelInfo, elapsed_time: float, has_next_level: bool) -> void:
	_time_label.text = "Time: %.2fs" % elapsed_time
	_stars_label.text = "Stars: %d / 3" % info.get_stars(elapsed_time)
	var next_star_time := info.get_next_star_time(elapsed_time)
	_next_star_label.visible = next_star_time >= 0.0
	_next_star_label.text = "Next star: %.2fs or less" % next_star_time if next_star_time >= 0.0 else ""
	_next_level_button.disabled = not has_next_level
	_next_level_button.tooltip_text = "" if has_next_level else "This is the last level."
	_cancel_fade()
	$Overlay.modulate.a = 0.0
	$Overlay.show()
	_fade_tween = create_tween().set_ignore_time_scale(true)
	_fade_tween.tween_property($Overlay, "modulate:a", 1.0, 1.0)


func hide_menu() -> void:
	_cancel_fade()
	$Overlay.hide()
	$Overlay.modulate.a = 1.0


func _cancel_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_next_level_pressed() -> void:
	if not _next_level_button.disabled:
		next_level_requested.emit()


func _on_level_select_pressed() -> void:
	level_select_requested.emit()
