extends Control
## Legacy scene path retained; the circle graph is replaced by a chapter opening.
const Book := preload("res://scripts/book_ui.gd")
const BATTLE_PATH := "res://scenes/opening_film.tscn"
var loading_overlay: ColorRect
var loading_label: Label
var loading_bar: ProgressBar
var info_label: Label
var embark_button: Button
var back_button: Button
var loading_battle := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Book.install(self)
	_build_interface()
	modulate.a = 0.0
	create_tween().tween_property(self,"modulate:a",1.0,0.35)

func _build_interface() -> void:
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:
		margins.add_theme_constant_override("margin_"+side,65)
	for side in ["top","bottom"]:
		margins.add_theme_constant_override("margin_"+side,43)
	add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	margins.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var brand := Book.label("THE GOLDEN RECIPE   /   黄金食谱",15,Book.GOLD)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	top.add_child(Book.label("远征手记     ·     卷 一",17,Book.MUTED))
	column.add_child(Book.rule())
	var spread := PanelContainer.new()
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spread.add_theme_stylebox_override("panel",Book.style(Color("d9c69f"),Book.GOLD,28))
	column.add_child(spread)
	Book.paper_texture(spread)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",32)
	spread.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 360
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.73
	left.add_theme_constant_override("separation",13)
	body.add_child(left)
	left.add_child(Book.label("CHAPTER  I   /   远征启程",15,Color("80653d")))
	left.add_child(Book.label("第一章",28,Color("6d4532")))
	left.add_child(Book.label("雪原边境",56,Book.INK))
	left.add_child(Book.rule())
	left.add_child(Book.paragraph("风雪掩住了来路，\n却掩不住一缕炊烟。",23,Color("56452e")))
	left.add_child(Book.paragraph("一次失控的料理，把你带到了陌生的雪原。风雪中，一位老人正俯身看着你。带上平底锅，寻找回去的线索。",18,Color("66543d")))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(space)
	info_label = Book.paragraph("本章已完成 · 可以再次踏入雪原。" if "snow" in RunState.completed_chapters else "首站 · 雪原   /   第三人称料理战斗",16,Color("705339"))
	left.add_child(info_label)
	embark_button = Book.button("踏入雪原   →")
	embark_button.name = "EnterChapterButton"
	embark_button.pressed.connect(_start_battle_load)
	left.add_child(embark_button)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",12)
	body.add_child(right)
	right.add_child(Book.label("北 境 见 闻    /    THE FROSTLANDS",16,Color("755d38")))
	right.add_child(Book.map_picture(260))
	var quote := Book.paragraph("“火焰能煮熟食物。什么才能填满饥饿？”",19,Color("65523a"))
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(quote)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",25)
	column.add_child(footer)
	back_button = Book.button("←  返回书封",false)
	back_button.custom_minimum_size = Vector2(190,44)
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/front_end.tscn"))
	footer.add_child(back_button)
	var next_chapter := Book.label("三章调试入口均在首页",18,Book.MUTED)
	next_chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(next_chapter)
	footer.add_child(Book.label("I  /  II  /  III",17,Book.GOLD))
	_build_loader()

func _build_loader() -> void:
	loading_overlay = ColorRect.new()
	loading_overlay.color = Color(0.05,0.065,0.055,0.97)
	loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_overlay.visible = false
	add_child(loading_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 520
	column.add_theme_constant_override("separation",24)
	center.add_child(column)
	var heading := Book.label("第一章 · 雪原边境",36,Book.CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	loading_label = Book.label("正在翻开雪原手记…",22,Book.GOLD)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(loading_label)
	loading_bar = ProgressBar.new()
	loading_bar.custom_minimum_size.y = 8
	loading_bar.show_percentage = false
	loading_bar.add_theme_stylebox_override("background",Book.style(Color("242921"),Color("645739"),0))
	loading_bar.add_theme_stylebox_override("fill",Book.style(Book.GOLD,Book.GOLD,0))
	column.add_child(loading_bar)
	var hint := Book.label("WASD 移动   ·   左键挥锅   ·   空格翻滚",17,Book.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

func _start_battle_load() -> void:
	if loading_battle:
		return
	RunState.select_chapter("snow")
	embark_button.disabled = true
	back_button.disabled = true
	loading_overlay.visible = true
	loading_label.text = "正在翻开雪原手记…"
	loading_bar.value = 0
	var error := ResourceLoader.load_threaded_request(BATTLE_PATH)
	if error != OK:
		_show_load_error("无法启动加载：%s" % error_string(error))
		return
	loading_battle = true

func _process(_delta: float) -> void:
	if not loading_battle:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(BATTLE_PATH,progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		loading_battle = false
		var scene := ResourceLoader.load_threaded_get(BATTLE_PATH) as PackedScene
		if scene == null or get_tree().change_scene_to_packed(scene) != OK:
			_show_load_error("关卡打开失败，请重新导入项目资源。")
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_show_load_error("雪原资源加载失败，请重新导入项目资源。")
	elif not progress.is_empty():
		loading_bar.value = float(progress[0])*100.0
		loading_label.text = "正在准备雪原  %d%%" % roundi(loading_bar.value)

func _show_load_error(message: String) -> void:
	loading_battle = false
	loading_overlay.visible = false
	embark_button.disabled = false
	back_button.disabled = false
	info_label.text = message
	embark_button.grab_focus()
