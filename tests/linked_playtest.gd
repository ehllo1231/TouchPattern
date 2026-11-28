extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func at_beat(maker: ChartMaker, beat: float) -> void:
	maker.clock._begin_silent_tail(TouchChart.beat_to_seconds(maker.chart, beat))
	maker._process(0.0)


func run() -> void:
	root.size = Vector2i(1100, 900)
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	root.add_child(maker)
	maker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var window := maker.playtest_window
	var game := maker.playtest
	check(window.visible and game.get_window() == window and not maker.clock.running and game.state == "ready", "Opening the maker also opens an idle playtest window")
	if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		check(not window.is_embedded() and window.get_window_id() != root.get_window_id(), "The playtest is a separate native window")
		var work := DisplayServer.screen_get_usable_rect(root.current_screen)
		var editor_rect := Rect2i(root.position, root.size)
		var game_rect := Rect2i(window.position, window.size)
		if work.size.x >= editor_rect.size.x + game_rect.size.x + 48:
			check(work.encloses(game_rect) and not editor_rect.intersects(game_rect), "The companion opens alongside the editor on its monitor")
	check(game.clock == maker.clock and not game.is_processing(), "One audio clock drives both windows")
	var claps: Array[StringName] = []
	game.note_sounds.played.connect(func(source: StringName) -> void: claps.append(source))
	# Use an unsaved note and out-of-order sections so file reloads and index-based starts fail visibly.
	maker._new_chart()
	var later := {"show_beat": 12.0, "response_beat": 14.0, "length_beats": 2.0, "notes": [{"beat": 0.0, "cell": 3}]}
	maker.chart.phrases = [later, maker.chart.phrases[0]]
	maker.selected = 1
	maker._refresh()
	maker._toggle_note(0, 1)
	maker.playtest.offset_ms = 0.0
	maker._listen()
	check(maker.chart_path.is_empty() and game.state == "playing" and game.session == maker._preview_session and game.session.notes.size() == 1, "Section listening starts the visible game from the unsaved selected section")
	at_beat(maker, 4.0)
	check(game.demo_pad._glow[1] == 1.0 and maker.preview_pad._glow[1] > 0.9 and game._visual_phase == "demo", "The same unsaved note flashes in both views")
	at_beat(maker, 8.0)
	var key := InputEventKey.new()
	key.keycode = KEY_I
	key.pressed = true
	window.push_input(key)
	check(game.session.counts.PERFECT == 1 and game.input_pad.feedback.kinds[1] == "PERFECT", "Manual keyboard input in the second window is judged against the editor clock")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(maker.clock.running and game.state == "playing", "Changing focus cannot independently pause the playtest")
	maker._stop_preview()
	var frozen := game.input_pad._glow.duplicate()
	game.input_pad._process(0.5)
	check(window.visible and not maker.clock.running and not game.input_pad.interactive and game.input_pad._glow == frozen, "Stop freezes the visible playtest and disables input")
	window.close_requested.emit()
	check(not window.visible and maker.is_inside_tree(), "Closing the companion leaves the editor open")
	maker._select_phrase(0)
	maker.auto_mode_check.button_pressed = true
	maker._listen(true)
	check(window.visible and game.session.notes.size() == 1 and game.session.score == 0 and game.hud.auto_badge.visible, "Starting elsewhere reopens the same window and resets the run")
	at_beat(maker, 12.0)
	check(game._visual_phrase == 0 and game.demo_pad._glow[3] == 1.0 and maker.selected == 0, "A new start uses the newly selected section")
	at_beat(maker, 14.0)
	check(game.session.counts.PERFECT == 1 and not game.input_pad.interactive, "AUTO judges the current response at its authored time")
	at_beat(maker, 16.1)
	check(not maker.clock.running and game.state == "paused" and window.visible and game.progress.value == 100.0, "The editor and playtest stop at the same natural endpoint")
	maker._select_phrase(1)
	maker._listen(true)
	at_beat(maker, 12.0)
	check(game.session.notes.size() == 2 and game.session.counts.PERFECT == 1 and game._visual_phrase == maker.selected and maker.selected == 0, "Continuous listening follows the next section without resetting the score")
	maker.auto_mode_check.button_pressed = false
	check(game.input_pad.interactive and not game.hud.auto_badge.visible and maker.clock.running, "AUTO can change during listening without moving the transport")
	maker._toggle_note(0.5, 2)
	check(not maker.clock.running and game.state == "paused", "Editing a note stops both views")
	maker._new_chart()
	maker.bpm_spin.value = 240
	maker.show_spin.value = 0
	maker.length_spin.value = 1
	maker._toggle_note(0.0, 2)
	maker.auto_mode_check.button_pressed = true
	maker._listen()
	var deadline := Time.get_ticks_msec() + 4000
	while maker.clock.running and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not maker.clock.running and window.visible and game.session.counts.PERFECT == 1, "Real audio playback advances AUTO and stops both views at the selected boundary")
	check(claps.is_empty(), "The linked game does not play a second copy of the editor's note sounds")
	maker.queue_free()
	await process_frame
	check(not is_instance_valid(window), "Closing the maker releases its companion")
	await create_timer(0.2).timeout
	print("Linked playtest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
