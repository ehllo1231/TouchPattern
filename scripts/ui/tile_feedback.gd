class_name TileFeedback
extends Control

# This layer only renders judgments. It never owns input or a song clock.
const DURATIONS := {"PERFECT": 0.44, "GOOD": 0.38, "OK": 0.34, "MISS": 0.32}
const COLORS := {"PERFECT": Color("81fff0"), "GOOD": Color("79dfe9"), "OK": Color("e6d995"), "MISS": Color("e281a3")}

var grid: GridPad
var kinds: Array[String] = ["", "", "", ""]
var ages := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var visuals_paused := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func show_judgment(cell: int, kind: String) -> void:
	if cell < 0 or cell > 3 or not DURATIONS.has(kind):
		return
	# A repeated note replaces its own effect instead of stacking over the next tap.
	kinds[cell] = kind
	ages[cell] = 0.0
	set_process(true)
	queue_redraw()


func clear() -> void:
	kinds.fill("")
	ages.fill(0.0)
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if visuals_paused:
		return
	var alive := false
	for cell in range(4):
		if kinds[cell].is_empty():
			continue
		ages[cell] += delta
		if ages[cell] >= float(DURATIONS[kinds[cell]]):
			kinds[cell] = ""
		else:
			alive = true
	queue_redraw()
	set_process(alive)


func _draw() -> void:
	if grid == null:
		return
	var font := get_theme_default_font()
	for cell in range(4):
		var kind := kinds[cell]
		if kind.is_empty():
			continue
		var rect := grid.cell_rect(cell)
		var center := rect.get_center()
		var width := rect.size.x
		var t := clampf(ages[cell] / float(DURATIONS[kind]), 0.0, 1.0)
		var opacity := 1.0 - smoothstep(0.2, 1.0, t)
		var color: Color = COLORS[kind]
		color.a = opacity
		var failed := kind == "MISS"
		if failed:
			_draw_corners(rect.grow(-width * 0.12), Color(color, opacity * 0.6))
		else:
			var radius := width * (0.24 + 0.14 * t)
			draw_arc(center, radius, -PI * 0.9, PI * 0.9, 48, Color(color, opacity * 0.33), 1.1, true)
			if kind == "PERFECT":
				for index in range(8):
					var direction := Vector2.from_angle(index * TAU / 8.0 + 0.2)
					draw_line(center + direction * width * (0.32 + t * 0.08), center + direction * width * (0.35 + t * 0.1), Color(color, opacity * 0.55), 1.0, true)
		var text_y := center.y
		if kind == "PERFECT":
			var check_center := center + Vector2(0, -width * 0.12)
			var points := PackedVector2Array([check_center + Vector2(-width * 0.09, 0), check_center + Vector2(-width * 0.025, width * 0.065), check_center + Vector2(width * 0.105, -width * 0.07)])
			draw_polyline(points, color, maxf(2.0, width * 0.025), true)
			text_y += width * 0.12
		var font_size := maxi(10, int(width * (0.125 if kind == "PERFECT" else 0.15)))
		var text_width := font.get_string_size(kind, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := Vector2(center.x - text_width * 0.5, text_y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
		draw_string(font, baseline, kind, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_corners(rect: Rect2, color: Color) -> void:
	var length := rect.size.x * 0.12
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var toward: Vector2 = (rect.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(toward.x * length, 0), color, 1.4, true)
		draw_line(corner, corner + Vector2(0, toward.y * length), color, 1.4, true)
