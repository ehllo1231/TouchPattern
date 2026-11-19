class_name GameGrid
extends GridPad

const TILE_SHADER = preload("res://scripts/ui/game_tile.gdshader")
const VIOLET := Color("bb92f5")
const TEAL := Color("65eee0")
const STRENGTH := {"PERFECT": 1.0, "GOOD": 0.67, "OK": 0.43, "MISS": 0.32, "WRONG": 0.32}

var accent := VIOLET
var feedback := TileFeedback.new()
var visuals_paused := false:
	set(value):
		visuals_paused = value
		feedback.visuals_paused = value
var _tiles: Array[ColorRect] = []
var _hit_colors: Array[Color] = [VIOLET, VIOLET, VIOLET, VIOLET]
var _judgment_mode: Array[bool] = [false, false, false, false]
var _decay := PackedFloat32Array([3.5, 3.5, 3.5, 3.5])
var _activation := 0.0


func _ready() -> void:
	super._ready()
	show_keys = false
	_hit_colors.fill(accent)
	for cell in range(4):
		var tile := ColorRect.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = TILE_SHADER
		shader_material.set_shader_parameter("accent", accent)
		tile.material = shader_material
		add_child(tile)
		_tiles.append(tile)
	feedback.grid = self
	add_child(feedback)
	resized.connect(_layout_tiles)
	_layout_tiles()
	_update_materials()
	set_process(false)


func cell_rect(cell: int) -> Rect2:
	var side := minf(size.x, size.y)
	var gap := side * 0.034
	var width := (side - gap) * 0.5
	var origin := (size - Vector2.ONE * side) * 0.5
	return Rect2(origin + Vector2(cell % 2, cell / 2) * (width + gap), Vector2.ONE * width)


func _layout_tiles() -> void:
	for cell in range(_tiles.size()):
		var rect := cell_rect(cell)
		_tiles[cell].position = rect.position - Vector2.ONE * 20.0
		_tiles[cell].size = rect.size + Vector2.ONE * 40.0
		_tiles[cell].material.set_shader_parameter("tile_size", rect.size)
	feedback.size = size
	feedback.queue_redraw()


func set_active(value: bool) -> void:
	if emphasis == value:
		return
	emphasis = value
	set_process(true)


func flash(cell: int, failed: bool = false, strength: float = 1.0) -> void:
	if cell < 0 or cell > 3:
		return
	_glow[cell] = clampf(strength, 0.0, 1.0)
	_failed[cell] = 1.0 if failed else 0.0
	_hit_colors[cell] = AppStyle.RED if failed else accent
	_judgment_mode[cell] = false
	_decay[cell] = 3.5
	_update_materials()
	set_process(true)


func show_judgment(cell: int, kind: String) -> void:
	if cell < 0 or cell > 3 or not STRENGTH.has(kind):
		return
	flash(cell, kind in ["MISS", "WRONG"], float(STRENGTH[kind]))
	_hit_colors[cell] = TileFeedback.COLORS[kind]
	_judgment_mode[cell] = true
	_decay[cell] = float(STRENGTH[kind]) * 3.5
	_update_materials()
	feedback.show_judgment(cell, kind)


func clear() -> void:
	super.clear()
	feedback.clear()
	_update_materials()


func _process(delta: float) -> void:
	if visuals_paused:
		return
	# Only the presentation interpolates. Note and judgment events remain immediate.
	_activation = move_toward(_activation, 1.0 if emphasis else 0.0, delta / 0.16)
	for cell in range(4):
		_glow[cell] = maxf(0.0, _glow[cell] - delta * _decay[cell])
	_update_materials()
	if _glow.count(0.0) == 4 and is_equal_approx(_activation, 1.0 if emphasis else 0.0):
		set_process(false)


func _update_materials() -> void:
	for cell in range(_tiles.size()):
		var shader_material := _tiles[cell].material as ShaderMaterial
		shader_material.set_shader_parameter("activation", _activation)
		shader_material.set_shader_parameter("flash", _glow[cell])
		shader_material.set_shader_parameter("hit_color", _hit_colors[cell])
		shader_material.set_shader_parameter("judgment_mode", _judgment_mode[cell])


func _draw() -> void:
	# Tile surfaces and judgments have their own layers; no permanent tile labels.
	pass


func _gui_input(event: InputEvent) -> void:
	# Menus use Godot's normal touch-to-mouse support. The grid receives raw
	# multitouch in GridPad._input, so its emulated mouse must not hit twice.
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		accept_event()
		return
	super._gui_input(event)
