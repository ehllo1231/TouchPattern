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


func click_control(control: Control) -> void:
	await process_frame
	var point := control.get_global_transform_with_canvas() * (control.size / 2.0)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
	await process_frame


func silence(duration: float) -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(int(duration * audio.mix_rate) * 2)
	audio.data = samples
	return audio


func _run() -> void:
	root.size = Vector2i(1100, 900)
	var result := TouchChart.read(TouchChart.SAMPLE)
	check(str(result.error).is_empty(), "Bundled chart loads")
	if not str(result.error).is_empty():
		quit(1)
		return
	var chart: Dictionary = result.chart
	var audio := TouchChart.load_audio(TouchChart.audio_path(chart, TouchChart.SAMPLE))
	check(audio != null and audio.get_length() > TouchChart.beat_to_seconds(chart, TouchChart.end_beat(chart)) + RhythmSession.WINDOW, "Sample audio covers the full chart")
	var perfect := RhythmSession.new(chart)
	for note in perfect.notes:
		perfect.hit(int(note.cell), float(note.time))
	check(perfect.score == perfect.notes.size() * 1000, "All correct inputs receive full score")
	check(perfect.resolved == perfect.notes.size() and perfect.max_combo == perfect.notes.size(), "All notes resolve with a full combo")
	check(is_equal_approx(perfect.accuracy(), 100.0), "All-perfect accuracy is 100%")
	var demo := RhythmSession.new(chart)
	var demo_time := TouchChart.beat_to_seconds(chart, float(chart.phrases[0].show_beat))
	check(demo.hit(0, demo_time) == "IGNORED" and demo.score == 0 and demo.counts.MISS == 0, "Demo inputs are ignored")
	check(demo.demos_between(demo_time - 0.01, demo_time).size() == 1, "Demo flashes use the authored beat")
	check(demo.demos_between(demo_time, demo_time + 0.01).is_empty(), "Demo flash is not repeated on the next frame")
	var first := float(demo.notes[0].time)
	var early := RhythmSession.new(chart)
	check(early.hit(0, first - RhythmSession.WINDOW) == "OK", "Early edge is accepted even before the response boundary")
	var late := RhythmSession.new(chart)
	check(late.hit(0, first + RhythmSession.WINDOW) == "OK", "Exact late edge is accepted")
	var outside := RhythmSession.new(chart)
	check(outside.hit(0, first + RhythmSession.WINDOW + 0.001) == "MISS" and outside.counts.MISS == 2, "A late tap counts the missed note and unmatched input as misses")
	var mistaken := RhythmSession.new(chart)
	check(mistaken.hit(3, first) == "MISS" and mistaken.counts.MISS == 1 and not mistaken.notes[0].done, "An unmatched cell is reported as MISS without consuming the correct note")
	mistaken.hit(0, first)
	check(is_equal_approx(mistaken.accuracy(), 50.0), "An unmatched input is included once in the unified MISS accuracy")
	var missed := RhythmSession.new(chart)
	missed.advance(10000.0)
	check(missed.counts.MISS == missed.notes.size() and missed.score == 0, "Unplayed notes become misses")
	var chord_chart := chart.duplicate(true)
	chord_chart.phrases = [{"show_beat": 0, "response_beat": 4, "length_beats": 4, "notes": [{"beat": 0, "cell": 0}, {"beat": 0, "cell": 3}]}]
	var chord := RhythmSession.new(chord_chart)
	var chord_time := TouchChart.beat_to_seconds(chord_chart, 4)
	check(chord.hit(3, chord_time) == "PERFECT" and chord.hit(0, chord_time) == "PERFECT", "Chord cells accept either input order")
	var automatic := RhythmSession.new(chart)
	var auto_errors: Array[float] = []
	automatic.judged.connect(func(_kind: String, _cell: int, error_ms: float) -> void: auto_errors.append(error_ms))
	automatic.auto_play(first - 0.000001)
	check(automatic.resolved == 0, "AUTO never plays a note before its exact song time")
	automatic.auto_play(first)
	check(automatic.counts.PERFECT == 1 and automatic.score == 1000, "AUTO plays a due note at its exact authored time")
	automatic.auto_play(first)
	check(automatic.resolved == 1, "AUTO never repeats an already played note")
	automatic.auto_play(10000.0)
	check(automatic.counts.PERFECT == 42 and automatic.counts.MISS == 0 and automatic.max_combo == 42 and automatic.accuracy() == 100.0 and auto_errors.count(0.0) == 42, "AUTO handles skipped frames and chords with exact judgments and no misses")
	var auto_chord := RhythmSession.new(chord_chart)
	auto_chord.auto_play(chord_time)
	check(auto_chord.resolved == 2 and auto_chord.score == 2000, "AUTO plays simultaneous cells together")
	var auto_partial := RhythmSession.new(chart, 52.0)
	auto_partial.auto_play(10000.0)
	check(auto_partial.counts.PERFECT == 14 and auto_partial.counts.MISS == 0 and auto_partial.score == 14000, "AUTO respects the selected-pattern starting point")
	var partial := RhythmSession.new(chart, 52.0)
	check(partial.notes.size() == 14, "Starting at the seventh pattern only judges its fourteen remaining notes")
	partial.advance(TouchChart.beat_to_seconds(chart, 51.5))
	check(partial.counts.MISS == 0 and partial.resolved == 0 and partial.hit(0, TouchChart.beat_to_seconds(chart, 51.5)) == "IGNORED", "Skipped patterns cannot produce misses during the lead-in")
	check(partial.demos_between(-1000.0, TouchChart.beat_to_seconds(chart, 52.0)) == [0, 1], "Seeking does not replay demo flashes from skipped patterns")
	check(partial.phase_at(TouchChart.beat_to_seconds(chart, 52.0)).index == 6, "Partial play preserves the original pattern indices")
	for note in partial.notes:
		partial.hit(int(note.cell), float(note.time))
	check(partial.score == 14000 and partial.counts.MISS == 0 and partial.accuracy() == 100.0, "A selected-pattern run can finish with full accuracy and no skipped-note penalties")
	var interleaved_chart := chart.duplicate(true)
	interleaved_chart.phrases = [{"show_beat": 0.0, "response_beat": 20.0, "length_beats": 1.0, "notes": [{"beat": 0.0, "cell": 0}]}, {"show_beat": 4.0, "response_beat": 8.0, "length_beats": 1.0, "notes": [{"beat": 0.0, "cell": 3}]}]
	var interleaved := RhythmSession.new(interleaved_chart, 4.0)
	check(interleaved.end_beat == 9.0 and interleaved.phase_at(TouchChart.beat_to_seconds(interleaved_chart, 20.0)).kind == "complete", "Partial play ends after included patterns even if a skipped pattern has a later response")
	var invalid := chart.duplicate(true)
	invalid.bpm = 0
	check(not TouchChart.validate(invalid).is_empty(), "Reject zero BPM")
	invalid = chart.duplicate(true)
	invalid.phrases[0].notes[0].cell = 1.5
	check(not TouchChart.validate(invalid).is_empty(), "Reject fractional cell numbers")
	invalid = chart.duplicate(true)
	invalid.phrases[0].notes.append(invalid.phrases[0].notes[0].duplicate())
	check(not TouchChart.validate(invalid).is_empty(), "Reject duplicate notes")
	invalid = chart.duplicate(true)
	invalid.phrases[0].response_beat = invalid.phrases[0].show_beat
	check(not TouchChart.validate(invalid).is_empty(), "Reject overlapping demo/response")
	invalid = chart.duplicate(true)
	invalid.phrases[1].show_beat = invalid.phrases[0].response_beat
	check(not TouchChart.validate(invalid).is_empty(), "Reject overlapping phrases")
	invalid = chart.duplicate(true)
	invalid.phrases[0].notes[0].beat = invalid.phrases[0].length_beats
	check(not TouchChart.validate(invalid).is_empty(), "Reject notes beyond phrase length")
	invalid = chart.duplicate(true)
	invalid.phrases[0].notes[0] = null
	check(not TouchChart.validate(invalid).is_empty(), "Malformed nested notes fail cleanly")
	var ending := chart.duplicate(true)
	ending.audio_end_beat = float(ending.phrases[0].response_beat) + float(ending.phrases[0].length_beats)
	ending.fade_out_seconds = 2.5
	check(TouchChart.validate(ending).is_empty() and is_equal_approx(TouchChart.fade_out_seconds(ending), 2.5), "A phrase boundary accepts an authored ending and fade duration")
	invalid = ending.duplicate(true)
	invalid.audio_end_beat = float(invalid.audio_end_beat) + 0.25
	check(not TouchChart.validate(invalid).is_empty(), "Reject an authored ending outside a response boundary")
	invalid = ending.duplicate(true)
	invalid.fade_out_seconds = TouchChart.MAX_FADE_OUT_SECONDS + 0.1
	check(not TouchChart.validate(invalid).is_empty(), "Reject a fade duration outside the supported range")
	invalid = chart.duplicate(true)
	invalid.fade_out_seconds = 2.0
	check(not TouchChart.validate(invalid).is_empty(), "Reject a fade duration without an authored ending")
	var destination := "user://tests/roundtrip.json"
	check(TouchChart.write(chart, TouchChart.SAMPLE, destination).is_empty(), "Save chart")
	var roundtrip := TouchChart.read(destination)
	check(str(roundtrip.error).is_empty(), "Read saved chart")
	check(TouchChart.audio_path(roundtrip.chart, destination) == TouchChart.audio_path(chart, TouchChart.SAMPLE), "Save As preserves relative built-in audio references")
	var ending_path := "user://tests/ending_roundtrip.json"
	check(TouchChart.write(ending, TouchChart.SAMPLE, ending_path).is_empty(), "Save a chart with an authored audio ending")
	var ending_roundtrip := TouchChart.read(ending_path)
	check(str(ending_roundtrip.error).is_empty() and is_equal_approx(float(ending_roundtrip.chart.audio_end_beat), float(ending.audio_end_beat)) and is_equal_approx(float(ending_roundtrip.chart.fade_out_seconds), 2.5), "Authored ending and fade duration survive reloading")
	var ending_track := SongLibrary.track(ending_path)
	check(str(ending_track.error).is_empty() and is_equal_approx(float(ending_track.duration), TouchChart.beat_to_seconds(ending, float(ending.audio_end_beat))), "Song selection shows the shortened authored duration")
	var external := chart.duplicate(true)
	external.audio = "../audio/song.wav"
	var source_path := "user://tests/original/source.json"
	var relocated_path := "user://tests/moved/relocated.json"
	check(TouchChart.write(external, source_path, relocated_path).is_empty(), "Save external chart in another directory")
	var relocated := TouchChart.read(relocated_path)
	check(ProjectSettings.globalize_path(TouchChart.audio_path(relocated.chart, relocated_path)) == ProjectSettings.globalize_path(TouchChart.audio_path(external, source_path)), "Save As preserves external audio references")
	var outside_app_data := chart.duplicate(true)
	outside_app_data.audio = ProjectSettings.globalize_path(TouchChart.audio_path(chart, TouchChart.SAMPLE))
	var snapshot_path := "user://tests/external_audio_snapshot.json"
	check(TouchChart.write(outside_app_data, TouchChart.SAMPLE, snapshot_path).is_empty(), "Write a snapshot referencing audio outside app data")
	var snapshot := TouchChart.read(snapshot_path)
	var resolved_audio := TouchChart.audio_path(snapshot.chart, snapshot_path)
	check(resolved_audio == str(outside_app_data.audio).simplify_path(), "Resolve relative audio beyond the user:// root against the physical chart directory")
	check(TouchChart.load_audio(resolved_audio) != null, "Snapshot audio outside app data remains loadable")
	var shifted := chart.duplicate(true)
	shifted.offset_seconds = 0.3
	check(is_equal_approx(TouchChart.seconds_to_beat(shifted, TouchChart.beat_to_seconds(shifted, 13.25)), 13.25), "Beat/second conversion includes song offset")

	# Exercise actual controls and audio transport, in addition to pure judge logic.
	var player := PlayerView.new()
	player.theme = AppStyle.make_theme()
	root.add_child(player)
	player.size = Vector2(1100, 900)
	await process_frame
	check(player.session != null and player.state == "ready", "Player UI loads the sample")
	player._load_chart(snapshot_path)
	check(player.chart_path == snapshot_path, "Player loads a preview snapshot with external audio")
	player._start()
	await process_frame
	check(player.state == "playing" and player.clock.running, "Player starts audio transport")
	player._pause()
	check(player.state == "paused" and not player.clock.running, "Pause freezes audio and judging")
	player._toggle()
	check(player.state == "playing" and player.clock.running, "Resume restarts the calibrated clock")
	player.clock.pause()
	var touches: Array[int] = []
	player.input_pad.cell_pressed.connect(func(cell: int) -> void: touches.append(cell))
	for cell in [0, 3]:
		var touch := InputEventScreenTouch.new()
		touch.index = cell
		touch.pressed = true
		touch.position = player.input_pad.get_global_transform_with_canvas() * player.input_pad.cell_rect(cell).get_center()
		player.input_pad._input(touch)
	check(touches == [0, 3], "Independent touch events support simultaneous cells")
	var start_chart := chart.duplicate(true)
	start_chart.bpm = 120.0
	start_chart.offset_seconds = 0.3
	var selected_path := "user://tests/selected_start.json"
	check(TouchChart.write(start_chart, TouchChart.SAMPLE, selected_path).is_empty(), "Save a selected-pattern fixture with a different BPM and offset")
	player._load_chart(selected_path, 2)
	player._start()
	player._process(0.0)
	check(player.clock.running and is_equal_approx(player.clock._origin_seconds, 9.8) and player.session.notes.size() == 35, "Player seeks one beat before the selected demo using its BPM and song offset")
	check(player.session.counts.MISS == 0 and player.demo_pad._glow.count(0.0) == 4 and player.progress.value > 0.0, "A partial start has no old misses or demo bursts and displays its song position")
	player._pause()
	player._toggle()
	check(player.state == "playing" and player.clock._origin_seconds > 9.0 and player.session.notes.size() == 35, "Pause and resume preserve a selected-pattern test run")
	player.session.hit(0, float(player.session.notes[0].time))
	player._start()
	check(is_equal_approx(player.clock._origin_seconds, 9.8) and player.session.score == 0 and player.session.counts.MISS == 0 and player.session.notes.size() == 35, "Restarting retries the selected pattern with a clean score")
	player._load_chart(selected_path, 0)
	player._start()
	check(is_equal_approx(player.clock._origin_seconds, 1.8) and player.session.notes.size() == 42, "Testing the first pattern also begins one beat before its demo")
	player._load_chart(selected_path, 999)
	player._start()
	check(player.clock._origin_seconds == 0.0 and player.session.notes.size() == 42, "An invalid starting pattern safely falls back to a full run")
	player._load_chart(selected_path)
	player._start()
	check(player.clock._origin_seconds == 0.0 and player.session.notes.size() == 42, "Opening another chart resets the test starting point")
	player.queue_free()
	await process_frame
	var autoplay_test := PlayerView.new()
	autoplay_test.theme = AppStyle.make_theme()
	autoplay_test.initial_path = selected_path
	autoplay_test.initial_phrase = 2
	autoplay_test.autoplay = true
	root.add_child(autoplay_test)
	await process_frame
	check(autoplay_test.state == "playing" and is_equal_approx(autoplay_test.clock._origin_seconds, 9.8) and autoplay_test.session.notes.size() == 35 and autoplay_test.session.counts.MISS == 0, "An autoplay test window starts directly at the requested pattern")
	autoplay_test.queue_free()
	await process_frame
	var auto_player := PlayerView.new()
	auto_player.theme = AppStyle.make_theme()
	auto_player.initial_path = selected_path
	auto_player.initial_phrase = 2
	auto_player.autoplay = true
	auto_player.auto_mode = true
	root.add_child(auto_player)
	await process_frame
	check(auto_player.state == "playing" and not auto_player.input_pad.interactive and auto_player.hud.auto_badge.visible and is_equal_approx(auto_player.clock._origin_seconds, 9.8), "AUTO opens a clearly labeled, non-interactive demo at the selected pattern")
	auto_player._press(3)
	var auto_key := InputEventKey.new()
	auto_key.physical_keycode = KEY_K
	auto_key.pressed = true
	auto_player._unhandled_key_input(auto_key)
	check(auto_player.session.resolved == 0 and auto_player.session.counts.MISS == 0 and auto_player.input_pad._glow.count(0.0) == 4, "Manual key and pad inputs cannot interfere with AUTO")
	auto_player._pause()
	auto_player._toggle()
	check(auto_player.state == "playing" and auto_player.auto_mode, "AUTO can pause and resume")
	# Freeze the clock to test exact timing independently of rendering or audio latency.
	auto_player.clock.pause()
	var auto_first := float(auto_player.session.notes[0].time)
	auto_player.offset_ms = -250.0
	auto_player.clock._paused_seconds = auto_first - 0.000001
	auto_player._process(0.0)
	check(auto_player.session.resolved == 0, "Negative manual timing compensation cannot make AUTO play early")
	auto_player.offset_ms = 250.0
	auto_player.clock._paused_seconds = auto_first + 0.4
	auto_player._process(0.0)
	check(auto_player.session.counts.PERFECT == 2 and auto_player.session.counts.MISS == 0 and auto_player.input_pad._glow[1] > 0.0 and auto_player.input_pad.feedback.kinds[1] == "PERFECT", "AUTO ignores manual compensation and visibly plays every due response note")
	auto_player.clock._paused_seconds = TouchChart.beat_to_seconds(auto_player.chart, auto_player.session.end_beat) + RhythmSession.WINDOW + 0.01
	auto_player._process(0.0)
	check(auto_player.state == "playing" and auto_player._judging_finished and auto_player.session.counts.PERFECT == 35 and auto_player.session.counts.MISS == 0 and not auto_player.input_pad.interactive and not auto_player.menu.visible, "AUTO seals every remaining note as perfect while waiting for the outro")
	auto_player.clock._paused_seconds = auto_player.stream.get_length()
	auto_player.clock.player.finished.emit()
	auto_player._process(0.0)
	check(auto_player.state == "finished" and auto_player.hud.auto_badge.visible and auto_player.menu.visible, "AUTO shows the result after the song ends")
	auto_player._start()
	check(auto_player.auto_mode and auto_player.session.score == 0 and is_equal_approx(auto_player.clock._origin_seconds, 9.8), "Restarting AUTO resets its score and retries the same selected pattern")
	auto_player.queue_free()
	await process_frame
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	root.add_child(maker)
	maker.size = Vector2(1100, 900)
	await process_frame
	check(maker.chart.phrases.size() == chart.phrases.size(), "Maker loads the same chart")
	check(maker.pattern_strip.thumbnails.size() == chart.phrases.size() and maker.pattern_strip.thumbnails[0].button_pressed, "Every pattern appears as a thumbnail with one selected")
	await process_frame
	var first_section := maker.pattern_strip.thumbnails[0].get_global_rect()
	var second_section := maker.pattern_strip.thumbnails[1].get_global_rect()
	check(is_equal_approx(first_section.end.x, second_section.position.x) and is_equal_approx(first_section.position.y, second_section.position.y), "Pattern preview sections join without gaps on the same lanes")
	await click_control(maker.pattern_strip.thumbnails[1])
	check(maker.selected == 1 and maker.pattern_strip.selected == 1 and maker.timeline.phrase == maker.chart.phrases[1] and maker.show_spin.value == 12.0, "Clicking a thumbnail opens that pattern in the editor")
	check(maker.pattern_strip.thumbnails[1].button_pressed and not maker.pattern_strip.thumbnails[0].button_pressed and not maker.dirty, "Thumbnail selection is exclusive and never edits the chart")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = maker.pattern_strip.get_global_transform_with_canvas() * (maker.pattern_strip.size / 2.0)
	wheel.global_position = wheel.position
	Input.parse_input_event(wheel)
	await process_frame
	check(maker.pattern_strip.scroll_horizontal > 0, "The mouse wheel scrolls the thumbnail strip horizontally")
	maker._add_phrase()
	await process_frame
	await process_frame
	var last_thumbnail := maker.pattern_strip.thumbnails[-1]
	var strip_rect := maker.pattern_strip.get_global_rect()
	check(maker.selected == 8 and maker.pattern_strip.thumbnails.size() == 9 and last_thumbnail.button_pressed and strip_rect.intersects(last_thumbnail.get_global_rect()), "Adding a pattern selects and reveals its thumbnail")
	maker.fade_spin.value = 2.4
	maker._toggle_audio_end()
	check(is_equal_approx(float(maker.chart.audio_end_beat), maker._selected_response_end()) and is_equal_approx(float(maker.chart.fade_out_seconds), 2.4) and maker.pattern_strip.thumbnails[8].ends_audio and "✓" in maker.audio_end_button.text, "The selected pattern can mark and display the audio ending")
	maker.fade_spin.value = 1.7
	check(is_equal_approx(float(maker.chart.fade_out_seconds), 1.7), "Fade duration edits the active audio ending")
	maker._delete_phrase()
	check(maker.chart.phrases.size() == 8 and maker.pattern_strip.thumbnails.size() == 8 and maker.selected == 7 and maker.pattern_strip.thumbnails[7].button_pressed and not TouchChart.has_audio_end(maker.chart), "Deleting the ending pattern clears its marker and updates selection")
	maker._select_phrase(0)
	await process_frame
	await process_frame
	check(maker.pattern_strip.thumbnails[0].get_global_rect().position.x >= maker.pattern_strip.get_global_rect().position.x, "Selecting an earlier pattern scrolls it back into view")
	var before: int = maker.chart.phrases[0].notes.size()
	maker._toggle_note(0.25, 0)
	check(maker.dirty and maker.chart.phrases[0].notes.size() == before + 1, "Timeline adds a snapped note")
	check(maker.pattern_strip.thumbnails[0].phrase.notes.size() == before + 1, "Thumbnail data refreshes immediately after note editing")
	maker._toggle_note(0.25, 0)
	check(maker.chart.phrases[0].notes.size() == before, "Timeline toggles the note off")
	var timeline_size := maker.timeline.size
	var timeline_click := InputEventMouseButton.new()
	timeline_click.button_index = MOUSE_BUTTON_LEFT
	timeline_click.pressed = true
	maker.timeline.size = Vector2(800, 226)
	timeline_click.position = Vector2(148, 167)
	maker.timeline._gui_input(timeline_click)
	check(maker.chart.phrases[0].notes.any(func(note: Dictionary) -> bool: return int(note.cell) == 3 and is_equal_approx(float(note.beat), 0.5)), "The compact timeline maps clicks to the correct row and beat")
	maker.timeline.size = Vector2(800, 422)
	timeline_click.position = Vector2(148, 338.5)
	maker.timeline._gui_input(timeline_click)
	check(maker.chart.phrases[0].notes.size() == before, "Resizing the timeline preserves note input mapping")
	maker.timeline.size = timeline_size
	maker.length_spin.value = 8.0
	check(float(maker.pattern_strip.thumbnails[0].phrase.length_beats) == 8.0 and is_equal_approx(maker.pattern_strip.thumbnails[0].custom_minimum_size.x, maker.pattern_strip.thumbnails[1].custom_minimum_size.x * 2.0), "An eight-beat preview has twice the width of a four-beat preview")
	maker.length_spin.value = 32.0
	maker._select_phrase(1)
	await process_frame
	await process_frame
	maker._select_phrase(0)
	await process_frame
	await process_frame
	check(maker.pattern_strip.thumbnails[0].size.x > maker.pattern_strip.size.x and is_equal_approx(maker.pattern_strip.thumbnails[0].get_global_rect().position.x, maker.pattern_strip.get_global_rect().position.x), "Selecting a long pattern reveals its beginning")
	maker.length_spin.value = 4.0
	maker._change_length(1.0)
	check(float(maker.chart.phrases[0].length_beats) == 4.0, "Shrinking a phrase never silently deletes notes")
	maker._save_to("user://tests/maker_saved.json")
	check(not maker.dirty and str(TouchChart.read("user://tests/maker_saved.json").error).is_empty(), "Maker saves a chart that the player can load")
	maker._listen()
	await process_frame
	check(maker.clock.running, "Maker previews the selected phrase with audio")
	maker._stop_preview()
	var preview_chart := chart.duplicate(true)
	preview_chart.audio = TouchChart.audio_path(chart, TouchChart.SAMPLE)
	preview_chart.bpm = 173.0
	preview_chart.offset_seconds = 0.317
	preview_chart.phrases = [
		{"name": "Timing", "show_beat": 0.0, "response_beat": 4.0, "length_beats": 4.0, "notes": [{"beat": 0.0, "cell": 0}, {"beat": 0.0, "cell": 3}, {"beat": 0.125, "cell": 0}, {"beat": 3.875, "cell": 2}]},
		{"name": "Other", "show_beat": 8.0, "response_beat": 12.0, "length_beats": 4.0, "notes": [{"beat": 0.0, "cell": 1}]}
	]
	maker.chart = preview_chart
	maker._refresh()
	maker.chart.audio_end_beat = 8.0
	maker.chart.fade_out_seconds = 1.25
	maker._refresh()
	maker._listen(true)
	check(is_equal_approx(maker.clock._audio_end_seconds, TouchChart.beat_to_seconds(preview_chart, 8.0)) and is_equal_approx(maker.clock._fade_seconds, 1.25) and maker.pattern_strip.thumbnails[0].ends_audio, "Continuous preview uses and marks the authored fade-out ending")
	maker._stop_preview()
	maker.chart.erase("audio_end_beat")
	maker.chart.erase("fade_out_seconds")
	maker._refresh()
	maker._listen()
	check(maker.clock.running and maker._preview_session != null, "Timing fixture starts preview playback")
	var preview_demo := TouchChart.beat_to_seconds(preview_chart, 0.0)
	maker._update_preview(preview_demo - 0.000001)
	check(maker.timeline.preview_highlights.is_empty() and maker.preview_pad._glow.count(0.0) == 4, "Timing outlines never appear before the exact note time")
	maker._update_preview(preview_demo)
	check(maker.preview_pad.outline_only and not maker.preview_pad.interactive, "Timing preview shows outlines without accepting gameplay input")
	check(is_equal_approx(maker.preview_pad._glow[0], 1.0) and is_equal_approx(maker.preview_pad._glow[3], 1.0) and maker.timeline.preview_highlights.size() == 2, "Demo chord outlines peak together at the exact authored time, including the song offset")
	maker._update_preview(TouchChart.beat_to_seconds(preview_chart, 0.125))
	check(is_equal_approx(maker.preview_pad._glow[0], 1.0) and maker.timeline.preview_highlights.has(2), "Off-grid repeated notes start a new pulse at the authored BPM")
	maker._update_preview(preview_demo + ChartMaker.PREVIEW_FLASH_SECONDS + 0.000001)
	check(maker.preview_pad._glow[0] > 0.0 and is_zero_approx(maker.preview_pad._glow[3]), "Each pulse fades using song time while newer repeated notes remain visible")
	maker._update_preview(preview_demo + 0.5)
	check(maker.timeline.preview_highlights.is_empty() and maker.preview_pad._glow.count(0.0) == 4, "Rests clear timing outlines even when preview frames are skipped")
	var preview_response := TouchChart.beat_to_seconds(preview_chart, 4.0)
	maker._update_preview(preview_response)
	check(is_equal_approx(maker.preview_pad._glow[0], 1.0) and is_equal_approx(maker.preview_pad._glow[3], 1.0) and maker.timeline.playhead == 0.0, "Response outlines repeat the perfect input timing from the demo")
	var preview_judge := RhythmSession.new(preview_chart)
	check(preview_judge.hit(0, preview_response) == "PERFECT" and preview_judge.hit(3, preview_response) == "PERFECT", "Displayed response timing matches zero-error game judgments")
	maker._update_preview(TouchChart.beat_to_seconds(preview_chart, 8.0))
	check(is_zero_approx(maker.preview_pad._glow[1]), "Preview only highlights the selected phrase")
	check(maker.preview_pad._glow[2] > 0.0 and maker.timeline.preview_highlights.has(3), "The last note keeps its short pulse across a phrase boundary")
	maker.clock.start(audio, maker._preview_end + 1.0)
	maker._process(0.0)
	check(not maker.clock.running and maker.timeline.preview_highlights.is_empty() and maker.preview_pad._glow.count(0.0) == 4, "Reaching the preview end automatically clears timing outlines")
	maker._listen()
	maker._update_preview(preview_response)
	maker._stop_preview()
	check(maker.timeline.playhead < 0.0 and maker.timeline.preview_highlights.is_empty() and maker.preview_pad._glow.count(0.0) == 4, "Stopping clears the playhead and all timing outlines")
	maker._listen()
	maker._update_preview(preview_demo)
	maker._select_phrase(1)
	check(not maker.clock.running and maker.timeline.preview_highlights.is_empty() and maker.preview_pad._glow.count(0.0) == 4, "Changing phrases stops playback and clears old outlines")
	maker._select_phrase(0)
	var preview_before_follow := maker.chart.duplicate(true)
	var dirty_before_follow := maker.dirty
	maker._listen(true)
	var continuous_origin := maker.clock._origin_usec
	var continuous_stream := maker.clock.player.stream
	check(maker.clock.running and maker._preview_continuous and is_equal_approx(maker._preview_end, TouchChart.beat_to_seconds(preview_chart, 16.0)), "Continuous listening plays from the selected phrase through the final response")
	maker._update_preview(TouchChart.beat_to_seconds(preview_chart, 8.0) + 0.000001)
	check(maker.selected == 1 and maker.pattern_strip.selected == 1 and maker.show_spin.value == 8.0 and maker.timeline.phrase == maker.chart.phrases[1], "Continuous playback follows the active phrase in the strip, fields, and timeline")
	check(maker.clock.running and maker.clock._origin_usec == continuous_origin and maker.clock.player.stream == continuous_stream, "Following a new phrase keeps the same uninterrupted audio transport")
	check(maker.timeline.playhead >= 0.0 and maker.timeline.playhead < 0.001 and maker.preview_pad._glow[1] > 0.99 and maker.timeline.preview_highlights.has(0), "Continuous playback shows the next phrase's exact demo timing")
	check(maker.dirty == dirty_before_follow and maker.chart == preview_before_follow, "Automatic phrase selection never edits the chart or marks it dirty")
	maker._update_preview(TouchChart.beat_to_seconds(preview_chart, 12.0) + 0.000001)
	check(maker.selected == 1 and maker.preview_pad._glow[1] > 0.99 and "재현" in maker.preview_label.text, "Continuous playback keeps perfect timing outlines through the next response")
	maker.clock.start(audio, maker._preview_end + 1.0)
	maker._process(0.0)
	check(not maker.clock.running and not maker._preview_continuous and maker.timeline.preview_highlights.is_empty(), "Continuous listening stops and clears its state at the final response end")
	maker._listen(true)
	maker._update_preview(TouchChart.beat_to_seconds(preview_chart, 7.5))
	check(maker.selected == 1 and maker.preview_pad._glow.count(0.0) == 4, "Starting from a later phrase preserves its selection during the preceding phrase's lead-in")
	maker._select_phrase(0)
	check(not maker.clock.running and not maker._preview_continuous, "Manually selecting a phrase stops continuous listening")
	maker._listen()
	check(not maker._preview_continuous and is_equal_approx(maker._preview_end, preview_response + 4.0 * 60.0 / float(preview_chart.bpm)), "Single-phrase listening still ends at the selected response")
	maker._stop_preview()
	maker.chart.phrases.reverse()
	maker._refresh()
	maker._select_phrase(1)
	maker._listen(true)
	maker._update_preview(TouchChart.beat_to_seconds(preview_chart, 8.0) + 0.000001)
	check(maker.selected == 0 and maker.pattern_strip.thumbnails[0].button_pressed and maker.timeline.phrase == maker.chart.phrases[0] and maker.clock.running, "Continuous listening follows song time even when phrase list order differs")
	maker._stop_preview()
	maker.chart.phrases[0].show_beat = 10.0
	maker.chart.phrases[0].response_beat = 14.0
	maker._select_phrase(1)
	maker._listen(true)
	maker._update_preview(TouchChart.beat_to_seconds(preview_chart, 9.0))
	check(maker.clock.running and maker.selected == 1 and maker.timeline.playhead < 0.0 and maker.preview_pad._glow.count(0.0) == 4 and "대기" in maker.preview_label.text, "Continuous listening preserves musical gaps between phrases without inventing inputs")
	maker._update_preview(TouchChart.beat_to_seconds(preview_chart, 10.0) + 0.000001)
	check(maker.selected == 0 and maker.preview_pad._glow[1] > 0.99, "Continuous listening follows the next phrase after a gap")
	maker._toggle_note(0.5, 1)
	check(not maker.clock.running and not maker._preview_continuous and maker.timeline.preview_highlights.is_empty() and maker.preview_pad._glow.count(0.0) == 4, "Editing a note safely stops continuous listening and clears its timing display")
	maker._new_chart()
	check(not TouchChart.validate(maker.chart).is_empty() and TouchChart.validate(maker.chart, false).is_empty(), "Empty draft is listenable while saving and gameplay still require notes")
	maker._listen()
	await process_frame
	check(maker.clock.running and maker.chart.phrases[0].notes.is_empty(), "Listen works before the first note is authored")
	maker._update_preview(TouchChart.beat_to_seconds(maker.chart, 4.0))
	check(maker.timeline.preview_highlights.is_empty() and maker.preview_pad._glow.count(0.0) == 4, "An empty draft never invents timing outlines")
	maker._stop_preview()
	maker.length_spin.value = 0.25
	check(is_equal_approx(maker.pattern_strip.thumbnails[0].custom_minimum_size.x, PatternThumbnail.PIXELS_PER_BEAT * 0.25), "Short patterns keep the shared beat scale")
	maker._toggle_note(0.0, 0)
	var unnamed_path := "user://tests/unnamed_pattern.json"
	maker._save_to(unnamed_path)
	var unnamed := TouchChart.read(unnamed_path)
	check(str(unnamed.error).is_empty() and not unnamed.chart.phrases[0].has("name") and maker.pattern_strip.thumbnails.size() == 1 and maker.pattern_strip.thumbnails[0].button_pressed, "A new chart saves and reloads without pattern names")
	var silent_audio_path := "user://tests/silent_chart_tail.wav"
	var silent_chart_path := "user://tests/silent_chart_tail.json"
	check(silence(0.25).save_to_wav(silent_audio_path) == OK, "A short audio fixture is saved for silent-tail playback")
	var silent_chart := chart.duplicate(true)
	silent_chart.title = "Silent Chart Tail"
	silent_chart.audio = silent_audio_path
	silent_chart.bpm = 120.0
	silent_chart.offset_seconds = 0.0
	silent_chart.phrases = [{"show_beat": 2.0, "response_beat": 3.0, "length_beats": 1.0, "notes": [{"beat": 0.0, "cell": 2}]}]
	check(TouchChart.write(silent_chart, silent_chart_path, silent_chart_path).is_empty(), "A chart can be saved when its authored timeline outlasts the audio")
	var silent_track := SongLibrary.track(silent_chart_path)
	check(str(silent_track.error).is_empty() and silent_track.title == "Silent Chart Tail", "The song library accepts a chart that continues after its audio")
	maker._load_chart(silent_chart_path)
	maker._listen()
	check(maker.clock.running and not maker.clock.player.playing and maker.clock.seconds() >= 0.5, "Maker preview starts silently when the selected phrase begins after the audio")
	maker._update_preview(TouchChart.beat_to_seconds(silent_chart, 2.0))
	check(maker.preview_pad._glow[2] > 0.99 and maker.timeline.preview_highlights.has(0), "Maker demonstrates authored notes during the silent tail")
	maker._stop_preview()
	var silent_player := PlayerView.new()
	silent_player.theme = AppStyle.make_theme()
	silent_player.auto_mode = true
	silent_player.initial_path = silent_chart_path
	silent_player.initial_phrase = 0
	root.add_child(silent_player)
	await process_frame
	check(silent_player.chart_path == silent_chart_path and silent_player.session.notes.size() == 1, "Player loads a chart longer than its audio")
	silent_player._start()
	check(silent_player.clock.running and not silent_player.clock.player.playing and silent_player.clock.seconds() >= 0.5, "Selected-pattern play starts on the silent timeline beyond the audio")
	silent_player._pause()
	var silent_pause_time := silent_player.clock.seconds()
	silent_player._toggle()
	check(silent_player.state == "playing" and silent_player.clock.running and not silent_player.clock.player.playing and silent_player.clock.seconds() >= silent_pause_time, "Silent-tail play pauses and resumes without restarting audio")
	silent_player.clock.pause()
	silent_player.clock._paused_seconds = TouchChart.beat_to_seconds(silent_chart, 2.0)
	silent_player._process(0.0)
	check(silent_player.demo_pad._glow[2] > 0.0, "Player demonstration remains active without music")
	silent_player.clock._paused_seconds = TouchChart.beat_to_seconds(silent_chart, 3.0)
	silent_player._process(0.0)
	check(silent_player.session.counts.PERFECT == 1 and silent_player.session.counts.MISS == 0, "AUTO performs a response note in the silent tail")
	silent_player.clock._paused_seconds = TouchChart.beat_to_seconds(silent_chart, 4.0) + RhythmSession.WINDOW + 0.001
	silent_player._process(0.0)
	check(silent_player.state == "finished" and silent_player.progress.value == 100.0, "Silent-tail play finishes after the authored chart deadline")
	silent_player.queue_free()
	await process_frame
	var recent_preferences := "user://tests/recent_chart_maker.cfg"
	maker.preferences_path = recent_preferences
	maker.remember_recent_chart = true
	check(maker._load_chart(unnamed_path), "Maker opens a chart before remembering it")
	var recent_settings := ConfigFile.new()
	check(recent_settings.load(recent_preferences) == OK and str(recent_settings.get_value("chart_maker", "recent_chart_path", "")) == unnamed_path, "Maker stores the most recently opened chart path")
	maker.queue_free()
	await process_frame
	var restored_maker := ChartMaker.new()
	restored_maker.theme = AppStyle.make_theme()
	restored_maker.preferences_path = recent_preferences
	restored_maker.remember_recent_chart = true
	restored_maker.restore_recent_chart = true
	root.add_child(restored_maker)
	await process_frame
	check(restored_maker.chart_path == unnamed_path and restored_maker.chart.title == unnamed.chart.title, "A new maker session restores the most recent chart")
	restored_maker.queue_free()
	await process_frame
	recent_settings.set_value("chart_maker", "recent_chart_path", "user://tests/missing_recent_chart.json")
	recent_settings.save(recent_preferences)
	var fallback_maker := ChartMaker.new()
	fallback_maker.theme = AppStyle.make_theme()
	fallback_maker.preferences_path = recent_preferences
	fallback_maker.remember_recent_chart = true
	fallback_maker.restore_recent_chart = true
	root.add_child(fallback_maker)
	await process_frame
	check(fallback_maker.chart_path == TouchChart.SAMPLE and "기본 채보" in fallback_maker.status_label.text, "A missing recent chart safely falls back to the bundled sample")
	fallback_maker.queue_free()
	await process_frame
	# Allow the native audio mixer to release its last WAV playback reference.
	await create_timer(0.15).timeout
	for path in [destination, ending_path, relocated_path, snapshot_path, selected_path, unnamed_path, silent_audio_path, silent_chart_path, recent_preferences, "user://tests/maker_saved.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TouchPattern: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
