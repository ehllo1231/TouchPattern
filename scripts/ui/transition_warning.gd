class_name TransitionWarning
extends Control

const LEAD_BEATS := GuiLayout.WARNING_LEAD_BEATS
const ORANGE := Color("ff9165")
const TUBE_MASK := preload("res://assets/ui/transition_warning.svg")
const NEON_SHADER := preload("res://scripts/ui/transition_warning.gdshader")

var flicker_beats := 0.4
var flicker_depth := 0.65
var gap_beats := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var neon := ShaderMaterial.new()
	neon.shader = NEON_SHADER
	material = neon
	resized.connect(queue_redraw)
	hide()


func configure(layout: GuiLayout, grid: Rect2) -> void:
	size = Vector2(layout.warning_size, layout.warning_size * 0.875)
	position = Vector2(grid.get_center().x - size.x / 2.0, maxf(144.0, grid.position.y - size.y - 18.0))
	flicker_beats = layout.warning_flicker_beats
	flicker_depth = layout.warning_flicker_percent / 100.0
	gap_beats = layout.warning_gap_beats


func show_at(elapsed_beats: float, available_beats: float, accent: Color) -> void:
	# The gap is measured back from the next demo, including any chart rest.
	var duration_beats := minf(available_beats, LEAD_BEATS - gap_beats)
	if elapsed_beats < 0.0 or elapsed_beats >= duration_beats:
		hide()
		return
	# A rest can shorten the visible warning. Fit both flickers inside it.
	var edge_beats := minf(flicker_beats, duration_beats * 0.5)
	var remaining := duration_beats - elapsed_beats
	var intensity := 1.0
	if elapsed_beats < edge_beats:
		var t := elapsed_beats / edge_beats
		# A short strike, one voltage dip, then a decisive ignition and settle.
		var strike := 0.65 * smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.18, 0.32, t))
		var ignition := 0.8 * smoothstep(0.52, 0.68, t) + 0.2 * smoothstep(0.68, 1.0, t)
		intensity = lerpf(1.0 - flicker_depth, 1.0, strike + ignition)
	elif remaining < edge_beats and flicker_depth > 0.0:
		var t := 1.0 - remaining / edge_beats
		# One dip and a weaker last spark before the tube goes dark.
		var dip := smoothstep(0.0, 0.27, t)
		var spark := 0.72 * smoothstep(0.32, 0.54, t)
		intensity = (1.0 - flicker_depth * (dip - spark)) * (1.0 - smoothstep(0.58, 1.0, t))
	self_modulate = Color(accent, intensity)
	show()


func _draw() -> void:
	# The SVG has 12 design pixels of transparent bleed on each side of its
	# 48px glyph. Paint beyond the control so the saved size still sizes the tube.
	draw_texture_rect(TUBE_MASK, Rect2(Vector2.ZERO, size).grow(size.x * 0.25), false)
