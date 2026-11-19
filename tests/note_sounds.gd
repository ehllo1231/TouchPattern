extends SceneTree

var failures: Array[String] = []
var checks := 0
var test_dir := "user://tests/note_sounds_%d" % OS.get_process_id()
var preferences_path := test_dir.path_join("settings.cfg")
var chart_path := test_dir.path_join("chart.json")


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func _run() -> void:
	root.size = Vector2i(1100, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir))
	var settings := ConfigFile.new()
	settings.set_value("timing", "offset_ms", 37.0)
	settings.set_value("note_feedback", "enabled", true)
	settings.save(preferences_path)
	var chart: Dictionary = TouchChart.read(TouchChart.SAMPLE).chart.duplicate(true)
	chart.bpm = 120.0
	chart.offset_seconds = 0.2
	chart.phrases = [{"show_beat": 4.0, "response_beat": 8.0, "length_beats": 4.0, "notes": [{"beat": 0.0, "cell": 0}, {"beat": 0.0, "cell": 3}, {"beat": 1.0, "cell": 1}]}]
	check(TouchChart.write(chart, TouchChart.SAMPLE, chart_path).is_empty(), "Save the feedback timing fixture")
	await _test_module()
	await _test_volume()
	await _test_player(false)
	await _test_player(true)
	await _test_preview()
	await _test_preview_boundaries()
	if OS.get_cmdline_user_args().has("--verify-mixer"):
		await _test_editor_live()
	await create_timer(0.2).timeout
	for path in [preferences_path, chart_path, test_dir]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Note sounds: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_module() -> void:
	var feedback := NoteSounds.new()
	feedback.preferences_path = preferences_path
	feedback.config = feedback.config.duplicate()
	root.add_child(feedback)
	var cues: Array[StringName] = []
	feedback.played.connect(func(source: StringName) -> void: cues.append(source))
	check(feedback.config.sound != null and feedback.config.sound.get_length() > 0.05 and feedback.config.sound.get_length() < 0.5, "The packaged clap is a short, loadable audio asset")
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "NoteSoundTest")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture)
	feedback.player.bus = &"NoteSoundTest"
	feedback.play_demo()
	feedback.play_demo()
	feedback.play_input()
	check(cues == [&"demo"] and feedback.player.playing, "A simultaneous chord starts just one real clap playback")
	await create_timer(0.22).timeout
	var frames := capture.get_frames_available()
	var peak := 0.0
	if frames > 0:
		for sample in capture.get_buffer(frames):
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	if OS.get_cmdline_user_args().has("--verify-mixer"):
		check(frames > 0 and peak > 0.001, "The real audio mixer produces an audible clap waveform")
	feedback.stop()
	feedback.config.demo_enabled = false
	feedback.config.preview_enabled = false
	feedback.play_demo()
	feedback.play_preview()
	feedback.play_input()
	check(cues == [&"demo", &"input"], "Demo, input, and preview feedback can be enabled independently")
	feedback.stop()
	var replacement := feedback.config.sound.duplicate() as AudioStream
	feedback.config.sound = replacement
	feedback.config.volume_db = -20.0
	feedback.reload_preferences()
	feedback.play_input()
	check(feedback.player.stream == replacement and is_equal_approx(feedback.player.volume_db, -20.0), "Replacing the sound and reloading the configured default volume takes effect")
	feedback.set_enabled(false)
	var before := cues.size()
	feedback.play_input()
	check(not feedback.player.playing and cues.size() == before, "Disabling feedback stops current sounds and blocks new ones")
	var restored := NoteSounds.new()
	restored.preferences_path = preferences_path
	root.add_child(restored)
	check(not restored.enabled, "The enabled setting is shared with newly opened windows")
	restored.set_enabled(true)
	var settings := ConfigFile.new()
	settings.load(preferences_path)
	check(float(settings.get_value("timing", "offset_ms")) == 37.0, "Saving sound preferences preserves timing calibration")
	feedback.reload_preferences()
	check(feedback.enabled, "Returning to a window reloads the sound preference saved by another window")
	restored.queue_free()
	feedback.set_enabled(true, false)
	feedback.config.combine_simultaneous = false
	feedback.play_input()
	feedback.play_input()
	check(cues.size() == before + 2 and feedback.player.max_polyphony == feedback.config.polyphony, "Layered claps and polyphony remain configurable")
	feedback.stop()
	feedback.config.sound = null
	before = cues.size()
	feedback.play_input()
	check(cues.size() == before, "An unset sound cleanly disables the optional effect")
	feedback.queue_free()
	await process_frame
	AudioServer.remove_bus(bus)


func _test_volume() -> void:
	var path := test_dir.path_join("volume.cfg")
	var settings := ConfigFile.new()
	settings.set_value("timing", "offset_ms", 37.0)
	settings.set_value("note_feedback", "enabled", true)
	settings.save(path)
	var feedback := NoteSounds.new()
	feedback.preferences_path = path
	feedback.config = feedback.config.duplicate()
	feedback.config.combine_simultaneous = false
	root.add_child(feedback)
	check(is_equal_approx(feedback.player.volume_db, feedback.config.volume_db), "Existing users keep the original clap loudness before choosing a volume")
	var cues: Array[StringName] = []
	feedback.played.connect(func(source: StringName) -> void: cues.append(source))
	feedback.play_preview()
	feedback.set_volume_percent(50.0)
	check(feedback.player.playing and cues.size() == 1 and is_equal_approx(db_to_linear(feedback.player.volume_db), 0.5), "Changing volume immediately adjusts an active clap without restarting it")
	feedback.set_volume_percent(0.0)
	feedback.play_preview()
	check(feedback.enabled and not feedback.player.playing and cues.size() == 1, "Zero volume silences current and future claps without changing the enable checkbox")
	settings.load(path)
	check(float(settings.get_value("timing", "offset_ms")) == 37.0 and bool(settings.get_value("note_feedback", "enabled")) and float(settings.get_value("note_feedback", "volume_percent")) == 0.0, "Saving volume preserves timing and enable preferences")
	var restored := NoteSounds.new()
	restored.preferences_path = path
	root.add_child(restored)
	check(restored.enabled and restored.volume_percent == 0.0, "A new window restores zero volume independently of the enable setting")
	feedback.set_enabled(false)
	feedback.set_volume_percent(35.0)
	restored.reload_preferences()
	check(not restored.enabled and restored.volume_percent == 35.0, "Other windows reload both volume and mute preferences")
	restored.set_enabled(true)
	feedback.reload_preferences()
	check(feedback.enabled and feedback.volume_percent == 35.0, "Toggling feedback preserves the chosen volume")
	feedback.set_volume_percent(150.0, false)
	var upper_bound := feedback.volume_percent == 100.0
	feedback.set_volume_percent(-10.0, false)
	check(upper_bound and feedback.volume_percent == 0.0, "Volume is limited to the slider's zero to one hundred percent range")
	if OS.get_cmdline_user_args().has("--verify-mixer"):
		feedback.set_enabled(true, false)
		var bus := AudioServer.bus_count
		AudioServer.add_bus(bus)
		AudioServer.set_bus_name(bus, "ClapVolumeTest")
		var capture := AudioEffectCapture.new()
		capture.buffer_length = 1.0
		AudioServer.add_bus_effect(bus, capture)
		feedback.player.bus = &"ClapVolumeTest"
		var peaks: Array[float] = []
		for percent in [100.0, 50.0]:
			capture.clear_buffer()
			feedback.set_volume_percent(percent, false)
			feedback.play_preview()
			await create_timer(0.25).timeout
			var peak := 0.0
			var frames := capture.get_frames_available()
			if frames > 0:
				for sample in capture.get_buffer(frames):
					peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			peaks.append(peak)
		check(peaks[0] > 0.001 and absf(peaks[1] / peaks[0] - 0.5) < 0.05, "The actual Windows audio waveform is halved at fifty percent volume")
		feedback.stop()
		feedback.player.bus = &"Master"
		AudioServer.remove_bus(bus)
	feedback.queue_free()
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_player(automatic: bool) -> void:
	var view := PlayerView.new()
	view.theme = AppStyle.make_theme()
	view.initial_path = chart_path
	view.auto_mode = automatic
	view.note_sounds.preferences_path = preferences_path
	view.note_sounds.config = view.note_sounds.config.duplicate()
	view.note_sounds.config.combine_simultaneous = false
	view.note_sounds.config.volume_db = -70.0
	root.add_child(view)
	view.note_sounds.set_volume_percent(db_to_linear(-70.0) * 100.0, false)
	view.set_process(false)
	view.offset_ms = 0.0
	view.clock.player.volume_db = -70.0
	var cues: Array[StringName] = []
	view.note_sounds.played.connect(func(source: StringName) -> void: cues.append(source))
	view._start()
	view.clock.pause()
	view.clock._paused_seconds = TouchChart.beat_to_seconds(view.chart, 4.0)
	view._process(0.0)
	check(cues == [&"demo", &"demo"], "Player demo notes trigger feedback at their authored times")
	view._process(0.0)
	check(cues.size() == 2, "A displayed demo note cannot repeat its sound on later frames")
	view.clock._paused_seconds = TouchChart.beat_to_seconds(view.chart, 5.0)
	view._process(0.0)
	cues.clear()
	view.clock._paused_seconds = TouchChart.beat_to_seconds(view.chart, 8.0)
	if automatic:
		view._process(0.0)
		view._process(0.0)
		view._press(1)
	else:
		view._press(0)
		view._press(3)
	check(cues == [&"input", &"input"] and view.session.score == 2000, "AUTO or manual inputs produce one feedback event per note without double playback")
	if not automatic:
		view.session.advance(TouchChart.beat_to_seconds(view.chart, 11.0))
		check(cues.size() == 2, "A missed note does not create an input sound")
	view._pause()
	check(not view.note_sounds.player.playing, "Pausing stops the remaining clap tail")
	view.note_sound_check.button_pressed = false
	check(not view.note_sounds.enabled, "The player sound checkbox immediately mutes feedback")
	view.note_sound_check.button_pressed = true
	view.note_volume.slider.value = 45.0
	check(view.note_sounds.volume_percent == 45.0 and view.note_volume.value_label.text == "45%" and view.clock.player.volume_db == -70.0 and view.state == "paused", "Manual and AUTO player volume controls adjust only claps while preserving the play state")
	view.note_sounds.set_volume_percent(60.0, false)
	check(view.note_volume.slider.value == 60.0 and view.note_volume.value_label.text == "60%", "Reloaded volume updates the player slider and percentage without feedback loops")
	view.queue_free()
	await process_frame


func _test_preview() -> void:
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	maker.initial_path = chart_path
	maker.note_sounds.preferences_path = preferences_path
	maker.note_sounds.config = maker.note_sounds.config.duplicate()
	maker.note_sounds.config.combine_simultaneous = false
	maker.note_sounds.config.volume_db = -70.0
	root.add_child(maker)
	maker.note_sounds.set_volume_percent(db_to_linear(-70.0) * 100.0, false)
	maker.set_process(false)
	maker.clock.player.volume_db = -70.0
	var cues: Array[StringName] = []
	maker.note_sounds.played.connect(func(source: StringName) -> void: cues.append(source))
	maker._listen()
	var demo := TouchChart.beat_to_seconds(maker.chart, 4.0)
	maker._update_preview(demo)
	maker._update_preview(demo + 0.01)
	check(cues == [&"preview", &"preview"], "Editor demo sounds trigger once when notes are crossed, never during the highlight fade")
	maker._update_preview(TouchChart.beat_to_seconds(maker.chart, 5.0))
	cues.clear()
	var response := TouchChart.beat_to_seconds(maker.chart, 8.0)
	maker._update_preview(response)
	maker._update_preview(response + 0.01)
	check(cues == [&"preview", &"preview"], "Editor response notes also receive sound feedback exactly once")
	maker.note_volume.slider.value = 35.0
	check(maker.note_sounds.volume_percent == 35.0 and maker.note_volume.value_label.text == "35%" and maker.clock.running and maker.clock.player.volume_db == -70.0 and not maker.dirty, "Editor volume changes during listening preserve music playback and chart contents")
	maker._stop_preview()
	check(not maker.note_sounds.player.playing, "Stopping the editor preview cuts feedback playback")
	maker.note_sound_check.button_pressed = false
	check(not maker.note_sounds.enabled and not maker.dirty, "The editor sound checkbox does not modify the chart")
	maker.note_sound_check.button_pressed = true
	maker._new_chart()
	cues.clear()
	maker._listen()
	maker._update_preview(TouchChart.beat_to_seconds(maker.chart, 4.0))
	maker._toggle_note(0.0, 0)
	check(cues.is_empty(), "Empty drafts and note-editing clicks do not generate playback sounds")
	maker.queue_free()
	await process_frame


func _test_preview_boundaries() -> void:
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	maker.initial_path = chart_path
	maker.note_sounds.preferences_path = preferences_path
	maker.note_sounds.config = maker.note_sounds.config.duplicate()
	maker.note_sounds.config.combine_simultaneous = false
	maker.note_sounds.config.volume_db = -70.0
	root.add_child(maker)
	maker.note_sounds.set_volume_percent(db_to_linear(-70.0) * 100.0, false)
	maker.set_process(false)
	maker.clock.player.volume_db = -70.0
	# Keep list order different from song order and place a note near the boundary.
	maker.chart.phrases = [
		{"show_beat": 6.0, "response_beat": 7.0, "length_beats": 1.0, "notes": [{"beat": 0.0, "cell": 1}]},
		{"show_beat": 4.0, "response_beat": 5.0, "length_beats": 1.0, "notes": [{"beat": 0.9, "cell": 0}]}
	]
	maker._refresh()
	maker._select_phrase(1)
	var cues: Array[StringName] = []
	maker.note_sounds.played.connect(func(source: StringName) -> void: cues.append(source))
	maker._listen(true)
	maker._update_preview(2.7)
	check(cues.size() == 1, "Editor sounds follow song order independently of pattern list order")
	maker._update_preview(3.14)
	cues.clear()
	maker._update_preview(3.21)
	check(maker.selected == 0 and cues.size() == 2, "Continuous listening keeps both notes when a frame crosses a pattern boundary")
	maker._update_preview(3.22)
	check(cues.size() == 2, "Changing the displayed pattern cannot repeat a sound")
	maker.clock.start(maker.clock.player.stream, maker._preview_end + 0.5)
	maker._process(0.0)
	check(not maker.clock.running and cues.size() == 3 and maker.note_sounds.player.playing, "Natural preview completion plays remaining notes and lets the last clap finish")
	maker._stop_preview()
	check(not maker.note_sounds.player.playing, "Explicit stop still cuts the clap tail")
	maker.note_sound_check.button_pressed = false
	cues.clear()
	maker._listen(true)
	maker._update_preview(maker._preview_end)
	maker.note_sound_check.button_pressed = true
	maker._update_preview(maker._preview_end)
	check(cues.is_empty(), "Re-enabling editor feedback does not replay notes crossed while muted")
	maker._select_phrase(1)
	cues.clear()
	maker._listen()
	maker._update_preview(maker._preview_end)
	check(cues.size() == 2, "Single-pattern listening only plays the selected pattern's demo and response")
	maker._select_phrase(0)
	cues.clear()
	maker._listen(true)
	maker._update_preview(3.15)
	check(cues.is_empty(), "A selected pattern's lead-in does not play an earlier pattern's notes")
	maker._update_preview(3.21)
	check(cues.size() == 1, "Continuous listening begins feedback with the selected pattern")
	maker.queue_free()
	await process_frame


func _test_editor_live() -> void:
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	maker.initial_path = chart_path
	maker.note_sounds.preferences_path = preferences_path
	maker.note_sounds.config = maker.note_sounds.config.duplicate()
	maker.note_sounds.config.combine_simultaneous = true
	maker.note_sounds.config.preview_enabled = true
	root.add_child(maker)
	maker.clock.player.volume_db = -70.0
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "EditorLiveSoundTest")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 8.0
	AudioServer.add_bus_effect(bus, capture)
	maker.note_sounds.player.bus = &"EditorLiveSoundTest"
	var cues: Array[float] = []
	maker.note_sounds.played.connect(func(_source: StringName) -> void: cues.append(maker.clock.seconds()))
	maker._listen()
	var deadline := Time.get_ticks_msec() + 10000
	while maker.clock.running and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not maker.clock.running and cues.size() == 4, "Actual editor audio playback produces one clap per demo and response beat")
	var expected := [2.2, 2.7, 4.2, 4.7]
	var aligned := cues.size() == expected.size()
	for index in range(mini(cues.size(), expected.size())):
		aligned = aligned and absf(cues[index] - float(expected[index])) < 0.08
	check(aligned, "Live editor claps follow the song clock's authored note times")
	var peak := 0.0
	var frames := capture.get_frames_available()
	if frames > 0:
		for sample in capture.get_buffer(frames):
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(frames > 0 and peak > 0.001, "Editor listening reaches the real audio mixer with an audible waveform")
	maker.queue_free()
	await process_frame
	AudioServer.remove_bus(bus)
