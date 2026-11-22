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


func choose_file(maker: ChartMaker, path: String) -> void:
	maker.save_dialog.current_path = path
	await process_frame
	maker.save_dialog.get_ok_button().pressed.emit()
	await process_frame


func cancel_save(maker: ChartMaker) -> void:
	maker.save_dialog.canceled.emit()
	maker.save_dialog.hide()


func _run() -> void:
	root.size = Vector2i(1100, 900)
	var directory := ProjectSettings.globalize_path("res://.tools/chart-saving-%d" % OS.get_process_id())
	var audio_dir := directory.path_join("음원")
	var chosen_dir := directory.path_join("선택한 폴더")
	var other_dir := directory.path_join("別の保存先")
	for folder in [audio_dir, chosen_dir, other_dir]:
		check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create isolated save fixture folder: " + folder.get_file())
	var audio_path := audio_dir.path_join("노래.wav")
	var audio := AudioStreamWAV.new()
	audio.mix_rate = 8000
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	var samples := PackedByteArray()
	samples.resize(16000)
	audio.data = samples
	check(audio.save_to_wav(audio_path) == OK, "Create valid external audio without changing user songs")
	var legacy_path := "user://charts/untitled.json"
	var legacy_hash := FileAccess.get_sha256(legacy_path) if FileAccess.file_exists(legacy_path) else ""
	var maker := ChartMaker.new()
	maker.theme = AppStyle.make_theme()
	maker.preferences_path = directory.path_join("preferences.cfg")
	maker.remember_recent_chart = true
	root.add_child(maker)
	await process_frame
	# Exercise the same FileDialog confirmation as native save, without opening
	# a modal Windows window during the headless regression suite.
	maker.save_dialog.use_native_dialog = false
	maker._new_chart()
	maker._set_audio(audio_path)
	maker.title_edit.text = "새 채보"
	maker.title_edit.text_changed.emit("새 채보")
	maker._toggle_note(0.0, 0)
	check(maker.chart_path.is_empty() and maker.dirty and "아직 저장하지 않은 채보" in maker.path_label.text, "A new chart is explicitly unsaved instead of pointing at AppData/untitled.json")
	var draft := maker.chart.duplicate(true)
	maker._save()
	await process_frame
	check(maker.save_dialog.visible and maker.save_dialog.current_dir == audio_dir, "First Save opens a destination picker beside the selected audio")
	check(maker.save_dialog.current_file == "새 채보.json", "The initial suggested filename comes from the new chart title")
	cancel_save(maker)
	check(maker.chart_path.is_empty() and maker.dirty and maker.chart == draft, "Canceling the first save preserves the unsaved chart and never assigns a destination")
	maker._save()
	var chosen_path := chosen_dir.path_join("選んだ名前 (hard).json")
	await choose_file(maker, chosen_path.trim_suffix(".json"))
	check(FileAccess.file_exists(chosen_path) and maker.chart_path == chosen_path and not maker.dirty, "Confirming a different folder saves to that exact full path and adds the JSON extension")
	check(not FileAccess.file_exists(audio_dir.path_join(chosen_path.get_file())), "The suggested audio folder does not receive an unwanted extra copy")
	check(not maker.save_dialog.visible and chosen_path in maker.status_label.text and maker.path_label.tooltip_text == chosen_path, "The success message and path display identify the actual selected file")
	var saved := TouchChart.read(chosen_path)
	check(str(saved.error).is_empty() and saved.chart.title == "새 채보", "The selected file contains the edited chart")
	check(not str(saved.chart.audio).is_absolute_path() and TouchChart.audio_path(saved.chart, chosen_path) == audio_path, "Saving to another folder preserves the external audio via a correct relative reference")
	var settings := ConfigFile.new()
	check(settings.load(maker.preferences_path) == OK and settings.get_value("chart_maker", "recent_chart_path") == chosen_path, "Recent-chart restoration remembers the confirmed destination")
	maker.title_edit.text = "수정한 제목"
	maker.title_edit.text_changed.emit("수정한 제목")
	maker._save()
	check(not maker.save_dialog.visible and maker.chart_path == chosen_path and TouchChart.read(chosen_path).chart.title == "수정한 제목", "Subsequent Save writes the selected document even after its title changes")
	maker._save_as()
	await process_frame
	check(maker.save_dialog.current_dir == chosen_dir and maker.save_dialog.current_file == chosen_path.get_file(), "Save As opens beside the current file instead of resetting to AppData")
	var other_path := other_dir.path_join("新しい保存先.json")
	maker.save_dialog.current_path = other_path
	cancel_save(maker)
	check(maker.chart_path == chosen_path and not FileAccess.file_exists(other_path), "Canceling Save As leaves the current destination unchanged")
	maker._save_as()
	await choose_file(maker, other_path)
	check(maker.chart_path == other_path and FileAccess.file_exists(other_path), "Save As adopts the newly confirmed folder")
	var original_hash := FileAccess.get_sha256(chosen_path)
	maker.title_edit.text = "다른 폴더에서 수정"
	maker.title_edit.text_changed.emit("다른 폴더에서 수정")
	maker._save()
	check(TouchChart.read(other_path).chart.title == "다른 폴더에서 수정" and FileAccess.get_sha256(chosen_path) == original_hash, "Later saves update only the latest chosen destination")
	check(TouchChart.audio_path(maker.chart, maker.chart_path) == audio_path, "The audio remains linked after repeated relocation")
	maker._new_chart()
	maker._toggle_note(0.0, 0)
	maker._save()
	await process_frame
	check(maker.chart_path.is_empty() and maker.save_dialog.visible and FileAccess.get_sha256(chosen_path) == original_hash, "Another New Chart always requests a destination instead of overwriting an earlier chart")
	cancel_save(maker)
	var unchanged_legacy := FileAccess.get_sha256(legacy_path) if FileAccess.file_exists(legacy_path) else ""
	check(unchanged_legacy == legacy_hash, "The legacy AppData untitled path is never created or overwritten")
	maker.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	for path in [audio_path, chosen_path, other_path, directory.path_join("preferences.cfg")]:
		DirAccess.remove_absolute(path)
	for folder in [audio_dir, chosen_dir, other_dir, directory]:
		DirAccess.remove_absolute(folder)
	print("Chart saving: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
