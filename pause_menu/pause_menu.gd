class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal level_select_requested


func show_menu() -> void:
	$Overlay.show()


func hide_menu() -> void:
	$Overlay.hide()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_level_select_pressed() -> void:
	level_select_requested.emit()
