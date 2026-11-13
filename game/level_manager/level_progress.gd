class_name LevelProgress
extends RefCounted

## Player data is keyed by the UID of each saved LevelInfo resource.
const SAVE_PATH: String = "user://level_progress.cfg"

var _data: ConfigFile = ConfigFile.new()
var _save_path: String


func _init(save_path: String = SAVE_PATH) -> void:
	_save_path = save_path


func load_progress() -> Error:
	var loaded := ConfigFile.new()
	var error := loaded.load(_save_path)
	if error == OK:
		_data = loaded
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load level progress: " + error_string(error))
	return error


func get_best_time(level_uid: int) -> float:
	if level_uid < 0:
		return -1.0
	var value: Variant = _data.get_value(ResourceUID.id_to_text(level_uid), "best_time", -1.0)
	if (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0:
		return float(value)
	return -1.0


func is_completed(level_uid: int) -> bool:
	return get_best_time(level_uid) >= 0.0


func get_best_score(level_uid: int) -> int:
	if level_uid < 0:
		return 0
	var value: Variant = _data.get_value(ResourceUID.id_to_text(level_uid), "best_score", 0)
	return maxi(int(value), 0) if value is int else 0


func record_completion(level_uid: int, elapsed_time: float, score: int) -> Error:
	if level_uid < 0 or not is_finite(elapsed_time) or elapsed_time < 0.0:
		return ERR_INVALID_PARAMETER
	var previous_time := get_best_time(level_uid)
	if previous_time < 0.0 or elapsed_time < previous_time:
		_data.set_value(ResourceUID.id_to_text(level_uid), "best_time", elapsed_time)
	_data.set_value(ResourceUID.id_to_text(level_uid), "best_score", maxi(get_best_score(level_uid), score))
	var error := _data.save(_save_path)
	if error != OK:
		push_warning("Could not save level progress: " + error_string(error))
	return error
