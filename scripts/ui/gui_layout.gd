class_name GuiLayout
extends Resource

const PATH := "res://assets/ui/gui_layout.tres"
const DEFAULT_GRID_SIZE := 260.0
const MIN_GRID_SIZE := 180.0
const MAX_GRID_SIZE := 320.0
const WARNING_LEAD_BEATS := 2.0

@export_range(180, 320, 1) var demo_grid_size := DEFAULT_GRID_SIZE:
	set(value):
		demo_grid_size = _safe_size(value)
@export_range(180, 320, 1) var play_grid_size := DEFAULT_GRID_SIZE:
	set(value):
		play_grid_size = _safe_size(value)
@export_range(24, 64, 1) var warning_size := 48.0:
	set(value):
		warning_size = clampf(value, 24.0, 64.0) if is_finite(value) else 48.0
@export_range(0, 1, 0.05) var warning_flicker_beats := 0.4:
	set(value):
		warning_flicker_beats = clampf(value, 0.0, 1.0) if is_finite(value) else 0.4
@export_range(0, 100, 1) var warning_flicker_percent := 65.0:
	set(value):
		warning_flicker_percent = clampf(value, 0.0, 100.0) if is_finite(value) else 65.0
@export_range(0, WARNING_LEAD_BEATS, 0.05) var warning_gap_beats := 1.0:
	set(value):
		warning_gap_beats = clampf(value, 0.0, WARNING_LEAD_BEATS) if is_finite(value) else 1.0


static func read(path: String = PATH) -> GuiLayout:
	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GuiLayout
		if resource != null:
			return resource
	return GuiLayout.new()


static func _safe_size(value: float) -> float:
	return clampf(value, MIN_GRID_SIZE, MAX_GRID_SIZE) if is_finite(value) else DEFAULT_GRID_SIZE
