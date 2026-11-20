extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for song in SongLibrary.SONGS:
		var source := str(song.saved)
		if not FileAccess.file_exists(source):
			print("Using bundled song: ", song.title)
			continue
		var result := TouchChart.read(source)
		if not str(result.error).is_empty():
			_fail(str(song.title), str(result.error))
			return
		var chart: Dictionary = result.chart
		var source_audio := TouchChart.audio_path(chart, source)
		var audio := TouchChart.load_audio(source_audio)
		if audio == null:
			_fail(str(song.title), "Audio is missing or cannot be loaded.")
			return
		var filename := str(song.id) + "." + source_audio.get_extension().to_lower()
		var destination_audio := "res://assets/audio/" + filename
		if source_audio != destination_audio and (not FileAccess.file_exists(destination_audio) or FileAccess.get_sha256(source_audio) != FileAccess.get_sha256(destination_audio)):
			var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(source_audio), ProjectSettings.globalize_path(destination_audio))
			if error != OK:
				_fail(str(song.title), "Audio copy failed: " + error_string(error))
				return
		# Only the portable audio reference changes. Authored beats, notes, BPM,
		# and the original saved chart are left exactly as they are.
		chart.audio = "../audio/" + filename
		var target := str(song.bundled)
		var content := JSON.stringify(chart, "  ") + "\n"
		if not FileAccess.file_exists(target) or FileAccess.get_file_as_string(target) != content:
			var file := FileAccess.open(target, FileAccess.WRITE)
			if file == null:
				_fail(str(song.title), "Chart copy failed: " + error_string(FileAccess.get_open_error()))
				return
			file.store_string(content)
			file.flush()
			var error := file.get_error()
			file.close()
			if error != OK:
				_fail(str(song.title), "Chart write failed: " + error_string(error))
				return
		print("Synced saved song: ", song.title, " (", chart.phrases.size(), " patterns)")
	quit()


func _fail(title: String, error: String) -> void:
	push_error("Cannot bundle %s: %s" % [title, error])
	quit(1)
