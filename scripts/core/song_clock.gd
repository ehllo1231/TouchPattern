class_name SongClock
extends Node

var player := AudioStreamPlayer.new()
var running := false
var _origin_usec := 0
var _origin_seconds := 0.0
var _output_latency := 0.0
var _last_seconds := 0.0
var _finished_usec := 0
var _finished_seconds := 0.0
var _paused_seconds := 0.0


func _ready() -> void:
	add_child(player)
	player.volume_db = -5.0
	player.finished.connect(_on_finished)


func start(stream: AudioStream, from_seconds: float = 0.0) -> void:
	player.stop()
	player.stream = stream
	_origin_seconds = maxf(0.0, from_seconds)
	_output_latency = AudioServer.get_output_latency()
	_last_seconds = _origin_seconds - _output_latency
	_finished_usec = 0
	_origin_usec = Time.get_ticks_usec()
	player.play(_origin_seconds)
	running = true
	_paused_seconds = _origin_seconds


func seconds() -> float:
	if not running:
		return _paused_seconds
	var time: float
	if _finished_usec > 0:
		# Keep the final judgment window running after the last audio buffer.
		time = _finished_seconds + float(Time.get_ticks_usec() - _finished_usec) / 1000000.0
	else:
		# Follow the audio clock so decoder startup and long playback cannot drift.
		time = player.get_playback_position() + AudioServer.get_time_since_last_mix() - _output_latency
	# Audio and main-thread reads can jitter; never move a running clock backward.
	_last_seconds = maxf(_last_seconds, time)
	return _last_seconds


func _on_finished() -> void:
	if not running or player.playing:
		return
	_finished_seconds = maxf(_last_seconds, player.stream.get_length() + AudioServer.get_time_since_last_mix() - _output_latency)
	_finished_usec = Time.get_ticks_usec()


func pause() -> void:
	_paused_seconds = maxf(0.0, seconds())
	player.stop()
	running = false


func resume() -> void:
	if player.stream != null:
		start(player.stream, _paused_seconds)


func stop() -> void:
	player.stop()
	player.stream = null
	running = false
	_paused_seconds = 0.0
	_last_seconds = 0.0
	_finished_usec = 0


func _exit_tree() -> void:
	player.stop()
	player.stream = null

