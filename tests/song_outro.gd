extends SceneTree


class ObservedPlayer extends PlayerView:
	var finished_seconds := -1.0

	func _finish() -> void:
		finished_seconds = clock.seconds()
		super._finish()


var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func _silence(duration: float) -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(int(duration * audio.mix_rate) * 2)
	audio.data = samples
	return audio


func _run() -> void:
	root.size = Vector2i(540, 960)
	await _test_mode(false)
	await _test_mode(true)
	print("Song outro: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_mode(automatic: bool) -> void:
	var player := ObservedPlayer.new()
	player.theme = AppStyle.make_theme()
	player.auto_mode = automatic
	root.add_child(player)
	player.size = Vector2(540, 960)
	player.set_process(false)
	player.offset_ms = 0.0
	player.clock.player.volume_db = -70.0
	player.note_sounds.set_volume_percent(0.0, false)
	player.chart = player.chart.duplicate(true)
	player.chart.bpm = 120.0
	player.chart.offset_seconds = 0.0
	player.chart.phrases = [{"show_beat": 0.0, "response_beat": 0.5, "length_beats": 0.5, "notes": [{"beat": 0.49, "cell": 0}]}]
	player.stream = _silence(1.6)
	player._start()
	player.clock.pause()
	var deadline := 0.5 + RhythmSession.WINDOW
	player.clock._paused_seconds = deadline - 0.01
	if not automatic:
		player._press(0)
	player._process(0.0)
	check(not player._judging_finished and player.session.resolved == 1 and player.session.score == (1000 if automatic else 400), "The original late judgment window stays open before the outro")
	player.clock._paused_seconds = deadline + 0.001
	player._process(0.0)
	check(player._judging_finished and player.state == "playing" and not player.menu.visible and not player.input_pad.interactive and player.clock.player.stream == player.stream, "Judgments end without stopping the music or showing results early")
	check(player.progress.value > 40.0 and player.progress.value < 42.0 and not player.demo_pad.emphasis and not player.input_pad.emphasis, "The song progress includes the outro while both grids become inactive")
	var score := player.session.score
	var counts := player.session.counts.duplicate()
	player._press(0)
	player._press(3)
	check(player.session.score == score and player.session.counts == counts, "Outro taps cannot change the sealed result")
	player._pause()
	var paused_time := player.clock.seconds()
	await create_timer(0.05).timeout
	check(player.state == "paused" and not player.clock.running and player.clock.seconds() == paused_time, "Pausing freezes the outro")
	player._toggle()
	await create_timer(0.2).timeout
	check(player.state == "playing" and player.clock.running and player.clock.player.playing and player.clock.seconds() >= paused_time and player._judging_finished and not player.input_pad.interactive, "Resuming continues the music without reopening judgments")
	player._start()
	check(not player._judging_finished and player.session.score == 0 and player.input_pad.interactive == not automatic and player.clock._origin_seconds == 0.0, "Restarting an outro resets the song and judgment state")
	# Exercise the actual audio player's natural completion, not just a mocked time.
	if not automatic:
		player.clock.pause()
		player.clock._paused_seconds = float(player.session.notes[0].time)
		player._press(0)
	player.clock.start(player.stream, deadline + 0.01)
	var natural_ends: Array[float] = []
	player.clock.player.finished.connect(func() -> void: natural_ends.append(player.clock.seconds()))
	var limit := Time.get_ticks_msec() + 3500
	while player.state == "playing" and Time.get_ticks_msec() < limit:
		await process_frame
		player._process(0.0)
	check(player.state == "finished" and natural_ends.size() == 1 and player.finished_seconds >= player.stream.get_length(), "Results wait for natural playback and the audible end of the song")
	check(player.menu_results.visible and player.session.score == 1000 and player.session.counts.PERFECT == 1 and player.progress.value == 100.0 and not player.clock.running, "The outro ends with the original score and complete progress")
	if not automatic:
		# Music may finish before the compensated deadline. Do not lose late hits.
		player.stream = _silence(0.66)
		player.offset_ms = 250.0
		player._start()
		player.clock.pause()
		player.clock._paused_seconds = 0.67
		player.clock.player.finished.emit()
		player._process(0.0)
		check(player.state == "playing" and not player._judging_finished and player.session.resolved == 0, "Audio completion cannot truncate positive timing compensation")
		player.clock._paused_seconds = 0.91
		player._process(0.0)
		check(player.state == "finished" and player.session.counts.MISS == 1, "The final miss resolves after compensation before the result is shown")
	player.queue_free()
	await process_frame
	await create_timer(0.15).timeout
