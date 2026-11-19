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


func touch(control: Control, position: Vector2) -> void:
	var point := control.get_global_transform_with_canvas() * position
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.pressed = pressed
		event.position = point
		Input.parse_input_event(event)
		await process_frame


func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await create_timer(0.42).timeout
	await process_frame


func _run() -> void:
	root.size = Vector2i(540, 960)
	var bundled := SongLibrary.track(SongLibrary.BUNDLED_TRACK)
	check(str(bundled.error).is_empty() and bundled.title == "The Descent Loop", "The real bundled song and authored chart load on a fresh install")
	check(OS.get_user_data_dir().replace("\\", "/").ends_with("/TouchPattern"), "Renaming RINNER preserves the existing charts and preferences directory")
	if FileAccess.file_exists(SongLibrary.SAVED_TRACK):
		check(SongLibrary.track_path() == SongLibrary.SAVED_TRACK, "The song selection uses the author's latest saved chart")
	var app: Control = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	check(app.current_view is FrontMenu, "A normal launch opens the title instead of the player")
	var front := app.current_view as FrontMenu
	if front == null:
		quit(1)
		return
	check(front.screen == "title" and front.title_logo.text == "RINNER" and front.title_touch.text.is_empty() and not front.library_view.visible, "The RINNER title has a whole-screen touch target without a visible Start button")
	check(front.track_titles.size() == 2 and front.track_titles[0].text == "The Descent Loop" and front.track_titles[1].text == "Electric Dreams" and front.library_view.find_children("*", "Button", true, false).size() == 3, "Song selection contains both playable songs and a back control")
	for index in range(SongLibrary.SONGS.size()):
		var bundled_song := SongLibrary.track(str(SongLibrary.SONGS[index].bundled))
		check(str(bundled_song.error).is_empty() and bundled_song.title == SongLibrary.SONGS[index].title, "Bundled chart and audio are playable for %s" % SongLibrary.SONGS[index].title)
		if FileAccess.file_exists(str(SongLibrary.SONGS[index].saved)):
			check(SongLibrary.track_path(index) == SongLibrary.SONGS[index].saved, "Latest saved chart is preferred for %s" % SongLibrary.SONGS[index].title)
	for dimensions in [Vector2(320, 568), Vector2(360, 800), Vector2(390, 844), Vector2(540, 960), Vector2(768, 1024), Vector2(1100, 900), Vector2(960, 540)]:
		front.size = dimensions
		await process_frame
		var bounds := Rect2(Vector2.ZERO, dimensions).grow(0.1)
		check(bounds.encloses(front.stage.get_global_rect()) and bounds.encloses(front.title_logo.get_global_rect()) and bounds.encloses(front.track_buttons[0].get_global_rect()) and bounds.encloses(front.track_buttons[1].get_global_rect()), "Title and both song cards fit %dx%d" % [dimensions.x, dimensions.y])
		check(front.back_button.size.y * front.stage.scale.y >= 44.0, "Navigation remains touchable at %dx%d" % [dimensions.x, dimensions.y])
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await touch(front.title_touch, Vector2(8, 8))
	await create_timer(0.42).timeout
	await process_frame
	check(front.screen == "songs" and front.library_view.visible and not front.title_touch.visible and not front.track_buttons[0].disabled and not front.track_buttons[1].disabled, "A touch away from the logo opens the song selection without also launching gameplay")
	await touch(front.track_buttons[0], front.track_buttons[0].size * 0.5)
	await process_frame
	check(app.current_view is PlayerView, "Touching the first song opens a real player")
	var player := app.current_view as PlayerView
	if player == null:
		app.queue_free()
		await process_frame
		quit(1)
		return
	check(player.chart.title == "The Descent Loop" and player.state == "playing" and player.clock.running and not player.menu.visible, "The selected song immediately plays without another Start screen")
	check(player.show_song_select and player.song_select_button.visible, "The pause menu provides a route back to song selection")
	player._pause()
	player.size = Vector2(320, 568)
	player._show_settings()
	await process_frame
	await process_frame
	var pause_card := player.menu_surface.find_children("*", "PanelContainer", true, false)[0] as Control
	var pause_bounds := Rect2(Vector2.ZERO, player.size).grow(0.1)
	check(pause_bounds.encloses(player.menu_scroller.get_global_rect()) and (pause_bounds.encloses(pause_card.get_global_rect()) or player.menu_scroller.get_v_scroll_bar().max_value > player.menu_scroller.get_v_scroll_bar().page), "The expanded pause menu fits or scrolls within a small phone")
	player.menu_scroller.ensure_control_visible(player.song_select_button)
	await process_frame
	await touch(player.song_select_button, player.song_select_button.size * 0.5)
	await process_frame
	await process_frame
	check(app.current_view is FrontMenu and not is_instance_valid(player), "Returning to song selection frees the player and its audio")
	front = app.current_view as FrontMenu
	check(front.screen == "songs" and not front._switching and not front.track_buttons[0].disabled and not front.track_buttons[1].disabled, "Returning preserves both playable song choices rather than reopening the title")
	await key(KEY_ESCAPE)
	check(front.screen == "title", "Escape returns from song selection to the title")
	await key(KEY_ENTER)
	check(front.screen == "songs" and app.current_view is FrontMenu, "Enter opens song selection without consuming the same key as a play action")
	await touch(front.track_buttons[1], front.track_buttons[1].size * 0.5)
	await process_frame
	player = app.current_view as PlayerView
	if player == null:
		quit(1)
		return
	check(player.chart.title == "Electric Dreams" and player.state == "playing" and player.clock.running and not player.menu.visible, "The second card starts Electric Dreams instead of replaying the first song")
	# Decode the actual MP3, play its last three seconds, and auto-judge the real
	# authored chart. This also exercises the natural outro-to-result transition.
	player.auto_mode = true
	player._start()
	var note_count := player.session.notes.size()
	var seek_time := maxf(0.0, player.stream.get_length() - 3.0)
	player.clock.start(player.stream, seek_time)
	player._last_time = seek_time
	var limit := Time.get_ticks_msec() + 7000
	while player.state == "playing" and Time.get_ticks_msec() < limit:
		await process_frame
	check(player.state == "finished" and player.session.counts.PERFECT == note_count and player.session.score == note_count * 1000 and player.session.counts.MISS == 0, "Electric Dreams decodes, judges all authored notes, and plays through its outro to results")
	check(player.menu_results.visible and player.song_select_button.visible, "Results retain the song selection route")
	player.size = Vector2(320, 568)
	player._show_settings()
	await process_frame
	await process_frame
	var result_card := player.menu_surface.find_children("*", "PanelContainer", true, false)[0] as Control
	var result_bounds := Rect2(Vector2.ZERO, player.size).grow(0.1)
	check(result_bounds.encloses(player.menu_scroller.get_global_rect()) and (result_bounds.encloses(result_card.get_global_rect()) or player.menu_scroller.get_v_scroll_bar().max_value > player.menu_scroller.get_v_scroll_bar().page), "The expanded result menu fits or scrolls within a small phone")
	player.menu_scroller.ensure_control_visible(player.song_select_button)
	await process_frame
	await touch(player.song_select_button, player.song_select_button.size * 0.5)
	await process_frame
	await process_frame
	front = app.current_view as FrontMenu
	check(front != null and front.track_buttons.size() == 2 and front.screen == "songs", "Results return to the complete two-song selection")
	if front != null:
		front.track_buttons[1].grab_focus()
		await process_frame
		await key(KEY_ENTER)
		check(app.current_view is PlayerView and app.current_view.chart.title == "Electric Dreams", "Keyboard activation of the second card launches the second song")
	app.queue_free()
	await process_frame
	var invalid := FrontMenu.new()
	invalid.theme = AppStyle.make_theme()
	invalid.initial_chart = "res://missing-song-for-test.json"
	root.add_child(invalid)
	invalid.size = Vector2(540, 960)
	invalid.show_library(false)
	check(not str(invalid.tracks[0].error).is_empty() and invalid.track_buttons[0].disabled, "A missing song shows an error instead of silently launching a different track")
	invalid.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Front flow: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
