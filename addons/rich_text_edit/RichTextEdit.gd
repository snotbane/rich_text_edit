## Generic class for word processing. Supports only plain text.
@tool class_name RichTextEdit extends Control

const LB := "[lb]"
const RB := "[rb]"

static var REGEX_BBCODE := RegEx.create_from_string(r"\[.*?\]")
static var REGEX_BRACKETS := RegEx.create_from_string(r"[\[\]]")


class ShaperLine extends RefCounted:
	var index: int
	var offset: float
	var height: float
	var range: Vector2i
	var length: int:
		get: return range.y - range.x

	var text: String


	func _init(__index__: int, rtl: RichTextLabel) -> void:
		index = __index__
		offset = rtl.get_line_offset(index)
		height = rtl.get_line_height(index)
		range = rtl.get_line_range(index)
		text = rtl.text.substr(range.x, length)

		print("self : %s" % [ self ])

	func _to_string() -> String:
		return "[%s]: \"%s\" (%s..%s)" % [index, text, range.x, range.y]


static func get_bbcode_text(raw: String) -> String:
	var result: String
	var search := 0

	var rm_brackets := REGEX_BRACKETS.search(raw)
	while rm_brackets:
		var br := LB if rm_brackets.get_string() == "[" else RB
		result += raw.substr(search, rm_brackets.get_start() - search) + br
		search = rm_brackets.get_end()
		rm_brackets = REGEX_BRACKETS.search(raw, search)

	result += raw.substr(search)
	search = 0

	return result


var display: RichTextLabel
var editor: TextEdit
var carets: Array[RichTextEditCaret]
var cursor_caret: RichTextEditCaret


var shaper_lines: Array[ShaperLine]
@export_multiline var text: String:
	get: return editor.text
	set(value):
		editor.text = value
		_refresh_text()
func _refresh_text():
	display.text = get_bbcode_text(text)

	assert(editor.text == display.get_parsed_text())
	# await get_tree().process_frame

	shaper_lines.resize(display.get_line_count())
	var start := 0
	for i in shaper_lines.size():
		shaper_lines[i] = ShaperLine.new(i, display)
		start += shaper_lines[i].text.length() + 1

	# _refresh_carets()


@export_group("Caret", "caret_")

@export var caret_multiple: bool = false:
	get: return editor.caret_multiple
	set(value): editor.caret_multiple = value


@export var caret_style_box: StyleBox


@export_subgroup("Blink", "caret_blink_")

var caret_blink_tween: Tween
var caret_blink_opacity: float = 1.0:
	set(value):
		caret_blink_opacity = value
		for caret in carets:
			caret.self_modulate = Color(1, 1, 1, caret_blink_opacity)

@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var caret_blink_enabled: bool = true:
	set(value):
		caret_blink_enabled = value
		_caret_blink_tween_refresh()


@export_range(0.0, 1.0, 0.01) var caret_blink_transition: float = 0.0:
	set(value):
		caret_blink_transition = value
		_caret_blink_tween_refresh()


var _caret_blink_interval_third: float = 0.333333
var _caret_blink_interval_half: float = 0.5
@export_range(0.01, 1.0, 0.01, "or_greater") var caret_blink_interval: float = 1.0:
	set(value):
		caret_blink_interval = value
		_caret_blink_tween_refresh()


func _caret_blink_tween_refresh() -> void:
	caret_blink_opacity = 1.0

	_caret_blink_interval_third = caret_blink_interval * 0.333333
	_caret_blink_interval_half = caret_blink_interval * 0.5
	var caret_hold_duration = maxf(0.0, caret_blink_interval - caret_blink_transition * 2.0) * 0.5

	if caret_blink_tween and caret_blink_tween.is_running():
		caret_blink_tween.kill()

	if not caret_blink_enabled: return

	caret_blink_tween = create_tween()
	caret_blink_tween.set_loops()
	caret_blink_tween.set_ease(Tween.EASE_IN_OUT)
	caret_blink_tween.set_trans(Tween.TRANS_LINEAR)

	if caret_blink_transition > 0.0:
		caret_blink_tween.tween_interval(caret_hold_duration)

		caret_blink_tween.tween_property(self , ^"caret_blink_opacity", 0.0, caret_blink_transition)

		caret_blink_tween.tween_interval(caret_hold_duration)

		caret_blink_tween.tween_property(self , ^"caret_blink_opacity", 1.0, caret_blink_transition)

	else:
		caret_blink_tween.tween_interval(_caret_blink_interval_half)

		caret_blink_tween.tween_property(self , ^"caret_blink_opacity", 0.0, 0.0)

		caret_blink_tween.tween_interval(_caret_blink_interval_half)

		caret_blink_tween.tween_property(self , ^"caret_blink_opacity", 1.0, 0.0)


@export_subgroup("Slide", "caret_slide_")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var caret_slide_enabled: bool = false:
	set(value):
		caret_slide_enabled = value

@export var caret_slide_duration: float = 0.1:
	set(value):
		caret_slide_duration = value

@export var caret_slide_trans: Tween.TransitionType = Tween.TransitionType.TRANS_CUBIC:
	set(value):
		caret_slide_trans = value


func _init() -> void:
	display = RichTextLabel.new()
	display.bbcode_enabled = true
	display.fit_content = true
	display.focus_mode = FOCUS_NONE
	display.mouse_filter = MOUSE_FILTER_STOP
	display.mouse_default_cursor_shape = CURSOR_IBEAM
	display.set_anchors_preset(PRESET_FULL_RECT)
	add_child(display, false, INTERNAL_MODE_BACK)

	editor = TextEdit.new()
	editor.add_theme_font_size_override(&"font_size", 10)
	editor.caret_blink = false
	editor.mouse_filter = MOUSE_FILTER_IGNORE
	editor.modulate = Color(0.0, 0.0, 1.0, 0.5)
	editor.set_anchors_preset(PRESET_FULL_RECT)
	add_child(editor, false, INTERNAL_MODE_BACK)

	cursor_caret = RichTextEditCaret.new()
	cursor_caret.modulate = Color.TRANSPARENT
	add_child(cursor_caret, false, INTERNAL_MODE_BACK)

	editor.caret_changed.connect(_refresh_carets)
	editor.text_changed.connect(_refresh_text)
	display.gui_input.connect(_display_gui_input)


func _ready() -> void:
	if caret_style_box == null: caret_style_box = StyleBoxFlat.new()

	_refresh_text()
	_caret_blink_tween_refresh()

	resized.connect.call_deferred(_refresh_carets)


func _refresh_carets() -> void:
	# editor.merge_overlapping_carets()
	while carets.size() < editor.get_caret_count():
		var caret := RichTextEditCaret.new()
		add_child(caret)
		carets.push_back(caret)

	while carets.size() > editor.get_caret_count():
		carets.pop_back().queue_free()

	for caret in carets:
		caret.set_display_index_from_editor()

	cursor_caret._refresh_shaper()

	_caret_blink_tween_refresh()


func _display_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor_caret.set_indeces_from_position(event.position)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		editor.grab_focus.call_deferred()

		var is_alt_held := false
		if is_alt_held:
			pass
		else:
			for caret in carets:
				caret.set_editor_index_from_display(cursor_caret.display_absolute_index)
