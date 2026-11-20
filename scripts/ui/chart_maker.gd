class_name ChartMaker
extends Control

const PREVIEW_FLASH_SECONDS := 0.18
const PREVIEW_HINT := "입력 시점에 테두리가 빛나요."

var initial_path := TouchChart.SAMPLE
var chart_path := ""
var chart: Dictionary = {}
var selected := 0
var dirty := false
var _updating := false
var _preview_end := 0.0
var _preview_continuous := false
var _preview_follow_from := 0.0
var _preview_sound_times: Array[float] = []
var _preview_sound_cursor := 0
var clock := SongClock.new()
var note_sounds := NoteSounds.new()
var note_sound_check := CheckBox.new()
var note_volume: NoteVolumeControl
var timeline := PatternTimeline.new()
var preview_pad := GridPad.new()
var play_from_selection_check := CheckBox.new()
var auto_mode_check := CheckBox.new()
var title_edit := LineEdit.new()
var bpm_spin := SpinBox.new()
var bpm_find_button: Button
var _bpm_thread: Thread
var _bpm_detector: BpmDetector
var _bpm_revision := 0
var _bpm_request_revision := 0
var offset_spin := SpinBox.new()
var audio_edit := LineEdit.new()
var show_spin := SpinBox.new()
var response_spin := SpinBox.new()
var length_spin := SpinBox.new()
var fade_spin := SpinBox.new()
var audio_end_button: Button
var pattern_strip := PatternStrip.new()
var pattern_label: Label
var status_label: Label
var path_label: Label
var preview_label: Label
var open_dialog := FileDialog.new()
var save_dialog := FileDialog.new()
var audio_dialog := FileDialog.new()
var _preview_session: RhythmSession


func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(960, 740))
	get_tree().auto_accept_quit = false
	add_child(clock)
	add_child(note_sounds)
	_build_ui()
	_load_chart(TouchChart.SAMPLE)
	if initial_path != TouchChart.SAMPLE:
		_load_chart(initial_path)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(AppStyle.label("RINNER", 22, AppStyle.MINT))
	var edition := AppStyle.label("CHART MAKER", 13, AppStyle.MUTED)
	edition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(edition)
	header.add_child(AppStyle.button("플레이어 열기 ↗", func() -> void: AppStyle.launch(chart_path)))
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	toolbar.add_child(AppStyle.button("새 채보", func() -> void: _confirm_discard(_new_chart)))
	toolbar.add_child(AppStyle.button("열기", func() -> void: _confirm_discard(func() -> void: open_dialog.popup_centered_ratio(0.8))))
	toolbar.add_child(AppStyle.button("저장  Ctrl+S", _save))
	toolbar.add_child(AppStyle.button("다른 이름으로", _save_as))
	path_label = AppStyle.label("", 11, AppStyle.MUTED)
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(path_label)
	var metadata := AppStyle.card()
	root.add_child(metadata)
	var fields := HBoxContainer.new()
	metadata.add_child(fields)
	title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field(fields, "곡 제목", title_edit, true)
	_setup_spin(bpm_spin, 30, 300, 0.001)
	var bpm_controls := HBoxContainer.new()
	bpm_spin.custom_minimum_size.x = 105
	bpm_controls.add_child(bpm_spin)
	bpm_find_button = AppStyle.button("BPM 자동 찾기", _find_bpm)
	bpm_find_button.tooltip_text = "음원을 분석해 소수점 셋째 자리까지 입력해요. 반·두 배 박자는 현재 BPM을 참고해 선택해요."
	bpm_controls.add_child(bpm_find_button)
	_field(fields, "BPM", bpm_controls)
	_setup_spin(offset_spin, -600, 600, 0.001)
	offset_spin.suffix = " 초"
	_field(fields, "첫 박자 오프셋", offset_spin)
	title_edit.text_changed.connect(func(value: String) -> void:
		if not _updating:
			chart.title = value
			_mark_dirty()
	)
	bpm_spin.value_changed.connect(func(value: float) -> void:
		if not _updating:
			_invalidate_bpm_search()
			_stop_preview()
			chart.bpm = value
			_mark_dirty()
	)
	offset_spin.value_changed.connect(func(value: float) -> void:
		if not _updating:
			_stop_preview()
			chart.offset_seconds = value
			_mark_dirty()
	)
	var audio_row := HBoxContainer.new()
	root.add_child(audio_row)
	audio_row.add_child(AppStyle.label("음원", 12, AppStyle.MUTED))
	audio_edit.editable = false
	audio_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_child(audio_edit)
	audio_row.add_child(AppStyle.button("WAV / OGG / MP3 선택", func() -> void: audio_dialog.popup_centered_ratio(0.8)))
	var editor := VBoxContainer.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 8)
	root.add_child(editor)
	var phrase_fields := HBoxContainer.new()
	editor.add_child(phrase_fields)
	var phrase_caption := VBoxContainer.new()
	phrase_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phrase_caption.add_theme_constant_override("separation", 4)
	phrase_fields.add_child(phrase_caption)
	pattern_label = AppStyle.label("", 20, AppStyle.MINT)
	phrase_caption.add_child(pattern_label)
	phrase_caption.add_child(AppStyle.label("노트 편집 · 클릭해서 추가 / 제거", 11, AppStyle.MUTED))
	_setup_spin(show_spin, 0, 10000, 0.25)
	_setup_spin(response_spin, 0, 10000, 0.25)
	_setup_spin(length_spin, 0.25, 32, 0.25)
	_field(phrase_fields, "시범 시작 (박)", show_spin)
	_field(phrase_fields, "재현 시작 (박)", response_spin)
	_field(phrase_fields, "길이 (박)", length_spin)
	_setup_spin(fade_spin, 0, TouchChart.MAX_FADE_OUT_SECONDS, 0.1)
	fade_spin.suffix = " 초"
	fade_spin.value = TouchChart.DEFAULT_FADE_OUT_SECONDS
	_field(phrase_fields, "페이드 아웃", fade_spin)
	audio_end_button = AppStyle.button("여기서 곡 종료", _toggle_audio_end)
	audio_end_button.tooltip_text = "선택한 패턴의 재현이 끝날 때 음악을 페이드 아웃하고, 이후 채보는 무음으로 진행해요."
	_field(phrase_fields, "음원 종료", audio_end_button)
	audio_end_button.custom_minimum_size.x = 142
	show_spin.value_changed.connect(func(value: float) -> void: _change_phrase("show_beat", value))
	response_spin.value_changed.connect(func(value: float) -> void: _change_phrase("response_beat", value))
	length_spin.value_changed.connect(_change_length)
	fade_spin.value_changed.connect(_change_fade_out)
	var snap := OptionButton.new()
	for denominator in [1, 2, 4, 8]:
		snap.add_item("1/%d박" % denominator, denominator)
	snap.select(2)
	snap.item_selected.connect(func(index: int) -> void:
		timeline.snap = snap.get_item_id(index)
		timeline.queue_redraw()
	)
	_field(phrase_fields, "격자", snap)
	var timeline_card := AppStyle.card()
	timeline_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_child(timeline_card)
	var stage := HBoxContainer.new()
	stage.add_theme_constant_override("separation", 20)
	timeline_card.add_child(stage)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage.add_child(scroll)
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline.note_toggled.connect(_toggle_note)
	scroll.add_child(timeline)
	var timing_column := VBoxContainer.new()
	timing_column.custom_minimum_size.x = 112
	timing_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timing_column.add_theme_constant_override("separation", 6)
	stage.add_child(timing_column)
	var timing_title := AppStyle.label("PERFECT", 12, AppStyle.MINT)
	timing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing_column.add_child(timing_title)
	var timing_caption := AppStyle.label("입력 타이밍", 11, AppStyle.MUTED)
	timing_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing_column.add_child(timing_caption)
	var pad_center := CenterContainer.new()
	timing_column.add_child(pad_center)
	preview_pad.custom_minimum_size = Vector2(96, 96)
	preview_pad.show_keys = true
	preview_pad.outline_only = true
	pad_center.add_child(preview_pad)
	# The song clock drives preview brightness, including frames after a seek.
	preview_pad.set_process(false)
	preview_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label = AppStyle.label(PREVIEW_HINT, 11, AppStyle.MUTED)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timing_column.add_child(preview_label)
	var transport := HBoxContainer.new()
	editor.add_child(transport)
	transport.add_child(AppStyle.button("구간 듣기", _listen))
	var continuous_button := AppStyle.button("연속 듣기", _listen.bind(true))
	continuous_button.tooltip_text = "선택한 패턴부터 마지막 재현 구간까지 이어서 들어요."
	transport.add_child(continuous_button)
	transport.add_child(AppStyle.button("정지", _stop_preview))
	note_sound_check.text = "박수 소리"
	note_sound_check.button_pressed = note_sounds.enabled
	note_sound_check.focus_mode = Control.FOCUS_NONE
	note_sound_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	note_sound_check.tooltip_text = "구간 듣기·연속 듣기의 시범과 재현 노트에 박수를 내요. 플레이 테스트에도 적용돼요."
	note_sound_check.toggled.connect(note_sounds.set_enabled)
	note_sounds.enabled_changed.connect(note_sound_check.set_pressed_no_signal)
	transport.add_child(note_sound_check)
	note_volume = NoteVolumeControl.new(note_sounds)
	transport.add_child(note_volume)
	transport.add_child(AppStyle.button("플레이 테스트 ↗", _play_test))
	play_from_selection_check.text = "선택 구간부터"
	play_from_selection_check.button_pressed = true
	play_from_selection_check.focus_mode = Control.FOCUS_NONE
	play_from_selection_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	play_from_selection_check.tooltip_text = "체크하면 선택한 패턴의 시범 시작 한 박자 전부터, 해제하면 곡 처음부터 테스트해요."
	transport.add_child(play_from_selection_check)
	auto_mode_check.text = "AUTO"
	auto_mode_check.focus_mode = Control.FOCUS_NONE
	auto_mode_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	auto_mode_check.tooltip_text = "PC가 정답 타이밍에 자동으로 입력하는 시범 플레이를 보여줘요."
	transport.add_child(auto_mode_check)
	var strip_header := HBoxContainer.new()
	editor.add_child(strip_header)
	strip_header.add_child(AppStyle.label("패턴 미리보기", 15))
	var strip_hint := AppStyle.label("클릭해서 선택 · 휠로 가로 이동", 11, AppStyle.MUTED)
	strip_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_header.add_child(strip_hint)
	strip_header.add_child(AppStyle.button("+ 추가", _add_phrase))
	strip_header.add_child(AppStyle.button("− 삭제", _delete_phrase))
	var strip_tracks := HBoxContainer.new()
	strip_tracks.add_theme_constant_override("separation", 0)
	editor.add_child(strip_tracks)
	var track_labels := VBoxContainer.new()
	track_labels.custom_minimum_size.x = 28
	track_labels.add_theme_constant_override("separation", 0)
	strip_tracks.add_child(track_labels)
	var track_header := Control.new()
	track_header.custom_minimum_size.y = PatternThumbnail.HEADER_HEIGHT
	track_labels.add_child(track_header)
	for cell in range(4):
		var track_label := AppStyle.label(AppStyle.KEYS[cell], 11, AppStyle.CELLS[cell])
		track_label.custom_minimum_size.y = PatternThumbnail.ROW_HEIGHT
		track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		track_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		track_labels.add_child(track_label)
	pattern_strip.phrase_selected.connect(_select_phrase)
	strip_tracks.add_child(pattern_strip)
	status_label = AppStyle.label("", 12, AppStyle.MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 42
	root.add_child(status_label)
	_setup_dialog(open_dialog, FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.json ; TouchPattern 채보"]))
	open_dialog.file_selected.connect(_load_chart)
	_setup_dialog(save_dialog, FileDialog.FILE_MODE_SAVE_FILE, PackedStringArray(["*.json ; TouchPattern 채보"]))
	save_dialog.file_selected.connect(_save_to)
	_setup_dialog(audio_dialog, FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.wav,*.ogg,*.mp3 ; 음원 파일"]))
	audio_dialog.file_selected.connect(_set_audio)


func _field(parent: Control, caption: String, control: Control, expand: bool = false) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	column.add_child(AppStyle.label(caption, 11, AppStyle.MUTED))
	control.custom_minimum_size.x = 105 if not expand else 130
	column.add_child(control)
	parent.add_child(column)


func _setup_spin(spin: SpinBox, minimum: float, maximum: float, step: float) -> void:
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step


func _setup_dialog(dialog: FileDialog, mode: FileDialog.FileMode, filters: PackedStringArray) -> void:
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = filters
	add_child(dialog)


func _load_chart(path: String) -> void:
	var result := TouchChart.read(path)
	if not str(result.error).is_empty():
		_status(str(result.error), true)
		return
	_stop_preview()
	_invalidate_bpm_search()
	chart = result.chart
	chart_path = path
	selected = 0
	dirty = false
	_refresh()
	_status("채보를 열었어요. 노트를 편집하거나 플레이 테스트를 눌러 보세요.")


func _refresh() -> void:
	_updating = true
	title_edit.text = str(chart.title)
	bpm_spin.value = float(chart.bpm)
	offset_spin.value = float(chart.offset_seconds)
	audio_edit.text = TouchChart.audio_path(chart, chart_path)
	_refresh_strip()
	_updating = false
	_select_phrase(selected)
	_update_path()


func _refresh_strip() -> void:
	pattern_strip.set_phrases(chart.phrases, TouchChart.audio_end_beat(chart))
	pattern_strip.select(selected)
	pattern_label.text = "패턴 %02d / %02d" % [selected + 1, chart.phrases.size()]


func _select_phrase(index: int) -> void:
	_stop_preview()
	_display_phrase(index)


func _display_phrase(index: int) -> void:
	selected = index
	var phrase: Dictionary = chart.phrases[selected]
	_updating = true
	show_spin.value = float(phrase.show_beat)
	response_spin.value = float(phrase.response_beat)
	length_spin.value = float(phrase.length_beats)
	_refresh_audio_end_controls()
	_updating = false
	timeline.set_phrase(phrase)
	pattern_strip.select(selected)
	pattern_label.text = "패턴 %02d / %02d" % [selected + 1, chart.phrases.size()]


func _change_phrase(key: String, value: Variant) -> void:
	if _updating or chart.is_empty():
		return
	_stop_preview()
	var moves_audio_end := _selected_has_audio_end()
	chart.phrases[selected][key] = value
	if moves_audio_end:
		chart.audio_end_beat = _selected_response_end()
	_refresh_strip()
	_refresh_audio_end_controls()
	_mark_dirty()


func _change_length(value: float) -> void:
	if _updating or chart.is_empty():
		return
	var phrase: Dictionary = chart.phrases[selected]
	for note in phrase.notes:
		if float(note.beat) >= value:
			length_spin.set_value_no_signal(float(phrase.length_beats))
			_status("줄일 구간에 노트가 있어요. 먼저 해당 노트를 지워 주세요.", true)
			return
	_change_phrase("length_beats", value)
	timeline.set_phrase(phrase)


func _toggle_note(beat: float, cell: int) -> void:
	_stop_preview()
	var notes: Array = chart.phrases[selected].notes
	var found := -1
	for index in range(notes.size()):
		if int(notes[index].cell) == cell and is_equal_approx(float(notes[index].beat), beat):
			found = index
			break
	if found >= 0:
		notes.remove_at(found)
	else:
		notes.append({"beat": beat, "cell": cell})
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.beat) < float(b.beat) if not is_equal_approx(float(a.beat), float(b.beat)) else int(a.cell) < int(b.cell)
	)
	timeline.queue_redraw()
	_refresh_strip()
	_mark_dirty()


func _add_phrase() -> void:
	_stop_preview()
	var start := TouchChart.end_beat(chart)
	chart.phrases.append({"show_beat": start, "response_beat": start + 4.0, "length_beats": 4.0, "notes": []})
	selected = chart.phrases.size() - 1
	_refresh_strip()
	_select_phrase(selected)
	_mark_dirty()


func _delete_phrase() -> void:
	if chart.phrases.size() <= 1:
		_status("패턴은 하나 이상 남겨 주세요.", true)
		return
	_stop_preview()
	if _selected_has_audio_end():
		chart.erase("audio_end_beat")
		chart.erase("fade_out_seconds")
	chart.phrases.remove_at(selected)
	selected = mini(selected, chart.phrases.size() - 1)
	_refresh_strip()
	_select_phrase(selected)
	_mark_dirty()


func _selected_response_end() -> float:
	var phrase: Dictionary = chart.phrases[selected]
	return float(phrase.response_beat) + float(phrase.length_beats)


func _selected_has_audio_end() -> bool:
	return TouchChart.has_audio_end(chart) and is_equal_approx(TouchChart.audio_end_beat(chart), _selected_response_end())


func _refresh_audio_end_controls() -> void:
	if audio_end_button == null or chart.is_empty():
		return
	var selected_end := _selected_has_audio_end()
	audio_end_button.text = "✓ 여기서 곡 종료" if selected_end else "여기서 곡 종료"
	fade_spin.set_value_no_signal(TouchChart.fade_out_seconds(chart) if TouchChart.has_audio_end(chart) else TouchChart.DEFAULT_FADE_OUT_SECONDS)


func _toggle_audio_end() -> void:
	if chart.is_empty():
		return
	_stop_preview()
	if _selected_has_audio_end():
		chart.erase("audio_end_beat")
		chart.erase("fade_out_seconds")
		_refresh_strip()
		_refresh_audio_end_controls()
		_mark_dirty()
		_status("곡 종료 지점을 해제했어요. 음원을 원래 끝까지 재생해요.")
		return
	chart.audio_end_beat = _selected_response_end()
	chart.fade_out_seconds = fade_spin.value
	_refresh_strip()
	_refresh_audio_end_controls()
	_mark_dirty()
	_status("패턴 %d 재현 끝에서 곡을 종료해요. %.1f초 동안 페이드 아웃해요." % [selected + 1, fade_spin.value])


func _change_fade_out(value: float) -> void:
	if _updating or not TouchChart.has_audio_end(chart):
		return
	_stop_preview()
	chart.fade_out_seconds = value
	_mark_dirty()
	_status("곡 종료 전 %.1f초 동안 페이드 아웃해요." % value)


func _new_chart() -> void:
	_stop_preview()
	_invalidate_bpm_search()
	var audio := TouchChart.audio_path(chart, chart_path)
	chart = {"format_version": 1, "title": "새 곡", "artist": "", "bpm": 112.0, "offset_seconds": 0.0, "audio": audio, "grid": {"rows": 2, "columns": 2}, "phrases": [{"show_beat": 4.0, "response_beat": 8.0, "length_beats": 4.0, "notes": []}]}
	chart_path = "user://charts/untitled.json"
	selected = 0
	_refresh()
	_mark_dirty()


func _set_audio(path: String) -> void:
	var audio := TouchChart.load_audio(path)
	if audio == null:
		_status("음원을 열 수 없어요. 지원하는 WAV / OGG / MP3 파일을 선택해 주세요.", true)
		return
	_stop_preview()
	_invalidate_bpm_search()
	chart.audio = path
	audio_edit.text = path
	_mark_dirty()
	var duration := int(ceil(audio.get_length()))
	_status("음원을 불러왔어요: %s · %d:%02d · 구간 듣기로 확인해 보세요." % [path.get_file(), duration / 60, duration % 60])


func _find_bpm() -> void:
	if _bpm_thread != null:
		return
	_stop_preview()
	var audio := TouchChart.load_audio(TouchChart.audio_path(chart, chart_path))
	if audio == null:
		_status("음원을 열 수 없어요. 음원 경로를 확인해 주세요.", true)
		return
	_bpm_detector = BpmDetector.new()
	_bpm_request_revision = _bpm_revision
	_bpm_thread = Thread.new()
	var error := _bpm_thread.start(_bpm_detector.analyze.bind(audio.duplicate(), bpm_spin.value), Thread.PRIORITY_LOW)
	if error != OK:
		_bpm_thread = null
		_bpm_detector = null
		_status("BPM 분석을 시작할 수 없어요. 다시 시도해 주세요.", true)
		return
	bpm_find_button.disabled = true
	bpm_find_button.text = "분석 중 · 0%"
	_status("음원에서 BPM을 찾고 있어요. 분석이 끝나면 BPM 칸에 입력해요.")


func _invalidate_bpm_search() -> void:
	_bpm_revision += 1
	if _bpm_detector != null:
		_bpm_detector.cancel()


func _poll_bpm_search() -> void:
	if _bpm_thread == null:
		return
	if _bpm_thread.is_alive():
		bpm_find_button.text = "분석 중 · %d%%" % _bpm_detector.progress()
		return
	var result: Dictionary = _bpm_thread.wait_to_finish()
	_bpm_thread = null
	_bpm_detector = null
	bpm_find_button.disabled = false
	bpm_find_button.text = "BPM 자동 찾기"
	# Loading another chart/audio or typing BPM supersedes the old result.
	if _bpm_request_revision != _bpm_revision:
		return
	if not str(result.error).is_empty():
		_status(str(result.error), true)
		return
	bpm_spin.value = float(result.bpm)
	_status("BPM 자동 찾기 완료 · %.3f BPM을 입력했어요. 구간 듣기로 박자를 확인해 주세요." % float(result.bpm))


func _exit_tree() -> void:
	if _bpm_thread != null:
		_bpm_detector.cancel()
		_bpm_thread.wait_to_finish()


func _save() -> void:
	if chart_path.begins_with("res://") or not FileAccess.file_exists(chart_path):
		_save_as()
	else:
		_save_to(chart_path)


func _save_as() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://charts"))
	save_dialog.current_dir = ProjectSettings.globalize_path("user://charts")
	save_dialog.current_file = str(chart.title).validate_filename() + ".json"
	save_dialog.popup_centered_ratio(0.8)


func _save_to(path: String) -> void:
	if path.get_extension().to_lower() != "json":
		path += ".json"
	var error := TouchChart.write(chart, chart_path, path)
	if not error.is_empty():
		_status(error, true)
		return
	var result := TouchChart.read(path)
	chart = result.chart
	chart_path = path
	dirty = false
	_refresh()
	_status("저장했어요: " + ProjectSettings.globalize_path(path))


func _audio_for_preview(require_notes: bool = true) -> AudioStream:
	var error := TouchChart.validate(chart, require_notes)
	if not error.is_empty():
		_status(error, true)
		return null
	var audio := TouchChart.load_audio(TouchChart.audio_path(chart, chart_path))
	if audio == null:
		_status("음원 경로를 확인해 주세요.", true)
		return null
	return audio


func _listen(continuous: bool = false) -> void:
	_stop_preview()
	var audio := _audio_for_preview(false)
	if audio == null:
		return
	var phrase: Dictionary = chart.phrases[selected]
	_preview_continuous = continuous
	_preview_follow_from = TouchChart.beat_to_seconds(chart, float(phrase.show_beat))
	var end_beat := TouchChart.end_beat(chart) if continuous else float(phrase.response_beat) + float(phrase.length_beats)
	_preview_end = TouchChart.beat_to_seconds(chart, end_beat)
	var start := maxf(0.0, TouchChart.beat_to_seconds(chart, float(phrase.show_beat) - 1.0))
	_preview_session = RhythmSession.new(chart)
	_prepare_preview_sounds()
	clock.start(audio, start, TouchChart.audio_end_seconds(chart, audio.get_length()), TouchChart.audio_fade_out_seconds(chart, audio.get_length()))
	_update_preview(clock.seconds())


func _prepare_preview_sounds() -> void:
	_preview_sound_times.clear()
	_preview_sound_cursor = 0
	var phrases: Array = chart.phrases if _preview_continuous else [chart.phrases[selected]]
	var first_time := maxf(0.0, _preview_follow_from)
	for phrase in phrases:
		for start_beat in [float(phrase.show_beat), float(phrase.response_beat)]:
			for note in phrase.notes:
				var time := TouchChart.beat_to_seconds(chart, start_beat + float(note.beat))
				if time >= first_time and time <= _preview_end:
					_preview_sound_times.append(time)
	_preview_sound_times.sort()


func _play_preview_sounds(time: float) -> void:
	if not clock.running:
		return
	while _preview_sound_cursor < _preview_sound_times.size() and _preview_sound_times[_preview_sound_cursor] <= time:
		_preview_sound_cursor += 1
		note_sounds.play_preview()


func _stop_preview(stop_feedback: bool = true) -> void:
	clock.stop()
	if stop_feedback:
		note_sounds.stop()
	_preview_sound_times.clear()
	_preview_sound_cursor = 0
	_preview_continuous = false
	_preview_follow_from = 0.0
	_preview_session = null
	timeline.clear_preview()
	preview_pad.clear()
	if preview_label != null:
		preview_label.text = PREVIEW_HINT


func _play_test() -> void:
	_stop_preview()
	if _audio_for_preview() == null:
		return
	var temporary := "user://previews/editor_preview_%d.json" % Time.get_ticks_usec()
	var error := TouchChart.write(chart, chart_path, temporary)
	if not error.is_empty():
		_status(error, true)
		return
	var start_phrase := selected if play_from_selection_check.button_pressed else -1
	if AppStyle.launch(temporary, false, true, start_phrase, auto_mode_check.button_pressed) < 0:
		_status("플레이 테스트 창을 열 수 없어요.", true)
	else:
		var start_label := "선택한 패턴" if start_phrase >= 0 else "곡 처음"
		var mode_label := "PC 시범 플레이" if auto_mode_check.button_pressed else "플레이 테스트"
		_status("%s부터 %s 중이에요. 저장 파일은 그대로예요." % [start_label, mode_label])


func _process(_delta: float) -> void:
	_poll_bpm_search()
	if not clock.running:
		return
	var time := clock.seconds()
	if time >= _preview_end:
		_play_preview_sounds(_preview_end)
		# Let the last clap finish when a section ends naturally.
		_stop_preview(false)
		return
	_update_preview(time)


func _update_preview(time: float) -> void:
	_play_preview_sounds(time)
	preview_pad.clear()
	timeline.preview_highlights.clear()
	var phase := _preview_session.phase_at(time)
	# Follow the song without restarting audio or treating selection as an edit.
	# Keep the chosen phrase visible during its one-beat lead-in.
	if _preview_continuous and time >= _preview_follow_from and int(phase.index) >= 0 and int(phase.index) != selected:
		_display_phrase(int(phase.index))
	if int(phase.index) == selected:
		timeline.playhead = float(phase.beat)
		preview_label.text = "%s   ·   %.2f박" % ["시범" if phase.kind == "demo" else "재현", float(phase.beat)]
		if _preview_continuous:
			preview_label.text = "연속 · %02d/%02d\n%s" % [selected + 1, chart.phrases.size(), preview_label.text]
	else:
		timeline.playhead = -1.0
		preview_label.text = "연속 듣기\n다음 구간 대기" if _preview_continuous else "재생 준비"
	var phrase: Dictionary = chart.phrases[selected]
	for start_beat in [float(phrase.show_beat), float(phrase.response_beat)]:
		for index in range(phrase.notes.size()):
			var note: Dictionary = phrase.notes[index]
			var note_time := TouchChart.beat_to_seconds(chart, start_beat + float(note.beat))
			var elapsed := time - note_time
			if elapsed < 0.0 or elapsed >= PREVIEW_FLASH_SECONDS:
				continue
			var strength := 1.0 - elapsed / PREVIEW_FLASH_SECONDS
			# Multiple nearby notes may share a cell; keep its most recent pulse.
			var cell := int(note.cell)
			preview_pad.flash(cell, false, strength)
			timeline.preview_highlights[index] = maxf(float(timeline.preview_highlights.get(index, 0.0)), strength)
	timeline.queue_redraw()


func _mark_dirty() -> void:
	dirty = true
	_update_path()
	var error := TouchChart.validate(chart)
	_status("편집 중 · 저장되지 않은 변경사항이 있어요." if error.is_empty() else error, not error.is_empty())


func _update_path() -> void:
	path_label.text = ("● " if dirty else "") + chart_path
	path_label.tooltip_text = ProjectSettings.globalize_path(chart_path)
	DisplayServer.window_set_title("%s%s · TouchPattern Chart Maker" % ["* " if dirty else "", str(chart.get("title", ""))])


func _status(text: String, failed: bool = false) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", AppStyle.RED if failed else AppStyle.MUTED)


func _confirm_discard(action: Callable) -> void:
	if not dirty:
		action.call()
		return
	_stop_preview()
	var dialog := ConfirmationDialog.new()
	dialog.title = "저장되지 않은 변경사항"
	dialog.dialog_text = "저장되지 않은 편집 내용을 버리고 계속할까요?"
	dialog.ok_button_text = "버리고 계속"
	dialog.cancel_button_text = "취소"
	dialog.confirmed.connect(action)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible: dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_command_or_control_pressed() and event.keycode == KEY_S:
		if event.shift_pressed: _save_as()
		else: _save()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_discard(func() -> void: get_tree().quit())
