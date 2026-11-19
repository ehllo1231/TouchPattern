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


func _run() -> void:
	root.size = Vector2i(1100, 900)
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	root.add_child(maker)
	maker.size = Vector2(1100, 900)
	maker.note_sounds.set_volume_percent(0.0, false)
	await process_frame
	var input := maker.bpm_spin.get_line_edit()
	input.text = "116.123"
	input.text_submitted.emit(input.text)
	await process_frame
	check(absf(maker.bpm_spin.value - 116.123) < 0.000000001 and absf(float(maker.chart.bpm) - 116.123) < 0.000000001, "Committing a typed BPM keeps all three decimal places in the chart")
	check(input.text == "116.123", "The BPM field displays the third decimal digit")
	maker.bpm_spin.value += maker.bpm_spin.step
	check(absf(float(maker.chart.bpm) - 116.124) < 0.000000001, "One adjustment changes BPM by exactly 0.001")
	maker.bpm_spin.value = 116.123
	var path := "user://tests/bpm_precision_%d.json" % OS.get_process_id()
	maker._save_to(path)
	var result := TouchChart.read(path)
	check(str(result.error).is_empty() and absf(float(result.chart.bpm) - 116.123) < 0.000000001, "Saving and parsing JSON preserve the third BPM decimal")
	maker._load_chart(path)
	check(absf(maker.bpm_spin.value - 116.123) < 0.000000001 and input.text == "116.123" and not maker.dirty, "Reloading a three-decimal chart preserves its value and display")
	var chart: Dictionary = result.chart
	for beat in [0.0, 0.25, 1.0, 64.0, 1000.0, 10000.0]:
		var time := TouchChart.beat_to_seconds(chart, beat)
		check(absf(time - beat * 60.0 / 116.123) < 0.000000001 and absf(TouchChart.seconds_to_beat(chart, time) - beat) < 0.00000001, "Beat/time conversion preserves decimal BPM at beat %s" % beat)
	var session := RhythmSession.new(chart)
	var first := float(session.notes[0].time)
	check(absf(first - float(chart.phrases[0].response_beat) * 60.0 / 116.123) < 0.000000001, "Judgment note times use the unrounded BPM")
	var edge := RhythmSession.new(chart)
	check(edge.hit(int(edge.notes[0].cell), first + RhythmSession.WINDOW) == "OK", "Three-decimal BPM retains the original late judgment boundary")
	session.auto_play(10000.0)
	check(session.score == session.notes.size() * 1000 and session.counts.PERFECT == session.notes.size() and session.counts.MISS == 0, "Three-decimal BPM auto-plays every note with the original scoring")
	maker._listen(true)
	var end := TouchChart.beat_to_seconds(chart, TouchChart.end_beat(chart))
	check(maker.clock.running and absf(maker._preview_end - end) < 0.000000001, "Continuous preview duration uses the full BPM precision")
	maker._update_preview(TouchChart.beat_to_seconds(chart, float(chart.phrases[0].show_beat)) + 0.000000001)
	check(maker.preview_pad._glow[0] > 0.99, "Preview flashes at the exact authored beat with three-decimal BPM")
	maker._stop_preview()
	maker.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("BPM precision: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
