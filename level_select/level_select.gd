class_name LevelSelect
extends Control

func _on_button_pressed() -> void:
	var main: Main = get_parent()
	main.load_menu()
