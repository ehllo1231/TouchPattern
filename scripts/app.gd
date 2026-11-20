extends Control

# Diagnostics and explicit chart launches can still enter the player directly.
var skip_frontend := false
var current_view: Control


func _ready() -> void:
	theme = AppStyle.make_theme()
	if OS.has_feature("mobile"):
		get_tree().quit_on_go_back = false
	var args := OS.get_cmdline_user_args()
	var chart_path := TouchChart.SAMPLE
	var chart_index := args.find("--chart")
	if chart_index >= 0 and chart_index + 1 < args.size():
		chart_path = args[chart_index + 1]
	if args.has("--chart-maker"):
		get_tree().root.content_scale_size = Vector2i(480, 900)
		DisplayServer.window_set_min_size(Vector2i(1000, 740))
		DisplayServer.window_set_size(Vector2i(1100, 900))
		var maker := ChartMaker.new()
		maker.initial_path = chart_path
		maker.remember_recent_chart = true
		maker.restore_recent_chart = chart_index < 0
		DisplayServer.window_set_title("RINNER · Chart Maker")
		_replace_view(maker)
	elif skip_frontend or chart_index >= 0 or args.has("--autoplay") or args.has("--auto-mode") or args.has("--start-phrase"):
		var player := PlayerView.new()
		player.initial_path = chart_path
		player.autoplay = args.has("--autoplay")
		player.auto_mode = args.has("--auto-mode")
		var start_index := args.find("--start-phrase")
		if start_index >= 0 and start_index + 1 < args.size() and args[start_index + 1].is_valid_int():
			player.initial_phrase = int(args[start_index + 1])
		DisplayServer.window_set_title("RINNER")
		_replace_view(player)
	else:
		_show_front()


func _show_front(songs: bool = false) -> void:
	DisplayServer.window_set_title("RINNER")
	var front := FrontMenu.new()
	front.play_requested.connect(_play_song)
	_replace_view(front)
	if songs:
		front.show_library(false)


func _play_song(path: String) -> void:
	var player := PlayerView.new()
	player.initial_path = path
	player.autoplay = true
	player.show_song_select = true
	player.song_select_requested.connect(func() -> void: _show_front.call_deferred(true))
	_replace_view(player)


func _replace_view(view: Control) -> void:
	if is_instance_valid(current_view):
		if current_view is PlayerView:
			current_view.clock.stop()
			current_view.note_sounds.stop()
		remove_child(current_view)
		current_view.queue_free()
	current_view = view
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if current_view is PlayerView:
		if current_view.state == "paused":
			current_view._toggle()
		else:
			current_view._pause()
	elif current_view is FrontMenu:
		if current_view.screen == "songs":
			current_view.show_title()
		elif not current_view._switching:
			get_tree().quit()
