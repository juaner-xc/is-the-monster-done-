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
var magic_meter: Control
var _snow_status: VBoxContainer
var _notice_tween: Tween
var _notice_heading: Label
var upgrade_only := false
var magic_level := 1
var build_label: Label
var timer_label: Label
var wave_label: Label
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
var _debug_label: Label
var _debug_refresh_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	if not upgrade_only:
		_build_debug_label()


func _build_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.text = ""
	_debug_label.position = Vector2(12, 8)
	_debug_label.size = Vector2(1000, 60)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.add_theme_color_override("font_color", Color("9fe8ff"))
	_debug_label.add_theme_color_override("font_outline_color", Color("101820"))
	_debug_label.add_theme_constant_override("outline_size", 4)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.visible = false
	add_child(_debug_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ek := event as InputEventKey
		if ek.pressed and not ek.echo and ek.keycode == KEY_F3 and _debug_label != null:
			_debug_label.visible = not _debug_label.visible


func _process(delta: float) -> void:
	if _debug_label == null or not _debug_label.visible:
		return
	_debug_refresh_left -= delta
	if _debug_refresh_left > 0.0:
		return
	_debug_refresh_left = 0.25
	var p := get_tree().get_first_node_in_group("Player") as Node3D
	if p != null:
		_debug_label.text = "FPS %d | Draws %d | Triangles %d | Physics %.2f ms\nXYZ %.2f, %.2f, %.2f" % [
			Engine.get_frames_per_second(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			p.global_position.x, p.global_position.y, p.global_position.z]


func update_status(player: Node, recipe_system: Node, time_left: float, wave: int, enemy_count: int) -> void:
	health_bar.max_value = player.max_health
	health_bar.value = maxf(player.health, 0.0)
	health_label.text = "%d / %d" % [roundi(player.health), roundi(player.max_health)]
	update_condensation(player.experience, player.experience_needed, player.level)
	build_label.text = player.kitchen_status() if player.has_method("kitchen_status") else ""
	var total_seconds := maxi(0, ceili(time_left))
	timer_label.text = "%02d:%02d" % [floori(float(total_seconds) / 60.0), total_seconds % 60]
	wave_label.text = "第 %d 波  ·  场上 %d" % [wave, enemy_count]


func update_condensation(current: int, needed: int, level: int = -1) -> void:
	if level > 0:
		magic_level = level
	magic_meter.update_magic(current, needed, magic_level)


func show_upgrade(options: Array[Dictionary], discovery := false, reward_level := 0) -> void:
	upgrade_title.text = "发现魔力凝材" if discovery else "魔力凝材"
	upgrade_subtitle.text = "魔力 Lv.%d  ·  选择 1 种食材" % reward_level if reward_level > 0 else "选择 1 种食材"
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


func show_notice(text: String, heading := "") -> void:
	_notice_heading.text = heading
	_notice_heading.visible = not heading.is_empty()
	notice_label.text = text
	var half_width := 164.0 if not heading.is_empty() else 260.0
	notice_panel.offset_left = -half_width
	notice_panel.offset_right = half_width
	notice_panel.offset_top = 154.0 if not heading.is_empty() else 110.0
	notice_panel.offset_bottom = notice_panel.offset_top + 36.0
	if _notice_tween != null:
		_notice_tween.kill()
	notice_panel.modulate.a = 0.0
	_notice_tween = create_tween()
	_notice_tween.tween_property(notice_panel, "modulate:a", 1.0, 0.20)
	_notice_tween.tween_interval(2.2 if not heading.is_empty() else 1.5)
	_notice_tween.tween_property(notice_panel, "modulate:a", 0.0, 0.55)


func set_paused_hint(paused: bool) -> void:
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

	if upgrade_only:
		_build_upgrade_overlay(root)
		return
	_build_snow_status(root)
	_build_recipe_card(root)
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


func _build_snow_status(root: Control) -> void:
	var frame := PanelContainer.new()
	frame.name = "SnowStatus"
	frame.position = Vector2(26, 23)
	frame.custom_minimum_size.x = 246
	frame.add_theme_stylebox_override("panel", _snow_frame(Color("15252eea"), Color("8caebc")))
	root.add_child(frame)
	_snow_status = VBoxContainer.new()
	_snow_status.add_theme_constant_override("separation", 8)
	frame.add_child(_snow_status)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	_snow_status.add_child(heading)
	var snowflake := Book.label("❄", 21, Color("b4dcea"))
	heading.add_child(snowflake)
	heading.add_child(Book.label(RunState.player_name if RunState.has_profile() else "奶蛙", 18, Color("f4e8cc")))
	var border := ColorRect.new()
	border.color = Color("91b1bf66")
	border.custom_minimum_size.y = 1
	_snow_status.add_child(border)

	var life := VBoxContainer.new()
	life.add_theme_constant_override("separation", 4)
	_snow_status.add_child(life)
	var row := HBoxContainer.new()
	life.add_child(row)
	var caption := Book.label("♥  生命", 15, Color("ffd9ce"))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	health_label = Book.label("", 13, Color("eec9c3"))
	row.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size.y = 6
	_style_progress_bar(health_bar, Color("49313f"), Color("d88082"))
	life.add_child(health_bar)

	magic_meter = preload("res://scripts/magic_meter.gd").new()
	magic_meter.name = "MagicMeter"
	_snow_status.add_child(magic_meter)
	magic_meter.use_snow_row()

	var timer := VBoxContainer.new()
	timer.name = "EncounterStatus"
	_snow_status.add_child(timer)
	timer.add_child(Book.label("战斗计时", 13, Color("c1dce6")))
	timer_label = Book.label("", 13, Color("f4e8cc"))
	timer.add_child(timer_label)
	wave_label = Book.label("", 12, Color("a1b8c5"))
	timer.add_child(wave_label)
	timer.visible = not RunState.chapter_mode


func attach_snow_heat(heat: Node) -> void:
	heat.attach_snow_meter(_snow_status)
	_snow_status.move_child(_snow_status.get_node("HeatMeter"), 3)


func _snow_frame(background: Color, accent: Color) -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = background
	frame.border_color = accent
	frame.border_width_left = 2
	frame.border_width_top = 1
	frame.border_width_bottom = 1
	frame.set_corner_radius_all(5)
	frame.content_margin_left = 14
	frame.content_margin_right = 14
	frame.content_margin_top = 9
	frame.content_margin_bottom = 10
	frame.shadow_color = Color("0a15246b")
	frame.shadow_size = 6
	frame.shadow_offset = Vector2(0, 3)
	return frame


func _build_recipe_card(root: Control) -> void:
	build_label=Label.new();root.add_child(build_label);build_label.hide()


func _build_notice(root: Control) -> void:
	notice_panel = PanelContainer.new()
	notice_panel.anchor_left = 0.5
	notice_panel.anchor_right = 0.5
	notice_panel.offset_left = -260.0
	notice_panel.offset_right = 260.0
	notice_panel.offset_top = 110.0
	notice_panel.offset_bottom = 146.0
	notice_panel.add_theme_stylebox_override("panel", _snow_frame(Color("13232eea"), Color("c1a97a")))
	root.add_child(notice_panel)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	notice_panel.add_child(lines)
	_notice_heading = Book.label("", 22, Color("f7dba5"))
	_notice_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_heading.hide()
	lines.add_child(_notice_heading)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 15)
	notice_label.add_theme_color_override("font_color", CREAM)
	lines.add_child(notice_label)
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
	pause_overlay.hide()
	timer_label.get_parent().show()
	timer_label.get_parent().get_child(0).text = "战斗已结束"
	timer_label.text = "炉火熄灭"
	timer_label.add_theme_font_size_override("font_size", 24)
	wave_label.text = "可自由检视残骸"
	show_notice("烤炉轰然散落。走近残骸，看看留下了什么。")


