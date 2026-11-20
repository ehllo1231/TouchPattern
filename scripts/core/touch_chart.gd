class_name TouchChart
extends RefCounted

const SAMPLE := "res://assets/charts/first_echo.json"
const VERSION := 1
const DEFAULT_FADE_OUT_SECONDS := 3.0
const MAX_FADE_OUT_SECONDS := 60.0


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "채보 파일을 찾을 수 없어요: " + path}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"error": "JSON %d줄: %s" % [parser.get_error_line(), parser.get_error_message()]}
	if not parser.data is Dictionary:
		return {"error": "채보의 최상위 값은 JSON 객체여야 해요."}
	var data: Dictionary = parser.data
	var error := validate(data)
	if not error.is_empty():
		return {"error": error}
	return {"chart": data, "path": path, "error": ""}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func validate(data: Dictionary, require_notes: bool = true) -> String:
	if data.get("format_version") != VERSION:
		return "지원하는 채보 버전은 1이에요."
	if not data.get("title") is String or str(data.title).strip_edges().is_empty():
		return "곡 제목을 입력해 주세요."
	if not data.get("audio") is String or str(data.audio).is_empty():
		return "음원 파일을 지정해 주세요."
	if not _number(data.get("bpm")) or float(data.bpm) < 30.0 or float(data.bpm) > 300.0:
		return "BPM은 30~300 사이여야 해요."
	if not _number(data.get("offset_seconds")) or absf(float(data.offset_seconds)) > 600.0:
		return "곡 오프셋은 -600~600초 사이여야 해요."
	if not data.get("grid") is Dictionary:
		return "그리드 정보를 확인해 주세요."
	if data.grid.get("rows") != 2 or data.grid.get("columns") != 2:
		return "이번 MVP는 2×2 그리드를 지원해요."
	if not data.get("phrases") is Array or data.phrases.is_empty():
		return "패턴이 하나 이상 필요해요."
	var has_audio_end := data.has("audio_end_beat")
	var audio_end := 0.0
	if has_audio_end:
		if not _number(data.audio_end_beat) or float(data.audio_end_beat) < 0.0:
			return "곡 종료 박자는 0 이상이어야 해요."
		audio_end = float(data.audio_end_beat)
		var fade: Variant = data.get("fade_out_seconds", DEFAULT_FADE_OUT_SECONDS)
		if not _number(fade) or float(fade) < 0.0 or float(fade) > MAX_FADE_OUT_SECONDS:
			return "페이드 아웃은 0~%d초 사이여야 해요." % int(MAX_FADE_OUT_SECONDS)
	elif data.has("fade_out_seconds"):
		return "페이드 아웃을 쓰려면 곡 종료 지점을 먼저 지정해 주세요."
	var intervals: Array[Dictionary] = []
	var note_count := 0
	var audio_end_matches_phrase := false
	for index in range(data.phrases.size()):
		var phrase: Variant = data.phrases[index]
		var prefix := "패턴 %d: " % (index + 1)
		if not phrase is Dictionary:
			return prefix + "패턴 형식이 올바르지 않아요."
		for key in ["show_beat", "response_beat", "length_beats"]:
			if not _number(phrase.get(key)):
				return prefix + key + " 값은 숫자여야 해요."
		var length := float(phrase.length_beats)
		if length <= 0.0 or length > 32.0:
			return prefix + "길이는 0보다 크고 32박 이하여야 해요."
		if float(phrase.show_beat) < 0.0:
			return prefix + "시범 시작은 0박 이후여야 해요."
		if float(phrase.response_beat) < float(phrase.show_beat) + length:
			return prefix + "재현 구간은 시범이 끝난 후에 시작해야 해요."
		audio_end_matches_phrase = audio_end_matches_phrase or (has_audio_end and is_equal_approx(audio_end, float(phrase.response_beat) + length))
		intervals.append({"start": float(phrase.show_beat), "end": float(phrase.show_beat) + length})
		intervals.append({"start": float(phrase.response_beat), "end": float(phrase.response_beat) + length})
		if not phrase.get("notes") is Array:
			return prefix + "노트 목록을 확인해 주세요."
		var seen: Dictionary = {}
		for note in phrase.notes:
			if not note is Dictionary or not _number(note.get("beat")) or not _number(note.get("cell")):
				return prefix + "노트의 beat와 cell은 숫자여야 해요."
			var beat := float(note.beat)
			var cell := float(note.cell)
			if beat < 0.0 or beat >= length:
				return prefix + "노트가 패턴 길이를 벗어났어요."
			if cell != floorf(cell) or cell < 0.0 or cell >= 4.0:
				return prefix + "칸 번호는 0~3 정수여야 해요."
			var identity := "%d:%d" % [int(round(beat * 1000000.0)), int(cell)]
			if seen.has(identity):
				return prefix + "같은 박자와 칸에 노트가 중복되어 있어요."
			seen[identity] = true
			note_count += 1
	if require_notes and note_count == 0:
		return "노트를 하나 이상 배치해 주세요."
	if has_audio_end and not audio_end_matches_phrase:
		return "곡 종료 지점은 패턴의 재현 구간 끝과 맞아야 해요."
	intervals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.start < b.start)
	for index in range(1, intervals.size()):
		if float(intervals[index].start) < float(intervals[index - 1].end) - 0.000001:
			return "시범·재현 구간끼리 겹쳐 있어요. 시작 박자를 조정해 주세요."
	return ""


static func beat_to_seconds(chart: Dictionary, beat: float) -> float:
	return float(chart.offset_seconds) + beat * 60.0 / float(chart.bpm)


static func seconds_to_beat(chart: Dictionary, seconds: float) -> float:
	return (seconds - float(chart.offset_seconds)) * float(chart.bpm) / 60.0


static func end_beat(chart: Dictionary) -> float:
	var result := 0.0
	for phrase in chart.phrases:
		result = maxf(result, float(phrase.response_beat) + float(phrase.length_beats))
	return result


static func has_audio_end(chart: Dictionary) -> bool:
	return _number(chart.get("audio_end_beat"))


static func audio_end_beat(chart: Dictionary) -> float:
	return float(chart.audio_end_beat) if has_audio_end(chart) else INF


static func fade_out_seconds(chart: Dictionary) -> float:
	return clampf(float(chart.get("fade_out_seconds", DEFAULT_FADE_OUT_SECONDS)), 0.0, MAX_FADE_OUT_SECONDS) if has_audio_end(chart) else 0.0


static func audio_end_seconds(chart: Dictionary, stream_length: float) -> float:
	if not has_audio_end(chart):
		return maxf(0.0, stream_length)
	return clampf(beat_to_seconds(chart, audio_end_beat(chart)), 0.0, maxf(0.0, stream_length))


static func audio_fade_out_seconds(chart: Dictionary, stream_length: float) -> float:
	if not has_audio_end(chart) or beat_to_seconds(chart, audio_end_beat(chart)) > stream_length + 0.000001:
		return 0.0
	return fade_out_seconds(chart)


static func audio_path(chart: Dictionary, chart_path: String) -> String:
	var path := str(chart.audio)
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path.simplify_path()
	var directory := chart_path.get_base_dir()
	# Relative references may leave the app-data directory (e.g. Downloads).
	# Simplifying user://../.. first would clamp the path to its virtual root.
	if directory.begins_with("user://"):
		directory = ProjectSettings.globalize_path(directory)
	return directory.path_join(path).simplify_path()


static func load_audio(path: String) -> AudioStream:
	# Exported projects store imported audio behind resource remaps. External
	# authoring files still use the file loaders below.
	if path.begins_with("res://") and ResourceLoader.exists(path, "AudioStream"):
		return ResourceLoader.load(path, "AudioStream") as AudioStream
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"wav": return AudioStreamWAV.load_from_file(path)
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
		"mp3": return AudioStreamMP3.load_from_file(path)
	return null


static func relative_file(base_directory: String, target: String) -> String:
	var base := base_directory.replace("\\", "/").simplify_path().split("/", false)
	var parts := target.replace("\\", "/").simplify_path().split("/", false)
	if base.is_empty() or parts.is_empty():
		return target
	if (base[0].ends_with(":") or parts[0].ends_with(":")) and base[0].to_lower() != parts[0].to_lower():
		return target
	if target.begins_with("//") and (base.size() < 2 or parts.size() < 2 or base[0] != parts[0] or base[1] != parts[1]):
		return target
	var common := 0
	while common < mini(base.size(), parts.size()) and base[common] == parts[common]:
		common += 1
	var result := PackedStringArray()
	for index in range(common, base.size()):
		result.append("..")
	for index in range(common, parts.size()):
		result.append(parts[index])
	return "/".join(result)


static func write(chart: Dictionary, original_path: String, destination: String) -> String:
	var error := validate(chart)
	if not error.is_empty():
		return error
	var copy := chart.duplicate(true)
	var absolute_audio := audio_path(chart, original_path)
	# Built-in sample assets remain resource paths; external files become relative.
	if absolute_audio.begins_with("res://"):
		copy.audio = absolute_audio
	else:
		var target_dir := ProjectSettings.globalize_path(destination.get_base_dir())
		copy.audio = relative_file(target_dir, ProjectSettings.globalize_path(absolute_audio))
	var parent := ProjectSettings.globalize_path(destination.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		return "저장 폴더를 만들 수 없어요."
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return "채보를 저장할 수 없어요. 오류 코드: %d" % FileAccess.get_open_error()
	file.store_string(JSON.stringify(copy, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	return "" if write_error == OK else "채보 파일을 쓰는 중 오류가 발생했어요."

