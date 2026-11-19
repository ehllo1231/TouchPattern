class_name NoteVolumeControl
extends HBoxContainer

var slider := HSlider.new()
var value_label := AppStyle.label("", 12, AppStyle.MUTED)


func _init(feedback: NoteSounds) -> void:
	add_theme_constant_override("separation", 6)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(96, 24)
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.tooltip_text = "박수 소리 음량 (0~100%)"
	add_child(slider)
	value_label.custom_minimum_size.x = 36
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(value_label)
	_update_value(feedback.volume_percent)
	slider.value_changed.connect(feedback.set_volume_percent)
	feedback.volume_changed.connect(_update_value)


func _update_value(percent: float) -> void:
	slider.set_value_no_signal(percent)
	value_label.text = "%d%%" % roundi(percent)
