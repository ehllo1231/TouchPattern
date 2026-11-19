class_name StageDecor
extends Control

var accent := GameGrid.VIOLET
var _transition: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_phase(kind: String) -> void:
	var target := GameGrid.TEAL if kind == "response" else GameGrid.VIOLET
	if _transition != null:
		_transition.kill()
	_transition = create_tween()
	_transition.tween_method(_set_accent, accent, target, 0.16)


func _set_accent(value: Color) -> void:
	accent = value
	queue_redraw()


func _draw() -> void:
	# A quiet orbit, three small diamonds, and the reference's bottom waveform.
	var center := Vector2(270, 403)
	for segment in range(100):
		var angle := TAU * float(segment) / 100.0
		var next := TAU * float(segment + 1) / 100.0
		var alpha := 0.035 + pow(absf(cos(angle)), 22.0) * 0.28
		draw_line(center + Vector2.from_angle(angle) * 238.0, center + Vector2.from_angle(next) * 238.0, Color(accent, alpha), 0.85, true)
	for x in [32.0, 508.0]:
		_diamond(Vector2(x, 403), 4.2, Color(accent, 0.85))
	for index in range(3):
		_diamond(Vector2(270, 530 + index * 13), 3.6 - index * 0.7, Color(accent, 0.9 - index * 0.32))
	for index in range(70):
		var opacity := float(index) / 70.0 * 0.6
		var x := 80.0 + index * 2.0
		draw_line(Vector2(x, 908), Vector2(x + 2.0, 908), Color(accent, opacity), 0.8, true)
		draw_line(Vector2(540 - x, 908), Vector2(538 - x, 908), Color(accent, opacity), 0.8, true)
	for index in range(-3, 4):
		var half_height: float = [13.0, 8.0, 4.0, 1.0][absi(index)]
		var x := 270.0 + index * 11.0
		draw_line(Vector2(x, 908 - half_height), Vector2(x, 908 + half_height), Color(accent, 0.72), 1.6, true)


func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2.UP * radius, center + Vector2.RIGHT * radius, center + Vector2.DOWN * radius, center + Vector2.LEFT * radius]), color)
