class_name Ch02ChoiceUI
extends CanvasLayer
## 第二章的「能源二选一」：两张卡片，左栏写战斗中会发生什么，右栏写世界里会发生什么。
## 只负责显示与回传选择，不写旗标；旗标由场景来写。

signal chosen(id: String)

const CREAM := Color("fff2cf")
const ORANGE := Color("f28b2f")

var _root: Control
var _title: Label
var _row: HBoxContainer
var _playing := false


func _ready() -> void:
	layer = 14
	# 弹出时整个场景会暂停，这个界面必须能在暂停里继续跑，否则按钮点不动
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func present(title_text: String, options: Array) -> void:
	if _playing:
		return
	_playing = true
	_title.text = title_text
	for child in _row.get_children():
		child.queue_free()
	for option in options:
		_row.add_child(_build_card(option))
	_root.visible = true
	# 暂停场景：Boss 的招式、粒子、玩家移动全部停下，玩家只看这一个选择。
	# 顺带解决「鼠标记不住」——相机在暂停时才会把光标还回来。
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_playing = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _playing


func _build_card(option: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(390, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _style(Color(0.09, 0.06, 0.04, 0.96)))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)

	var name_label := Label.new()
	name_label.text = String(option.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", ORANGE)
	column.add_child(name_label)

	column.add_child(_line("战斗中", String(option.get("battle", ""))))
	column.add_child(_line("世界里", String(option.get("world", ""))))

	var button := Button.new()
	button.text = "就这个"
	button.custom_minimum_size = Vector2(0, 46)
	var id := String(option.get("id", ""))
	button.pressed.connect(func() -> void:
		close()
		chosen.emit(id)
	)
	column.add_child(button)
	return card


func _line(prefix: String, text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var head := Label.new()
	head.text = prefix
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52))
	box.add_child(head)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(340, 0)
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", CREAM)
	box.add_child(body)
	return box


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(840, 0)
	center.offset_left = -420.0
	center.offset_right = 420.0
	center.offset_top = -190.0
	center.offset_bottom = 190.0
	center.add_theme_constant_override("separation", 18)
	_root.add_child(center)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", CREAM)
	center.add_child(_title)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 26)
	center.add_child(_row)


func _style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = ORANGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style
