extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func at_beat(player: PlayerView, beat: float) -> void:
	player.clock._paused_seconds = TouchChart.beat_to_seconds(player.chart, beat)
	player._process(0.0)


func mixed_chart() -> Dictionary:
	var chart: Dictionary = TouchChart.read(TouchChart.SAMPLE).chart.duplicate(true)
	chart.title = "Four and Two Beats"
	chart.audio = TouchChart.audio_path(chart, TouchChart.SAMPLE)
	chart.bpm = 120.0
	chart.offset_seconds = 0.125
	chart.phrases = [
		{"show_beat": 4.0, "response_beat": 8.0, "length_beats": 4.0, "notes": [{"beat": 0.0, "cell": 0}, {"beat": 3.0, "cell": 3}]},
		{"show_beat": 12.0, "response_beat": 14.0, "length_beats": 2.0, "notes": [{"beat": 0.0, "cell": 1}, {"beat": 1.5, "cell": 3}]},
		{"show_beat": 16.0, "response_beat": 18.0, "length_beats": 2.0, "notes": [{"beat": 0.0, "cell": 2}, {"beat": 0.75, "cell": 0}]},
		{"show_beat": 20.0, "response_beat": 24.0, "length_beats": 4.0, "notes": [{"beat": 0.0, "cell": 0}, {"beat": 3.0, "cell": 3}]}
	]
	return chart


func _run() -> void:
	root.size = Vector2i(540, 960)
	var chart := mixed_chart()
	check(TouchChart.validate(chart).is_empty(), "A song can mix four-beat and two-beat phrases")
	var session := RhythmSession.new(chart)
	for example in [[12.0, "demo", 1], [13.999, "demo", 1], [14.0, "response", 1], [16.0, "demo", 2], [18.0, "response", 2], [20.0, "demo", 3]]:
		var phase := session.phase_at(TouchChart.beat_to_seconds(chart, float(example[0])))
		check(phase.kind == example[1] and phase.index == example[2], "Mixed pattern boundary at beat %s has the correct phase" % str(example[0]))
	var judge := RhythmSession.new(chart)
	var first_two := TouchChart.beat_to_seconds(chart, 14.0)
	check(judge.hit(1, first_two - RhythmSession.WINDOW) == "OK", "A two-beat pattern retains the original early judgment window")
	var auto_session := RhythmSession.new(chart)
	auto_session.auto_play(1000.0)
	check(auto_session.counts.PERFECT == 8 and auto_session.counts.MISS == 0 and auto_session.score == 8000, "Mixed-length patterns retain the same scoring and AUTO timing")
	var fixture_path := "user://tests/two_beat_%d.json" % OS.get_process_id()
	check(TouchChart.write(chart, TouchChart.SAMPLE, fixture_path).is_empty(), "The mixed chart saves using the existing format")
	var player := PlayerView.new()
	player.theme = AppStyle.make_theme()
	player.preferences_path = "user://tests/two_beat_preferences.cfg"
	player.initial_path = fixture_path
	root.add_child(player)
	player.apply_gui_layout(GuiLayout.new())
	player.size = Vector2(540, 960)
	await process_frame
	player._start()
	player.set_process(false)
	player.clock.pause()
	var warning := player.transition_warning
	var left_tile := player.demo_pad._tiles[0].material as ShaderMaterial
	var right_tile := player.demo_pad._tiles[1].material as ShaderMaterial
	at_beat(player, 9.999)
	check(not warning.visible, "The warning stays hidden before the last two response beats")
	at_beat(player, 10.0)
	check(warning.visible and warning.self_modulate.a < 1.0 and player.input_pad.emphasis, "The four-to-two warning begins flickering on the third response beat")
	player.detailed_judgment = true
	player._judged("GOOD", 1, 34.0)
	check(not player.timing_readout.get_global_rect().intersects(warning.get_global_rect()) and warning.get_rect().end.y < player.demo_pad.position.y, "Live timing feedback and the warning both fit above the demo grid")
	player._pause()
	check(not warning.visible, "Pause hides the warning")
	check(left_tile.get_shader_parameter("warning_light") == Color.TRANSPARENT, "Pausing clears the reflection along with the warning")
	player._toggle()
	check(warning.visible, "Resume restores the warning from the song clock")
	check(left_tile.get_shader_parameter("warning_light") == warning.self_modulate, "Resume restores the reflection at the current flicker brightness")
	player.clock.pause()
	at_beat(player, 10.001)
	var onset_light := warning.self_modulate.a
	for beat in [10.4, 10.5, 10.6]:
		at_beat(player, beat)
		check(warning.visible and warning.self_modulate.is_equal_approx(TransitionWarning.ORANGE), "The orange warning holds for the middle 0.2 beats")
	check(left_tile.get_shader_parameter("warning_light") == TransitionWarning.ORANGE and right_tile.get_shader_parameter("warning_light") == TransitionWarning.ORANGE, "The two upper demo tiles reflect the orange warning together")
	check(player.demo_pad.accent == GameGrid.VIOLET, "A four-beat response keeps the ordinary demonstration color")
	at_beat(player, 10.999)
	check(warning.visible and is_equal_approx(warning.self_modulate.a, onset_light), "The orange warning ends at the mirrored ignition brightness")
	player.demo_pad.clear()
	at_beat(player, 11.0)
	check(not warning.visible, "The orange warning turns off a full beat before the short demo")
	check(right_tile.get_shader_parameter("warning_light") == Color.TRANSPARENT, "The reflected light goes dark at the start of the gap")
	check(player.demo_pad.accent == GameGrid.VIOLET and player.demo_pad._glow.count(0.0) == 4 and not player.demo_pad.emphasis, "One beat before a short phrase, the upper grid has no early color, activation, or note flash")
	check(player.input_pad.accent == GameGrid.TEAL and player.input_pad.emphasis, "The current response stays active until the actual phase boundary")
	at_beat(player, 12.0)
	check(not warning.visible and player.timing_readout.position.x == 140.0, "The warning clears at the next demo downbeat and frees the timing readout space")
	check(player.demo_pad.accent == GameGrid.CORAL and player.demo_pad._hit_colors[1] == GameGrid.CORAL and player.demo_pad._glow[1] == 1.0, "The first two-beat note flashes red immediately at the boundary")
	check(player.demo_pad.emphasis and not player.input_pad.emphasis, "Two-beat demonstrations activate only the upper grid")
	check(not player.stage.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text in ["2박", "다음 2박"]), "Gameplay shows no short-phrase text")
	check(left_tile.get_shader_parameter("accent") == GameGrid.CORAL, "Runtime phrase color reaches the actual tile shader")
	await player.hud._transition.finished
	check(player.hud.accent.is_equal_approx(GameGrid.CORAL) and player.decor.accent.is_equal_approx(GameGrid.CORAL), "The demonstration HUD and stage accents follow the red phrase")
	at_beat(player, 14.0)
	check(player.input_pad.accent == GameGrid.TEAL and player.input_pad.emphasis and not player.demo_pad.emphasis, "A two-beat response uses the same teal input grid")
	var before_score := player.session.score
	player._press(1)
	check(player.session.score == before_score + 1000 and player.input_pad.feedback.kinds[1] == "PERFECT", "Actual manual input scores normally in a two-beat response")
	await player.hud._transition.finished
	check(player.hud.accent.is_equal_approx(GameGrid.TEAL) and player.decor.accent.is_equal_approx(GameGrid.TEAL), "Response HUD and decorations remain teal")
	at_beat(player, 15.0)
	check(not warning.visible, "Equal two-beat lengths have no warning")
	check(player.input_pad.emphasis and not player.demo_pad.emphasis, "A following two-beat phrase does not activate the upper grid early")
	at_beat(player, 16.0)
	check(player.demo_pad._hit_colors[2] == GameGrid.CORAL and player.demo_pad._glow[2] == 1.0, "The next two-beat phrase starts without a gap or tempo change")
	player._pause()
	var paused_time := player.clock.seconds()
	player.demo_pad._process(1.0)
	check(player.clock.seconds() == paused_time and player.demo_pad._glow[2] == 1.0, "Pausing freezes two-beat notes")
	player._toggle()
	player.clock.pause()
	at_beat(player, 18.0)
	check(warning.visible and warning.self_modulate.a < 1.0, "A two-to-four warning starts on the first response beat")
	at_beat(player, 18.5)
	check(warning.visible and warning.self_modulate.is_equal_approx(GameGrid.VIOLET), "The four-beat warning holds steady in violet")
	check(left_tile.get_shader_parameter("warning_light") == GameGrid.VIOLET and right_tile.get_shader_parameter("warning_light") == GameGrid.VIOLET, "The reverse transition reflects violet on both upper tiles")
	at_beat(player, 19.0)
	check(not warning.visible and player.input_pad.emphasis, "The gap begins on the last response beat in the reverse direction")
	at_beat(player, 19.999)
	check(not warning.visible, "The violet neon stays off until the demo downbeat")
	at_beat(player, 20.0)
	check(not warning.visible, "Four-beat demo also hides the warning at its first beat")
	check(player.demo_pad.accent == GameGrid.VIOLET and player.demo_pad._hit_colors[0] == GameGrid.VIOLET, "Returning to four beats restores purple")
	player._set_phase("demo", 1)
	player._set_phase("demo", 0)
	check(player.demo_pad.accent == GameGrid.VIOLET, "A phrase change updates color even if the phase kind stays demo")
	player._start()
	player.clock.pause()
	check(player.demo_pad.accent == GameGrid.VIOLET and player.session.score == 0, "Restart resets short-phrase visuals along with the score")
	player._load_chart(fixture_path, 1)
	player._start()
	player.clock.pause()
	check(player.demo_pad.accent == GameGrid.VIOLET and not player.demo_pad.emphasis and player.session.notes.size() == 6 and player.session.counts.MISS == 0 and player.demo_pad._glow.count(0.0) == 4, "Selected-pattern testing begins quietly and excludes earlier notes")
	player.auto_mode = true
	player._start()
	player.clock.pause()
	for beat in [12.0, 14.0, 15.5, 16.0, 18.0, 18.75, 20.0, 24.0, 27.0]:
		at_beat(player, beat)
	check(player.session.counts.PERFECT == 6 and player.session.counts.MISS == 0 and not player.input_pad.interactive, "AUTO plays all remaining mixed-length notes with the original timing")
	check(not warning.visible, "The final response has no warning without a following demonstration")
	# A valid chart can be out of file order and leave a rest before the next demo.
	var spaced := mixed_chart()
	spaced.phrases = [spaced.phrases[1], spaced.phrases[0]]
	spaced.phrases[0].show_beat = 13.0
	spaced.phrases[0].response_beat = 15.0
	player.session = RhythmSession.new(spaced)
	player._update_phase(TouchChart.beat_to_seconds(spaced, 10.5))
	check(not warning.visible, "A rest moves the warning window with the upcoming demo")
	player._update_phase(TouchChart.beat_to_seconds(spaced, 11.001))
	var spaced_onset_light := warning.self_modulate.a
	player._update_phase(TouchChart.beat_to_seconds(spaced, 11.5))
	check(warning.visible and warning.self_modulate.is_equal_approx(TransitionWarning.ORANGE), "The warning uses chronological order rather than JSON order")
	player._update_phase(TouchChart.beat_to_seconds(spaced, 11.999))
	check(warning.visible and is_equal_approx(warning.self_modulate.a, spaced_onset_light), "A shortened warning also mirrors ignition before the rest")
	player._update_phase(TouchChart.beat_to_seconds(spaced, 12.0))
	check(not warning.visible, "There is no lingering warning during a rest")
	var one_beat := mixed_chart()
	one_beat.phrases = [one_beat.phrases[0],
		{"show_beat": 12.0, "response_beat": 13.0, "length_beats": 1.0, "notes": [{"beat": 0.0, "cell": 1}]},
		{"show_beat": 14.0, "response_beat": 16.0, "length_beats": 2.0, "notes": [{"beat": 0.0, "cell": 2}]}]
	check(TouchChart.write(one_beat, TouchChart.SAMPLE, fixture_path).is_empty(), "One-beat notes use the same chart format")
	player._load_chart(fixture_path)
	player._start()
	player.clock.pause()
	at_beat(player, 10.5)
	check(warning.visible and warning.self_modulate == Color("#d9698b"), "The next one-beat phrase is announced in raspberry red")
	at_beat(player, 12.0)
	check(not warning.visible and player.demo_pad._hit_colors[1] == Color("#d9698b") and player.demo_pad._glow[1] == 1.0, "The very first note of a one-beat demo flashes raspberry")
	var custom := GuiLayout.new()
	custom.one_beat_color = Color("#ba5349")
	custom.two_beat_color = Color("#ed9d62")
	custom.warning_gap_beats = 0.25
	player.gui_layout_path = "user://tests/one_beat_layout_%d.tres" % OS.get_process_id()
	check(ResourceSaver.save(custom, player.gui_layout_path) == OK, "Custom beat colors save to a layout")
	player._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(player.demo_pad.accent.is_equal_approx(custom.one_beat_color), "Focus reload refreshes the current one-beat phase immediately")
	at_beat(player, 13.375)
	check(warning.visible and warning.self_modulate.is_equal_approx(custom.two_beat_color) and player.input_pad.emphasis, "The short response warns in the saved two-beat color")
	at_beat(player, 13.75)
	check(not warning.visible, "One-beat responses leave exactly the configured gap")
	at_beat(player, 14.0)
	check(not warning.visible and player.demo_pad._hit_colors[2].is_equal_approx(custom.two_beat_color), "The next demo uses its saved color at its first note")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.gui_layout_path))
	player.queue_free()
	await process_frame
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	root.add_child(maker)
	await process_frame
	check(not maker.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "response_spin"), "The maker no longer exposes a separate response-start input")
	maker._new_chart()
	maker._toggle_note(0.0, 1)
	maker.length_spin.value = 2.0
	check(is_equal_approx(float(maker.chart.phrases[0].response_beat), 6.0), "Setting length to two beats derives response start from show start plus length")
	maker.show_spin.value = 10.0
	check(is_equal_approx(float(maker.chart.phrases[0].response_beat), 12.0), "Editing demonstration start automatically moves response start")
	maker._listen()
	check(maker.clock.running and is_equal_approx(maker._preview_end, TouchChart.beat_to_seconds(maker.chart, 14.0)), "Preview uses the derived two-beat response and its end")
	maker._stop_preview()
	maker._toggle_audio_end()
	check(is_equal_approx(float(maker.chart.audio_end_beat), 14.0), "The authored audio ending uses the derived response end")
	maker.length_spin.value = 3.0
	check(is_equal_approx(float(maker.chart.phrases[0].response_beat), 13.0) and is_equal_approx(float(maker.chart.audio_end_beat), 16.0), "Length edits move response start and the selected audio-ending marker together")
	maker.show_spin.value = 12.0
	check(is_equal_approx(float(maker.chart.phrases[0].response_beat), 15.0) and is_equal_approx(float(maker.chart.audio_end_beat), 18.0), "Start edits keep the audio ending attached to the same pattern")
	maker._toggle_note(2.5, 3)
	maker.length_spin.value = 2.0
	check(is_equal_approx(float(maker.chart.phrases[0].length_beats), 3.0) and is_equal_approx(float(maker.chart.phrases[0].response_beat), 15.0) and is_equal_approx(float(maker.chart.audio_end_beat), 18.0), "Rejected shortening preserves notes, derived response, and the audio ending")
	maker._toggle_note(2.5, 3)
	maker.length_spin.value = 2.0
	check(is_equal_approx(float(maker.chart.phrases[0].response_beat), 14.0) and is_equal_approx(float(maker.chart.audio_end_beat), 16.0), "Shortening succeeds after removing the out-of-range note")
	var saved_path := "user://tests/two_beat_maker_%d.json" % OS.get_process_id()
	maker._save_to(saved_path)
	var saved := TouchChart.read(saved_path)
	check(str(saved.error).is_empty() and is_equal_approx(float(saved.chart.phrases[0].response_beat), float(saved.chart.phrases[0].show_beat) + float(saved.chart.phrases[0].length_beats)), "Derived response start survives saving and reloading in the existing chart format")
	maker._add_phrase()
	check(is_equal_approx(float(maker.chart.phrases[1].show_beat), 16.0) and is_equal_approx(float(maker.chart.phrases[1].response_beat), 20.0), "Adding a pattern starts after the derived previous response end")
	maker.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	for path in [fixture_path, saved_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Two-beat patterns: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
