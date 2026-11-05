class_name Menu
extends Control




func _on_play_pressed() -> void:
	var main: Main = get_parent()
	main.load_level_select()


func _on_options_pressed() -> void:
	var main: Main = get_parent()
	main.load_options()


func _on_quit_pressed() -> void:
	get_tree().quit()
