class_name RhythmSession
extends RefCounted

signal judged(kind: String, cell: int, error_ms: float)

const PERFECT := 0.050
const GOOD := 0.100
const WINDOW := 0.150

var chart: Dictionary
var start_beat := -INF
var end_beat := 0.0
var notes: Array[Dictionary] = []
var score := 0
var combo := 0
var max_combo := 0
var resolved := 0
var counts: Dictionary = {"PERFECT": 0, "GOOD": 0, "OK": 0, "MISS": 0}


func _init(data: Dictionary, from_beat: float = -INF) -> void:
	chart = data
	start_beat = from_beat
	for phrase in chart.phrases:
		if float(phrase.show_beat) < start_beat:
			continue
		end_beat = maxf(end_beat, float(phrase.response_beat) + float(phrase.length_beats))
		for note in phrase.notes:
			notes.append({"time": TouchChart.beat_to_seconds(chart, float(phrase.response_beat) + float(note.beat)), "cell": int(note.cell), "done": false})
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)


func advance(song_seconds: float) -> void:
	for note in notes:
		if not note.done and song_seconds > float(note.time) + WINDOW + 0.000001:
			note.done = true
			resolved += 1
			combo = 0
			counts.MISS += 1
			judged.emit("MISS", int(note.cell), 0.0)


func auto_play(song_seconds: float) -> void:
	for note in notes:
		if float(note.time) > song_seconds:
			break
		if not note.done:
			# Judge at the authored time even when a frame spans several notes.
			hit(int(note.cell), float(note.time))


func hit(cell: int, song_seconds: float) -> String:
	advance(song_seconds)
	var nearest: Dictionary = {}
	var distance := WINDOW + 0.000001
	for note in notes:
		var difference := absf(song_seconds - float(note.time))
		if not note.done and int(note.cell) == cell and difference <= distance:
			nearest = note
			distance = difference
	if not nearest.is_empty():
		nearest.done = true
		resolved += 1
		combo += 1
		max_combo = maxi(max_combo, combo)
		var kind := "PERFECT" if distance <= PERFECT + 0.000001 else ("GOOD" if distance <= GOOD + 0.000001 else "OK")
		score += {"PERFECT": 1000, "GOOD": 700, "OK": 400}[kind]
		counts[kind] += 1
		judged.emit(kind, cell, (song_seconds - float(nearest.time)) * 1000.0)
		return kind
	if phase_at(song_seconds).kind == "response":
		combo = 0
		counts.MISS += 1
		judged.emit("MISS", cell, 0.0)
		return "MISS"
	return "IGNORED"


func accuracy() -> float:
	var denominator: int = counts.PERFECT + counts.GOOD + counts.OK + counts.MISS
	return 100.0 * float(score) / float(denominator * 1000) if denominator > 0 else 100.0


func phase_at(song_seconds: float) -> Dictionary:
	var beat := TouchChart.seconds_to_beat(chart, song_seconds)
	for index in range(chart.phrases.size()):
		var phrase: Dictionary = chart.phrases[index]
		if float(phrase.show_beat) < start_beat:
			continue
		var length := float(phrase.length_beats)
		for kind in ["demo", "response"]:
			var start := float(phrase.show_beat if kind == "demo" else phrase.response_beat)
			if beat >= start and beat < start + length:
				return {"kind": kind, "index": index, "beat": beat - start, "progress": (beat - start) / length}
	return {"kind": "complete" if beat >= end_beat else "wait", "index": -1, "beat": beat, "progress": 0.0}


func demos_between(from_seconds: float, to_seconds: float) -> Array[int]:
	var cells: Array[int] = []
	for phrase in chart.phrases:
		if float(phrase.show_beat) < start_beat:
			continue
		for note in phrase.notes:
			var time := TouchChart.beat_to_seconds(chart, float(phrase.show_beat) + float(note.beat))
			if time > from_seconds and time <= to_seconds:
				cells.append(int(note.cell))
	return cells

