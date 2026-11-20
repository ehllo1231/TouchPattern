class_name PatternStrip
extends ScrollContainer

signal phrase_selected(index: int)

var selected := 0
var thumbnails: Array[PatternThumbnail] = []
var _row := HBoxContainer.new()
var _group := ButtonGroup.new()
var _reveal_pending := false
var _layout_revision := 0


func _ready() -> void:
	custom_minimum_size.y = 132
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_horizontal_by_default = true
	follow_focus = true
	_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_row.add_theme_constant_override("separation", 0)
	add_child(_row)


func set_phrases(phrases: Array, audio_end_beat: float = INF) -> void:
	var layout_changed := thumbnails.size() != phrases.size()
	if thumbnails.size() != phrases.size():
		for thumbnail in thumbnails:
			_row.remove_child(thumbnail)
			thumbnail.queue_free()
		thumbnails.clear()
		for index in range(phrases.size()):
			var thumbnail := PatternThumbnail.new()
			thumbnail.button_group = _group
			thumbnail.pressed.connect(_on_thumbnail_pressed.bind(index))
			_row.add_child(thumbnail)
			thumbnails.append(thumbnail)
	var beat := 0.0
	for index in range(phrases.size()):
		var previous_width := thumbnails[index].custom_minimum_size.x
		var phrase: Dictionary = phrases[index]
		var ends_audio := is_finite(audio_end_beat) and is_equal_approx(audio_end_beat, float(phrase.response_beat) + float(phrase.length_beats))
		thumbnails[index].set_phrase(phrase, index, beat, ends_audio)
		layout_changed = layout_changed or not is_equal_approx(previous_width, thumbnails[index].custom_minimum_size.x)
		beat += float(phrases[index].length_beats)
	if layout_changed:
		_layout_revision += 1


func select(index: int) -> void:
	if index < 0 or index >= thumbnails.size():
		return
	selected = index
	for item in range(thumbnails.size()):
		thumbnails[item].set_pressed_no_signal(item == selected)
	if not _reveal_pending:
		_reveal_pending = true
		_reveal_selection.call_deferred()


func _reveal_selection() -> void:
	if not is_inside_tree():
		_reveal_pending = false
		return
	# A second rebuild can occur while an earlier selection is waiting for layout.
	var revision := _layout_revision
	await get_tree().process_frame
	while is_inside_tree() and revision != _layout_revision:
		revision = _layout_revision
		await get_tree().process_frame
	_reveal_pending = false
	if is_inside_tree() and selected >= 0 and selected < thumbnails.size():
		var thumbnail := thumbnails[selected]
		if thumbnail.size.x > size.x:
			# A long pattern opens at its first beat instead of its far edge.
			scroll_horizontal = int(thumbnail.position.x)
		else:
			ensure_control_visible(thumbnail)


func _on_thumbnail_pressed(index: int) -> void:
	select(index)
	phrase_selected.emit(index)
