extends Control

var _settings: AudioSettings
var _progress: LevelProgress

@onready var _sfx_slider: HSlider = %SFXSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_value: Label = %SFXValue
@onready var _music_value: Label = %MusicValue
@onready var _reset_warning: Control = %ResetWarning
@onready var _status: Label = %Status


func _ready() -> void:
	var main := get_parent() as Main
	if main != null:
		_settings = main.audio_settings
		_progress = main.progress
	else:
		# Allow previewing this scene directly with F6.
		_settings = AudioSettings.new()
		_settings.load_settings()
		_progress = LevelProgress.new()
		_progress.load_progress()
	_sfx_slider.set_value_no_signal(_settings.sfx_volume)
	_music_slider.set_value_no_signal(_settings.music_volume)
	_sfx_value.text = "%d" % _settings.sfx_volume
	_music_value.text = "%d" % _settings.music_volume
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	%ResetProgress.pressed.connect(_show_reset_warning)
	%CancelReset.pressed.connect(_cancel_reset)
	%ConfirmReset.pressed.connect(_confirm_reset)


func _on_sfx_changed(value: float) -> void:
	_sfx_value.text = "%d" % value
	_report_save_error(_settings.set_sfx_volume(value))


func _on_music_changed(value: float) -> void:
	_music_value.text = "%d" % value
	_report_save_error(_settings.set_music_volume(value))


func _report_save_error(error: Error) -> void:
	_status.text = "" if error == OK else "Couldn't save volume settings."


func _show_reset_warning() -> void:
	_reset_warning.show()


func _cancel_reset() -> void:
	_reset_warning.hide()


func _confirm_reset() -> void:
	if not _reset_warning.visible:
		return
	var error := _progress.reset_progress()
	_reset_warning.hide()
	_status.text = "Progress reset." if error == OK else "Couldn't reset progress. Try again."


func _on_back_pressed() -> void:
	var main := get_parent() as Main
	if main != null:
		main.load_menu()
