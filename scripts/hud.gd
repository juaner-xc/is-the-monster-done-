extends CanvasLayer


signal upgrade_chosen(id: String)
signal restart_requested
signal route_map_requested
signal resume_requested
signal recipes_requested
signal title_requested

const Book := preload("res://scripts/book_ui.gd")

const INK := Color("3a2418")
const CREAM := Color("fff2cf")
const PANEL_DARK := Color(0.025, 0.07, 0.08, 0.93)
const PANEL_LIGHT := Color(0.98, 0.88, 0.66, 0.96)
const ORANGE := Color("ba9a62")
const RED := Color("e05243")
const GREEN := Color("76b852")
const BLUE := Color("5bbde8")

const INGREDIENT_COLORS := {
	"chili": "e95445",
	"oil": "f3b23a",
	"fruit": "d85ea7",
	"ice": "68c9ed",
	"mushroom": "9a72d1",
	"cream": "f5dfad",
	"flour": "dfc79e",
	"black_salt": "66506e",
}

var health_label: Label
var health_bar: ProgressBar
var experience_label: Label
var experience_bar: ProgressBar
var build_label: Label
var timer_label: Label
var wave_label: Label
var help_label: Label
var notice_label: Label
var notice_panel: PanelContainer
var upgrade_overlay: ColorRect
var upgrade_button_box: HBoxContainer
var upgrade_title: Label
var upgrade_subtitle: Label
var end_overlay: ColorRect
var end_title: Label
var pause_overlay: ColorRect
var pause_title: Label
var pause_description: Label
var pause_resume_button: Button
var pause_title_button: Button
var confirming_return := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()


func update_status(player: Node, recipe_system: Node, time_left: float, wave: int, enemy_count: int) -> void:
	health_bar.max_value = player.max_health
	health_bar.value = maxf(player.health, 0.0)
	health_label.text = "%d / %d" % [roundi(player.health), roundi(player.max_health)]
	update_condensation(player.experience, player.experience_needed)
	build_label.text = player.kitchen_status() if player.has_method("kitchen_status") else ""
	var total_seconds := maxi(0, ceili(time_left))
	timer_label.text = "%02d:%02d" % [floori(float(total_seconds) / 60.0), total_seconds % 60]
	wave_label.text = "第 %d 波  ·  场上 %d" % [wave, enemy_count]


func update_condensation(current: int, needed: int) -> void:
	var filled := mini(current, needed)
	experience_bar.max_value = needed
	experience_bar.value = filled
	experience_label.text = "%d / %d" % [filled, needed]


func show_upgrade(options: Array[Dictionary], discovery := false) -> void:
	upgrade_title.text = "发现魔力凝材" if discovery else "魔力凝材"
	upgrade_subtitle.text = "散逸的魔力凝结了 · 选择一种食材" if discovery else "选择一种食材"
	for child in upgrade_button_box.get_children():
		upgrade_button_box.remove_child(child)
		child.queue_free()
	for option in options:
		var button := Button.new()
		var option_id: String = option["id"]
		var accent := Color(INGREDIENT_COLORS.get(option_id, "f28b2f"))
		button.text = option["name"]
		button.custom_minimum_size = Vector2(275.0, 235.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		_style_ingredient_button(button, accent)
		button.pressed.connect(func() -> void: _choose_upgrade(option_id))
		upgrade_button_box.add_child(button)
	upgrade_overlay.visible = true
	if upgrade_button_box.get_child_count() > 0:
		upgrade_button_box.get_child(0).grab_focus()


func is_upgrade_open() -> bool:
	return upgrade_overlay.visible


func show_end_screen(won: bool) -> void:
	end_title.text = "料理完成！" if won else "这锅糊了……"
	end_title.add_theme_color_override("font_color", GREEN if won else RED)
	end_overlay.visible = true


func show_notice(text: String) -> void:
	notice_label.text = text
	notice_panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(notice_panel, "modulate:a", 0.0, 0.55)


func set_paused_hint(paused: bool) -> void:
	help_label.text = "暂停中  ·  按 Esc 返回厨房" if paused else "左键 挥锅 · 右键 调味 · Shift 闪避 · 空格 跳跃\nV 挥手 / Tab 料理手记 / Esc 暂停"
	pause_overlay.visible = paused
	confirming_return = false
	_update_pause_menu()
	if paused:
		pause_resume_button.grab_focus()
	else:
		pause_resume_button.release_focus()
		pause_title_button.release_focus()


func cancel_return_confirmation() -> bool:
	if not confirming_return:
		return false
	confirming_return = false
	_update_pause_menu()
	pause_resume_button.grab_focus()
	return true


func _update_pause_menu() -> void:
	pause_title.text = "返回主界面？" if confirming_return else "炉火暂歇"
	pause_description.text = "本场战斗的进度和临时构筑不会保存。\n已有名字、章节记录与遗物会保留。" if confirming_return else "旅途可以稍作停留。\n准备好后，再回到雪原的火光里。"
	pause_resume_button.text = "取消，留在暂停菜单" if confirming_return else "继续游戏  /  Esc"
	pause_title_button.text = "确认返回主界面" if confirming_return else "返回主界面"


func _on_pause_resume() -> void:
	if cancel_return_confirmation():
		return
	resume_requested.emit()


func _on_pause_title() -> void:
	if confirming_return:
		title_requested.emit()
	else:
		confirming_return = true
		_update_pause_menu()
		pause_resume_button.grab_focus()


func _build_pause_overlay(root: Control) -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseMenu"
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.03,0.045,0.035,0.88)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	root.add_child(pause_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540,360)
	panel.add_theme_stylebox_override("panel",Book.style(Color("222c24"),Book.GOLD,32))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi","STKaiti","SimSun"])
	panel.theme = Theme.new()
	panel.theme.default_font = font
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",20)
	panel.add_child(column)
	column.add_child(Book.label("THE GOLDEN RECIPE  /  远征手记",15,Book.GOLD))
	pause_title = Book.label("炉火暂歇",36)
	column.add_child(pause_title)
	column.add_child(Book.rule())
	pause_description = Book.paragraph("",20)
	pause_description.custom_minimum_size = Vector2(470,64)
	column.add_child(pause_description)
	pause_resume_button = Book.button("继续游戏  /  Esc")
	pause_resume_button.name = "ResumeGameButton"
	pause_resume_button.pressed.connect(_on_pause_resume)
	column.add_child(pause_resume_button)
	var recipe_button := Book.button("本局料理配方  /  Tab", false)
	recipe_button.name = "PauseRecipesButton"
	recipe_button.pressed.connect(func() -> void: recipes_requested.emit())
	column.add_child(recipe_button)
	pause_title_button = Book.button("返回主界面",false)
	pause_title_button.name = "ReturnTitleButton"
	pause_title_button.pressed.connect(_on_pause_title)
	column.add_child(pause_title_button)
	_update_pause_menu()


func _choose_upgrade(id: String) -> void:
	upgrade_overlay.visible = false
	upgrade_chosen.emit(id)


func _build_interface() -> void:
	var root := Control.new()
	root.name = "KitchenHUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_status_card(root)
	_build_condensation_card(root)
	_build_timer_card(root)
	_build_recipe_card(root)
	_build_help_bar(root)
	_build_notice(root)
	for child in root.get_children():
		_make_mouse_transparent(child)
	_build_upgrade_overlay(root)
	_build_end_overlay(root)
	_build_pause_overlay(root)


func _make_mouse_transparent(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_mouse_transparent(child)


func _build_status_card(root: Control) -> void:
	var frame=load("res://scripts/arcane_trim.gd").new()
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	frame.offset_left=28;frame.offset_right=298;frame.offset_top=-160;frame.offset_bottom=-103
	var title=Label.new();title.text="◇  "+(RunState.player_name if RunState.has_profile() else "奶蛙")
	title.position=Vector2(16,9);title.add_theme_font_size_override("font_size",16);title.add_theme_color_override("font_color",Color("e1d5b4"));frame.add_child(title)
	health_bar=ProgressBar.new();frame.add_child(health_bar);health_bar.position=Vector2(17,37);health_bar.size=Vector2(230,8);health_bar.show_percentage=false
	_style_progress_bar(health_bar,Color("17262b"),Color("81bbb1"))
	health_bar.add_theme_font_size_override("font_size",1);health_bar.size.y=8
	health_label=Label.new();frame.add_child(health_label);health_label.position=Vector2(170,10);health_label.size.x=80;health_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;health_label.add_theme_font_size_override("font_size",14)


func _build_condensation_card(root: Control) -> void:
	var frame := preload("res://scripts/arcane_trim.gd").new()
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	frame.offset_left = 28
	frame.offset_right = 298
	frame.offset_top = -93
	frame.offset_bottom = -30
	var title := Label.new()
	title.text = "魔力凝结"
	title.position = Vector2(17, 10)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", CREAM)
	frame.add_child(title)
	experience_label = Label.new()
	experience_label.position = Vector2(122, 12)
	experience_label.size.x = 125
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	experience_label.add_theme_font_size_override("font_size", 14)
	frame.add_child(experience_label)
	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(17, 39)
	experience_bar.size = Vector2(230, 9)
	experience_bar.show_percentage = false
	_style_progress_bar(experience_bar, Color("26383c"), Color("e0ba73"))
	frame.add_child(experience_bar)


func _build_timer_card(root: Control) -> void:
	# Keep compatibility with game/aftermath, without a permanent timer panel.
	var box=VBoxContainer.new();root.add_child(box);box.position=Vector2(30,24)
	var title=Label.new();title.text="雪原边境";title.add_theme_font_size_override("font_size",14);title.add_theme_color_override("font_color",Color("dbd1b6"));box.add_child(title)
	timer_label=Label.new();box.add_child(timer_label);timer_label.add_theme_font_size_override("font_size",12)
	wave_label=Label.new();box.add_child(wave_label);wave_label.hide()


func _build_recipe_card(root: Control) -> void:
	build_label=Label.new();root.add_child(build_label);build_label.hide()


func _build_help_bar(root: Control) -> void:
	help_label=Label.new();root.add_child(help_label);help_label.hide()
	help_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	help_label.offset_left=-330;help_label.offset_right=-30;help_label.offset_top=-66;help_label.offset_bottom=-25
	help_label.text="左键 挥锅  ·  右键 调味  ·  Shift 闪避 · 空格 跳跃\nV 挥手  /  Tab 背包  /  Esc 暂停"
	help_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	help_label.add_theme_font_size_override("font_size",13);help_label.add_theme_color_override("font_color",Color("ddd5bd"));help_label.add_theme_color_override("font_shadow_color",Color("15242a"));help_label.add_theme_constant_override("shadow_outline_size",4)


func _build_notice(root: Control) -> void:
	notice_panel = PanelContainer.new()
	notice_panel.anchor_left = 0.5
	notice_panel.anchor_right = 0.5
	notice_panel.offset_left = -260.0
	notice_panel.offset_right = 260.0
	notice_panel.offset_top = 110.0
	notice_panel.offset_bottom = 146.0
	notice_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.07, 0.04, 0.94), ORANGE, 18, 2))
	root.add_child(notice_panel)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 15)
	notice_label.add_theme_color_override("font_color", CREAM)
	notice_panel.add_child(notice_label)
	notice_panel.modulate.a = 0.0


func _build_upgrade_overlay(root: Control) -> void:
	upgrade_overlay = ColorRect.new()
	upgrade_overlay.color = Color(0.04, 0.025, 0.018, 0.88)
	upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade_overlay.visible = false
	root.add_child(upgrade_overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -500.0
	panel.offset_top = -260.0
	panel.offset_right = 500.0
	panel.offset_bottom = 260.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color("f6ddb0"), ORANGE, 26, 4))
	upgrade_overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	upgrade_title = Label.new()
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title.add_theme_font_size_override("font_size", 34)
	upgrade_title.add_theme_color_override("font_color", INK)
	layout.add_child(upgrade_title)
	upgrade_subtitle = Label.new()
	upgrade_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_subtitle.add_theme_font_size_override("font_size", 16)
	upgrade_subtitle.add_theme_color_override("font_color", Color("76523d"))
	layout.add_child(upgrade_subtitle)
	upgrade_button_box = HBoxContainer.new()
	upgrade_button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_button_box.add_theme_constant_override("separation", 20)
	layout.add_child(upgrade_button_box)


func _build_end_overlay(root: Control) -> void:
	end_overlay = ColorRect.new()
	end_overlay.color = Color(0.035, 0.02, 0.015, 0.9)
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.visible = false
	root.add_child(end_overlay)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_top = -155.0
	panel.offset_right = 260.0
	panel.offset_bottom = 155.0
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_LIGHT, ORANGE, 28, 4))
	end_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var small_title := Label.new()
	small_title.text = "怪物，熟了没？"
	small_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small_title.add_theme_color_override("font_color", Color("76523d"))
	box.add_child(small_title)
	end_title = Label.new()
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 42)
	box.add_child(end_title)
	var restart_button := Button.new()
	restart_button.text = "再做一锅"
	restart_button.custom_minimum_size = Vector2(280.0, 58.0)
	restart_button.add_theme_font_size_override("font_size", 20)
	_style_ingredient_button(restart_button, ORANGE)
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(restart_button)
	var route_button := Button.new()
	route_button.text = "返回章节手记"
	route_button.custom_minimum_size = Vector2(280.0, 52.0)
	route_button.add_theme_font_size_override("font_size", 19)
	_style_ingredient_button(route_button, Color("61bde8"))
	route_button.pressed.connect(func() -> void: route_map_requested.emit())
	box.add_child(route_button)


func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _style_progress_bar(bar: ProgressBar, background: Color, fill: Color) -> void:
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = background
	background_style.set_corner_radius_all(1)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(1)
	bar.add_theme_stylebox_override("background", background_style)
	bar.add_theme_stylebox_override("fill", fill_style)


func _style_ingredient_button(button: Button, accent: Color) -> void:
	var normal := _panel_style(Color("fff1cf"), accent, 18, 3)
	normal.shadow_size = 4
	var hover := _panel_style(Color("fff9e8"), accent.lightened(0.08), 18, 4)
	hover.shadow_size = 8
	var pressed := _panel_style(Color("f0d39b"), accent.darkened(0.08), 18, 4)
	pressed.shadow_size = 2
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


func show_aftermath() -> void:
	experience_label.text = "炉火已熄"
	experience_bar.hide()
	upgrade_overlay.hide()
	pause_overlay.hide()
	timer_label.get_parent().get_child(0).text = "战斗已结束"
	timer_label.text = "炉火熄灭"
	timer_label.add_theme_font_size_override("font_size", 24)
	wave_label.text = "可自由检视残骸"
	help_label.text = "WASD 移动    鼠标转镜头    F 检视残骸    Esc 暂停"
	show_notice("烤炉轰然散落。走近残骸，看看留下了什么。")


