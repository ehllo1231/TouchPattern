class_name FrontArtwork
extends Control

var cover := false
var variant := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not cover:
		var breath := create_tween().set_loops()
		breath.tween_property(self, "modulate:a", 0.78, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breath.tween_property(self, "modulate:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var unit := minf(size.x, size.y)
	var violet := GameGrid.VIOLET
	var teal := GameGrid.TEAL
	if cover and variant == 1:
		_draw_loop(center, unit * 0.68, teal, 0.25, 0.0)
		_draw_loop(center, unit * 0.48, violet, 0.3, 0.0)
		var bolt := PackedVector2Array()
		for point in [Vector2(0.13, -0.28), Vector2(-0.16, 0.025), Vector2(0.04, 0.025), Vector2(-0.11, 0.29)]:
			bolt.append(center + point * unit)
		draw_polyline(bolt, Color(teal, 0.1), 10.0, true)
		draw_polyline(bolt, Color(teal, 0.9), 1.8, true)
	elif cover:
		# The same loop motif descends into the cover's vanishing point.
		for index in range(6):
			var depth := float(index) / 5.0
			var side := unit * lerpf(0.63, 0.10, depth)
			var origin := center + Vector2(0, lerpf(-unit * 0.08, unit * 0.15, depth))
			var color := violet.lerp(teal, depth)
			_draw_loop(origin, side, color, 0.18 + depth * 0.3, 0.0)
		_diamond(center + Vector2(0, unit * 0.1533), unit * 0.0167, Color(teal, 0.95))
		for index in range(48):
			var alpha := float(index) / 48.0 * 0.19
			draw_line(Vector2(24 + index * 2, size.y - 32), Vector2(26 + index * 2, size.y - 32), Color(violet, alpha), 0.8, true)
	else:
		var radius := unit * 0.43
		for index in range(128):
			var angle := float(index) / 128.0 * TAU
			var next := float(index + 1) / 128.0 * TAU
			var alpha := 0.035 + pow(absf(sin(angle)), 18.0) * 0.24
			draw_line(center + Vector2.from_angle(angle) * radius, center + Vector2.from_angle(next) * radius, Color(violet.lerp(teal, float(index) / 128.0), alpha), 0.85, true)
		_draw_loop(center, unit * 0.44, violet, 0.64, 12.0)
		_draw_loop(center, unit * 0.32, violet.lerp(teal, 0.35), 0.28, 0.0)
		var tile_side := unit * 0.1
		var gap := unit * 0.025
		for cell in range(4):
			var position := center - Vector2.ONE * (tile_side + gap * 0.5) + Vector2(cell % 2, cell / 2) * (tile_side + gap)
			var color := violet if cell < 2 else teal
			var style := AppStyle.box(Color(color, 0.11 if cell != 1 else 0.42), 7, Color(color, 0.8))
			style.shadow_color = Color(color, 0.16 if cell == 1 else 0.04)
			style.shadow_size = 12
			draw_style_box(style, Rect2(position, Vector2.ONE * tile_side))
		_diamond(center + Vector2.UP * radius, 4.0, violet)
		_diamond(center + Vector2.DOWN * radius, 4.0, teal)


func _draw_loop(center: Vector2, side: float, color: Color, opacity: float, glow: float) -> void:
	var half := side * 0.5
	var radius := side * 0.17
	var points := PackedVector2Array()
	var corners := [Vector2(half - radius, -half + radius), Vector2(half - radius, half - radius), Vector2(-half + radius, half - radius), Vector2(-half + radius, -half + radius)]
	for corner in range(4):
		for step in range(13):
			var angle := -PI * 0.5 + corner * PI * 0.5 + float(step) / 12.0 * PI * 0.5
			var point: Vector2 = corners[corner] + Vector2.from_angle(angle) * radius
			points.append(center + point.rotated(PI * 0.25))
	points.append(points[0])
	draw_colored_polygon(points, Color(color, 0.012))
	if glow > 0.0:
		draw_polyline(points, Color(color, 0.025), glow, true)
		draw_polyline(points, Color(color, 0.04), glow * 0.5, true)
	draw_polyline(points, Color(color, opacity), 1.0, true)


func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2.UP * radius, center + Vector2.RIGHT * radius, center + Vector2.DOWN * radius, center + Vector2.LEFT * radius]), color)
