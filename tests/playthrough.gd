extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1100, 900)
	var app: Control = load("res://scenes/app.tscn").instantiate()
	app.skip_frontend = true
	root.add_child(app)
	var player := app.get_child(0) as PlayerView
	await process_frame
	player._start()
	var selected_test := OS.get_cmdline_user_args().has("--start-phrase")
	var auto_test := OS.get_cmdline_user_args().has("--auto-mode")
	var expected_notes := 14 if selected_test else 42
	if selected_test and (player.initial_phrase != 6 or not is_equal_approx(player.clock._origin_seconds, 51.0 * 60.0 / 112.0)):
		push_error("Selected-pattern playthrough must start at pattern seven with a one-beat lead-in")
		quit(1)
		return
	var index := 0
	var keys := [KEY_U, KEY_I, KEY_J, KEY_K]
	var origin := Time.get_ticks_msec()
	var previous_phase := ""
	while player.state == "playing":
		await process_frame
		var now := player.clock.seconds() - player.offset_ms / 1000.0
		var phase := str(player.session.phase_at(now).kind)
		if phase != previous_phase:
			print("Phase: %s at %.2fs" % [phase, now])
			previous_phase = phase
		while not auto_test and index < player.session.notes.size() and float(player.session.notes[index].time) <= now:
			var event := InputEventKey.new()
			event.physical_keycode = keys[int(player.session.notes[index].cell)]
			event.keycode = event.physical_keycode
			event.pressed = true
			Input.parse_input_event(event)
			index += 1
		if Time.get_ticks_msec() - origin > 45000:
			push_error("Full-song playthrough timed out")
			quit(1)
			return
	var success: bool = player.state == "finished" and player.session.counts.PERFECT == expected_notes and player.session.score == expected_notes * 1000 and player.session.counts.MISS == 0
	print("%s %s playthrough: score=%d, perfect=%d, misses=%d" % ["Selected-pattern" if selected_test else "Full-song", "AUTO" if auto_test else "keyboard", player.session.score, player.session.counts.PERFECT, player.session.counts.MISS])
	app.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if success else 1)
