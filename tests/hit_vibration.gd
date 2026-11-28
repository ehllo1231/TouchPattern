extends SceneTree

class RecordingVibration extends HitVibration:
	var pads: Array[int] = []
	var touch_count := 0
	var last_strength := 0.0

	func _vibrate_gamepad(device: int, strength: float) -> void:
		pads.append(device)
		last_strength = strength

	func _vibrate_handheld(strength: float) -> void:
		touch_count += 1
		last_strength = strength

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)


func press_pad(button: JoyButton, device: int) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.device = device
		event.pressed = down
		root.push_input(event, true)


func _run() -> void:
	root.size = Vector2i(540, 960)
	var path := "user://tests/haptics_%d.cfg" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var player := PlayerView.new()
	var vibration := RecordingVibration.new()
	player.hit_vibration = vibration
	player.preferences_path = path
	player.note_sounds.preferences_path = path
	root.add_child(player)
	player.size = Vector2(540, 960)
	await process_frame
	player.set_process(false)
	player.note_sounds.set_volume_percent(0, false)
	player._start()
	player.clock.pause()
	player.clock._paused_seconds = float(player.session.notes[0].time)
	press_pad(JOY_BUTTON_X, 0)
	check(player.session.counts.PERFECT == 1 and vibration.pads.is_empty(), "With default vibration off, X still hits the top-left tile")
	player._pause()
	player._show_settings()
	player.vibration_control.slider.value = 60
	check(vibration.strength_percent == 60 and player.vibration_control.value_label.text == "60%", "The setting updates the strength and its percentage")
	player._start()
	player.clock.pause()
	var buttons := [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_A, JOY_BUTTON_B]
	var offsets := [0.0, 0.07, 0.12, 0.0]
	for cell in buttons.size():
		player.clock._paused_seconds = float(player.session.notes[cell].time) + offsets[cell]
		press_pad(buttons[cell], cell % 2)
	check(player.session.score == 3100 and player.session.counts.MISS == 0, "X/Y/A/B score in the four requested cells using normal judgment windows")
	check(vibration.pads == [0, 1, 0, 1] and vibration.touch_count == 0 and vibration.last_strength == 0.6, "Perfect, Good and OK each pulse only their originating pad once")
	press_pad(JOY_BUTTON_B, 1)
	check(player.session.counts.MISS == 1 and vibration.pads.size() == 4, "A wrong pad press scores Miss without a pulse")
	player._start()
	player.clock.pause()
	player.clock._paused_seconds = 0.0
	press_pad(JOY_BUTTON_X, 1)
	check(player.session.score == 0 and vibration.pads.size() == 4, "An ignored pad press does not vibrate")
	player.clock._paused_seconds = float(player.session.notes[0].time)
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = player.input_pad.get_global_transform_with_canvas() * player.input_pad.cell_rect(0).get_center()
		touch.pressed = down
		Input.parse_input_event(touch)
		await process_frame
	check(player.session.counts.PERFECT == 1 and player.session.counts.MISS == 0 and vibration.touch_count == 1 and vibration.pads.size() == 4, "A real touch event and its emulated mouse produce exactly one handheld pulse")
	player.session.auto_play(float(player.session.notes[1].time))
	check(vibration.touch_count == 1 and vibration.pads.size() == 4, "AUTO judgments do not vibrate")
	player.clock._paused_seconds = float(player.session.notes[2].time)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	root.push_input(key, true)
	check(player.session.counts.PERFECT == 3 and vibration.touch_count == 1 and vibration.pads.size() == 4, "Keyboard hits score without vibrating another device")
	player.clock._paused_seconds = float(player.session.notes[3].time)
	for down in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = player.input_pad.get_global_transform_with_canvas() * player.input_pad.cell_rect(3).get_center()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		root.push_input(mouse, true)
	check(player.session.counts.PERFECT == 4 and vibration.touch_count == 1 and vibration.pads.size() == 4, "Mouse hits also leave both motors quiet")
	player._pause()
	press_pad(JOY_BUTTON_B, 1)
	check(player.state == "paused" and vibration.pads.size() == 4, "Paused gameplay ignores pad hits")
	player.queue_free()
	await process_frame
	var reopened := PlayerView.new()
	reopened.preferences_path = path
	root.add_child(reopened)
	check(reopened.vibration_control.slider.value == 60 and reopened.hit_vibration.strength_percent == 60, "The chosen strength is restored on reopening the game")
	reopened.vibration_control.slider.value = 0
	var saved := ConfigFile.new()
	saved.load(path)
	check(reopened.hit_vibration.strength_percent == 0 and saved.get_value("haptics", "strength_percent") == 0, "Turning vibration back off is immediate and persists")
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Hit vibration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
