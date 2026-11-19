class_name TimingReadout
extends Control

var value_label := AppStyle.label("", 23, Color("e7dfef"))
var unit_label := AppStyle.label("ms", 11, Color("9b8faa"))
var direction_label := AppStyle.label("", 10)
var error_ms := 0.0
var has_timing := false
var accent := GameGrid.TEAL
var visuals_paused := false:
	set(value):
		visuals_paused = value
		if _fade != null and _fade.is_valid():
			if value:
				_fade.pause()
			else:
				_fade.play()
var _fade: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.size = Vector2(260, 34)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	center.add_child(row)
	row.add_child(value_label)
	row.add_child(unit_label)
	unit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	direction_label.position = Vector2(0, 32)
	direction_label.size = Vector2(260, 14)
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(direction_label)
	for label in [value_label, unit_label, direction_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_judgment(kind: String, offset: float) -> void:
	error_ms = offset
	has_timing = kind in ["PERFECT", "GOOD", "OK"]
	if has_timing:
		var displayed := snappedf(offset, 0.1)
		if is_zero_approx(displayed):
			displayed = 0.0
		value_label.text = ("%+.1f" % displayed).replace("-", "−")
		direction_label.text = "EARLY" if displayed < 0.0 else ("LATE" if displayed > 0.0 else "ON TIME")
		accent = GameGrid.VIOLET if displayed < 0.0 else GameGrid.TEAL
	else:
		# A missed note or wrong cell has no matched input offset.
		value_label.text = "—"
		direction_label.text = "NO TIMING"
		accent = AppStyle.RED
	direction_label.add_theme_color_override("font_color", accent)
	if _fade != null:
		_fade.kill()
	modulate.a = 1.0
	show()
	queue_redraw()
	_fade = create_tween()
	_fade.tween_interval(0.45)
	_fade.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade.tween_callback(hide)
	if visuals_paused:
		_fade.pause()


func clear() -> void:
	if _fade != null:
		_fade.kill()
	value_label.text = ""
	direction_label.text = ""
	error_ms = 0.0
	has_timing = false
	hide()


func _draw() -> void:
	var style := AppStyle.box(Color(0.085, 0.075, 0.125, 0.78), 12, Color(accent, 0.18))
	style.shadow_color = Color(accent, 0.055)
	style.shadow_size = 7
	draw_style_box(style, Rect2(48, 0, 164, 47))
	draw_line(Vector2(60, 53), Vector2(200, 53), Color("45394e"), 0.8, true)
	draw_line(Vector2(130, 50), Vector2(130, 56), Color("9686a9"), 0.8, true)
	if has_timing:
		var marker := 130.0 + clampf(error_ms / (RhythmSession.WINDOW * 1000.0), -1.0, 1.0) * 70.0
		draw_circle(Vector2(marker, 53), 2.3, accent, true, -1.0, true)
