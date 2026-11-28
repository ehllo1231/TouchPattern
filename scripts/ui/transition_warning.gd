class_name TransitionWarning
extends TextureRect

const LEAD_BEATS := 2.0
const ORANGE := Color("ff9165")

var flicker_beats := 0.35
var flicker_depth := 0.65


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture = preload("res://assets/ui/transition_warning.svg")
	hide()


func configure(layout: GuiLayout, grid: Rect2) -> void:
	size = Vector2(layout.warning_size, layout.warning_size * 0.875)
	position = Vector2(grid.get_center().x - size.x / 2.0, maxf(144.0, grid.position.y - size.y - 18.0))
	flicker_beats = layout.warning_flicker_beats
	flicker_depth = layout.warning_flicker_percent / 100.0


func show_at(elapsed_beats: float, accent: Color) -> void:
	if elapsed_beats < 0.0 or elapsed_beats >= LEAD_BEATS:
		hide()
		return
	var intensity := 1.0
	if elapsed_beats < flicker_beats:
		var t := elapsed_beats / flicker_beats
		# Two brief dips at onset, then a continuous light. Only the glyph flickers.
		var pulse := 0.5 + 0.5 * cos(TAU * 2.0 * t)
		intensity -= flicker_depth * pulse * (1.0 - t)
	self_modulate = Color(accent, intensity)
	show()
