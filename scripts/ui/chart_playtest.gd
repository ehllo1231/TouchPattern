extends PlayerView

var _listen_end := 0.0


func _init() -> void:
	preview_mode = true


func _ready() -> void:
	super._ready()
	hud.pause_button.hide()
	set_process_unhandled_key_input(true)


func begin(listening_session: RhythmSession, start: float, end: float) -> void:
	chart = listening_session.chart
	_start_seconds = start
	_listen_end = end
	_last_time = start - 0.000001
	apply_gui_layout(GuiLayout.read(gui_layout_path))
	_reset_session(listening_session)
	state = "playing"
	input_pad.interactive = not auto_mode
	progress.value = 0.0


func advance_to(time: float) -> void:
	if state == "playing":
		_advance_gameplay(time)
		progress.value = 100.0 * inverse_lerp(_start_seconds, _listen_end, time) if _listen_end > _start_seconds else 100.0


func stop_listening() -> void:
	if state == "playing":
		state = "paused"
		input_pad.interactive = false
		demo_pad.visuals_paused = true
		input_pad.visuals_paused = true
		timing_readout.visuals_paused = true


func set_auto(enabled: bool) -> void:
	auto_mode = enabled
	hud.auto_badge.visible = enabled
	input_pad.interactive = state == "playing" and not enabled


func _press(cell: int, event: InputEvent = null) -> void:
	if clock.running and clock.seconds() < _listen_end:
		super._press(cell, event)
