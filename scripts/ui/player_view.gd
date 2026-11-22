class_name PlayerView
extends Control

signal song_select_requested

const KEY_CELLS := {KEY_U: 0, KEY_I: 1, KEY_J: 2, KEY_K: 3}
const DESIGN_SIZE := Vector2(540, 960)
const BACKDROP_SHADER = preload("res://scripts/ui/game_backdrop.gdshader")

var initial_path := TouchChart.SAMPLE
var initial_phrase := -1
var autoplay := false
var auto_mode := false
var show_song_select := false
var chart_path := ""
var chart: Dictionary = {}
var stream: AudioStream
var session: RhythmSession
var clock := SongClock.new()
var note_sounds := NoteSounds.new()
var note_sound_check := CheckBox.new()
var note_volume: NoteVolumeControl
var preferences_path := "user://settings.cfg"
var detailed_judgment := false
var detailed_judgment_check := CheckBox.new()
var timing_readout := TimingReadout.new()
var state := "ready"
var offset_ms := 0.0
var _last_time := -1000.0
var _start_seconds := 0.0
var _session_start_beat := -INF
var _visual_phase := ""
var _visual_phrase := -1
var _visual_cue := -1
var _judging_finished := false
var _music_finished := false
var demo_pad := GameGrid.new()
var two_beat_badge := PanelContainer.new()
var two_beat_label := AppStyle.label("2박", 16, GameGrid.CORAL)
var input_pad := GameGrid.new()
var hud := GameHUD.new()
var progress: ProgressBar
var decor := StageDecor.new()
var stage := Control.new()
var title_label: Label
var detail_label: Label
var menu := Control.new()
var menu_surface := Control.new()
var menu_scroller := ScrollContainer.new()
var menu_heading: Label
var menu_results: Label
var menu_error: Label
var start_button: Button
var restart_button: Button
var settings_button: Button
var song_select_button: Button
var settings_panel := VBoxContainer.new()
var timing_spin := SpinBox.new()
var open_dialog := FileDialog.new()


func _ready() -> void:
	add_child(clock)
	clock.player.finished.connect(_on_music_finished)
	add_child(note_sounds)
	var settings := ConfigFile.new()
	settings.load(preferences_path)
	offset_ms = float(settings.get_value("timing", "offset_ms", 0.0))
	detailed_judgment = bool(settings.get_value("display", "detailed_judgment", false))
	_build_ui()
	_load_chart(initial_path, initial_phrase)
	if autoplay and not chart.is_empty():
		_start()


func _build_ui() -> void:
	# Background, stage decoration, grids, HUD, and modal UI are independent layers.
	var background := ColorRect.new()
	background.name = "Background"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = BACKDROP_SHADER
	background.material = backdrop_material
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.name = "GameplayStage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	decor.name = "StageDecoration"
	decor.size = DESIGN_SIZE
	stage.add_child(decor)
	demo_pad.name = "DemonstrationGrid"
	demo_pad.position = Vector2(140, 238)
	demo_pad.size = Vector2(260, 260)
	demo_pad.accent = GameGrid.VIOLET
	demo_pad.mouse_default_cursor_shape = Control.CURSOR_ARROW
	stage.add_child(demo_pad)
	two_beat_badge.name = "TwoBeatBadge"
	two_beat_badge.position = Vector2(415, 240)
	two_beat_badge.size = Vector2(100, 32)
	two_beat_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := AppStyle.box(Color(0.16, 0.065, 0.07, 0.88), 9, Color(GameGrid.CORAL, 0.32))
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	two_beat_badge.add_theme_stylebox_override("panel", badge_style)
	two_beat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	two_beat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	two_beat_badge.add_child(two_beat_label)
	stage.add_child(two_beat_badge)
	two_beat_badge.hide()
	input_pad.name = "PlayerGrid"
	input_pad.position = Vector2(140, 582)
	input_pad.size = demo_pad.size
	input_pad.accent = GameGrid.TEAL
	input_pad.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	input_pad.cell_pressed.connect(_press)
	stage.add_child(input_pad)
	timing_readout.name = "DetailedJudgment"
	timing_readout.position = Vector2(140, 168)
	timing_readout.size = Vector2(260, 60)
	stage.add_child(timing_readout)
	hud.name = "HUD"
	hud.size = Vector2(540, 160)
	hud.pause_requested.connect(_pause)
	stage.add_child(hud)
	hud.auto_badge.visible = auto_mode
	progress = hud.progress
	_build_menu()
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.use_native_dialog = true
	open_dialog.filters = PackedStringArray(["*.json ; TouchPattern 채보"])
	open_dialog.title = "채보 열기"
	open_dialog.file_selected.connect(_load_chart)
	add_child(open_dialog)
	resized.connect(_layout_ui)
	_layout_ui()


func _build_menu() -> void:
	menu.name = "PauseMenu"
	menu.z_index = 20
	add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.027, 0.025, 0.047, 0.88)
	menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(menu_surface)
	menu_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroller.follow_focus = true
	menu_surface.add_child(menu_scroller)
	menu_scroller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var padding := MarginContainer.new()
	padding.custom_minimum_size = Vector2(0, DESIGN_SIZE.y)
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padding.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 24)
	menu_scroller.add_child(padding)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 440
	var style := AppStyle.box(Color("171623"), 24, Color("3a304e"))
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	var brand := AppStyle.label("R I N N E R", 13, GameGrid.VIOLET)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(brand)
	menu_heading = AppStyle.label("리듬을 기억하세요", 28, Color("eee7fa"))
	menu_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(menu_heading)
	title_label = AppStyle.label("First Echo", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title_label)
	detail_label = AppStyle.label("", 14, AppStyle.MUTED)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(detail_label)
	menu_results = AppStyle.label("", 16, GameGrid.TEAL)
	menu_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_results.visible = false
	column.add_child(menu_results)
	menu_error = AppStyle.label("", 15, AppStyle.RED)
	menu_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_error.visible = false
	column.add_child(menu_error)
	start_button = _menu_button("시작하기", _toggle, true)
	column.add_child(start_button)
	restart_button = _menu_button("다시 시작", _start)
	column.add_child(restart_button)
	settings_button = _menu_button("소리 · 타이밍 설정", _show_settings)
	column.add_child(settings_button)
	settings_panel.add_theme_constant_override("separation", 12)
	settings_panel.visible = false
	column.add_child(settings_panel)
	_build_settings()
	song_select_button = _menu_button("곡 선택으로", _return_to_songs)
	song_select_button.visible = show_song_select
	column.add_child(song_select_button)
	var utilities := HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 10)
	utilities.visible = not OS.has_feature("mobile")
	column.add_child(utilities)
	utilities.add_child(_menu_button("채보 열기", _open_chart))
	utilities.add_child(_menu_button("메이커 ↗", _open_maker))


func _menu_button(text: String, action: Callable, primary: bool = false) -> Button:
	var button := AppStyle.button(text, action)
	button.custom_minimum_size.y = 76
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	var fill := Color("a98bd5") if primary else Color("211e2e")
	var ink := Color("171121") if primary else Color("e1d9ed")
	button.add_theme_stylebox_override("normal", AppStyle.box(fill, 12, Color.TRANSPARENT if primary else Color("3d334e")))
	button.add_theme_stylebox_override("hover", AppStyle.box(fill.lightened(0.09), 12, GameGrid.VIOLET))
	button.add_theme_stylebox_override("pressed", AppStyle.box(fill.darkened(0.12), 12, GameGrid.VIOLET))
	for button_state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(button_state, ink)
	return button


func _build_settings() -> void:
	var detailed_row := HBoxContainer.new()
	settings_panel.add_child(detailed_row)
	detailed_judgment_check.text = "상세 판정 보기"
	detailed_judgment_check.focus_mode = Control.FOCUS_NONE
	detailed_judgment_check.button_pressed = detailed_judgment
	detailed_judgment_check.custom_minimum_size.y = 76
	detailed_judgment_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detailed_judgment_check.add_theme_font_size_override("font_size", 16)
	for checkbox_state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		detailed_judgment_check.add_theme_stylebox_override(checkbox_state, StyleBoxEmpty.new())
	detailed_judgment_check.toggled.connect(_set_detailed_judgment)
	detailed_row.add_child(detailed_judgment_check)
	var direction_hint := AppStyle.label("− 빠름 · + 늦음", 12, AppStyle.MUTED)
	direction_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detailed_row.add_child(direction_hint)
	var sound_row := HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 8)
	settings_panel.add_child(sound_row)
	note_sound_check.text = "노트 효과음"
	note_sound_check.button_pressed = note_sounds.enabled
	note_sound_check.focus_mode = Control.FOCUS_NONE
	note_sound_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_sound_check.custom_minimum_size.y = 76
	note_sound_check.add_theme_font_size_override("font_size", 16)
	for checkbox_state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		note_sound_check.add_theme_stylebox_override(checkbox_state, StyleBoxEmpty.new())
	note_sound_check.toggled.connect(note_sounds.set_enabled)
	note_sounds.enabled_changed.connect(note_sound_check.set_pressed_no_signal)
	sound_row.add_child(note_sound_check)
	note_volume = NoteVolumeControl.new(note_sounds)
	note_volume.slider.custom_minimum_size = Vector2(110, 76)
	sound_row.add_child(note_volume)
	var timing_row := HBoxContainer.new()
	settings_panel.add_child(timing_row)
	var timing_caption := AppStyle.label("타이밍 보정", 16, AppStyle.MUTED)
	timing_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timing_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timing_row.add_child(timing_caption)
	timing_spin.min_value = -250
	timing_spin.max_value = 250
	timing_spin.step = 5
	timing_spin.suffix = " ms"
	timing_spin.value = offset_ms
	timing_spin.custom_minimum_size = Vector2(172, 76)
	timing_spin.add_theme_font_size_override("font_size", 16)
	timing_spin.value_changed.connect(_save_offset)
	timing_row.add_child(timing_spin)
	var hint := AppStyle.label("입력이 늦으면 + 방향으로 조정하세요.", 13, AppStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_panel.add_child(hint)


func _layout_ui() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	factor = maxf(0.01, factor)
	for surface in [stage, menu_surface]:
		surface.size = DESIGN_SIZE
		surface.scale = Vector2.ONE * factor
		surface.position = (size - DESIGN_SIZE * factor) * 0.5


func _load_chart(path: String, from_phrase: int = -1) -> void:
	var result := TouchChart.read(path)
	if not str(result.error).is_empty():
		_message(str(result.error), AppStyle.RED)
		return
	var data: Dictionary = result.chart
	var audio := TouchChart.load_audio(TouchChart.audio_path(data, path))
	if audio == null:
		_message("음원을 열 수 없어요. WAV / OGG / MP3 경로를 확인해 주세요.", AppStyle.RED)
		return
	clock.stop()
	chart = data
	chart_path = path
	stream = audio
	_start_seconds = 0.0
	_session_start_beat = -INF
	if from_phrase >= 0 and from_phrase < chart.phrases.size():
		_session_start_beat = float(chart.phrases[from_phrase].show_beat)
		_start_seconds = maxf(0.0, TouchChart.beat_to_seconds(chart, _session_start_beat - 1.0))
	state = "ready"
	title_label.text = str(chart.title)
	detail_label.text = "%s · %s BPM%s" % [str(chart.get("artist", "TouchPattern")), str(chart.bpm), " · AUTO" if auto_mode else ""]
	timing_spin.set_value_no_signal(offset_ms)
	_reset_session()
	progress.value = 0.0
	_set_phase("demo", from_phrase if from_phrase >= 0 and from_phrase < chart.phrases.size() else 0)
	menu_error.visible = false
	_show_menu()


func _reset_session() -> void:
	note_sounds.stop()
	_judging_finished = false
	_music_finished = false
	session = RhythmSession.new(chart, _session_start_beat)
	session.judged.connect(_judged)
	demo_pad.visuals_paused = false
	input_pad.visuals_paused = false
	timing_readout.visuals_paused = false
	demo_pad.clear()
	input_pad.clear()
	timing_readout.clear()
	_visual_phase = ""
	_visual_phrase = -1
	_visual_cue = -1
	two_beat_badge.hide()
	demo_pad.set_preview_hint(0.0)
	_update_stats()


func _start() -> void:
	if chart.is_empty() or stream == null:
		return
	_reset_session()
	_last_time = _start_seconds - 0.000001
	state = "playing"
	clock.start(stream, _start_seconds, _music_end_seconds(), TouchChart.audio_fade_out_seconds(chart, stream.get_length()))
	progress.value = clampf(_start_seconds / _run_end_seconds(), 0.0, 1.0) * 100.0
	menu.hide()
	input_pad.interactive = not auto_mode
	_update_phase(_start_seconds)


func _toggle() -> void:
	match state:
		"playing": _pause()
		"paused":
			_music_finished = false
			clock.resume()
			state = "playing"
			menu.hide()
			input_pad.interactive = not auto_mode and not _judging_finished
			demo_pad.visuals_paused = false
			input_pad.visuals_paused = false
			timing_readout.visuals_paused = false
		_: _start()


func _pause() -> void:
	if state == "playing":
		clock.pause()
		note_sounds.stop()
		state = "paused"
		demo_pad.visuals_paused = true
		input_pad.visuals_paused = true
		timing_readout.visuals_paused = true
	_show_menu()


func _show_menu() -> void:
	input_pad.interactive = false
	match state:
		"paused":
			menu_heading.text = "일시정지"
			start_button.text = "계속하기"
		"finished":
			menu_heading.text = "연주 완료" if auto_mode else "플레이 완료"
			start_button.text = "다시 플레이"
		_:
			menu_heading.text = "RINNER"
			start_button.text = "시작하기"
	restart_button.visible = state == "paused"
	menu_results.visible = state == "finished"
	if state == "finished":
		menu_results.text = "%06d  ·  최대 콤보 %d\n정확도 %.1f%%\n\nPERFECT %d  ·  GOOD %d  ·  OK %d\nMISS %d" % [session.score, session.max_combo, session.accuracy(), session.counts.PERFECT, session.counts.GOOD, session.counts.OK, session.counts.MISS]
	settings_panel.hide()
	menu_scroller.scroll_vertical = 0
	menu.show()


func _process(_delta: float) -> void:
	if state != "playing":
		return
	var time := clock.seconds()
	# A selected start beyond the authored ending and a fade-out cut do not emit
	# the audio player's natural finished signal; both continue as a silent tail.
	if not _music_finished and clock.audio_finished() and time >= _music_end_seconds():
		_music_finished = true
	if not _judging_finished:
		# Select the phrase color before its very first demonstration flash.
		_update_phase(time)
		var judge_time := time if auto_mode else time - offset_ms / 1000.0
		if auto_mode:
			session.auto_play(time)
		else:
			session.advance(judge_time)
		for cell in session.demos_between(_last_time, time):
			demo_pad.flash(cell)
			note_sounds.play_demo()
		_last_time = time
		_update_stats()
		var end_seconds := TouchChart.beat_to_seconds(chart, session.end_beat)
		if judge_time > end_seconds + RhythmSession.WINDOW:
			# Seal the result at the original judgment deadline, then let the
			# audio clock and music continue through the outro without new hits.
			_judging_finished = true
			input_pad.interactive = false
			note_sounds.stop()
			_set_phase("complete")
	progress.value = clampf(time / _run_end_seconds(), 0.0, 1.0) * 100.0
	# Waiting for both conditions preserves the audible tail and the final
	# judgment grace period, including silent chart time and timing compensation.
	if _judging_finished and _music_finished and time >= _run_end_seconds():
		_finish()


func _run_end_seconds() -> float:
	var judgment_end := TouchChart.beat_to_seconds(chart, session.end_beat) + RhythmSession.WINDOW
	if not auto_mode:
		judgment_end += offset_ms / 1000.0
	return maxf(0.001, maxf(_music_end_seconds(), judgment_end))


func _music_end_seconds() -> float:
	return TouchChart.audio_end_seconds(chart, stream.get_length())


func _on_music_finished() -> void:
	if state == "playing" and not clock.player.playing:
		_music_finished = true


func _update_phase(time: float) -> void:
	var phase := session.phase_at(time)
	var cue_index := -1
	if phase.kind != "demo":
		var beat := TouchChart.seconds_to_beat(chart, time)
		var next_show := INF
		for index in range(chart.phrases.size()):
			var phrase: Dictionary = chart.phrases[index]
			var show_beat := float(phrase.show_beat)
			if show_beat < session.start_beat or not is_equal_approx(float(phrase.length_beats), 2.0):
				continue
			if show_beat > beat and show_beat - beat <= 1.0 and show_beat < next_show:
				cue_index = index
				next_show = show_beat
	_set_phase(str(phase.kind), int(phase.index), cue_index)


func _set_phase(kind: String, phrase_index: int = -1, cue_index: int = -1) -> void:
	if phrase_index < 0 and kind in ["demo", "response"] and session != null:
		phrase_index = int(session.phase_at(clock.seconds()).index)
	if _visual_phase == kind and _visual_phrase == phrase_index and _visual_cue == cue_index:
		return
	_visual_phase = kind
	_visual_phrase = phrase_index
	_visual_cue = cue_index
	var short_phrase: bool = phrase_index >= 0 and phrase_index < chart.phrases.size() and is_equal_approx(float(chart.phrases[phrase_index].length_beats), 2.0)
	var short_cue := cue_index >= 0
	var demo_accent := GameGrid.CORAL if short_phrase or short_cue else GameGrid.VIOLET
	demo_pad.set_accent(demo_accent)
	demo_pad.set_preview_hint(1.0 if short_cue else (0.45 if short_phrase and kind == "response" else 0.0))
	two_beat_badge.visible = short_phrase or short_cue
	two_beat_label.text = "다음 2박" if short_cue else "2박"
	two_beat_badge.modulate.a = 0.75 if short_cue or kind == "response" else 1.0
	demo_pad.set_active(kind == "demo")
	input_pad.set_active(kind == "response")
	decor.set_phase(kind, demo_accent)
	hud.set_phase(kind, demo_accent)


func _press(cell: int) -> void:
	if auto_mode or state != "playing" or _judging_finished:
		return
	# Keep the session's early/late window, including taps just before a phase boundary.
	var result := session.hit(cell, clock.seconds() - offset_ms / 1000.0)
	if result != "IGNORED":
		note_sounds.play_input()
	_update_stats()


func _judged(kind: String, cell: int, error_ms: float) -> void:
	if auto_mode and kind in ["PERFECT", "GOOD", "OK"]:
		note_sounds.play_input()
	input_pad.show_judgment(cell, kind)
	if detailed_judgment:
		timing_readout.show_judgment(kind, error_ms)


func _update_stats() -> void:
	hud.update_stats(session)


func _finish() -> void:
	clock.stop()
	note_sounds.stop()
	state = "finished"
	timing_readout.clear()
	_set_phase("complete")
	progress.value = 100.0
	_show_menu()


func _message(text: String, color: Color) -> void:
	_pause()
	menu_error.text = text
	menu_error.add_theme_color_override("font_color", color)
	menu_error.show()


func _open_chart() -> void:
	_pause()
	open_dialog.popup_centered_ratio(0.8)


func _return_to_songs() -> void:
	clock.stop()
	note_sounds.stop()
	input_pad.interactive = false
	state = "ready"
	song_select_requested.emit()


func _open_maker() -> void:
	_pause()
	if AppStyle.launch(chart_path if not chart_path.is_empty() else TouchChart.SAMPLE, true) < 0:
		_message("채보 메이커 창을 열 수 없어요.", AppStyle.RED)


func _show_settings() -> void:
	if state == "playing":
		_pause()
	settings_panel.visible = not settings_panel.visible


func _save_offset(value: float) -> void:
	offset_ms = value
	var settings := ConfigFile.new()
	settings.load(preferences_path)
	settings.set_value("timing", "offset_ms", offset_ms)
	settings.save(preferences_path)


func _set_detailed_judgment(enabled: bool) -> void:
	detailed_judgment = enabled
	if not enabled:
		timing_readout.clear()
	var settings := ConfigFile.new()
	settings.load(preferences_path)
	settings.set_value("display", "detailed_judgment", enabled)
	settings.save(preferences_path)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if KEY_CELLS.has(key):
		_press(int(KEY_CELLS[key]))
	elif key == KEY_SPACE:
		_toggle()
	elif key == KEY_R:
		_start()
	elif key == KEY_ESCAPE:
		_toggle() if state == "paused" else _pause()
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "playing":
		_pause()
