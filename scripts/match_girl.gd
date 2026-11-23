extends Node3D
## 圣诞小镇广场的卖火柴姑娘。

const INTERACT_RANGE := 3.2
const MODEL_PATH := "res://assets/models/match_girl_nailong.glb"
## 模型原始尺寸偏大（比玩家高约 4 倍），统一缩到正常 NPC 身高
const MODEL_SCALE := 0.25

var _player_near := false
var _prompt: Label3D
var _body: Node3D

var _overlay: CanvasLayer
var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _hint_label: Label
var _lines: PackedStringArray = PackedStringArray()
var _speakers: PackedStringArray = PackedStringArray()
var _index := 0
var _open := false
var _saved_mouse := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("match_girl")
	var res := load(MODEL_PATH)
	if res is PackedScene:
		_body = (res as PackedScene).instantiate() as Node3D
		if _body != null:
			_body.scale = Vector3.ONE * MODEL_SCALE
			add_child(_body)
	_build_prompt()
	_build_ui()
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = INTERACT_RANGE
	cs.shape = shape
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _build_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.text = "按 F 与卖火柴的小姑娘交谈"
	_prompt.font_size = 48
	_prompt.pixel_size = 0.012
	_prompt.position = Vector3(0, 1.7, 0)
	_prompt.modulate = Color(1.0, 0.92, 0.78)
	_prompt.visible = false
	add_child(_prompt)


func _build_ui() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "MatchGirlConversation"
	_overlay.layer = 28
	add_child(_overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 18
	root.theme = skin
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position = Vector2(-210, -115)
	_hint_label.size = Vector2(420, 42)
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color("fff2d3"))
	_hint_label.add_theme_color_override("font_outline_color", Color("302b25"))
	_hint_label.add_theme_constant_override("outline_size", 4)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_label)
	_hint_label.hide()
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 320
	_panel.offset_right = -100
	_panel.offset_top = -226
	_panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263c3df5")
	style.border_color = Color("b3a27b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 18
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", Color("efd9a8"))
	column.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 21)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_label)
	_panel.hide()


func _on_body_entered(b: Node3D) -> void:
	if b.is_in_group("Player"):
		_player_near = true


func _on_body_exited(b: Node3D) -> void:
	if b.is_in_group("Player"):
		_player_near = false


func _process(_delta: float) -> void:
	if _prompt != null:
		_prompt.visible = _player_near and not _open and not get_tree().paused and not Engine.is_editor_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if _open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_advance()
		return
	if Engine.is_editor_hint() or not _player_near or get_tree().paused:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_interact()


func _on_interact() -> void:
	match RunState.match_girl_stage:
		1:
			_lines = PackedStringArray([
				"给礼堂的豆奶带的？",
				"小姑娘从围裙兜里掏出一盒干燥的火柴，递给奶蛙。",
				"你走灶台后面那条巷子。看见摩天轮，就到她门口了。",
			])
			_speakers = PackedStringArray(["小女孩", "旁白", "小女孩"])
		2:
			_lines = PackedStringArray(["走灶台后面那条巷子。看见摩天轮，就到豆奶门口了。"])
			_speakers = PackedStringArray(["小女孩"])
		_:
			_lines = PackedStringArray(["要买火柴吗？这一盒还是干的。"])
			_speakers = PackedStringArray(["小女孩"])
	_begin_dialogue()


func _begin_dialogue() -> void:
	_index = 0
	_open = true
	_saved_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_line()


func _update_line() -> void:
	_text_label.text = _lines[_index]
	var sp: String = _speakers[_index] if _index < _speakers.size() else ""
	if sp.is_empty():
		_name_label.text = "旁白"
		_name_label.add_theme_color_override("font_color", Color("cfd9e0"))
	else:
		_name_label.text = sp
		_name_label.add_theme_color_override("font_color", Color("efd9a8"))
	_hint_label.text = "[F / Enter] 继续" if _index < _lines.size() - 1 else "[F / Enter] 关闭"
	_hint_label.show()
	_panel.show()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_update_line()


func _close() -> void:
	_open = false
	_panel.hide()
	_hint_label.hide()
	get_tree().paused = false
	Input.mouse_mode = _saved_mouse
	if RunState.match_girl_stage == 1 and RunState.spend_item("coins", 3):
		RunState.give_item("matches")
		RunState.match_girl_stage = 2
		RunState.save_progress()
		var game := get_tree().current_scene
		if game != null and game.get("hud") != null:
			game.hud.show_notice("火柴 ×1 · 从灶台后的小路回礼堂门房")


func _exit_tree() -> void:
	if _open:
		get_tree().paused = false
