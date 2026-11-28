class_name HitVibrationControl
extends HBoxContainer

var slider := HSlider.new()
var value_label := AppStyle.label("", 14, AppStyle.MUTED)


func _init(feedback: HitVibration, preferences_path: String) -> void:
	var caption := AppStyle.label("입력 진동 강도", 16, AppStyle.MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(caption)
	slider.max_value = 100
	slider.step = 1
	slider.value = feedback.strength_percent
	slider.custom_minimum_size = Vector2(130, 76)
	slider.focus_mode = Control.FOCUS_NONE
	add_child(slider)
	value_label.text = "%d%%" % roundi(slider.value)
	value_label.custom_minimum_size.x = 46
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(value_label)
	slider.value_changed.connect(_change_strength.bind(feedback, preferences_path))


func _change_strength(value: float, feedback: HitVibration, preferences_path: String) -> void:
	feedback.strength_percent = value
	value_label.text = "%d%%" % roundi(value)
	var settings := ConfigFile.new()
	settings.load(preferences_path)
	settings.set_value("haptics", "strength_percent", feedback.strength_percent)
	settings.save(preferences_path)
