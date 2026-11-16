class_name CookingUI
extends CanvasLayer
## 料理合成界面：只读背包数据、只抛出合成请求，不认识玩家与场景。
## 界面风格与第一章保持一致（深底 + 描金 + 楷体），结构尽量扁平便于改动。

signal closed
signal craft_requested(id_a: String, id_b: String)

const PANEL_COLOR := Color(0.10, 0.07, 0.05, 0.94)
const CREAM := Color("fff2cf")
const GOLD := Color("c9a568")
const MUTED := Color("b8a98c")
const INK := Color("372b22")
const OK_COLOR := Color("9ed36a")
const FAIL_COLOR := Color("e08a7a")

var inventory: FoodInventory
var cooking: CookingSystem

var _ingredient_buttons: Dictionary = {}
var _slot_buttons: Array[Button] = []
var _selection: Array[String] = ["", ""]
var _craft_button: Button
var _result_label: Label
var _dish_label: Label
## 非空时表示「结果提示」被锁定，refresh 不再覆盖它
var _result_override := ""


func setup(inv: FoodInventory, system: CookingSystem) -> void:
	inventory = inv
	cooking = system
	_build_interface()
	if inventory != null and not inventory.changed.is_connected(refresh):
		inventory.changed.connect(refresh)
	hide()


func open() -> void:
	_result_override = ""
	refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


func refresh() -> void:
	_clear_empty_slots()
	_refresh_ingredients()
	_refresh_slots()
	_refresh_dishes()
	_refresh_result_hint()


## 合成结束后由控制器回填结果；该结果会保留到玩家再次改动槽位为止
func show_result(message: String, ok: bool) -> void:
	_result_override = message
	_result_label.text = message
	_result_label.add_theme_color_override("font_color", OK_COLOR if ok else FAIL_COLOR)


## Esc 与关闭按钮统一走这里；按键判定集中在场景主控，避免两处各响应一次
func request_close() -> void:
	close()


# ------------------------------------------------------------------ 构建
func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_apply_theme(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(840.0, 580.0)
	panel.size = Vector2(840.0, 580.0)
	panel.position = Vector2(-420.0, -290.0)
	root.add_child(panel)
	_style_panel(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	outer.add_child(_label("第二章  /  火山洞窟", 15, MUTED))
	outer.add_child(_label("料理台 · 熔岩灶", 26, CREAM))
	outer.add_child(_separator())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	body.add_child(_build_ingredient_column())
	body.add_child(_separator(true))
	body.add_child(_build_craft_column())

	outer.add_child(_separator())
	outer.add_child(_build_footer())


func _build_ingredient_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(300.0, 0.0)
	column.add_theme_constant_override("separation", 8)
	column.add_child(_label("背包食材", 22, GOLD))
	var hint := _label("点击食材放入右侧槽位", 16, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 290.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var buttons := VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(buttons)
	for id in FoodData.ingredient_ids():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 54.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var ingredient_id: String = id
		button.pressed.connect(func() -> void: _select_ingredient(ingredient_id))
		_style_button(button)
		buttons.add_child(button)
		_ingredient_buttons[ingredient_id] = button
	return column


func _build_craft_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	column.add_child(_label("投入食材", 22, GOLD))

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	column.add_child(slots)
	for index in 2:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(0.0, 62.0)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var slot_index: int = index
		slot.pressed.connect(func() -> void: _clear_slot(slot_index))
		_style_button(slot)
		slots.add_child(slot)
		_slot_buttons.append(slot)

	_craft_button = Button.new()
	_craft_button.text = "开始烹饪"
	_craft_button.custom_minimum_size = Vector2(0.0, 52.0)
	_craft_button.pressed.connect(_on_craft_pressed)
	_style_button(_craft_button, GOLD)
	column.add_child(_craft_button)

	_result_label = _label("从左侧选择两种食材。", 18, CREAM)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size = Vector2(0.0, 76.0)
	column.add_child(_result_label)

	column.add_child(_separator())
	column.add_child(_label("配方提示", 20, GOLD))
	for entry in FoodData.recipe_entries():
		var item: Dictionary = entry
		var line := _label("%s = %s（%s）" % [
				String(item["formula"]), String(item["dish"]), String(item["buff"])],
				17, MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(line)
	return column


func _build_footer() -> Control:
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	_dish_label = _label("料理手记：暂无", 18, CREAM)
	_dish_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_dish_label)
	var close_button := Button.new()
	close_button.text = "关闭（Esc）"
	close_button.custom_minimum_size = Vector2(0.0, 46.0)
	close_button.pressed.connect(close)
	_style_button(close_button)
	footer.add_child(close_button)
	return footer


# ------------------------------------------------------------------ 刷新
func _refresh_ingredients() -> void:
	for id in FoodData.ingredient_ids():
		var button: Button = _ingredient_buttons.get(id, null)
		if button == null:
			continue
		var count := 0 if inventory == null else inventory.ingredient_count(id)
		button.visible = count > 0
		button.text = "%s  x%d" % [FoodData.ingredient_name(id), count]
		button.disabled = count <= 0


func _refresh_slots() -> void:
	for index in 2:
		if index >= _slot_buttons.size():
			continue
		var id: String = _selection[index]
		var button: Button = _slot_buttons[index]
		if id.is_empty():
			button.text = "槽位 %d：空" % (index + 1)
		else:
			button.text = "槽位 %d：%s" % [index + 1, FoodData.ingredient_name(id)]
	_craft_button.disabled = _selection[0].is_empty() or _selection[1].is_empty()


func _refresh_dishes() -> void:
	if _dish_label == null:
		return
	var names: PackedStringArray = []
	for id in RunState.cooking_journal:
		var recipe := FoodData.recipe_by_id(id)
		names.append(FoodData.dish_name(String(recipe.get("dish", id))))
	_dish_label.text = "料理手记：%s" % ("、".join(names) if not names.is_empty() else "暂无")


func _refresh_result_hint() -> void:
	if _result_label == null or cooking == null:
		return
	# 最近一次合成结果优先展示，直到玩家改动槽位
	if not _result_override.is_empty():
		return
	if _selection[0].is_empty() or _selection[1].is_empty():
		_result_label.text = "从左侧选择两种食材。"
		_result_label.add_theme_color_override("font_color", CREAM)
		return
	var preview := cooking.preview(_selection[0], _selection[1])
	var ok := bool(preview.get("ok", false))
	_result_label.text = String(preview.get("message", ""))
	_result_label.add_theme_color_override("font_color", OK_COLOR if ok else FAIL_COLOR)


func _select_ingredient(id: String) -> void:
	if inventory == null or inventory.ingredient_count(id) <= 0:
		return
	_result_override = ""
	if _selection[0].is_empty():
		_selection[0] = id
	elif _selection[1].is_empty():
		_selection[1] = id
	else:
		_selection[0] = id
		_selection[1] = ""
	refresh()


func _clear_slot(index: int) -> void:
	if index < 0 or index >= _selection.size():
		return
	_selection[index] = ""
	_result_override = ""
	refresh()


## 槽位里已被合成消耗掉的食材自动清空，避免显示「背包里没有」的残留选项
func _clear_empty_slots() -> void:
	for index in _selection.size():
		var id: String = _selection[index]
		if id.is_empty():
			continue
		if inventory == null or inventory.ingredient_count(id) <= 0:
			_selection[index] = ""


func _on_craft_pressed() -> void:
	craft_requested.emit(_selection[0], _selection[1])


# ------------------------------------------------------------------ 样式
func _apply_theme(root: Control) -> void:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimSun"])
	theme.default_font = font
	theme.default_font_size = 19
	root.theme = theme


func _style_panel(panel: PanelContainer) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_COLOR
	box.border_color = GOLD
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)


func _style_button(button: Button, accent := GOLD) -> void:
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.55))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.11, 0.08, 0.9)
	normal.border_color = Color(accent, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent, 0.85)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.12, 0.09, 0.07, 0.75)
	disabled.border_color = Color(MUTED, 0.3)
	button.add_theme_stylebox_override("disabled", disabled)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _separator(vertical := false) -> Control:
	var separator: Control = VSeparator.new() if vertical else HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator
