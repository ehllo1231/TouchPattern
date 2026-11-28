class_name TransitionWarning
extends Control

const LEAD_BEATS := GuiLayout.WARNING_LEAD_BEATS
const ORANGE := Color("ff9165")
const TUBE_MASK := preload("res://assets/ui/transition_warning.svg")
const NEON_SHADER := preload("res://scripts/ui/transition_warning.gdshader")

var flicker_beats := 0.4
var flicker_depth := 0.65
var gap_beats := 1.0
var _neon := ShaderMaterial.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_neon.shader = NEON_SHADER
	material = _neon
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
	var halo_power := 1.0
	var core_only := false
	if elapsed_beats < edge_beats:
		var t := elapsed_beats / edge_beats
		# A short strike, one voltage dip, then a decisive ignition and settle.
		var strike := 0.65 * smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.18, 0.32, t))
		var ignition := 0.8 * smoothstep(0.52, 0.68, t) + 0.2 * smoothstep(0.68, 1.0, t)
		intensity = lerpf(1.0 - flicker_depth, 1.0, strike + ignition)
		halo_power = pow(intensity, 5.0)
	elif remaining < edge_beats and flicker_depth > 0.0:
		var t := 1.0 - remaining / edge_beats
		if t < 0.67:
			# Hold the first interruption long enough to read, then relight the whole tube.
			var dim := pow(1.0 - flicker_depth, 3.0)
			intensity = lerpf(1.0, dim, smoothstep(0.03, 0.16, t))
			intensity += (1.0 - dim) * 0.78 * smoothstep(0.34, 0.44, t)
			intensity *= 1.0 - smoothstep(0.56, 0.67, t)
			halo_power = intensity * intensity
		else:
			# A shorter, weaker restrike catches only the white center of the tube mask.
			core_only = true
			halo_power = 0.0
			intensity = 0.58 * flicker_depth * smoothstep(0.72, 0.78, t) * (1.0 - smoothstep(0.86, 0.94, t))
	_neon.set_shader_parameter(&"halo_power", halo_power)
	_neon.set_shader_parameter(&"core_only", core_only)
	self_modulate = Color(accent, intensity)
	show()


func _draw() -> void:
	# The SVG has 12 design pixels of transparent bleed on each side of its
	# 48px glyph. Paint beyond the control so the saved size still sizes the tube.
	draw_texture_rect(TUBE_MASK, Rect2(Vector2.ZERO, size).grow(size.x * 0.25), false)
