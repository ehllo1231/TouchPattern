extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var portrait := args.has("--portrait")
	var capture_size := Vector2i(390, 740) if portrait else Vector2i(540, 960)
	var size_index := args.find("--size")
	if size_index >= 0 and size_index + 1 < args.size():
		var dimensions := args[size_index + 1].split("x")
		capture_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	root.size = capture_size
	var phase := "title"
	var phase_index := args.find("--phase")
	if phase_index >= 0 and phase_index + 1 < args.size():
		phase = args[phase_index + 1]
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.skip_frontend = phase not in ["title", "songs"]
	root.add_child(app)
	for frame in range(12):
		await process_frame
	if app.get_child(0) is FrontMenu and phase == "songs":
		app.get_child(0).show_library(false)
	if app.get_child(0) is PlayerView and phase != "ready":
		var player := app.get_child(0) as PlayerView
		player._start()
		player.set_process(false)
		player.clock.pause()
		var beat := 8.0 if phase in ["response", "judgments", "timing", "timing-settings"] else 5.0
		var song_time := TouchChart.beat_to_seconds(player.chart, beat)
		player.clock._paused_seconds = song_time
		player._last_time = song_time - 0.000001
		player._process(0.0)
		await create_timer(0.2).timeout
		if phase in ["demo", "paused"]:
			player.demo_pad.flash(1)
		elif phase == "judgments":
			for cell in range(4):
				player._judged(["PERFECT", "GOOD", "OK", "MISS"][cell], cell, 0.0)
			player.input_pad.feedback._process(0.06)
		elif phase in ["timing", "timing-settings"]:
			player.detailed_judgment = true
			player.detailed_judgment_check.set_pressed_no_signal(true)
			var note: Dictionary = player.session.notes[0]
			player.clock._paused_seconds = float(note.time) + player.offset_ms / 1000.0 + 0.0234
			player._press(int(note.cell))
		if phase in ["paused", "timing-settings"]:
			player._pause()
			player._show_settings()
		if phase == "finished":
			player.session.auto_play(10000.0)
			player._finish()
	for frame in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	var name := "chart_maker" if args.has("--chart-maker") else phase
	var destination := "res://.tools/diagnostics/ui_%s_%dx%d.png" % [name, capture_size.x, capture_size.y]
	var output_index := args.find("--output")
	if output_index >= 0 and output_index + 1 < args.size():
		destination = args[output_index + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	var error := root.get_texture().get_image().save_png(destination)
	if error != OK:
		push_error("Could not save preview: " + error_string(error))
		quit(1)
		return
	print("Saved " + destination)
	app.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
