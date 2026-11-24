class_name Ch02Dialogue
extends CanvasLayer
## 第二章对白。短句跟随角色，旁白和长句使用字幕。
## 只负责「显示与推进」，不写剧情旗标；结束发 finished，由场景决定后果。

signal started
signal finished
signal line_shown(index: int, line: Dictionary)

const CREAM := Color("fff2cf")
const NARRATION := Color("c8b79a")
const PANEL_BG := Color(0.09, 0.06, 0.04, 0.94)

const CHARS_PER_SECOND := 46.0

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _hint: Label
var _style: StyleBoxFlat
var _actor: Node3D
var _taotao: Node3D
var _hero: Node3D
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


func play(lines: Array, taotao: Node3D = null, hero: Node3D = null) -> void:
	if lines == null or lines.is_empty() or _playing:
		return
	_lines = lines
	_taotao = taotao
	_hero = hero
	_index = -1
	_playing = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_visible_panel(true)
	_frame_nearby_speaker()
	started.emit()
	_next_line()


## 对话一开场：人先转过去，镜头跟上，别对着空气说话。
func _frame_nearby_speaker() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var best: Node3D = null
	var best_distance := 7.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var other := n as Node3D
		if other == null or other == player or not other.is_inside_tree():
			continue
		var d := other.global_position.distance_to(player.global_position)
		if d < best_distance:
			best_distance = d
			best = other
	if best == null:
		return
	var dir := best.global_position - player.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return
	player.rotation.y = atan2(-dir.x, -dir.z)
	var cam: Variant = player.get("camera")
	if cam != null and cam is Node3D:
		cam.set("yaw", player.rotation.y)


func stop() -> void:
	if not _playing:
		return
	_playing = false
	_lines = []
	_actor = null
	_taotao = null
	_hero = null
	_set_visible_panel(false)
	Input.mouse_mode = _previous_mouse_mode
	finished.emit()


func _process(delta: float) -> void:
	if not _playing:
		return
	_position_line()
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
	_name_label.visible = not who.is_empty()
	_actor = null
	if text.length() <= 34 and not text.contains("\n"):
		match who:
			"陶陶": _actor = _taotao
			"奶蛙": _actor = _hero if is_instance_valid(_taotao) else null
	_text_label.text = text
	_text_label.visible_characters = 0
	_text_label.add_theme_color_override("font_color", CREAM if not who.is_empty() else NARRATION)
	_length = text.length()
	_reveal = 0.0
	_position_line()
	line_shown.emit(_index, line)


func _set_visible_panel(value: bool) -> void:
	if _panel != null:
		_panel.visible = value


func _position_line() -> void:
	var viewport := get_viewport()
	var view := viewport.get_visible_rect().size
	var camera := viewport.get_camera_3d()
	var bubble := false
	var point := Vector2.ZERO
	if is_instance_valid(_actor) and camera != null:
		var height := 2.53 if _actor == _taotao else 2.25
		var head := _actor.global_position + Vector3.UP * height
		if not camera.is_position_behind(head):
			point = camera.unproject_position(head)
			bubble = point.x >= 150.0 and point.x <= view.x - 150.0 and point.y >= 180.0 and point.y <= view.y - 75.0
	var width := minf(view.x * 0.76, 350.0 if bubble else 620.0)
	_panel.size = Vector2(width, 0)
	var half := _panel.size.x * 0.5
	var x := clampf(point.x, half + 20.0, view.x - half - 20.0) if bubble else view.x * 0.5
	var y := point.y - 12.0 if bubble else view.y - 30.0
	_panel.position = Vector2(x - half, y - _panel.size.y)
	_style.bg_color = Color("211612bb") if bubble else Color("211612eb")


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "StoryLine"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	var theme := Theme.new()
	theme.default_font = font
	_panel.theme = theme

	_style = StyleBoxFlat.new()
	_style.bg_color = PANEL_BG
	_style.border_color = Color("b7845d99")
	_style.border_width_bottom = 1
	_style.set_corner_radius_all(5)
	_style.content_margin_left = 16
	_style.content_margin_right = 16
	_style.content_margin_top = 10
	_style.content_margin_bottom = 9
	_panel.add_theme_stylebox_override("panel", _style)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.add_theme_color_override("font_color", Color("e4b482"))
	column.add_child(_name_label)

	_text_label = Label.new()
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 21)
	_text_label.add_theme_constant_override("line_spacing", 4)
	column.add_child(_text_label)

	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = "F / 空格  继续"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color("dec5ad"))
	column.add_child(_hint)
