class_name GameHUD
extends Control

signal pause_requested

var score_label := AppStyle.label("000000", 30, Color("e7dff7"))
var combo_label := AppStyle.label("0", 30, Color("e7dff7"))
var progress := ProgressBar.new()
var pause_button := PauseIcon.new()
var auto_badge := AppStyle.label("AUTO", 12, AppStyle.MUTED)
var accent := GameGrid.VIOLET
var _fill: StyleBoxFlat
var _transition: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_button.position = Vector2(7, 1)
	pause_button.size = Vector2(76, 76)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	add_child(pause_button)
	score_label.position = Vector2(99, 72)
	score_label.size = Vector2(177, 44)
	score_label.add_theme_constant_override("outline_size", 0)
	var score_font := FontVariation.new()
	score_font.base_font = get_theme_default_font()
	score_font.spacing_glyph = 4
	score_label.add_theme_font_override("font", score_font)
	add_child(score_label)
	var caption := AppStyle.label("C O M B O", 14, Color("827b94"))
	caption.position = Vector2(332, 84)
	add_child(caption)
	combo_label.position = Vector2(422, 72)
	combo_label.size = Vector2(55, 44)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(combo_label)
	auto_badge.position = Vector2(455, 25)
	add_child(auto_badge)
	progress.position = Vector2(75, 133)
	progress.size = Vector2(390, 6)
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", _track_style(Color("393248")))
	_fill = _track_style(accent)
	_fill.shadow_color = Color(accent, 0.13)
	_fill.shadow_size = 5
	progress.add_theme_stylebox_override("fill", _fill)
	add_child(progress)
	progress.size = Vector2(390, 6)


func _track_style(color: Color) -> StyleBoxFlat:
	var style := AppStyle.box(color, 3)
	style.set_border_width_all(0)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 0.0)
	return style


func update_stats(session: RhythmSession) -> void:
	score_label.text = "%06d" % session.score
	combo_label.text = str(session.combo)


func set_phase(kind: String) -> void:
	if _transition != null:
		_transition.kill()
	_transition = create_tween()
	_transition.tween_method(_set_accent, accent, GameGrid.TEAL if kind == "response" else GameGrid.VIOLET, 0.16)


func _set_accent(value: Color) -> void:
	accent = value
	_fill.bg_color = accent
	_fill.shadow_color = Color(accent, 0.13)
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2(288, 81), Vector2(288, 114), Color("a69ab8"), 0.75, true)
	for index in range(55):
		var x := 134.0 + index * 2.1
		var alpha := float(index) / 55.0 * 0.65
		draw_line(Vector2(x, 37), Vector2(x + 2.1, 37), Color(accent, alpha), 0.75, true)
		draw_line(Vector2(540 - x, 37), Vector2(537.9 - x, 37), Color(accent, alpha), 0.75, true)
	var points := PackedVector2Array()
	for index in range(8):
		var angle := -PI * 0.5 + index * PI * 0.25
		var radius := 9.0 if index % 2 == 0 else 2.8
		points.append(Vector2(270, 37) + Vector2.from_angle(angle) * radius)
	draw_colored_polygon(points, accent)
