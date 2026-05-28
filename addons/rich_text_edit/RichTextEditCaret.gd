class_name RichTextEditCaret extends Panel

var shaper: RichTextLabel


# var _bbcode_index_prev: int = -1
# var bbcode_index: int
# var display_index: int
# var editor_line: int
# var editor_column: int

var _display_absolute_index
var display_absolute_index: int:
	get: return _display_absolute_index

var _editor_column_line: Vector2i
var editor_column_line: Vector2i:
	get: return _editor_column_line


@onready var word: RichTextEdit = get_parent()


func _ready() -> void:
	assert(word is RichTextEdit)

	add_theme_stylebox_override(&"panel", word.caret_style_box)

	size.x = word.editor.get_theme_constant(&"caret_width")

	shaper = word.display.duplicate()
	shaper.mouse_filter = MOUSE_FILTER_IGNORE
	shaper.modulate = Color.TRANSPARENT
	shaper.set_anchors_preset(PRESET_TOP_LEFT)
	_refresh_shaper()
	add_child(shaper)


func _refresh_shaper() -> void:
	shaper.size = word.display.size


func _refresh_display():
	var display_line: int = (
		word.display.get_character_line(_display_absolute_index)
		if _display_absolute_index < word.text.length()
		else (word.display.get_line_count() - 1)
	)
	shaper.text = word.shaper_lines[display_line].text

	var display_column: int = _display_absolute_index - word.display.get_line_range(display_line).x
	shaper.visible_characters = word.shaper_lines[display_line].snippet_index(display_column)

	await get_tree().process_frame

	position = Vector2(
		shaper.get_visible_content_rect().size.x,
		shaper.get_line_offset(display_line)
	)

	var line_height := word.display.get_line_height(display_line)
	if line_height == 0: return

	size.y = line_height


func _refresh_editor():
	word.editor.set_caret_line(editor_column_line.y, true, true, 0, get_index())
	word.editor.set_caret_column(editor_column_line.x, true, get_index())


func column_line_to_absolute(column_line: Vector2i) -> int:
	var result := column_line.x
	for i in column_line.y:
		result += word.editor.get_line(i).length() + 1

	return result


func absolute_to_editor_column_line(absolute: int) -> Vector2i:
	var result := Vector2i.ZERO
	for i in word.editor.get_line_count():
		var line_text := word.editor.get_line(i)
	return result


func set_editor_index_from_display(value: int = display_absolute_index):
	if value == _display_absolute_index: return
	_display_absolute_index = value

	# _editor_column_line = absolute_to_editor_column_line(_display_absolute_index) ## Unnecessary because non-cursor carets don't need to update this info

	await _refresh_editor()


func set_display_index_from_editor() -> void:
	_editor_column_line = Vector2i(
		word.editor.get_caret_column(get_index()),
		word.editor.get_caret_line(get_index())
	)

	_display_absolute_index = column_line_to_absolute(_editor_column_line)

	await _refresh_display()


## Only valid on a cursor caret, so this does not affect the editor.
func set_indeces_from_position(pos: Vector2) -> void:
	_display_absolute_index = 0

	var shaper_line: RichTextEdit.ShaperLine
	for i in word.shaper_lines.size():
		shaper_line = word.shaper_lines[i]
		pos.y -= shaper_line.line_height
		if pos.y < 0.0: break

		_display_absolute_index += shaper_line.bbcode_length + 1

	shaper.text = shaper_line.bbcode_line
	var bin_search_factor = 0.5
	var nearest_index: int = 0
	var nearest_dist: float = INF

	for i in shaper_line.bbcode_length:
		shaper.visible_ratio = bin_search_factor
		var this_index := shaper.visible_characters
		if this_index == nearest_index: break

		await get_tree().process_frame

		var this_diff := pos.x - shaper.get_visible_content_rect().size.x
		var this_dist := absf(this_diff)
		if this_dist < nearest_dist:
			nearest_dist = this_dist
			nearest_index = this_index

		bin_search_factor += signf(this_diff) * (0.5 ** (i + 2))
		print("bin_search_factor : %s" % [bin_search_factor])

	_display_absolute_index += nearest_index
	_editor_column_line = absolute_to_editor_column_line(_display_absolute_index)

	await _refresh_display()
