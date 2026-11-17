class_name AudioSettings
extends RefCounted

const SAVE_PATH: String = "user://audio_settings.cfg"
var music_volume: float = 25.0
var sfx_volume: float = 50.0
var _save_path: String


func _init(save_path: String = SAVE_PATH) -> void:
	_save_path = save_path


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(_save_path)
	if error == OK:
		music_volume = _read_volume(config, "music", music_volume)
		sfx_volume = _read_volume(config, "sfx", sfx_volume)
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load audio settings: " + error_string(error))
	apply()


func _read_volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = config.get_value("audio", key, fallback)
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 100.0)
	return fallback


func set_music_volume(value: float) -> Error:
	music_volume = clampf(value, 0.0, 100.0)
	_apply_bus(&"Music", music_volume)
	return save_settings()


func set_sfx_volume(value: float) -> Error:
	sfx_volume = clampf(value, 0.0, 100.0)
	_apply_bus(&"SFX", sfx_volume)
	return save_settings()


func apply() -> void:
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"SFX", sfx_volume)


func _apply_bus(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("Missing audio bus: " + bus)
		return
	AudioServer.set_bus_volume_linear(index, volume / 100.0)
	AudioServer.set_bus_mute(index, volume <= 0.0)


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	return config.save(_save_path)
