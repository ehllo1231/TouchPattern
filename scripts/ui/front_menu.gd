class_name FrontMenu
extends Control

signal play_requested(chart_path: String)

const DESIGN_SIZE := Vector2(540, 960)
const BACKDROP_SHADER = preload("res://scripts/ui/game_backdrop.gdshader")

var initial_chart := ""
var screen := "title"
var tracks: Array[Dictionary] = []
var track_buttons: Array[Button] = []
var stage := Control.new()
var title_view := Control.new()
var library_view := Control.new()
var title_touch := Button.new()
var back_button := Button.new()
var title_logo: Label
var track_titles: Array[Label] = []
var selected_track := 0
var _switching := false
var _transition: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BACKDROP_SHADER
	background.material = shader_material
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.name = "FrontStage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	for view in [title_view, library_view]:
		view.size = DESIGN_SIZE
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(view)
	if initial_chart.is_empty():
		tracks = SongLibrary.tracks()
	else:
		tracks.append(SongLibrary.track(initial_chart))
	_build_title()
	_build_library()
	library_view.hide()
	# The title's entire viewport is a touch target, including tall/wide margins.
	_flat_button(title_touch)
	add_child(title_touch)
	title_touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_touch.pressed.connect(show_library)
	resized.connect(_layout_ui)
	_layout_ui()


func _build_title() -> void:
	_label(title_view, "MEMORY  /  RHYTHM", Rect2(70, 116, 400, 30), 12, Color("8d819f"), 3)
	var art := FrontArtwork.new()
	art.position = Vector2(100, 207)
	art.size = Vector2(340, 340)
	title_view.add_child(art)
	title_logo = _label(title_view, "RINNER", Rect2(35, 553, 470, 95), 63, Color("ede5fa"), 9, 300)
	var prompt := _label(title_view, "TOUCH TO BEGIN", Rect2(70, 769, 400, 36), 12, Color("b6a9c8"), 3)
	var breath := create_tween().set_loops()
	breath.tween_property(prompt, "modulate:a", 0.45, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(prompt, "modulate:a", 1.0, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_footer(title_view)


func _build_library() -> void:
	_flat_button(back_button)
	back_button.position = Vector2(20, 25)
	back_button.size = Vector2(80, 80)
	back_button.text = "‹"
	back_button.tooltip_text = "타이틀로"
	back_button.add_theme_font_size_override("font_size", 36)
	back_button.add_theme_color_override("font_color", Color("c0b3d2"))
	back_button.pressed.connect(show_title)
	library_view.add_child(back_button)
	_label(library_view, "RINNER", Rect2(150, 45, 240, 40), 20, Color("d7c8e9"), 5, 350)
	_label(library_view, "곡 선택", Rect2(44, 154, 452, 54), 34, Color("eee7f8"), 0, 400).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label(library_view, "SELECT A TRACK", Rect2(44, 213, 350, 28), 11, Color("8a7d9a"), 3).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label(library_view, "%02d TRACKS" % tracks.size(), Rect2(378, 213, 118, 28), 11, Color("9a8aa9"), 1).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index in range(tracks.size()):
		_build_track_card(index)
	_footer(library_view)


func _build_track_card(index: int) -> void:
	var entry: Dictionary = tracks[index]
	var accent := GameGrid.TEAL if entry.get("id", "") == "electric_dreams" else GameGrid.VIOLET
	var button := Button.new()
	button.name = str(entry.title).replace(" ", "")
	button.position = Vector2(44, 270 + index * 256)
	button.size = Vector2(452, 236)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = str(entry.title) + " 플레이"
	for button_state in ["normal", "hover", "pressed", "disabled"]:
		var border := Color("51405f")
		var fill := Color("191622")
		if button_state == "hover":
			border = accent
			fill = Color("211b30")
		elif button_state == "pressed":
			border = GameGrid.TEAL
		button.add_theme_stylebox_override(button_state, AppStyle.box(fill, 22, border))
	button.add_theme_stylebox_override("focus", AppStyle.box(Color(0, 0, 0, 0), 22, accent))
	button.pressed.connect(_play_track.bind(index))
	button.focus_entered.connect(func() -> void: selected_track = index)
	library_view.add_child(button)
	track_buttons.append(button)
	var cover := Panel.new()
	cover.position = Vector2(12, 12)
	cover.size = Vector2(140, 212)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover_style := AppStyle.box(Color("14121f"), 14)
	cover_style.set_border_width_all(0)
	cover.add_theme_stylebox_override("panel", cover_style)
	button.add_child(cover)
	var art := FrontArtwork.new()
	art.cover = true
	art.variant = 1 if entry.get("id", "") == "electric_dreams" else 0
	art.size = cover.size
	cover.add_child(art)
	_label(cover, "%02d" % (index + 1), Rect2(13, 12, 80, 24), 11, Color("8d7d9f"), 2).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var title := _label(button, str(entry.title), Rect2(174, 28, 250, 80), 24, Color("eee7fa"), 0, 450)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	track_titles.append(title)
	if str(entry.error).is_empty():
		var duration := int(ceil(float(entry.duration)))
		_label(button, "%s BPM" % str(entry.bpm), Rect2(174, 116, 250, 28), 14, Color("a69bb7")).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label(button, "%02d:%02d    ·    %d 패턴" % [duration / 60, duration % 60, int(entry.phrases)], Rect2(174, 146, 250, 28), 13, Color("8d819f")).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label(button, "터치해서 플레이", Rect2(174, 189, 200, 28), 12, accent).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label(button, "↗", Rect2(380, 180, 44, 40), 25, accent)
	else:
		var error := _label(button, str(entry.error), Rect2(174, 116, 250, 90), 12, AppStyle.RED)
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = true


func _label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color, spacing: int = 0, weight: int = 400) -> Label:
	var label := AppStyle.label(text, font_size, color)
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): float(weight)}
	font.spacing_glyph = spacing
	label.add_theme_font_override("font", font)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _flat_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for button_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(button_state, StyleBoxEmpty.new())


func _footer(parent: Control) -> void:
	var line := HSeparator.new()
	line.position = Vector2(208, 891)
	line.size = Vector2(124, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxLine.new()
	style.color = Color("493653")
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	parent.add_child(line)
	_label(parent, "R I N N E R", Rect2(140, 907, 260, 24), 9, Color("645670"), 2)


func _layout_ui() -> void:
	var factor := maxf(0.01, minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y))
	stage.size = DESIGN_SIZE
	stage.scale = Vector2.ONE * factor
	stage.position = (size - DESIGN_SIZE * factor) * 0.5


func show_library(animated: bool = true) -> void:
	_switch_screen("songs", animated)


func show_title(animated: bool = true) -> void:
	_switch_screen("title", animated)


func _switch_screen(target: String, animated: bool) -> void:
	if _switching or screen == target:
		return
	_switching = true
	title_touch.disabled = true
	for button in track_buttons:
		button.disabled = true
	var previous := title_view if screen == "title" else library_view
	var next := library_view if target == "songs" else title_view
	var swap := func() -> void:
		previous.hide()
		next.show()
		screen = target
	var complete := func() -> void:
		_switching = false
		title_touch.visible = screen == "title"
		title_touch.disabled = false
		for index in range(track_buttons.size()):
			track_buttons[index].disabled = not str(tracks[index].error).is_empty()
	if not animated:
		swap.call()
		previous.modulate.a = 1.0
		next.modulate.a = 1.0
		complete.call()
		return
	_transition = create_tween()
	_transition.tween_property(previous, "modulate:a", 0.0, 0.14)
	_transition.tween_callback(swap)
	_transition.tween_property(next, "modulate:a", 0.0, 0.0)
	_transition.tween_property(next, "modulate:a", 1.0, 0.2)
	_transition.tween_callback(complete)


func _play_track(index: int) -> void:
	if _switching or screen != "songs" or index < 0 or index >= tracks.size() or not str(tracks[index].error).is_empty():
		return
	for button in track_buttons:
		button.disabled = true
	play_requested.emit(str(tracks[index].path))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _switching:
		return
	var viewport := get_viewport()
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		viewport.set_input_as_handled()
		if screen == "title":
			show_library()
		else:
			var focused := track_buttons.find(viewport.gui_get_focus_owner())
			_play_track(focused if focused >= 0 else selected_track)
	elif key in [KEY_UP, KEY_DOWN] and screen == "songs":
		viewport.set_input_as_handled()
		var direction := 1 if key == KEY_DOWN else -1
		for attempt in range(track_buttons.size()):
			selected_track = posmod(selected_track + direction, track_buttons.size())
			if not track_buttons[selected_track].disabled:
				track_buttons[selected_track].grab_focus()
				break
	elif key == KEY_ESCAPE and screen == "songs":
		viewport.set_input_as_handled()
		show_title()
	else:
		return
