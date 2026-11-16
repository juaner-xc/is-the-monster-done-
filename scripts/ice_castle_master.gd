extends Node3D

## 冰堡主人交互（doubao 模型，女性）。支持：
##  · 初始按 F 对话（没钥匙时提示钥匙丢了）
##  · 还钥匙 → 门开 → 豆包经门洞走人大厅（多路点+随坡爬升高度），到画像前站定
##  · 到画像后底部小字「她好像还有话说」，F 触发多说话人对话（仅一次）：
##    画像 → 道谢并给零钱（让玩家去圣诞小镇买火柴取暖）→ 底部小字「去圣诞小镇买火柴」
##  · 普通对话面板样式同食堂肯德齐，F/Enter 逐句推进，对话期间暂停游戏
const INTERACT_RANGE := 3.4

var _player_near := false
var _prompt: Label3D
var _hint_layer: CanvasLayer
var _body: Node3D
var _body_base_y := 0.0
var _castle: Node

# 对话 UI（与 snow_dining_house 同款样式）
var _overlay: CanvasLayer
var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _hint_label: Label
var _lines: PackedStringArray = []
var _speakers: PackedStringArray = []
var _index := 0
var _open := false
var _returning_key := false
var _saved_mouse := Input.MOUSE_MODE_VISIBLE

# 门开后演出
var _after_key := false
var _walking := false
var _waypoints: Array[Vector3] = []   # 世界坐标路径点（含各自目标高度）
var _wp_index := 0
var _walk_done := false
var _said_after := false
# 开场对话给零钱（仅一次）
var _gave_coins := false
var _dialogue_kind := ""

# 画像/喷泉前站位（冰堡本地坐标，由 _castle.global_position 换算到世界）
# 喷泉碰撞半径 4.0（中心 z=-6.15），站位取 z=-1.6 保证站在泉外
const PORTRAIT_STAND_LOCAL := Vector3(0.0, 0.0, -1.6)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 重生后按存档恢复「画像对话已完成」：底部小字继续显示「去圣诞小镇买火柴」，
	# 路标也据此指向小镇（否则实例变量丢失，任务提示与箭头都消失）
	if RunState.ice_castle_talk_done:
		_said_after = true
		_after_key = true
	_body = get_node_or_null("Body")
	# Body 子节点自带 0.9 的抬升（让脚底对齐根原点），必须保留，
	# 否则脚本把 position.y 归零会把豆包半截埋进地面
	if _body != null:
		_body_base_y = _body.position.y
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
	_prompt.text = "按 F 与冰堡主人交谈"
	_prompt.font_size = 48
	_prompt.pixel_size = 0.012
	_prompt.position = Vector3(0, 2.2, 0)
	_prompt.modulate = Color(0.85, 0.95, 1.0)
	_prompt.visible = false
	add_child(_prompt)


func _build_ui() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "MasterConversation"
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


func _resolve_castle() -> void:
	if _castle == null or not is_instance_valid(_castle):
		_castle = get_tree().get_first_node_in_group("ice_castle")


func _on_body_entered(b: Node3D) -> void:
	if b.is_in_group("Player") or b is CharacterBody3D:
		_player_near = true


func _on_body_exited(b: Node3D) -> void:
	if b.is_in_group("Player") or b is CharacterBody3D:
		_player_near = false


func _process(delta: float) -> void:
	_update_prompts()
	if _walking:
		_glide(delta)


## 箭头指引：需要还钥匙时指向门房本人；她走进大厅后指向画像前的她；
## 对话说完（已给零钱）交给小镇入口那一步，返回 INF。
func task_target() -> Vector3:
	if _said_after:
		return Vector3.INF
	return global_position


func _update_prompts() -> void:
	if _prompt != null:
		_prompt.visible = _player_near and not _open and not _after_key and not _said_after and not Engine.is_editor_hint()
	_update_bottom_hint()


## 底部小字：画像后「她好像还有话说（按 F）」→ 对话说完改「去圣诞小镇买火柴」（买到火柴后消失）
func _update_bottom_hint() -> void:
	var text := ""
	if _walk_done and not _said_after and not _open:
		text = "她好像还有话说（按 F）"
	elif _said_after and not _open and not RunState.has_item("matches"):
		text = "去圣诞小镇买火柴"
	if text != "":
		if _hint_layer == null:
			_hint_layer = CanvasLayer.new()
			_hint_layer.layer = 30
			var label := Label.new()
			label.name = "HintLabel"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
			label.position = Vector2(-210, -115)
			label.size = Vector2(420, 42)
			label.add_theme_font_size_override("font_size", 15)
			label.add_theme_color_override("font_color", Color("fff2d3"))
			label.add_theme_color_override("font_outline_color", Color("302b25"))
			label.add_theme_constant_override("outline_size", 4)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hint_layer.add_child(label)
			get_tree().root.add_child(_hint_layer)
		var lbl := _hint_layer.get_node_or_null("HintLabel") as Label
		if lbl != null:
			lbl.text = text
	elif _hint_layer != null:
		_hint_layer.queue_free()
		_hint_layer = null


func _glide(delta: float) -> void:
	if _wp_index >= _waypoints.size():
		_walking = false
		_walk_done = true
		if _body != null:
			_body.position.y = _body_base_y
		return
	var target := _waypoints[_wp_index]
	var step := 2.2 * delta
	var off := target - global_position
	off.y = 0.0
	# 高度单独缓动（门外地面 → 门前台阶 → 大厅地板），不再半截入土
	global_position.y = move_toward(global_position.y, target.y, 1.6 * delta)
	if off.length() <= step:
		global_position.x = target.x
		global_position.z = target.z
		_wp_index += 1
		if _wp_index >= _waypoints.size():
			_walking = false
			_walk_done = true
			if _body != null:
				_body.position.y = _body_base_y
	else:
		var dir := off.normalized()
		# 面向行进方向（模型前方为 -Z），每段路自动转身
		global_rotation.y = atan2(-dir.x, -dir.z)
		global_position.x += dir.x * step
		global_position.z += dir.z * step
	# 整体上下颠簸伪步行（无骨骼），叠加在原始抬升之上
	if _body != null and _walking:
		_body.position.y = _body_base_y + sin(Time.get_ticks_msec() * 0.006) * 0.04


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
	if event is InputEventKey:
		var ek := event as InputEventKey
		if ek.pressed and not ek.echo and ek.keycode == KEY_F:
			get_viewport().set_input_as_handled()
			_talk()


func _talk() -> void:
	if _said_after:
		return
	if _after_key and not _walk_done:
		return
	if _after_key:
		_dialogue_kind = "after"
		_start_dialogue([
			"门一开，奶蛙先看见墙上挂着一张照片。照片里的人端着一口锅，脸微微偏过来，像是拍照的人刚叫了他一声。",
			"奶蛙走近两步，才看清那张脸有多像自己。",
			"我刚见你的时候，还以为在哪儿见过你。你跟照片上这人长得真像。",
			"你认识他？",
			"不认识。镇上的人从一堆旧厨具里翻出来的。大伙儿说，礼堂墙上总得挂幅像样的画，就把它挂上了。",
			"谢谢你帮我找到钥匙。你来这儿身上没有钱吧，给你一些钱，你可以去圣诞小镇买根火柴取暖。",
			"真是太感谢你了。",
		], ["旁白", "旁白", "冰堡主人", "奶蛙", "冰堡主人", "冰堡主人", "奶蛙"])
		return
	_resolve_castle()
	if RunState.has_item("ice_castle_keys"):
		_returning_key = true
		_dialogue_kind = "return"
		_start_dialogue([
			"“还真是我的，”她蹲着没起身，小声嘟囔，“我都快把门口这片雪翻完了。”",
			"“进来吧。”她把冰门推开。",
		], ["冰堡主人", "冰堡主人"])
		return
	# 没钥匙时只提示钥匙丢了；火柴委托已移到还钥匙后的画像对话（道谢给钱）
	_dialogue_kind = "initial"
	_start_dialogue([
		"门被锁着，我把钥匙弄丢了。要是你在雪地里捡着，麻烦帮我带回来。",
	], ["冰堡主人"])


func _start_dialogue(lines: PackedStringArray, speakers: PackedStringArray) -> void:
	_lines = lines
	_speakers = speakers
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
	if _index < _lines.size() - 1:
		_hint_label.text = "[F / Enter] 继续"
	else:
		_hint_label.text = "[F / Enter] 关闭"
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
	if _returning_key:
		_returning_key = false
		RunState.take_item("ice_castle_keys")
		if _castle != null and _castle.has_method("open_by_key"):
			_castle.open_by_key()
		RunState.ice_castle_keys_returned = true
		_begin_after_key_walk()
	elif _after_key:
		_said_after = true
		RunState.ice_castle_talk_done = true
		if not _gave_coins:
			RunState.give_item("coins", 3)
			_gave_coins = true
	_dialogue_kind = ""


## 门开后：豆包经门洞走人大厅到喷泉/画像前（无骨骼，整体滑行+颠簸）
## 路径：门前台阶对正 → 踏上基座 → 过门洞 → 厅中央 → 喷泉/画像前
## 高度按实测地形：模型脚底=节点原点，门前台阶顶 0.6 → 基座/大厅地板 1.2（HALL_FLOOR）
func _begin_after_key_walk() -> void:
	_after_key = true
	_resolve_castle()
	if _castle != null and is_instance_valid(_castle):
		var o: Vector3 = _castle.global_position
		_waypoints = [
			o + Vector3(0.0, 0.6, 21.0),     # 门前台阶上对正（FrontStep 顶 y=0.6）
			o + Vector3(0.0, 1.2, 18.5),     # 踏上基座顶（与大厅地板同高）
			o + Vector3(0.0, 1.2, 14.9),     # 过门洞（DOOR_Z）
			o + Vector3(0.0, 1.2, 5.0),      # 厅中央
			o + PORTRAIT_STAND_LOCAL + Vector3(0.0, 1.2, 0.0),  # 喷泉/画像前站位
		]
	else:
		_waypoints = [
			global_position + Vector3(0.0, 0.0, -4.0),
			global_position + Vector3(0.0, 0.0, -10.0),
		]
	_wp_index = 0
	_walking = true


func _exit_tree() -> void:
	if _open:
		get_tree().paused = false
	if _hint_layer != null and is_instance_valid(_hint_layer):
		_hint_layer.queue_free()
		_hint_layer = null
