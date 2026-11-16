extends Control


const RecipeBook := preload("res://scripts/recipe_book.gd")
const Book := preload("res://scripts/book_ui.gd")
const INK := Color("372b22")
const PAPER := Color("efe0bc")
const COPPER := Color("c9a568")
const SNOW := Color("c9c7a7")
const MODEL_PATH := "res://assets/models/nailong_adventure.glb"
const HeroMotion = preload("res://scripts/hero_motion.gd")

var recipe_book: CanvasLayer
var screen_root: Control
var screen_name := "title"
var transitioning := false
var name_field: LineEdit
var name_error: Label
var model_turntable: Node3D
var chapter_buttons: Array[Button] = []
var chapter_info: Label
var chapter_loading_overlay: ColorRect
var chapter_loading_label: Label
var chapter_loading_bar: ProgressBar
var loading_chapter := false
var loading_scene_path := ""
var loading_chapter_title := ""


func _ready() -> void:
	get_tree().paused = false
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
	_build_chapter_loader()


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
	if loading_chapter:
		_poll_chapter_load()
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
	row.add_child(_label("开发版本   /   三章自由调试", 15, Book.MUTED))
	return row


func _build_title(column: VBoxContainer) -> void:
	chapter_buttons.clear()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 34)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 395
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 13)
	body.add_child(left)
	left.add_child(_label("—  一部尚未写完的魔法食谱  —", 17, COPPER))
	var title := _label("IS THE\nMONSTER DONE?", 51, PAPER)
	title.name = "GameTitle"
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	serif.font_weight = 700
	title.add_theme_font_override("font", serif)
	left.add_child(title)
	left.add_child(Book.rule())
	left.add_child(_paragraph("带着一口锅，走进饥饿异界。\n这一页，先由我们一起慢慢写完。", 21, Book.MUTED, 65))
	left.add_child(_paragraph("开发调试中 · 三章均可直接进入\n无需通关前章，也无需重建角色档案。", 18, COPPER, 58))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var story := Book.button("从序章开始新冒险", false)
	story.name = "StartAdventureButton"
	story.pressed.connect(func(): _transition_to("identity"))
	left.add_child(story)
	if RunState.has_profile():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		left.add_child(row)
		var resume := Book.button("剧情入口 · %s" % RunState.player_name, false)
		resume.custom_minimum_size.x = 0
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resume.clip_text = true
		resume.add_theme_font_size_override("font_size", 18)
		resume.pressed.connect(_open_route)
		row.add_child(resume)
		var rename := Book.button("修改名字", false)
		rename.name = "RenamePlayerButton"
		rename.custom_minimum_size.x = 125
		rename.add_theme_font_size_override("font_size", 18)
		rename.pressed.connect(func(): _transition_to("rename"))
		row.add_child(rename)
	var recipes := Book.button("料理图鉴 / Tab", false)
	recipes.name = "RecipeEncyclopediaButton"
	recipes.pressed.connect(_open_recipe_book)
	left.add_child(recipes)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 605
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)
	right.add_child(_label("✦  选择章节 · 直接进入场景", 23, COPPER))
	var index := 0
	for data in RunState.CHAPTERS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Book.style(Color("192c30"), COPPER, 18))
		card.custom_minimum_size.y = 113
		right.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		var number := _label(["I", "II", "III"][index], 33, COPPER)
		number.custom_minimum_size.x = 45
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(number)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", 9)
		row.add_child(words)
		words.add_child(_label(String(data["title"]), 24, PAPER))
		words.add_child(_label(String(data["debug_hint"]), 16, Book.MUTED))
		var enter := Book.button("进入第%s章" % ["一", "二", "三"][index], true)
		enter.name = "ChapterButton_"+String(data["id"])
		enter.custom_minimum_size = Vector2(140, 62)
		enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		enter.add_theme_font_size_override("font_size", 20)
		enter.set_meta("chapter_id", String(data["id"]))
		enter.pressed.connect(_open_debug_chapter.bind(String(data["id"])))
		row.add_child(enter)
		chapter_buttons.append(enter)
		index += 1
	chapter_info = _paragraph("第一章与第二章、第三章均为开发中内容。\n进入章节后可随时按 F10 返回这里。", 16, Book.MUTED, 46)
	right.add_child(chapter_info)
	column.add_child(_label("WASD 移动  ·  鼠标转视角  ·  左键挥锅  ·  F 交互  ·  V 挥手  ·  F10 章节首页  ·  Tab 料理图鉴", 14, Book.MUTED))


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
	right_box.add_child(_label("见习厨师 · 奶蛙", 24, PAPER))
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
		var motion := HeroMotion.new()
		if not motion.setup(model):
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
				material.vertex_color_is_srgb = true
				material.albedo_color = Color.WHITE
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


func _build_chapter_loader() -> void:
	chapter_loading_overlay = ColorRect.new()
	chapter_loading_overlay.color = Color(0.025,0.06,0.07,0.97)
	chapter_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chapter_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(chapter_loading_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chapter_loading_overlay.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 560
	col.add_theme_constant_override("separation", 22)
	center.add_child(col)
	var title := Book.label("翻开下一页食谱", 34, Book.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	chapter_loading_label = Book.label("", 22, Book.GOLD)
	chapter_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(chapter_loading_label)
	chapter_loading_bar = ProgressBar.new()
	chapter_loading_bar.custom_minimum_size.y = 10
	chapter_loading_bar.show_percentage = false
	chapter_loading_bar.add_theme_stylebox_override("fill", Book.style(Book.GOLD,Book.GOLD,0))
	col.add_child(chapter_loading_bar)
	chapter_loading_overlay.hide()

func _open_debug_chapter(id: String, with_film := false) -> void:
	if transitioning or loading_chapter or recipe_book.is_open():
		return
	var chapter := RunState.get_chapter(id)
	var path := String(chapter.get("scene", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		_show_chapter_error("章节场景不存在，请检查合并文件。")
		return
	if not RunState.select_chapter(id):
		_show_chapter_error("章节资料无法读取。")
		return
	if with_film:
		var films := {
			"snow": "res://scenes/chapter1_film.tscn",
			"second": "res://scenes/chapter2_film.tscn",
			"third": "res://scenes/chapter3_film.tscn",
		}
		if films.has(id):
			_open_chapter_with_film(path, films[id])
			return
	loading_scene_path = path
	loading_chapter_title = String(chapter["title"])
	for b in chapter_buttons: b.disabled = true
	chapter_loading_label.text = "正在打开 "+loading_chapter_title
	chapter_loading_bar.value = 0
	chapter_loading_overlay.show()
	var error := ResourceLoader.load_threaded_request(path)
	if error != OK:
		_show_chapter_error("加载未启动："+error_string(error))
		return
	loading_chapter = true


func _open_chapter_with_film(path: String, film_path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		_show_chapter_error("章节场景不存在，请检查合并文件。")
		return
	transitioning = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	CinematicFlow.pending_scene = path
	var error := ResourceLoader.load_threaded_request(film_path)
	if error != OK:
		transitioning = false
		CinematicFlow.pending_scene = ""
		_show_chapter_error("转场加载未启动：" + error_string(error))
		return
	while ResourceLoader.load_threaded_get_status(film_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(film_path) as PackedScene
	transitioning = false
	if packed == null:
		CinematicFlow.pending_scene = ""
		_show_chapter_error("转场读取失败，请重试。")
		return
	get_tree().change_scene_to_packed(packed)


func _poll_chapter_load() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(loading_scene_path,progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		loading_chapter = false
		var packed := ResourceLoader.load_threaded_get(loading_scene_path) as PackedScene
		if packed == null:
			_show_chapter_error("章节资源读取失败，可以重新点击重试。")
			return
		CinematicFlow.from_film = false
		CinematicFlow.battle_arrival = false
		CinematicFlow.clear_hold()
		if RunState.chapter_id == "second":
			CinematicFlow.set_meta("skip_minecart_intro", true)
		CinematicFlow.stop_wind(0.2)
		get_tree().paused = false
		if get_tree().change_scene_to_packed(packed) != OK:
			if CinematicFlow.has_meta("skip_minecart_intro"):
				CinematicFlow.remove_meta("skip_minecart_intro")
			_show_chapter_error("章节未能打开，请返回后重试。")
	elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		_show_chapter_error("章节加载失败，请检查导入资源后重试。")
	elif not progress.is_empty():
		chapter_loading_bar.value = float(progress[0])*100
		chapter_loading_label.text = "%s · %d%%" % [loading_chapter_title,roundi(chapter_loading_bar.value)]

func _show_chapter_error(message: String) -> void:
	loading_chapter = false
	chapter_loading_overlay.hide()
	for b in chapter_buttons:
		if is_instance_valid(b): b.disabled = false
	if is_instance_valid(chapter_info): chapter_info.text = message
