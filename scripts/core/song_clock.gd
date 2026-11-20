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
var _audio_end_seconds := 0.0
var _fade_seconds := 0.0
var _cuts_audio_early := false
var _normal_volume_db := -5.0
var _volume_modified := false


func _ready() -> void:
	add_child(player)
	player.volume_db = -5.0
	_normal_volume_db = player.volume_db
	player.finished.connect(_on_finished)


func start(stream: AudioStream, from_seconds: float = 0.0, audio_end_seconds: float = -1.0, fade_seconds: float = 0.0) -> void:
	_restore_volume()
	player.stop()
	player.stream = stream
	_normal_volume_db = player.volume_db
	_origin_seconds = maxf(0.0, from_seconds)
	_audio_end_seconds = clampf(audio_end_seconds if audio_end_seconds >= 0.0 else stream.get_length(), 0.0, stream.get_length())
	_fade_seconds = minf(maxf(0.0, fade_seconds), _audio_end_seconds)
	_cuts_audio_early = _audio_end_seconds < stream.get_length() - 0.000001
	_output_latency = AudioServer.get_output_latency()
	_last_seconds = _origin_seconds - _output_latency
	_finished_usec = 0
	_finished_seconds = 0.0
	_origin_usec = Time.get_ticks_usec()
	running = true
	_paused_seconds = _origin_seconds
	if _origin_seconds >= _audio_end_seconds:
		# A chart can continue after its audio. Starting or resuming inside that
		# silent tail still needs a monotonic song clock even though there is no
		# audio frame for AudioStreamPlayer to seek to or finish.
		_begin_silent_tail(_origin_seconds)
		return
	player.play(_origin_seconds)
	_update_fade(_origin_seconds)


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
	if _finished_usec == 0:
		if _cuts_audio_early and _last_seconds >= _audio_end_seconds:
			_begin_silent_tail(_last_seconds)
		else:
			_update_fade(_last_seconds)
	return _last_seconds


func audio_finished() -> bool:
	return _finished_usec > 0 and not player.playing


func _on_finished() -> void:
	if not running or player.playing:
		return
	_finished_seconds = maxf(_last_seconds, player.stream.get_length() + AudioServer.get_time_since_last_mix() - _output_latency)
	_finished_usec = maxi(1, Time.get_ticks_usec())
	_restore_volume()


func _begin_silent_tail(at_seconds: float) -> void:
	player.stop()
	_last_seconds = maxf(_last_seconds, at_seconds)
	_finished_seconds = _last_seconds
	_finished_usec = maxi(1, Time.get_ticks_usec())
	_restore_volume()


func _update_fade(time: float) -> void:
	if _fade_seconds <= 0.0:
		return
	var gain := clampf((_audio_end_seconds - time) / _fade_seconds, 0.0, 1.0)
	player.volume_db = _normal_volume_db + linear_to_db(maxf(0.0001, gain))
	_volume_modified = true


func _restore_volume() -> void:
	if _volume_modified:
		player.volume_db = _normal_volume_db
		_volume_modified = false


func pause() -> void:
	_paused_seconds = maxf(0.0, seconds())
	player.stop()
	_restore_volume()
	running = false


func resume() -> void:
	if player.stream != null:
		start(player.stream, _paused_seconds, _audio_end_seconds, _fade_seconds)


func stop() -> void:
	_restore_volume()
	player.stop()
	player.stream = null
	running = false
	_paused_seconds = 0.0
	_last_seconds = 0.0
	_finished_usec = 0
	_audio_end_seconds = 0.0
	_fade_seconds = 0.0
	_cuts_audio_early = false


func _exit_tree() -> void:
	_restore_volume()
	player.stop()
	player.stream = null

