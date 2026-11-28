class_name GuiEditor
extends Control

const PREVIEW_SIZES := [Vector2i(540, 960), Vector2i(390, 844), Vector2i(768, 1024), Vector2i(960, 540)]

var layout_path := GuiLayout.PATH
var layout: GuiLayout
var unsaved := false
var saved_sizes := Vector2.ZERO
var size_sliders: Dictionary = {}
var size_spins: Dictionary = {}
var screen_select := OptionButton.new()
var size_select := OptionButton.new()
var phase_select := OptionButton.new()
var game_settings := VBoxContainer.new()
var title_hint: Label
var status := AppStyle.label("", 13, AppStyle.MUTED)
var save_button: Button
var reset_button: Button
var preview_area := Control.new()
var preview_frame := SubViewportContainer.new()
var preview_viewport := SubViewport.new()
var player_preview := PlayerView.new()
var title_preview := FrontMenu.new()


func _ready() -> void:
	theme = AppStyle.make_theme()
	layout = GuiLayout.read(layout_path)
	saved_sizes = _sizes()
	_build_ui()
	_build_preview()
	_sync_controls()
	_show_screen(0)
	_refresh_dirty()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0d101b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := AppStyle.label("GUI 에디터", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var live := AppStyle.label("●  LIVE PREVIEW", 12, GameGrid.TEAL)
	live.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(live)
	reset_button = AppStyle.button("기본값으로", _reset)
	reset_button.custom_minimum_size.y = 42
	header.add_child(reset_button)
	save_button = AppStyle.button("저장  Ctrl+S", _save)
	save_button.custom_minimum_size = Vector2(140, 42)
	header.add_child(save_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)
	var sidebar := AppStyle.card()
	sidebar.custom_minimum_size.x = 320
	body.add_child(sidebar)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 22)
	scroll.add_child(inspector)
	inspector.add_child(AppStyle.label("편집할 화면", 13, AppStyle.MUTED))
	screen_select.add_item("게임 화면")
	screen_select.add_item("시작 화면")
	screen_select.custom_minimum_size.y = 44
	screen_select.item_selected.connect(_show_screen)
	inspector.add_child(screen_select)
	inspector.add_child(HSeparator.new())
	game_settings.add_theme_constant_override("separation", 24)
	inspector.add_child(game_settings)
	_add_size_control("demo", "시범 그리드", GameGrid.VIOLET)
	_add_size_control("play", "플레이 그리드", GameGrid.TEAL)
	game_settings.add_child(_hint("2×2 그리드의 한 변 길이를 조절합니다.\n중심 위치는 유지됩니다.\n\n기준 화면: 540 × 960\n기본 크기: 260 × 260"))
	title_hint = _hint("시작 화면 미리보기\n\n이번 버전에서는 게임 화면의\n그리드 크기를 편집할 수 있습니다.")
	inspector.add_child(title_hint)
	var preview_column := VBoxContainer.new()
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(preview_column)
	var toolbar := HBoxContainer.new()
	preview_column.add_child(toolbar)
	var caption := AppStyle.label("실제 화면 미리보기", 14, AppStyle.MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(caption)
	phase_select.add_item("시범")
	phase_select.add_item("플레이")
	phase_select.custom_minimum_size.y = 40
	phase_select.item_selected.connect(_show_phase)
	toolbar.add_child(phase_select)
	for dimensions in PREVIEW_SIZES:
		size_select.add_item("%d × %d" % [dimensions.x, dimensions.y])
	size_select.custom_minimum_size.y = 40
	size_select.item_selected.connect(func(_index: int) -> void: _layout_preview())
	toolbar.add_child(size_select)
	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", AppStyle.box(Color("080a12"), 16, AppStyle.LINE))
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_child(preview_panel)
	preview_area.custom_minimum_size = Vector2(280, 400)
	preview_area.clip_contents = true
	preview_panel.add_child(preview_area)
	preview_area.resized.connect(_layout_preview)
	status.custom_minimum_size.y = 24
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(status)


func _hint(text: String) -> Label:
	var label := AppStyle.label(text, 13, AppStyle.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _add_size_control(key: String, caption: String, accent: Color) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	game_settings.add_child(column)
	column.add_child(AppStyle.label(caption, 18, accent))
	var row := HBoxContainer.new()
	column.add_child(row)
	var label := AppStyle.label("한 변", 13, AppStyle.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = GuiLayout.MIN_GRID_SIZE
	spin.max_value = GuiLayout.MAX_GRID_SIZE
	spin.step = 1
	spin.suffix = " px"
	spin.custom_minimum_size = Vector2(148, 42)
	row.add_child(spin)
	var slider := HSlider.new()
	slider.min_value = GuiLayout.MIN_GRID_SIZE
	slider.max_value = GuiLayout.MAX_GRID_SIZE
	slider.step = 1
	slider.custom_minimum_size.y = 32
	column.add_child(slider)
	size_sliders[key] = slider
	size_spins[key] = spin
	spin.value_changed.connect(_set_grid_size.bind(key))
	slider.value_changed.connect(_set_grid_size.bind(key))


func _build_preview() -> void:
	preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_area.add_child(preview_frame)
	preview_viewport.size = PREVIEW_SIZES[0]
	preview_viewport.gui_disable_input = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_frame.add_child(preview_viewport)
	player_preview.preview_mode = true
	player_preview.gui_layout_path = layout_path
	preview_viewport.add_child(player_preview)
	player_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_preview.apply_gui_layout(layout)
	player_preview.hud.score_label.text = "024000"
	player_preview.hud.combo_label.text = "24"
	player_preview.progress.value = 42
	title_preview.initial_chart = TouchChart.SAMPLE
	preview_viewport.add_child(title_preview)
	title_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_preview.set_process_unhandled_key_input(false)
	_layout_preview()
	_show_phase(0)


func _layout_preview() -> void:
	if not is_instance_valid(player_preview) or not player_preview.is_node_ready():
		return
	var dimensions: Vector2i = PREVIEW_SIZES[size_select.selected]
	preview_viewport.size = dimensions
	preview_frame.size = Vector2(dimensions)
	var factor := maxf(0.01, minf(preview_area.size.x / dimensions.x, preview_area.size.y / dimensions.y))
	preview_frame.scale = Vector2.ONE * factor
	preview_frame.position = (preview_area.size - Vector2(dimensions) * factor) * 0.5


func _show_screen(index: int) -> void:
	game_settings.visible = index == 0
	title_hint.visible = index == 1
	phase_select.visible = index == 0
	player_preview.visible = index == 0
	title_preview.visible = index == 1


func _show_phase(index: int) -> void:
	player_preview.demo_pad.set_active(index == 0)
	player_preview.input_pad.set_active(index == 1)
	var phase := "demo" if index == 0 else "response"
	player_preview.hud.set_phase(phase)
	player_preview.decor.set_phase(phase)


func _set_grid_size(value: float, key: String) -> void:
	layout.set(key + "_grid_size", value)
	_sync_controls()
	player_preview.apply_gui_layout(layout)
	_refresh_dirty()


func _sync_controls() -> void:
	for key in ["demo", "play"]:
		var value := float(layout.get(key + "_grid_size"))
		size_sliders[key].set_value_no_signal(value)
		size_spins[key].set_value_no_signal(value)


func _sizes() -> Vector2:
	return Vector2(layout.demo_grid_size, layout.play_grid_size)


func _refresh_dirty() -> void:
	unsaved = _sizes() != saved_sizes
	save_button.disabled = not unsaved
	status.text = "● 저장하지 않은 변경 · 미리보기에 반영됨 · 저장하면 게임에 적용됩니다." if unsaved else "저장된 레이아웃 · 그리드 크기를 조절하면 미리보기에 바로 반영됩니다."
	status.add_theme_color_override("font_color", GameGrid.VIOLET if unsaved else AppStyle.MUTED)


func _save() -> void:
	for spin in size_spins.values():
		if spin.get_line_edit().has_focus():
			spin.apply()
	var error := ResourceSaver.save(layout, layout_path)
	if error != OK:
		status.text = "저장 실패: " + error_string(error)
		status.add_theme_color_override("font_color", AppStyle.RED)
		return
	saved_sizes = _sizes()
	_refresh_dirty()
	status.text = "저장됨 · 게임 창으로 돌아가면 적용됩니다. 다음 실행과 빌드에도 반영됩니다."


func _reset() -> void:
	for spin in size_spins.values():
		spin.get_line_edit().release_focus()
	layout = GuiLayout.new()
	_sync_controls()
	player_preview.apply_gui_layout(layout)
	_refresh_dirty()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_command_or_control_pressed() and event.keycode == KEY_S:
		_save()
		get_viewport().set_input_as_handled()
