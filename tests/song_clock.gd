extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func _run() -> void:
	var result := TouchChart.read(TouchChart.SAMPLE)
	var stream := TouchChart.load_audio(TouchChart.audio_path(result.chart, TouchChart.SAMPLE))
	var clock := SongClock.new()
	root.add_child(clock)
	clock.player.volume_db = -70.0
	clock.start(stream)
	var previous := clock.seconds()
	var monotonic := true
	for frame in range(36):
		await process_frame
		var current := clock.seconds()
		monotonic = monotonic and current >= previous
		previous = current
	check(monotonic and previous > 0.0, "Audio clock advances without moving backward")
	var before := clock.seconds()
	clock._origin_usec -= 5000000
	check(absf(clock.seconds() - before) < 0.1, "System-clock drift cannot move the audio-based song time")
	clock.start(stream, 12.0)
	await create_timer(0.25).timeout
	check(clock.seconds() >= 12.0 and clock.seconds() < 12.6, "Seeking keeps the original song position")
	clock.pause()
	var paused := clock.seconds()
	await create_timer(0.1).timeout
	check(not clock.running and is_equal_approx(clock.seconds(), paused), "Pause freezes the audible song position")
	clock.resume()
	await create_timer(0.2).timeout
	check(clock.running and clock.seconds() >= paused and clock.seconds() < paused + 0.6, "Resume continues from the paused song position")
	clock.start(stream)
	var restarted := clock.seconds()
	await create_timer(0.1).timeout
	check(restarted < 0.5 and clock.seconds() < 0.6, "Restarting from the beginning cannot retain the previous audio position")
	clock.start(stream, stream.get_length() - 0.12)
	await create_timer(0.6).timeout
	check(clock.running and not clock.player.playing and clock.seconds() > stream.get_length() + 0.1, "Natural audio completion preserves the final judgment grace period")
	clock.stop()
	await create_timer(0.05).timeout
	check(not clock.running and clock.seconds() == 0.0, "Stop clears the audio clock and its end-of-song tail")
	clock.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("SongClock: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
