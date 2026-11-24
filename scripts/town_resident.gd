extends Node3D
## 圣诞小镇的居民。纯氛围角色：站在广场上和玩家说几句话，不参战、不掉落、不推动剧情。
## 模型从 GLB 载入后按目标身高归一化，并自动落地对齐。

const INTERACT_RANGE := 2.8
const PROMPT_COLOR := Color(1.0, 0.92, 0.78)
const PANEL_BG := Color("263c3df5")
const PANEL_BORDER := Color("b3a27b")
const NAME_COLOR := Color("efd9a8")

## 由 town_level.gd 在实例化后写入
var resident_id: String = "cocoa"
var display_name: String = "热可可太太"
var model_path: String = ""
var prompt_text: String = ""
var target_height: float = 1.5
## 呼吸/摇晃幅度，越高越"晃"
var sway: float = 0.012
var dialogue: Array = []
var ambient_dialogue := false
var audience_only := false

var _player_near := false
var _ambient_speaking := false
var _prompt: Label3D
var _body: Node3D
var _body_base_y := 0.0
var _t := 0.0
var _eyes: Array[Node3D] = []
var _eye_heights: Array[float] = []
var _held_prop: Node3D
var _cocoa_steam: Array[MeshInstance3D] = []
var _cocoa_rim_height := 0.0

var _overlay: CanvasLayer
var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _hint_label: Label
var _index := 0
var _active_dialogue: Array = []
var _open := false
var _saved_mouse := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	if audience_only:
		_t = randf() * TAU
		_load_model()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("town_resident")
	_t = randf() * TAU
	_load_model()
	_build_prompt()
	if not ambient_dialogue:
		_build_ui()
	_build_collision()
	_build_area()


func _build_area() -> void:
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = INTERACT_RANGE
	cs.shape = shape
	cs.position.y = target_height * 0.5
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _load_model() -> void:
	if model_path.is_empty():
		return
	var res := load(model_path)
	if not (res is PackedScene):
		push_warning("居民模型缺失: " + model_path)
		return
	_body = (res as PackedScene).instantiate() as Node3D
	if _body == null:
		return
	add_child(_body)
	var box := _aabb_of(_body)
	if box.size.y > 0.001:
		var s := target_height / box.size.y
		_body.scale = Vector3.ONE * s
		_body.position.y = -box.position.y * s
	_body_base_y = _body.position.y
	_finish_model(box)


func _aabb_of(n: Node) -> AABB:
	var box := AABB()
	var first := true
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	var to_model := (n as Node3D).global_transform.affine_inverse()
	for mi in meshes:
		var mesh_instance := mi as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local := (to_model * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if first:
			box = local
			first = false
		else:
			box = box.merge(local)
	return box


func _finish_model(box: AABB) -> void:
	for eye_name in ["EyeL", "EyeR"]:
		var eye := _body.get_node_or_null(eye_name) as Node3D
		if eye != null:
			_eyes.append(eye)
			_eye_heights.append(eye.scale.y)
	match resident_id:
		"ginger":
			# 提灯挂在左手上，随呼吸轻晃
			_pivot_prop(Vector3(0.505, 0.800, -0.010), ["Lantern", "LanternRope"])
		"cinnamon":
			# 托盘连同三个小肉桂卷一起端在身前
			_pivot_prop(Vector3(0.0, 0.588, -0.610), [
				"Tray", "MiniRoll0", "MiniRoll1", "MiniRoll2",
				"MiniIcing0", "MiniIcing1", "MiniIcing2",
			])
		"candy":
			_pivot_prop(Vector3(0.342, 0.788, -0.126), ["Lantern", "LanternRope"])
		"cocoa":
			var tag_origin := Vector3(0.19, box.end.y - 0.24, box.position.z * 0.76)
			var tag := _piece_box(tag_origin, Vector3(0.16, 0.20, 0.035), Color("d5ba86"))
			tag.rotation.z = -0.15
			_piece_box(tag_origin + Vector3(-0.015, 0.158, 0.007), Vector3(0.023, 0.18, 0.023), Color("d8c59d"))
			_piece_box(tag_origin + Vector3(0, -0.02, -0.022), Vector3(0.081, 0.019, 0.009), Color("9d6051"))
			for i in 3:
				var steam := _orb(Vector3.ZERO, Vector3(0.125, 0.095, 0.105), Color(0.88, 0.83, 0.69, 0.31))
				steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_cocoa_steam.append(steam)
			_cocoa_rim_height = box.end.y


func _pivot_prop(at: Vector3, piece_names: Array[String]) -> void:
	_held_prop = Node3D.new()
	_held_prop.name = "HeldPropPivot"
	_held_prop.position = at
	_body.add_child(_held_prop)
	for piece_name in piece_names:
		var piece := _body.get_node_or_null(piece_name) as Node3D
		if piece != null:
			piece.reparent(_held_prop, true)


func _piece_box(at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _model_piece(at, mesh, color)


func _orb(at: Vector3, radii: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var piece := _model_piece(at, mesh, color)
	piece.scale = radii
	return piece


func _model_piece(at: Vector3, mesh: Mesh, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	_body.add_child(piece)
	return piece


func _build_collision() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = maxf(target_height * 0.85, 0.8)
	cs.shape = capsule
	cs.position.y = capsule.height * 0.5
	body.add_child(cs)
	add_child(body)


func _build_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.text = prompt_text if not prompt_text.is_empty() else "按 F 和" + display_name + "说话"
	_prompt.font_size = 48
	_prompt.pixel_size = 0.010
	_prompt.outline_size = 8
	_prompt.position = Vector3(0, target_height + 0.42, 0)
	_prompt.modulate = PROMPT_COLOR
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.visible = false
	add_child(_prompt)


func _build_ui() -> void:
	_overlay = CanvasLayer.new()
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
	_panel.offset_top = -206
	_panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 23)
	_name_label.add_theme_color_override("font_color", NAME_COLOR)
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


func _process(delta: float) -> void:
	_t += delta
	if _body != null:
		# 站着的轻微呼吸 + 前后一点点晃，静止角色不至于像雕塑
		_body.position.y = _body_base_y + sin(_t * 1.5) * sway
		_body.rotation.z = sin(_t * 0.8) * sway * 0.5
		_body.rotation.x = sin(_t * 1.1 + 0.6) * sway * 0.25
		var blink := smoothstep(0.0, 0.075, absf(fposmod(_t, 4.2) - 0.10))
		for i in _eyes.size():
			_eyes[i].scale.y = _eye_heights[i] * lerpf(0.15, 1.0, blink)
		if _held_prop != null:
			if resident_id == "cinnamon":
				_held_prop.rotation.x = sin(_t * 1.1) * 0.095
			else:
				_held_prop.rotation.z = sin(_t * 1.9) * 0.13
		for i in _cocoa_steam.size():
			var phase := fposmod(_t * 0.62 + float(i) / _cocoa_steam.size(), 1.0)
			var puff := _cocoa_steam[i]
			puff.position = Vector3(-0.18 + sin(i + phase * 2.8) * 0.08, _cocoa_rim_height + phase * 0.35, 0.02)
			puff.scale = Vector3(0.10, 0.07, 0.09) * sin(phase * PI)
	if _prompt != null:
		_prompt.visible = _player_near and not _open and not _ambient_speaking and not get_tree().paused \
				and not Engine.is_editor_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if _open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_advance()
		return
	if Engine.is_editor_hint() or not _player_near or _ambient_speaking or get_tree().paused:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if ambient_dialogue:
			_speak_without_pausing()
		else:
			_open_dialogue()


func _speak_without_pausing() -> void:
	if dialogue.is_empty():
		return
	_ambient_speaking = true
	await say_briefly(String(dialogue[0]))
	_ambient_speaking = false


func _open_dialogue() -> void:
	if dialogue.is_empty():
		return
	_active_dialogue = dialogue.duplicate()
	if RunState.snow_town_lights_stage == 1 and resident_id == "candy":
		_active_dialogue.append("那是我家屋顶！看，灯线拖进旧货运站了，站台上有根扳道杆。")
	elif RunState.snow_town_lights_stage == 4:
		match resident_id:
			"ginger": _active_dialogue.append("是你找回的灯吧？屋顶的星星我来挂，你到篝火边歇会儿。")
			"cinnamon": _active_dialogue.append("灯亮了，我也把那扇旧炉门扶回去了。明天还能照常开摊。")
			"cocoa", "candy": _active_dialogue.append("灯又亮了，我记得是你找回来的。篝火边给你留了一只碗。")
	_index = 0
	_open = true
	_saved_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_line()


func say_briefly(line: String) -> void:
	var speech := Label3D.new()
	speech.text = line
	speech.position.y = target_height + 0.48
	speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech.font_size = 40
	speech.pixel_size = 0.006 if ambient_dialogue else 0.009
	speech.modulate = PROMPT_COLOR
	speech.visibility_range_end = 22.0
	add_child(speech)
	if ambient_dialogue:
		speech.modulate.a = 0.0
		var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		fade.tween_property(speech, "modulate:a", 1.0, 0.25)
		fade.tween_interval(4.0)
		fade.tween_property(speech, "modulate:a", 0.0, 0.35)
		await fade.finished
	else:
		await get_tree().create_timer(4.0, false).timeout
	speech.queue_free()


func _show_line() -> void:
	_name_label.text = display_name
	_text_label.text = String(_active_dialogue[_index])
	_hint_label.text = "[F / Enter] 继续" if _index < _active_dialogue.size() - 1 else "[F / Enter] 关闭"
	_hint_label.show()
	_panel.show()


func _advance() -> void:
	_index += 1
	if _index >= _active_dialogue.size():
		_close()
	else:
		_show_line()


func _close() -> void:
	_open = false
	_panel.hide()
	_hint_label.hide()
	get_tree().paused = false
	Input.mouse_mode = _saved_mouse


func _exit_tree() -> void:
	if _open:
		get_tree().paused = false
