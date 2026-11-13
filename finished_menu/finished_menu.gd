class_name FinishedMenu
extends CanvasLayer

signal retry_requested
signal next_level_requested
signal level_select_requested

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
	$Overlay.show()


func hide_menu() -> void:
	$Overlay.hide()


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_next_level_pressed() -> void:
	if not _next_level_button.disabled:
		next_level_requested.emit()


func _on_level_select_pressed() -> void:
	level_select_requested.emit()
