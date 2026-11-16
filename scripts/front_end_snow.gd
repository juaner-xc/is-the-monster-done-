extends Control


const RecipeBook := preload("res://scripts/recipe_book.gd")
const Book := preload("res://scripts/book_ui.gd")
const INK := Color("372b22")
const PAPER := Color("efe0bc")
const COPPER := Color("c9a568")
const SNOW := Color("c9c7a7")
const MODEL_PATH := "res://assets/models/nailong_runner.glb"

var recipe_book: CanvasLayer
var screen_root: Control
var screen_name := "title"
var transitioning := false
var name_field: LineEdit
var name_error: Label
var model_turntable: Node3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	screen_root = Control.new()
	screen_root.name = "ScreenContent"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)
	_render_screen("title")
	recipe_book = RecipeBook.new()
	add_child(recipe_book)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB) and screen_name == "title" and not transitioning:
			if not recipe_book.is_open():
				get_viewport().set_input_as_handled()
				recipe_book.open_book()


func _open_recipe_book() -> void:
	if not transitioning:
		recipe_book.open_book()


func _process(delta: float) -> void:
	if is_instance_valid(model_turntable):
		model_turntable.rotate_y(delta * 0.16)


func _build_backdrop() -> void:
	Book.install(self)


func _transition_to(target: String) -> void:
	if transitioning:
		return
	transitioning = true
	var tween := create_tween()
	tween.tween_property(screen_root, "modulate:a", 0.0, 0.18)
	tween.tween_callback(_render_screen.bind(target))
	tween.tween_property(screen_root, "modulate:a", 1.0, 0.28)
	tween.tween_callback(func() -> void: transitioning = false)


func _render_screen(target: String) -> void:
	screen_name = target
	model_turntable = null
	for child in screen_root.get_children():
		screen_root.remove_child(child)
		child.queue_free()
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 62)
	margins.add_theme_constant_override("margin_right", 62)
	margins.add_theme_constant_override("margin_top", 48)
	margins.add_theme_constant_override("margin_bottom", 42)
	screen_root.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 25)
	margins.add_child(column)
	column.add_child(_top_line())
	match target:
		"title":
			_build_title(column)
		"identity", "rename":
			_build_identity(column)
		"reveal":
			_build_reveal(column)
		_:
			_build_title(column)


func _top_line() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 28
	var brand := _label("THE GOLDEN RECIPE  /  黄金食谱", 14, COPPER)
	row.add_child(brand)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label("饥饿异界   /   见习厨师的远征手记", 15, Book.MUTED))
	return row


func _build_title(column: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 65)
	column.add_child(body)
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size.x = 460
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 12)
	body.add_child(left_box)
	left_box.add_child(_label("—  一部尚未写完的魔法食谱  —", 18, COPPER))
	var game_title := _label("IS THE\nMONSTER DONE?", 60, PAPER)
	game_title.name = "GameTitle"
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	title_font.font_weight = 700
	game_title.add_theme_font_override("font", title_font)
	left_box.add_child(game_title)
	left_box.add_child(Book.rule())
	left_box.add_child(_paragraph("一次失败的料理，打开了饥饿异界。\n你带着一口锅，去找回失散的黄金菜谱。", 21, Color("c5b89c"), 60))
	left_box.add_child(_paragraph("当力量也有味道，你愿意付出什么代价？", 18, Book.MUTED, 28))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(space)
	var start := _button("开始冒险", COPPER)
	start.name = "StartAdventureButton"
	start.pressed.connect(func() -> void: _transition_to("identity"))
	left_box.add_child(start)
	if RunState.has_profile():
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 12)
		left_box.add_child(actions)
		var resume := Book.button("继续旅程  ·  %s" % RunState.player_name, false)
		resume.custom_minimum_size.x = 0
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resume.clip_text = true
		resume.tooltip_text = "继续 %s 的旅程" % RunState.player_name
		resume.pressed.connect(_open_route)
		actions.add_child(resume)
		var rename := Book.button("修改名字", false)
		rename.name = "RenamePlayerButton"
		rename.custom_minimum_size.x = 135
		rename.pressed.connect(func() -> void: _transition_to("rename"))
		actions.add_child(rename)
	var recipe_button := Book.button("料理图鉴  /  Tab", false)
	recipe_button.name = "RecipeEncyclopediaButton"
	recipe_button.pressed.connect(_open_recipe_book)
	left_box.add_child(recipe_button)
	var right := _panel(Color("222c24"), COPPER)
	right.custom_minimum_size.x = 480
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var right_box := _panel_column(right, 16)
	var volume := _label("✦   被撕碎的食谱 · 第一卷   ✦", 20, COPPER)
	volume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_box.add_child(volume)
	right_box.add_child(Book.map_picture(240))
	right_box.add_child(_label("第一章  /  雪原边境", 29, PAPER))
	right_box.add_child(_paragraph("风雪尽头，仍有一处火光。\n第一道料理，从这里开始。", 20, Book.MUTED, 54))
	right_box.add_child(Book.rule())
	right_box.add_child(_label("魔法料理   ·   自由构筑   ·   异界远征", 16, COPPER))
	column.add_child(_label("WASD 移动  ·  鼠标调整视角  ·  左键挥锅  ·  右键料理弹  ·  Shift 闪避 · 空格跳跃  ·  Tab 料理图鉴", 14, Book.MUTED))


func _build_identity(column: VBoxContainer) -> void:
	var renaming := screen_name == "rename"
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)
	var left := _panel(Color("f0e3ce"), COPPER)
	left.custom_minimum_size.x = 615
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var box := _panel_column(left, 10)
	box.add_child(_label("人物档案  /  修改署名" if renaming else "序章  /  裂缝之前", 18, Color("8d6249")))
	box.add_child(_label("换一个名字" if renaming else "你是——", 48, INK))
	box.add_child(_paragraph("故事还是你的故事。修改食谱上的署名，不会重置章节进度、已完成记录或遗物。" if renaming else "一位见习厨师。那天，你只是想做好一道菜，却让另一边的饥饿涌进了厨房。", 20, INK, 85))
	box.add_child(_paragraph("输入新名字（1—18 个字符），确认后保存。" if renaming else "在这本失散的食谱上，先写下你的名字。", 17, Color("665b52"), 34))
	name_field = LineEdit.new()
	name_field.name = "HeroNameInput"
	name_field.placeholder_text = "输入你的名字"
	name_field.text = RunState.player_name
	name_field.max_length = 18
	name_field.custom_minimum_size = Vector2(420, 54)
	name_field.add_theme_font_size_override("font_size", 23)
	name_field.add_theme_color_override("font_color", INK)
	name_field.add_theme_stylebox_override("normal", _style(Color("fff9ec"), COPPER, 12, 2))
	name_field.text_submitted.connect(func(_text: String) -> void: _accept_name())
	box.add_child(name_field)
	name_error = _label("", 15, Color("bd5447"))
	box.add_child(name_error)
	var confirm := _button("保存名字" if renaming else "写下名字，翻开食谱", COPPER)
	confirm.name = "ConfirmNameButton"
	confirm.pressed.connect(_accept_name)
	box.add_child(confirm)
	var back := _button("取消修改，返回标题" if renaming else "返回标题", Color("637b80"))
	back.name = "CancelNameButton"
	back.pressed.connect(func() -> void: _transition_to("title"))
	box.add_child(back)

	var right := _panel(Color("1e3038"), Color("4c6770"))
	right.custom_minimum_size.x = 390
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var right_box := _panel_column(right, 24)
	right_box.add_child(_label("旅程不会重写" if renaming else "第一道选择", 27, PAPER))
	right_box.add_child(_paragraph("保留章节进度与通关记录\n保留已获得的遗物\n只修改角色的显示名字" if renaming else "熟悉的配方能让你活下来。\n未知的搭配可能带来新的路。\n黑暗料理则会索取代价。", 21, SNOW, 180))
	right_box.add_child(_paragraph("名字可以改变，走过的路不会消失。" if renaming else "没有哪一种味道，能替所有人回答饥饿。", 18, Color("e9b683"), 100))
	name_field.grab_focus.call_deferred()


func _accept_name() -> void:
	if transitioning:
		return
	var chosen := name_field.text.strip_edges()
	if chosen.is_empty():
		name_error.text = "先写下名字，才能继续。"
		name_field.grab_focus()
		return
	if screen_name == "rename":
		var error := RunState.rename_player(chosen)
		if error != OK:
			name_error.text = "名字未保存，请检查输入或存档写入权限后重试。"
			return
		_transition_to("title")
		return
	RunState.begin_new_adventure(chosen)
	_transition_to("reveal")


func _build_reveal(column: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)
	var left := _panel(Color("f0e3ce"), COPPER)
	left.custom_minimum_size.x = 540
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var box := _panel_column(left, 11)
	box.add_child(_label("人物档案  /  PLAYER 01", 17, Color("8d6249")))
	box.add_child(_paragraph("%s，欢迎来到异界。" % RunState.player_name, 32, INK, 42))
	box.add_child(_paragraph("你操纵的，是误打误撞打开裂缝的见习厨师奶龙。手中的平底锅能击退怪物；手边的食材，还能组成从未有人写下的料理。", 19, INK, 110))
	box.add_child(_paragraph("黄金菜谱被暴食领主撕碎。第一张残页落在雪原。带着你选择的名字，去看看这道料理会走向哪里。", 17, Color("5c514b"), 100))
	_spacer(box, 8)
	var embark := _button("前往第一章 · 雪原边境", COPPER)
	embark.pressed.connect(_open_route)
	box.add_child(embark)
	var back := _button("返回标题", Color("637b80"))
	back.pressed.connect(func() -> void: _transition_to("title"))
	box.add_child(back)

	var right := _panel(Color("1b2e38"), SNOW)
	right.custom_minimum_size.x = 470
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var right_box := _panel_column(right, 12)
	right_box.add_child(_label("见习厨师 · 奶龙", 24, PAPER))
	right_box.add_child(_label("角色模型预览  /  可在游戏中奔跑与战斗", 15, Color("acc6cc")))
	_build_model_preview(right_box)


func _build_model_preview(parent: VBoxContainer) -> void:
	var preview := SubViewportContainer.new()
	preview.name = "HeroPreview"
	preview.stretch = true
	preview.custom_minimum_size = Vector2(400, 350)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(preview)
	var viewport := SubViewport.new()
	viewport.name = "HeroPreviewViewport"
	viewport.size = Vector2i(440, 420)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b2e38")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ffffff")
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -28, 0)
	light.light_energy = 1.5
	world.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.0, 4.2)
	camera.fov = 38
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	model_turntable = Node3D.new()
	world.add_child(model_turntable)
	var resource := load(MODEL_PATH)
	if resource is PackedScene:
		var model: Node3D = resource.instantiate()
		model.scale = Vector3.ONE * 3.0
		model.position.y = -0.15
		model.rotation.y = 0.0
		model_turntable.add_child(model)
		_configure_preview_materials(model)
		_play_idle(model)
	else:
		parent.add_child(_label("模型仍在导入中，请重新打开项目。", 16, PAPER))


func _configure_preview_materials(model: Node) -> void:
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface)
			if source is StandardMaterial3D:
				var material := source.duplicate() as StandardMaterial3D
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				material.albedo_color = Color(0.72, 0.72, 0.72, 1.0)
				material.roughness = 0.85
				mesh_instance.set_surface_override_material(surface, material)


func _play_idle(node: Node) -> bool:
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		for clip in player.get_animation_list():
			if String(clip).contains("Idle"):
				player.play(clip)
				return true
	for child in node.get_children():
		if _play_idle(child):
			return true
	return false


func _open_route() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/route_map.tscn")


func _panel(background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var parchment := background.r > 0.6
	panel.add_theme_stylebox_override("panel", Book.style(Color("d9c69f") if parchment else Color("222c24"), COPPER, 26))
	return panel


func _panel_column(panel: PanelContainer, separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	panel.add_child(box)
	return box


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _paragraph(value: String, font_size: int, color: Color, minimum_height: float) -> Label:
	var label := _label(value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = minimum_height
	return label


func _spacer(box: VBoxContainer, height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	box.add_child(space)


func _button(value: String, accent: Color) -> Button:
	return Book.button(value, accent == COPPER)


func _style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 21
	style.content_margin_bottom = 21
	return style
