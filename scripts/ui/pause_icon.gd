class_name PauseIcon
extends Button


func _ready() -> void:
	text = ""
	tooltip_text = "일시정지"
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", AppStyle.box(Color("242033"), 12))


func _draw() -> void:
	var center := size * 0.5
	var color := Color("eae5f6")
	for x in [-5.0, 5.0]:
		draw_style_box(AppStyle.box(color, 2), Rect2(center + Vector2(x - 1.6, -8), Vector2(3.2, 16)))
