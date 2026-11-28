class_name GuiLayout
extends Resource

const PATH := "res://assets/ui/gui_layout.tres"
const DEFAULT_GRID_SIZE := 260.0
const MIN_GRID_SIZE := 180.0
const MAX_GRID_SIZE := 320.0

@export_range(180, 320, 1) var demo_grid_size := DEFAULT_GRID_SIZE:
	set(value):
		demo_grid_size = _safe_size(value)
@export_range(180, 320, 1) var play_grid_size := DEFAULT_GRID_SIZE:
	set(value):
		play_grid_size = _safe_size(value)


static func read(path: String = PATH) -> GuiLayout:
	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GuiLayout
		if resource != null:
			return resource
	return GuiLayout.new()


static func _safe_size(value: float) -> float:
	return clampf(value, MIN_GRID_SIZE, MAX_GRID_SIZE) if is_finite(value) else DEFAULT_GRID_SIZE
