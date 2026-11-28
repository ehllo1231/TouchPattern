extends SceneTree

var checks := 0
var failures: Array[String] = []
var layout_path := "user://tests/gui_layout_%d.tres" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func _run() -> void:
	root.size = Vector2i(1180, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(layout_path.get_base_dir()))
	var editor := GuiEditor.new()
	editor.layout_path = layout_path
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	check(editor.player_preview.preview_mode and editor.player_preview.chart.is_empty() and not editor.player_preview.clock.running and not editor.player_preview.input_pad.interactive, "Preview uses the real player UI without starting a song or accepting gameplay input")
	check(not editor.unsaved and editor.save_button.disabled, "A fresh layout starts at the saved defaults")
	editor.size_sliders.demo.value = 300
	editor.size_spins.play.value = 180
	check(editor.player_preview.demo_pad.size == Vector2(300, 300) and editor.player_preview.input_pad.size == Vector2(180, 180), "Slider and numeric input independently resize the real preview grids")
	check(editor.size_spins.demo.value == 300 and editor.size_sliders.play.value == 180 and editor.unsaved, "Both input styles stay synchronized and mark the edit as unsaved")
	check(not FileAccess.file_exists(layout_path), "Live preview leaves the saved layout untouched until Save")
	editor.save_button.pressed.emit()
	var saved := GuiLayout.read(layout_path)
	check(saved.demo_grid_size == 300 and saved.play_grid_size == 180 and not editor.unsaved, "Save persists both grid sizes and clears the unsaved state")
	var player := PlayerView.new()
	player.gui_layout_path = layout_path
	player.theme = AppStyle.make_theme()
	root.add_child(player)
	player.size = Vector2(540, 960)
	player.note_sounds.set_volume_percent(0.0, false)
	await process_frame
	check(player.demo_pad.size == editor.player_preview.demo_pad.size and player.input_pad.size == editor.player_preview.input_pad.size, "A real game loads exactly the saved preview geometry")
	player.hide()
	editor.size_spins.demo.value = 180
	editor.size_sliders.play.value = 300
	await process_frame
	editor.size_spins.play.get_line_edit().grab_focus()
	await process_frame
	editor.size_spins.play.get_line_edit().text = "320"
	check(player.demo_pad.size.x == 300 and player.input_pad.size.x == 180, "Unsaved editor changes do not alter a running game")
	# Send the actual keyboard shortcut; preview children must not consume it.
	for pressed in [true, false]:
		var shortcut := InputEventKey.new()
		shortcut.keycode = KEY_S
		shortcut.ctrl_pressed = true
		shortcut.pressed = pressed
		Input.parse_input_event(shortcut)
		await process_frame
	check(not editor.unsaved and GuiLayout.read(layout_path).play_grid_size == 320, "Ctrl+S saves while the preview is present")
	player._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(player.demo_pad.size.x == 180 and player.input_pad.size.x == 320, "Returning to the game reloads a saved layout without restarting")
	player.show()
	for dimensions in [Vector2(320, 568), Vector2(360, 800), Vector2(390, 844), Vector2(540, 960), Vector2(768, 1024), Vector2(1100, 900), Vector2(960, 540)]:
		player.size = dimensions
		await process_frame
		var bounds := Rect2(Vector2.ZERO, dimensions).grow(0.1)
		check(bounds.encloses(player.demo_pad.get_global_rect()) and bounds.encloses(player.input_pad.get_global_rect()), "Custom grids fit %dx%d" % [dimensions.x, dimensions.y])
		check(player.input_pad.cell_rect(0).size.x * player.stage.scale.x >= 44.0, "Custom gameplay touch targets fit %dx%d" % [dimensions.x, dimensions.y])
	# At the maximum demo size, detailed feedback must still fit below the HUD.
	var maximum := GuiLayout.new()
	maximum.demo_grid_size = 320
	maximum.play_grid_size = 180
	player.apply_gui_layout(maximum)
	check(player.timing_readout.position.y >= player.hud.progress.get_rect().end.y and player.timing_readout.get_rect().end.y <= player.demo_pad.position.y, "Detailed timing stays between the HUD and the largest demo grid")
	check(not player.demo_pad.get_rect().intersects(player.input_pad.get_rect()), "Independent grid sizes leave the two grids separate")
	player.apply_gui_layout(saved)
	root.size = Vector2i(540, 960)
	player.size = Vector2(540, 960)
	await process_frame
	player._start()
	player.set_process(false)
	player.clock.pause()
	player.offset_ms = 0.0
	var note: Dictionary = player.session.notes[0]
	player.clock._paused_seconds = float(note.time)
	var point := player.input_pad.get_global_transform_with_canvas() * player.input_pad.cell_rect(int(note.cell)).get_center()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame
	check(player.session.counts.PERFECT == 1 and player.session.counts.MISS == 0, "A resized grid maps a real touch to exactly one correct judgment")
	player.queue_free()
	await process_frame
	root.size = Vector2i(1180, 900)
	await process_frame
	editor.screen_select.select(1)
	editor.screen_select.item_selected.emit(1)
	check(editor.title_preview.visible and not editor.player_preview.visible and not editor.game_settings.visible, "The start screen selector shows the real title and hides game controls")
	for pressed in [true, false]:
		var space := InputEventKey.new()
		space.keycode = KEY_SPACE
		space.pressed = pressed
		Input.parse_input_event(space)
		await process_frame
	check(editor.title_preview.screen == "title" and editor.player_preview.state == "ready", "Preview keyboard input cannot navigate the title or start gameplay")
	for index in range(GuiEditor.PREVIEW_SIZES.size()):
		editor.size_select.select(index)
		editor.size_select.item_selected.emit(index)
		await process_frame
		check(editor.preview_viewport.size == GuiEditor.PREVIEW_SIZES[index] and Rect2(Vector2.ZERO, editor.preview_area.size).grow(0.1).encloses(editor.preview_frame.get_rect()), "Preview preserves the chosen resolution and fits preset %d" % index)
	editor.reset_button.pressed.emit()
	check(editor.layout.demo_grid_size == 260 and editor.layout.play_grid_size == 260 and editor.unsaved, "Reset restores defaults in the preview and waits for Save")
	check(GuiLayout.read(layout_path).play_grid_size == 320, "Reset does not overwrite the saved layout immediately")
	editor._save()
	var reopened := GuiEditor.new()
	reopened.layout_path = layout_path
	root.add_child(reopened)
	await process_frame
	check(reopened.layout.demo_grid_size == 260 and reopened.layout.play_grid_size == 260 and not reopened.unsaved, "Reopening the editor restores the latest saved values")
	var invalid := GuiLayout.new()
	invalid.demo_grid_size = NAN
	invalid.play_grid_size = 9999
	check(invalid.demo_grid_size == 260 and invalid.play_grid_size == 320, "Invalid and out-of-range resource values stay within usable limits")
	invalid.play_grid_size = -20
	check(invalid.play_grid_size == 180, "A negative size cannot create an unusable touch target")
	editor.queue_free()
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(layout_path))
	await create_timer(0.15).timeout
	print("GUI editor: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
