class_name LevelSelect
extends Control

const LEVEL_BUTTON: PackedScene = preload("res://level_select/level_button.tscn")

@onready var _level_list: VBoxContainer = %LevelList
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	var main: Main = get_parent() as Main
	if main == null or main.level_manager == null:
		return
	var levels: Array[LevelInfo] = main.level_manager.get_available_levels()
	_empty_label.visible = levels.is_empty()
	for info in levels:
		var button := LEVEL_BUTTON.instantiate() as LevelButton
		button.level_info = info
		button.best_time = main.progress.get_best_time(info.get_uid())
		button.completed = main.progress.is_completed(info.get_uid())
		button.level_selected.connect(main.load_level)
		_level_list.add_child(button)


func _on_button_pressed() -> void:
	var main: Main = get_parent()
	main.load_menu()
