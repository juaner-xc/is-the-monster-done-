extends CenterContainer

const Book = preload("res://scripts/book_ui.gd")
const Illustration = preload("res://scripts/recipe_illustration.gd")
const ACCENTS := [Color("d1ad72"), Color("91c4bc"), Color("cbb0de")]
const TITLES := ["食物", "装备", "料理"]
const EMPTY_TEXT := ["还没有食材", "还没有装备", "还没有料理"]
const COLUMNS := 3
const VISIBLE_SLOTS := 9
const SLOT_SIZE := Vector2(96, 84)

var _grids: Array[GridContainer] = []
var _counts: Array[Label] = []
var _empty_labels: Array[Label] = []
var _coins: Label
var _detail_title: Label
var _detail_text: Label
var _action: Button
var _prep: Button
var _station: Button
var _quest: Button
var _group := ButtonGroup.new()
var _entries := {}
var _slots := {}
var _selected := ""


func setup(on_close: Callable, on_prep: Callable, on_station: Callable, on_quest: Callable) -> void:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1080, 604)
	frame.add_theme_stylebox_override("panel", Book.style(Color("171d1b"), Book.GOLD, 0))
	add_child(frame)

	var leather := Control.new()
	leather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(leather)
	Book.install(leather)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 41)
	margins.add_theme_constant_override("margin_right", 41)
	margins.add_theme_constant_override("margin_top", 37)
	margins.add_theme_constant_override("margin_bottom", 34)
	leather.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margins.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	var title := Book.label("旅人背包", 36, Color("f1ddad"))
	title.add_theme_font_override("font", preload("res://assets/ui/study/ye_font_liu_ye_ti.ttf"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_coins = Book.label("", 19, Book.GOLD)
	header.add_child(_coins)
	header.add_child(_button("关闭  [Tab]", on_close, 112))
	content.add_child(Book.rule())

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	for index in TITLES.size():
		_build_column(columns, index)

	var detail := PanelContainer.new()
	detail.custom_minimum_size.y = 88
	detail.add_theme_stylebox_override("panel", Book.style(Color("262723"), Color("685436"), 9))
	content.add_child(detail)
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", 14)
	detail.add_child(details)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(words)
	_detail_title = Book.label("", 21)
	words.add_child(_detail_title)
	_detail_text = Book.paragraph("", 16, Color("d5c6a7"))
	words.add_child(_detail_text)
	_action = _button("", _activate, 128, true)
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_child(_action)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)
	var hint := Book.label("点击格子查看物品", 16, Book.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	_quest = _button("任务物品", on_quest, 112)
	footer.add_child(_quest)
	_prep = _button("备餐  [R]", on_prep, 112)
	footer.add_child(_prep)
	_station = _button("灶台试做", on_station, 112)
	footer.add_child(_station)


func _build_column(columns: HBoxContainer, index: int) -> void:
	var accent: Color = ACCENTS[index]
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Book.style(Color("121917"), Color(accent, 0.5), 6))
	columns.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Book.label("  " + TITLES[index], 24, accent)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var count := Book.label("", 15, Book.MUTED)
	heading.add_child(count)
	_counts.append(count)
	column.add_child(Book.rule())

	var slots_area := Control.new()
	slots_area.custom_minimum_size.y = SLOT_SIZE.y * 3.0 + 12.0
	slots_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(slots_area)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	slots_area.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(grid)
	_grids.append(grid)
	var empty := Book.label(EMPTY_TEXT[index], 18, Book.MUTED)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots_area.add_child(empty)
	empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_labels.append(empty)


func update_items(groups: Array, coins: int, can_prep: bool, can_try: bool, has_quests: bool, focus_category: int = -1) -> void:
	_coins.text = "金币  %d" % coins
	_prep.visible = can_prep
	_station.visible = can_try
	_quest.visible = has_quests
	_entries.clear()
	_slots.clear()
	for index in TITLES.size():
		var entries: Array = groups[index]
		var grid := _grids[index]
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
		_counts[index].text = "%d 种  " % entries.size()
		_empty_labels[index].visible = entries.is_empty()
		var total := maxi(VISIBLE_SLOTS, ceili(float(entries.size()) / COLUMNS) * COLUMNS)
		for slot_index in total:
			if slot_index >= entries.size():
				grid.add_child(_empty_slot(index))
				continue
			var entry: Dictionary = entries[slot_index]
			var key: String = entry.key
			_entries[key] = entry
			var slot := _item_slot(entry, ACCENTS[index])
			_slots[key] = slot
			grid.add_child(slot)
	if focus_category >= 0:
		var entries: Array = groups[focus_category]
		_selected = entries[0].key if not entries.is_empty() else ""
	elif _entries.has("tutorial_soup") and _entries["tutorial_soup"].action.is_valid():
		_selected = "tutorial_soup"
	elif not _entries.has(_selected):
		_selected = ""
	_select(_selected)
	if _selected == "tutorial_soup" and _action.visible and not _action.disabled:
		_action.grab_focus()
	elif focus_category >= 0 and _slots.has(_selected):
		_slots[_selected].grab_focus()


func _empty_slot(index: int) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _slot_style(Color("141a18"), Color(ACCENTS[index], 0.19)))
	return slot


func _item_slot(entry: Dictionary, accent: Color) -> Button:
	var slot := Button.new()
	slot.name = entry.key
	slot.custom_minimum_size = SLOT_SIZE
	slot.toggle_mode = true
	slot.button_group = _group
	slot.tooltip_text = entry.title
	slot.add_theme_stylebox_override("normal", _slot_style(Color("222a25"), Color(accent, 0.52)))
	slot.add_theme_stylebox_override("hover", _slot_style(Color("343c30"), accent))
	slot.add_theme_stylebox_override("pressed", _slot_style(Color("3d3a2e"), accent, 2))
	slot.add_theme_stylebox_override("hover_pressed", _slot_style(Color("494235"), accent, 2))
	slot.add_theme_stylebox_override("focus", _slot_style(Color.TRANSPARENT, Book.CREAM))
	slot.pressed.connect(_select.bind(entry.key))

	var art := Illustration.new()
	art.set_kind(entry.icon)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 8
	art.offset_right = -8
	art.offset_top = 3
	art.offset_bottom = -18

	var title := Book.label(entry.title, 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_left = 4
	title.offset_right = -4
	title.offset_top = -23
	title.offset_bottom = -3
	var badge: String = entry.get("badge", "")
	if not badge.is_empty():
		var badge_label := Book.label(badge, 13, accent.lightened(0.32))
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge_label.add_theme_stylebox_override("normal", _slot_style(Color("161918"), Color(accent, 0.35)))
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge_label)
		badge_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge_label.offset_left = -badge_label.get_combined_minimum_size().x - 5
		badge_label.offset_right = -4
		badge_label.offset_top = 4
	return slot


func _select(key: String) -> void:
	_selected = key
	var entry: Dictionary = _entries.get(key, {})
	if _slots.has(key):
		_slots[key].set_pressed_no_signal(true)
	_detail_title.text = entry.get("title", "物品详情")
	_detail_text.text = entry.get("description", "食物栏收纳食材，装备栏展示武器与穿戴，料理栏收纳已做好的料理。")
	_action.text = entry.get("action_label", "")
	_action.visible = not _action.text.is_empty()
	_action.disabled = not entry.get("action", Callable()).is_valid()


func _activate() -> void:
	var action: Callable = _entries.get(_selected, {}).get("action", Callable())
	if action.is_valid():
		action.call()


func _button(caption: String, callback: Callable, width: int, primary: bool = false) -> Button:
	var node := Book.button(caption, primary)
	node.custom_minimum_size = Vector2(width, 34)
	node.add_theme_font_size_override("font_size", 16)
	node.pressed.connect(callback)
	return node


func _slot_style(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box := Book.style(background, border, 2)
	box.set_border_width_all(width)
	box.shadow_size = 0
	return box
