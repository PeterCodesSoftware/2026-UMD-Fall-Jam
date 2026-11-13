class_name LevelButton
extends Button

signal level_selected(info: LevelInfo)

var level_info: LevelInfo
var best_time: float = -1.0
var completed: bool = false


func _ready() -> void:
	pressed.connect(_on_pressed)
	if level_info == null:
		disabled = true
		text = "Unavailable"
		return
	var status := "Not completed"
	if completed:
		status = "Best: %.2fs" % best_time
		var stars := level_info.get_stars(best_time)
		if stars > 0:
			status += "  |  %d/3 stars" % stars
	text = level_info.display_name + "\n" + status


func _on_pressed() -> void:
	if level_info != null:
		level_selected.emit(level_info)
