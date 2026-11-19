extends SceneTree

var checks := 0
var failures: Array[String] = []
var preferences := "user://tests/detailed_judgment_%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func make_player() -> PlayerView:
	var player := PlayerView.new()
	player.theme = AppStyle.make_theme()
	player.preferences_path = preferences
	player.note_sounds.preferences_path = preferences
	player.show_song_select = true
	root.add_child(player)
	player.size = Vector2(540, 960)
	player.set_process(false)
	player.clock.player.volume_db = -70.0
	player.note_sounds.set_volume_percent(0.0, false)
	return player


func _run() -> void:
	root.size = Vector2i(540, 960)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(preferences.get_base_dir()))
	var settings := ConfigFile.new()
	settings.set_value("timing", "offset_ms", 37.0)
	settings.set_value("note_feedback", "volume_percent", 40.0)
	settings.save(preferences)
	var player := make_player()
	await process_frame
	check(not player.detailed_judgment and not player.detailed_judgment_check.button_pressed and not player.timing_readout.visible, "Detailed timing is off by default and leaves gameplay clean")
	player._judged("PERFECT", 0, 23.4)
	check(not player.timing_readout.visible and player.input_pad.feedback.kinds[0] == "PERFECT", "Disabling details preserves normal tile feedback")
	player._start()
	player.clock.pause()
	player._pause()
	player._show_settings()
	await process_frame
	await process_frame
	player.menu_scroller.ensure_control_visible(player.detailed_judgment_check)
	await process_frame
	var point := player.detailed_judgment_check.get_global_transform_with_canvas() * (player.detailed_judgment_check.size * 0.5)
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.pressed = pressed
		touch.position = point
		Input.parse_input_event(touch)
		await process_frame
	check(player.detailed_judgment and player.detailed_judgment_check.button_pressed and player.state == "paused", "Touching the option enables details without resuming the game")
	settings.load(preferences)
	check(settings.get_value("display", "detailed_judgment", false) == true and settings.get_value("timing", "offset_ms") == 37.0 and settings.get_value("note_feedback", "volume_percent") == 40.0, "The option persists without replacing audio or timing preferences")
	player._toggle()
	player.clock.pause()
	var first := float(player.session.notes[0].time)
	player.clock._paused_seconds = first + player.offset_ms / 1000.0 + 0.0234
	player._press(int(player.session.notes[0].cell))
	check(player.session.score == 1000 and player.session.counts.PERFECT == 1, "Displaying details retains the original judgment and score")
	check(player.timing_readout.visible and player.timing_readout.value_label.text == "+23.4" and player.timing_readout.direction_label.text == "LATE" and absf(player.timing_readout.error_ms - 23.4) < 0.000001, "A late hit displays the compensated judgment offset with a plus sign")
	var second := float(player.session.notes[1].time)
	player.clock._paused_seconds = second + player.offset_ms / 1000.0 - 0.0724
	player._press(int(player.session.notes[1].cell))
	check(player.session.score == 1700 and player.session.counts.GOOD == 1 and player.timing_readout.value_label.text == "−72.4" and player.timing_readout.direction_label.text == "EARLY", "An early hit displays a minus sign and retains GOOD scoring")
	var readout := player.timing_readout.get_global_rect()
	var demo := player.demo_pad.get_global_rect()
	check(readout.end.y <= demo.position.y and is_equal_approx(readout.get_center().x, demo.get_center().x), "The readout sits centered above the demo grid")
	check(player.timing_readout.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The feedback layer cannot intercept input")
	player._pause()
	var alpha := player.timing_readout.modulate.a
	await create_timer(0.85).timeout
	check(player.timing_readout.visible and is_equal_approx(player.timing_readout.modulate.a, alpha), "Pausing also freezes the current timing readout")
	player._toggle()
	await create_timer(0.9).timeout
	check(not player.timing_readout.visible, "The readout fades away after resuming")
	player._judged("PERFECT", 0, 10.0)
	await create_timer(0.35).timeout
	player._judged("GOOD", 1, 72.4)
	await create_timer(0.5).timeout
	check(player.timing_readout.visible and player.timing_readout.value_label.text == "+72.4", "A new input replaces the old readout without an older fade hiding it")
	player._judged("PERFECT", 0, -0.001)
	check(player.timing_readout.value_label.text == "+0.0" and player.timing_readout.direction_label.text == "ON TIME", "Near-zero errors do not show a misleading negative zero")
	for kind in ["MISS", "WRONG"]:
		player._judged(kind, 0, 0.0)
		check(player.timing_readout.value_label.text == "—" and player.timing_readout.direction_label.text == "NO TIMING" and not player.timing_readout.has_timing, "%s does not invent a zero-ms hit or repeat a grade outside the tile" % kind)
	player.detailed_judgment_check.button_pressed = false
	check(not player.detailed_judgment and not player.timing_readout.visible, "Turning the option off clears the current detail immediately")
	player._judged("OK", 0, 123.4)
	check(not player.timing_readout.visible, "Further judgments stay hidden after disabling details")
	player.detailed_judgment_check.button_pressed = true
	player._judged("PERFECT", 0, 25.0)
	player._start()
	check(player.detailed_judgment and not player.timing_readout.visible and player.timing_readout.value_label.text.is_empty(), "Restart clears the old error while keeping the option")
	player._judged("PERFECT", 0, 25.0)
	player._finish()
	check(not player.timing_readout.visible and player.menu_results.visible, "Finishing clears detail feedback before results")
	player.queue_free()
	await process_frame
	player = make_player()
	check(player.detailed_judgment and player.detailed_judgment_check.button_pressed and not player.timing_readout.visible, "A new player restores the saved option without stale feedback")
	player._pause()
	player._show_settings()
	player.size = Vector2(320, 568)
	await process_frame
	await process_frame
	player.menu_scroller.scroll_vertical = int(player.menu_scroller.get_v_scroll_bar().max_value)
	await process_frame
	check(player.menu_scroller.get_global_rect().encloses(player.song_select_button.get_global_rect()), "A small phone can scroll to the song selection control")
	player._show_menu()
	check(player.menu_scroller.scroll_vertical == 0, "Opening the menu resets its scroll position")
	player.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preferences))
	print("Detailed judgment: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
