class_name Ch02Dialogue
extends CanvasLayer
## 第二章通用对白层：底部卡片 + 打字机 + 空格/点击推进。
## 只负责「显示与推进」，不写剧情旗标；结束发 finished，由场景决定后果。

signal started
signal finished
signal line_shown(index: int, line: Dictionary)

const CREAM := Color("fff2cf")
const NARRATION := Color("c8b79a")
const ORANGE := Color("f28b2f")
const PANEL_BG := Color(0.09, 0.06, 0.04, 0.94)

const CHARS_PER_SECOND := 46.0

## 陶陶立绘：从设定图裁出来的对话用半身像
const TAOTAO_PORTRAIT := "res://assets/chapter2/portraits/taotao_dialogue.png"

var _panel: PanelContainer
var _name_chip: PanelContainer
var _name_label: Label
var _text_label: Label
var _hint: Label
var _portrait: TextureRect
var _lines: Array = []
var _index := -1
var _reveal := 0.0
var _length := 0
var _playing := false
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 12
	_build_ui()
	_set_visible_panel(false)


func is_playing() -> bool:
	return _playing


func play(lines: Array) -> void:
	if lines == null or lines.is_empty() or _playing:
		return
	_lines = lines
	_index = -1
	_playing = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_visible_panel(true)
	started.emit()
	_next_line()


func stop() -> void:
	if not _playing:
		return
	_playing = false
	_lines = []
	_set_visible_panel(false)
	Input.mouse_mode = _previous_mouse_mode
	finished.emit()


func _process(delta: float) -> void:
	if not _playing:
		return
	if _reveal < float(_length):
		_reveal = minf(_reveal + CHARS_PER_SECOND * delta, float(_length))
		_text_label.visible_characters = int(_reveal)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	var advance := false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		advance = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	# 第一次按先补完整句，再按才推进——避免误触跳读
	if _reveal < float(_length):
		_reveal = float(_length)
		_text_label.visible_characters = -1
		return
	_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= _lines.size():
		stop()
		return
	var line: Dictionary = _lines[_index]
	var who := String(line.get("who", ""))
	var text := String(line.get("text", ""))
	_name_label.text = who
	_name_chip.visible = not who.is_empty()
	# 目前只有陶陶有立绘；旁白和居民保持纯文字
	if _portrait != null:
		_portrait.visible = who == "陶陶" and _portrait.texture != null
	_text_label.text = text
	_text_label.visible_characters = 0
	_text_label.add_theme_color_override("font_color", CREAM if not who.is_empty() else NARRATION)
	_length = text.length()
	_reveal = 0.0
	line_shown.emit(_index, line)


func _set_visible_panel(value: bool) -> void:
	if _panel != null:
		_panel.visible = value


# ------------------------------------------------------------------ 界面
func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -470.0
	_panel.offset_right = 470.0
	_panel.offset_top = -236.0
	_panel.offset_bottom = -48.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel",
			_panel_style(PANEL_BG, ORANGE, 20, 2))
	root.add_child(_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(132, 132)
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	if ResourceLoader.exists(TAOTAO_PORTRAIT):
		_portrait.texture = load(TAOTAO_PORTRAIT)
	row.add_child(_portrait)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	row.add_child(column)

	_name_chip = PanelContainer.new()
	_name_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_name_chip.add_theme_stylebox_override("panel",
			_panel_style(Color(0.78, 0.42, 0.16, 0.96), ORANGE, 12, 1))
	column.add_child(_name_chip)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 19)
	_name_label.add_theme_color_override("font_color", Color("2b1a10"))
	_name_chip.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(0, 96)
	_text_label.add_theme_font_size_override("font_size", 23)
	_text_label.add_theme_color_override("font_color", CREAM)
	_text_label.add_theme_constant_override("line_spacing", 8)
	column.add_child(_text_label)

	_hint = Label.new()
	_hint.text = "空格 / 左键  继续"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52, 0.9))
	column.add_child(_hint)


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
