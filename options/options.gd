extends Control

func _on_back_pressed() -> void:
	var main: Main = get_parent()
	main.load_menu()
