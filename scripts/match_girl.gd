extends Node3D
## 圣诞小镇 · 卖火柴的小姑娘。靠近按 F 对话，对话结束把「火柴」交给玩家。
## 买完火柴后的延伸剧情：
##   提示「按 F 划动火柴」→ 播放魔法食谱短片 → 提示获得食谱 → 第二段对话
##   → 提示「按 Tab 确认食谱」→ 打开「食谱合成料理」页（选两种食材合成，无需去食堂）。
## 对话 UI 样式同冰堡主人 / 食堂肯德齐，F/Enter 逐句推进，对话期间暂停游戏。

const INTERACT_RANGE := 3.2
const MODEL_PATH := "res://assets/models/match_girl_nailong.glb"
## 模型原始尺寸偏大（比玩家高约 4 倍），统一缩到正常 NPC 身高
const MODEL_SCALE := 0.25
const HERO_NAME := "我"
const MagicRecipeVideo = preload("res://scripts/magic_recipe_video.gd")

## 0=未买火柴 1=已买、待划火柴 2=划完、待看片 3=看完、待第二段对话 4=对话完、待确认食谱 5=已确认
var stage := 0
var _game: Node = null

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
var _sold := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("match_girl")
	# 重生后按存档精确恢复断点；正在播短片(2)时死了就退回「划火柴」重来
	stage = RunState.match_girl_stage
	if stage == 2:
		stage = 1
	if RunState.has_item("matches") or stage > 0:
		_sold = true
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
	if b.is_in_group("Player") or b is CharacterBody3D:
		_player_near = true


func _on_body_exited(b: Node3D) -> void:
	if b.is_in_group("Player") or b is CharacterBody3D:
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
	if event.is_action_pressed("interact") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_F):
		get_viewport().set_input_as_handled()
		_on_interact()
	elif event.is_action_pressed("tap") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_TAB):
		get_viewport().set_input_as_handled()
		_on_tap()


## 靠近按 F：第一次买火柴；之后按阶段推进剧情
func _on_interact() -> void:
	match stage:
		0:
			_talk_intro()
		1:
			_strike_match()
		3:
			_talk_after_recipe()
		4:
			_hint("按 Tab 确认食谱 · 食谱合成料理马上开启")
		5:
			_hint("按 Tab 打开食谱合成料理 · 自由搭配现有食材")


## 按 Tab：确认食谱 → 打开「食谱合成料理」页（已拿到食谱后随时可开）
func _on_tap() -> void:
	if stage >= 4:
		_open_cook()


## 食堂背包页入口：拿到食谱后随时打开合成页
func open_recipe_cook_from_kitchen() -> void:
	if RunState.magic_recipe_received:
		_set_stage(5)
	_open_cook()


## 推进剧情断点并立即存档（死亡重生后据此精确恢复 / 小字与路标据此指引）
func _set_stage(value: int) -> void:
	stage = value
	RunState.match_girl_stage = value
	RunState.save_progress()


func _hint(text: String) -> void:
	if _game != null and _game.get("hud") != null:
		var hud = _game.get("hud")
		if hud != null and hud.has_method("show_notice"):
			hud.show_notice(text)


func _find_game() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_show_recipe_arrival") or node.get("hud") != null:
			return node
		node = node.get_parent()
	return null


func _talk_intro() -> void:
	_lines = PackedStringArray([
		"你好，你想买根火柴吗，我今天一根火柴没有卖出去。",
		"我就是来买火柴的。",
		"谢谢你，这是你的火柴，它每次亮起都会有好运。",
	])
	_speakers = PackedStringArray(["小女孩", "奶蛙", "小女孩"])
	_begin_dialogue()


func _talk_after_recipe() -> void:
	_lines = PackedStringArray([
		"看，好运发生了。",
		"这是什么？",
		"这是一本魔法食谱，我只在奶奶的故事里听说过，那是一百年前留下来的。",
		"可能是与你有缘吧！它有想象不到的魔力。",
	])
	_speakers = PackedStringArray(["小女孩", HERO_NAME, "小女孩", "小女孩"])
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
	if stage == 0:
		if not _sold:
			_sold = true
			RunState.spend_item("coins", 3)
			RunState.give_item("matches", 1)
		_set_stage(1)
		_hint("火柴 ×1 已放入背包 · 按 F 划动火柴")
	elif stage == 3:
		_set_stage(4)
		_hint("按 Tab 确认食谱 · 食谱合成料理即将开启")


## 划火柴：播魔法食谱短片，播完进入「获得魔法食谱」提示
func _strike_match() -> void:
	_set_stage(2)
	_saved_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _game == null:
		_game = _find_game()
	if _game != null:
		_game.recipe_arrival_active = true
	var video := MagicRecipeVideo.new()
	add_child(video)
	video.completed.connect(_on_magic_video_done.bind(video))


func _on_magic_video_done(video: Node) -> void:
	video.queue_free()
	if _game != null and "recipe_arrival_active" in _game:
		_game.recipe_arrival_active = false
	get_tree().paused = false
	Input.mouse_mode = _saved_mouse
	RunState.magic_recipe_received = true
	_set_stage(3)
	_hint("获得魔法食谱 · 按 F 继续与小女孩对话")


# ------------------------------------------------------------------ 食谱合成料理
## 统一委托给 game 持有的随身合成台（食堂背包按钮也走这里），避免两套 UI。
func _open_cook() -> void:
	if _game == null:
		_game = _find_game()
	if _game != null and _game.has_method("open_recipe_cook"):
		_game.open_recipe_cook()
		_set_stage(5)


func _exit_tree() -> void:
	if _open:
		get_tree().paused = false
