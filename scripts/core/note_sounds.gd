class_name NoteSounds
extends Node

signal played(source: StringName)
signal enabled_changed(value: bool)
signal volume_changed(percent: float)

var config: NoteSoundConfig = preload("res://assets/audio/note_sound_config.tres")
var preferences_path := "user://settings.cfg"
var enabled := true
var volume_percent := 100.0
var player := AudioStreamPlayer.new()
var _last_frame := -1


func _ready() -> void:
	add_child(player)
	reload_preferences()


func reload_preferences() -> void:
	var settings := ConfigFile.new()
	settings.load(preferences_path)
	set_enabled(bool(settings.get_value("note_feedback", "enabled", config.enabled_by_default)), false)
	set_volume_percent(float(settings.get_value("note_feedback", "volume_percent", db_to_linear(config.volume_db) * 100.0)), false)


func set_enabled(value: bool, persist: bool = true) -> void:
	var changed := enabled != value
	enabled = value
	if not enabled:
		stop()
	if persist:
		_save_preference("enabled", enabled)
	if changed:
		enabled_changed.emit(enabled)


func set_volume_percent(value: float, persist: bool = true) -> void:
	var next := clampf(value, 0.0, 100.0)
	var changed := not is_equal_approx(volume_percent, next)
	volume_percent = next
	_apply_volume()
	if volume_percent <= 0.0:
		stop()
	if persist:
		_save_preference("volume_percent", volume_percent)
	if changed:
		volume_changed.emit(volume_percent)


func _apply_volume() -> void:
	player.volume_db = linear_to_db(maxf(volume_percent / 100.0, 0.0001))


func _save_preference(key: String, value: Variant) -> void:
	var settings := ConfigFile.new()
	settings.load(preferences_path)
	settings.set_value("note_feedback", key, value)
	settings.save(preferences_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		reload_preferences()


func play_demo() -> void:
	_play(&"demo", config.demo_enabled)


func play_input() -> void:
	_play(&"input", config.input_enabled)


func play_preview() -> void:
	_play(&"preview", config.preview_enabled)


func _play(source: StringName, allowed: bool) -> void:
	if not enabled or volume_percent <= 0.0 or not allowed or config.sound == null:
		return
	var frame := Engine.get_process_frames()
	if config.combine_simultaneous and frame == _last_frame:
		return
	_last_frame = frame
	if player.stream != config.sound:
		player.stream = config.sound
	_apply_volume()
	player.max_polyphony = config.polyphony
	player.play()
	played.emit(source)


func stop() -> void:
	player.stop()
	_last_frame = -1


func _exit_tree() -> void:
	player.stop()
	player.stream = null
