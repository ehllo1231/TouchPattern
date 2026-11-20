class_name SongLibrary
extends RefCounted

const BUNDLED_TRACK := "res://assets/charts/the_descent_loop.json"
const SAVED_TRACK := "user://charts/The Descent Loop.json"
const SONGS := [
	{"id": "the_descent_loop", "title": "The Descent Loop", "saved": SAVED_TRACK, "bundled": BUNDLED_TRACK},
	{"id": "electric_dreams", "title": "Electric Dreams", "saved": "user://charts/Electric Dreams.json", "bundled": "res://assets/charts/electric_dreams.json"},
]


static func track_path(index: int = 0) -> String:
	# Prefer the author's current chart; the bundled copy also works on a fresh PC.
	var song: Dictionary = SONGS[index]
	return str(song.saved) if FileAccess.file_exists(str(song.saved)) else str(song.bundled)


static func tracks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(SONGS.size()):
		var entry := track(track_path(index))
		entry["id"] = SONGS[index].id
		result.append(entry)
	return result


static func track(path: String = "") -> Dictionary:
	if path.is_empty():
		path = track_path()
	var result := TouchChart.read(path)
	if not str(result.error).is_empty():
		var title := path.get_file().get_basename().replace("_", " ")
		for song in SONGS:
			if path in [song.saved, song.bundled]:
				title = str(song.title)
		return {"path": path, "title": title, "error": str(result.error)}
	var chart: Dictionary = result.chart
	var audio := TouchChart.load_audio(TouchChart.audio_path(chart, path))
	if audio == null:
		return {"path": path, "title": str(chart.title), "error": "곡의 음원을 찾을 수 없어요."}
	return {"path": path, "title": str(chart.title), "artist": str(chart.get("artist", "")), "bpm": float(chart.bpm), "duration": audio.get_length(), "phrases": chart.phrases.size(), "error": ""}
