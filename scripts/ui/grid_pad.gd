class_name GridPad
extends Control

signal cell_pressed(cell: int)

var interactive := false
var show_keys := false
var emphasis := false
var outline_only := false
var _glow := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _failed := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func cell_rect(cell: int) -> Rect2:
	var gap := 10.0
	var side := minf(size.x, size.y)
	var width := (side - gap) / 2.0
	var origin := (size - Vector2.ONE * side) / 2.0
	return Rect2(origin + Vector2(cell % 2, cell / 2) * (width + gap), Vector2.ONE * width)


func flash(cell: int, failed: bool = false, strength: float = 1.0) -> void:
	if cell < 0 or cell > 3:
		return
	_glow[cell] = maxf(_glow[cell], clampf(strength, 0.0, 1.0))
	_failed[cell] = 1.0 if failed else 0.0
	queue_redraw()


func clear() -> void:
	_glow.fill(0.0)
	_failed.fill(0.0)
	queue_redraw()


func _process(delta: float) -> void:
	for cell in range(4):
		_glow[cell] = maxf(0.0, _glow[cell] - delta * 3.5)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	for cell in range(4):
		var rect := cell_rect(cell)
		var tint: Color = AppStyle.RED if _failed[cell] > 0.5 else AppStyle.CELLS[cell]
		var fill := Color("142131").lerp(tint, _glow[cell] * (0.12 if outline_only else 0.8))
		var border := AppStyle.LINE.lerp(tint, 0.45 if emphasis else 0.1)
		var style := AppStyle.box(fill, 15, border.lerp(tint, _glow[cell]))
		if outline_only and _glow[cell] > 0.0:
			style.set_border_width_all(3)
			style.border_color = border.lerp(AppStyle.TEXT, _glow[cell])
		draw_style_box(style, rect)
		var text: String = AppStyle.KEYS[cell] if show_keys else "%02d" % (cell + 1)
		var font_size := 24 if show_keys else 15
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var position := rect.get_center() + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) / 2.0 - 2.0)
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint if outline_only or _glow[cell] < 0.5 else AppStyle.BG)


func _press_at(position: Vector2) -> void:
	if not interactive:
		return
	for cell in range(4):
		if cell_rect(cell).has_point(position):
			cell_pressed.emit(cell)
			return


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press_at(event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	if interactive and event is InputEventScreenTouch and event.pressed and not event.canceled:
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(Vector2.ZERO, size).has_point(local_position):
			_press_at(local_position)
			get_viewport().set_input_as_handled()
