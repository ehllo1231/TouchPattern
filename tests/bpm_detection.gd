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


func clicks(bpm: float, seconds: float = 65.0, stereo: bool = false, subdivisions: bool = false) -> AudioStreamWAV:
	var rate := 8000
	var channels := 2 if stereo else 1
	var data := PackedByteArray()
	data.resize(int(ceil(seconds * rate)) * channels * 2)
	var step := 0.5 if subdivisions else 1.0
	var beat := 0.0
	while 0.371 + beat * 60.0 / bpm + 0.05 < seconds:
		var start := int(round((0.371 + beat * 60.0 / bpm) * rate))
		var amplitude := 20000.0 if is_equal_approx(beat, roundf(beat)) else 5000.0
		for index in range(180):
			var value := int(amplitude * exp(-float(index) / 30.0) * sin(index * 1.3))
			data.encode_s16((start + index) * channels * 2, value)
			if stereo:
				data.encode_s16((start + index) * channels * 2 + 2, -value)
		beat += step
	var audio := AudioStreamWAV.new()
	audio.mix_rate = rate
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.stereo = stereo
	audio.data = data
	return audio


func wait_for_analysis(maker: ChartMaker) -> void:
	var deadline := Time.get_ticks_msec() + 60000
	while maker._bpm_thread != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(maker._bpm_thread == null, "Background analysis finishes within 60 seconds")


func click(control: Control) -> void:
	await process_frame
	var position := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	for bpm in [87.654, 116.123, 143.789, 30.0, 300.0]:
		var started := Time.get_ticks_msec()
		# Supply a rough range for extreme tempos to resolve musical half/double-time.
		var hint: float = bpm if bpm == 30.0 or bpm == 300.0 else 120.0
		var result := BpmDetector.new().analyze(clicks(bpm, 65.0, true, true), hint)
		print("Synthetic %.3f BPM -> %s (%d ms)" % [bpm, str(result), Time.get_ticks_msec() - started])
		check(str(result.error).is_empty(), "Stereo click track %.3f BPM is detected" % bpm)
		if result.has("bpm"):
			check(absf(float(result.bpm) - bpm) <= 0.006, "Fractional tempo %.3f stays within 0.006 BPM with subdivisions and opposite-phase stereo" % bpm)
	var silence := clicks(112.0, 10.0)
	var silent_data := silence.data
	silent_data.fill(0)
	silence.data = silent_data
	check(not str(BpmDetector.new().analyze(silence).error).is_empty(), "Silence produces an error instead of an invented BPM")
	var quiet := clicks(116.123)
	var quiet_data := quiet.data
	for index in range(0, quiet_data.size(), 2):
		quiet_data.encode_s16(index, int(quiet_data.decode_s16(index) * 0.003))
	quiet.data = quiet_data
	var quiet_result := BpmDetector.new().analyze(quiet)
	check(str(quiet_result.error).is_empty() and absf(float(quiet_result.get("bpm", 0.0)) - 116.123) <= 0.006, "Quiet audio is normalized before estimating tempo")
	check(not str(BpmDetector.new().analyze(clicks(120.0, 2.0)).error).is_empty(), "Too-short audio is rejected")
	check(not str(BpmDetector.new().analyze(null).error).is_empty(), "Missing audio is rejected")
	var cancelled := BpmDetector.new()
	cancelled.cancel()
	check(cancelled.analyze(clicks(120.0)).error == "cancelled", "Cancellation stops offline decoding")
	for chart_path in [TouchChart.SAMPLE, "res://assets/charts/electric_dreams.json", "res://assets/charts/the_descent_loop.json"]:
		var chart: Dictionary = TouchChart.read(chart_path).chart
		var started := Time.get_ticks_msec()
		var result := BpmDetector.new().analyze(TouchChart.load_audio(TouchChart.audio_path(chart, chart_path)))
		print("Bundled %s -> %s (%d ms)" % [str(chart.title), str(result), Time.get_ticks_msec() - started])
		check(str(result.error).is_empty(), "Bundled WAV/MP3 music can be analyzed: " + str(chart.title))
		if result.has("bpm"):
			check(absf(float(result.bpm) - float(chart.bpm)) < 1.0, "Bundled music tempo agrees with the authored chart within 1 BPM: " + str(chart.title))
	root.size = Vector2i(1100, 900)
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	root.add_child(maker)
	await process_frame
	var path := "user://tests/bpm_detection_%d.wav" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check(clicks(116.123).save_to_wav(path) == OK, "Test audio is saved for the actual file loader")
	maker._set_audio(path)
	maker.bpm_spin.value = 99.0
	maker.dirty = false
	var original_offset: float = maker.chart.offset_seconds
	var original_notes: Array = maker.chart.phrases.duplicate(true)
	await click(maker.bpm_find_button)
	check(maker._bpm_thread != null and maker.bpm_find_button.disabled, "Clicking the button starts background analysis and prevents duplicate jobs")
	var title := "Edited during analysis"
	maker.title_edit.text = title
	maker.title_edit.text_changed.emit(title)
	await wait_for_analysis(maker)
	check(absf(maker.bpm_spin.value - 116.123) <= 0.006 and is_equal_approx(float(maker.chart.bpm), maker.bpm_spin.value), "The button applies the detected fractional BPM to the field and chart")
	check(maker.bpm_spin.get_line_edit().text.get_slice(".", 1).length() == 3, "Detected BPM displays three decimal places")
	check(maker.dirty and maker.chart.title == title, "Analysis keeps the UI usable and marks the BPM change as unsaved")
	check(maker.chart.offset_seconds == original_offset and maker.chart.phrases == original_notes, "Only BPM changes; offset and authored notes are preserved")
	var saved := "user://tests/bpm_detection_%d.json" % OS.get_process_id()
	maker._save_to(saved)
	check(is_equal_approx(float(TouchChart.read(saved).chart.bpm), maker.bpm_spin.value), "Detected decimal BPM survives saving and reloading")
	maker._find_bpm()
	maker.bpm_spin.value = 101.234
	await wait_for_analysis(maker)
	check(is_equal_approx(float(maker.chart.bpm), 101.234), "A manual BPM edit supersedes an in-flight result")
	maker._find_bpm()
	maker._load_chart(TouchChart.SAMPLE)
	await wait_for_analysis(maker)
	check(is_equal_approx(float(maker.chart.bpm), 112.0), "Loading another chart discards the old audio analysis")
	maker._find_bpm()
	maker._set_audio(path)
	await wait_for_analysis(maker)
	check(is_equal_approx(float(maker.chart.bpm), 112.0), "Replacing audio discards the previous analysis")
	maker.chart.audio = "user://tests/missing_bpm_audio.mp3"
	maker._find_bpm()
	check(maker._bpm_thread == null and is_equal_approx(float(maker.chart.bpm), 112.0), "Missing audio leaves the existing BPM intact")
	check(silence.save_to_wav(path) == OK, "A silent audio fixture can be loaded by the maker")
	maker._set_audio(path)
	maker._find_bpm()
	await wait_for_analysis(maker)
	check(is_equal_approx(float(maker.chart.bpm), 112.0) and not maker.bpm_find_button.disabled, "Analysis failure keeps the previous BPM and restores the button")
	maker._set_audio(path)
	maker._find_bpm()
	maker.queue_free()
	await process_frame
	check(not is_instance_valid(maker), "Closing the maker cancels and joins the worker")
	for file in [path, saved]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("BPM detection: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
