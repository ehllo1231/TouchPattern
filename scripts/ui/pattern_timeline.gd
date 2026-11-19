class_name PatternTimeline
extends Control

signal note_toggled(beat: float, cell: int)

var phrase: Dictionary = {"length_beats": 4.0, "notes": []}
var snap := 4
var playhead := -1.0
var preview_highlights: Dictionary = {}
const LEFT := 48.0
const TOP := 34.0
const MIN_ROW := 38.0


func _ready() -> void:
	custom_minimum_size = Vector2(600, 226)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_phrase(data: Dictionary) -> void:
	phrase = data
	clear_preview()
	custom_minimum_size.x = maxf(600.0, float(phrase.length_beats) * 120.0 + LEFT + 16.0)
	queue_redraw()


func clear_preview() -> void:
	playhead = -1.0
	preview_highlights.clear()
	queue_redraw()


func _draw() -> void:
	var length := float(phrase.length_beats)
	var width := (size.x - LEFT - 16.0) / length
	var row := _row_height()
	var font := get_theme_default_font()
	for cell in range(4):
		var rect := Rect2(LEFT, TOP + row * cell, size.x - LEFT - 16.0, row - 4.0)
		draw_style_box(AppStyle.box(Color("0b1320"), 6), rect)
		draw_string(font, Vector2(12, TOP + row * cell + row / 2.0 + 5.0), AppStyle.KEYS[cell], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AppStyle.CELLS[cell])
	for tick in range(int(ceil(length * snap)) + 1):
		var beat := float(tick) / float(snap)
		if beat > length:
			continue
		var x := LEFT + beat * width
		var is_beat := tick % snap == 0
		draw_line(Vector2(x, TOP), Vector2(x, TOP + 4.0 * row - 4.0), AppStyle.LINE if is_beat else Color("182234"), 1.0)
		if is_beat:
			draw_string(font, Vector2(x + 3.0, 23.0), str(int(beat)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AppStyle.MUTED)
	for index in range(phrase.notes.size()):
		var note: Dictionary = phrase.notes[index]
		var beat := float(note.beat)
		var cell := int(note.cell)
		var rect := Rect2(LEFT + beat * width + 3.0, TOP + cell * row + 6.0, maxf(8.0, width / float(snap) - 6.0), row - 16.0)
		draw_style_box(AppStyle.box(AppStyle.CELLS[cell], 6), rect)
		var strength := float(preview_highlights.get(index, 0.0))
		if strength > 0.0:
			var outline := AppStyle.box(Color.TRANSPARENT, 8, Color(AppStyle.TEXT, strength))
			outline.set_border_width_all(3)
			draw_style_box(outline, rect.grow(3.0))
	if playhead >= 0.0 and playhead < length:
		var x := LEFT + playhead * width
		draw_line(Vector2(x, TOP - 6.0), Vector2(x, TOP + 4.0 * row), AppStyle.TEXT, 2.0)
	draw_string(font, Vector2(LEFT, TOP + 4.0 * row + 24.0), "빈칸은 쉼표 · 같은 박자에 여러 칸을 찍으면 동시치기", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AppStyle.MUTED)


func _row_height() -> float:
	return maxf(MIN_ROW, (size.y - TOP - 40.0) / 4.0)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var point: Vector2 = event.position
	var length := float(phrase.length_beats)
	var row := _row_height()
	if point.x < LEFT or point.x >= size.x - 16.0 or point.y < TOP or point.y >= TOP + row * 4.0:
		return
	var cell := int((point.y - TOP) / row)
	var beat := floorf((point.x - LEFT) / (size.x - LEFT - 16.0) * length * snap) / float(snap)
	note_toggled.emit(beat, cell)
	accept_event()

