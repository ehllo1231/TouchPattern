class_name GuiLayout
extends Resource

const PATH := "res://assets/ui/gui_layout.tres"
const DEFAULT_GRID_SIZE := 260.0
const MIN_GRID_SIZE := 180.0
const MAX_GRID_SIZE := 320.0
const WARNING_LEAD_BEATS := 2.0
const BEAT_COLORS := {4: &"four_beat_color", 2: &"two_beat_color", 1: &"one_beat_color"}

@export_color_no_alpha var four_beat_color := GameGrid.VIOLET
@export_color_no_alpha var two_beat_color := GameGrid.CORAL
@export_color_no_alpha var one_beat_color := Color("#d9698b")

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


static func palette_beats(length: float) -> int:
	var beats := roundi(length)
	return beats if BEAT_COLORS.has(beats) and is_equal_approx(length, beats) else 0


func demo_color(length: float) -> Color:
	return get(BEAT_COLORS.get(palette_beats(length), &"four_beat_color"))
