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


func touch_at(control: Control, point: Vector2, index: int = 0) -> void:
	var position := control.get_global_transform_with_canvas() * point
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = index
		event.pressed = pressed
		event.position = position
		Input.parse_input_event(event)
		await process_frame


func _run() -> void:
	root.size = Vector2i(540, 960)
	var player := PlayerView.new()
	player.theme = AppStyle.make_theme()
	root.add_child(player)
	player.size = Vector2(540, 960)
	await process_frame
	check(player.menu.visible and not player.input_pad.interactive, "Ready menu blocks gameplay input")
	check(player.demo_pad.size == player.input_pad.size and player.demo_pad.cell_rect(0).size == player.input_pad.cell_rect(0).size, "Both grids share exactly the same geometry")
	check(player.progress.size.y <= 6.0, "Progress remains a thin track after layout")
	check(not player.demo_pad.show_keys and not player.input_pad.show_keys, "Gameplay grids have no permanent key or number labels")
	var card := player.menu_surface.find_children("*", "PanelContainer", true, false)[0] as Control
	for dimensions in [Vector2(320, 568), Vector2(360, 800), Vector2(390, 844), Vector2(540, 960), Vector2(768, 1024), Vector2(1100, 900), Vector2(960, 540)]:
		player.size = dimensions
		player._show_settings()
		await process_frame
		await process_frame
		var bounds := Rect2(Vector2.ZERO, dimensions).grow(0.1)
		check(bounds.encloses(player.stage.get_global_rect()) and bounds.encloses(card.get_global_rect()), "Stage and expanded menu fit %dx%d" % [dimensions.x, dimensions.y])
		check(player.input_pad.cell_rect(0).size.x * player.stage.scale.x >= 44.0, "Touch targets stay at least 44 pixels at %dx%d" % [dimensions.x, dimensions.y])
		check(player.start_button.size.y * player.menu_surface.scale.y >= 42.0 and player.hud.pause_button.size.y * player.stage.scale.y >= 42.0, "Menu and pause targets stay touchable at %dx%d" % [dimensions.x, dimensions.y])
		player.settings_panel.hide()
	player.size = Vector2(540, 960)
	await process_frame
	# Use actual touch dispatch, including Godot's emulated mouse for buttons.
	await touch_at(player.start_button, player.start_button.size * 0.5)
	check(player.state == "playing" and not player.menu.visible, "Touch starts gameplay from the menu")
	if player.state != "playing":
		player._start()
	player.set_process(false)
	player.clock.pause()
	player.offset_ms = 0.0
	var first := float(player.session.notes[0].time)
	player.clock._paused_seconds = first - RhythmSession.WINDOW
	player._set_phase("demo")
	player._press(0)
	check(player.session.counts.OK == 1, "The UI preserves the early hit window before the response boundary")
	player._start()
	player.clock.pause()
	player.clock._paused_seconds = float(player.session.notes[0].time)
	player._set_phase("response")
	await touch_at(player.input_pad, player.input_pad.cell_rect(0).get_center())
	check(player.session.counts.PERFECT == 1 and player.session.counts.WRONG == 0 and player.session.score == 1000, "A raw touch plus its emulated mouse judges exactly once")
	check(player.input_pad.feedback.kinds[0] == "PERFECT", "A judgment appears inside its originating tile")
	player._pause()
	var paused_score := player.session.score
	var paused_time := player.clock.seconds()
	await touch_at(player.input_pad, player.input_pad.cell_rect(1).get_center(), 1)
	player._press(1)
	check(player.menu.visible and not player.input_pad.interactive and player.session.score == paused_score and player.clock.seconds() == paused_time, "Pause blocks touches and keys without moving the song clock")
	player._toggle()
	check(not player.menu.visible and player.input_pad.interactive and player.clock.running, "Resume restores touch input and the song clock together")
	player.clock.pause()
	player._set_phase("demo")
	player.demo_pad._process(0.16)
	player.input_pad._process(0.16)
	check(player.demo_pad._activation == 1.0 and player.input_pad._activation == 0.0, "Demo activates only the purple grid")
	player._set_phase("response")
	player.demo_pad._process(0.16)
	player.input_pad._process(0.16)
	check(player.demo_pad._activation == 0.0 and player.input_pad._activation == 1.0, "Response activates only the teal grid")
	player.input_pad.clear()
	for cell in range(4):
		player._judged(["PERFECT", "GOOD", "OK", "MISS"][cell], cell, 0.0)
	check(player.input_pad.feedback.kinds == ["PERFECT", "GOOD", "OK", "MISS"] and player.input_pad._glow[0] > player.input_pad._glow[1] and player.input_pad._glow[1] > player.input_pad._glow[2], "Simultaneous judgments have independent cells, colors, and intensities")
	player._judged("WRONG", 0, 0.0)
	check(player.input_pad.feedback.kinds[0] == "WRONG" and player.input_pad.feedback.ages[0] == 0.0, "A new judgment replaces an old effect on the same cell")
	player.input_pad.feedback._process(0.5)
	check(player.input_pad.feedback.kinds == ["", "", "", ""], "Judgments clear in under half a second")
	player._finish()
	check(player.menu.visible and player.menu_results.visible and player.progress.value == 100.0, "Results stay in the end menu")
	player._start()
	check(player.session.score == 0 and not player.menu.visible and player.input_pad.feedback.kinds == ["", "", "", ""], "Restart clears all score and effect state")
	player.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Player UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
