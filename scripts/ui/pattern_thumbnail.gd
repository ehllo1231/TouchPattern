class_name PatternThumbnail
extends Button

const PIXELS_PER_BEAT := 40.0
const HEADER_HEIGHT := 24.0
const ROW_HEIGHT := 22.0
const GRID_HEIGHT := ROW_HEIGHT * 4.0
const PREVIEW_HEIGHT := HEADER_HEIGHT + GRID_HEIGHT + 4.0

var phrase: Dictionary = {"show_beat": 0.0, "response_beat": 4.0, "length_beats": 4.0, "notes": []}
var number := 1
var display_start_beat := 0.0
var ends_audio := false


func _ready() -> void:
	custom_minimum_size = Vector2(4.0 * PIXELS_PER_BEAT, PREVIEW_HEIGHT)
	toggle_mode = true
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func set_phrase(data: Dictionary, index: int, from_beat: float = 0.0, marks_audio_end: bool = false) -> void:
	phrase = data
	number = index + 1
	display_start_beat = from_beat
	ends_audio = marks_audio_end
	custom_minimum_size.x = float(phrase.length_beats) * PIXELS_PER_BEAT
	tooltip_text = "패턴 %02d · %d노트%s\n시범 %s박 · 재현 %s박 · 길이 %s박" % [number, phrase.notes.size(), " · 곡 종료" if ends_audio else "", str(phrase.show_beat), str(phrase.response_beat), str(phrase.length_beats)]
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var length := float(phrase.length_beats)
	var header_color := Color("153039") if button_pressed else Color("101928")
	if is_hovered():
		header_color = header_color.lightened(0.08)
	draw_rect(Rect2(0, 0, size.x, HEADER_HEIGHT), header_color)
	if size.x >= 30.0:
		draw_string(font, Vector2(8, 17), "%02d" % number, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AppStyle.MINT if button_pressed else AppStyle.TEXT)
	if ends_audio and size.x >= 74.0:
		var end_text := "END"
		var end_width := font.get_string_size(end_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(size.x - 8.0 - end_width, 17), end_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AppStyle.RED)
	elif size.x >= 80.0:
		var length_text := "%s박" % str(phrase.length_beats).trim_suffix(".0")
		var text_width := font.get_string_size(length_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(size.x - 8.0 - text_width, 17), length_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AppStyle.MUTED)
	for cell in range(4):
		var y := HEADER_HEIGHT + cell * ROW_HEIGHT
		var fill := Color("0b1520") if cell % 2 == 0 else Color("101e2c")
		if button_pressed:
			fill = fill.lerp(AppStyle.MINT, 0.10)
		elif is_hovered():
			fill = fill.lightened(0.05)
		draw_rect(Rect2(0, y, size.x, ROW_HEIGHT), fill)
		# Every section shares the same lane geometry, without inner margins.
		draw_line(Vector2(0, y), Vector2(size.x, y), AppStyle.LINE, 1.0)
	var first_tick := int(ceil(display_start_beat * 4.0 - 0.000001))
	var last_tick := int(floor((display_start_beat + length) * 4.0 + 0.000001))
	for tick in range(first_tick, last_tick + 1):
		var x := (float(tick) / 4.0 - display_start_beat) * PIXELS_PER_BEAT
		var color := Color("304456") if tick % 4 == 0 else Color("182837")
		draw_line(Vector2(x, HEADER_HEIGHT), Vector2(x, HEADER_HEIGHT + GRID_HEIGHT), color, 1.0)
	for note in phrase.notes:
		var x := float(note.beat) * PIXELS_PER_BEAT
		var width := maxf(1.0, minf(PIXELS_PER_BEAT / 4.0 - 2.0, size.x - x - 1.0))
		var rect := Rect2(x + 1.0, HEADER_HEIGHT + int(note.cell) * ROW_HEIGHT + 4.0, width, ROW_HEIGHT - 8.0)
		draw_style_box(AppStyle.box(AppStyle.CELLS[int(note.cell)], 2), rect)
	var bottom := HEADER_HEIGHT + GRID_HEIGHT
	draw_line(Vector2(0, bottom), Vector2(size.x, bottom), AppStyle.LINE, 1.0)
	var boundary := AppStyle.MINT if button_pressed else Color("60798b")
	draw_line(Vector2(0.5, HEADER_HEIGHT), Vector2(0.5, bottom), boundary, 2.0 if button_pressed else 1.0)
	draw_line(Vector2(size.x - 0.5, HEADER_HEIGHT), Vector2(size.x - 0.5, bottom), AppStyle.RED if ends_audio else boundary, 3.0 if ends_audio else (2.0 if button_pressed else 1.0))
	if button_pressed or has_focus():
		draw_line(Vector2(0, 1.5), Vector2(size.x, 1.5), AppStyle.MINT if button_pressed else AppStyle.TEXT, 3.0)
