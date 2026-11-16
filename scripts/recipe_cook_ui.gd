extends CanvasLayer
## 「食谱合成料理」页：拿到魔法食谱后随时可用的随身合成台。
## 复用食堂「试做」页的外观与机制（选两种食材→合成→写入烹饪日志），
## 但不依赖食堂场景、锅具、火候、灶台位置。
## 调用：new → add_child(host) → open()；关闭发 closed 信号。

signal closed

const Book := preload("res://scripts/book_ui.gd")
const Recipes := preload("res://scripts/recipe_system.gd")

var _shell: ColorRect
var _body: VBoxContainer
var _scroll: ScrollContainer
var _first := ""
var _paused_before := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _opened := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	Book.install(root)
	_shell = ColorRect.new()
	_shell.color = Color("16201ef5")
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_shell)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shell.add_child(center)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(600, 440)
	center.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)
	_refresh()


func open() -> void:
	if _opened:
		return
	_opened = true
	_paused_before = get_tree().paused
	_mouse_before = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	if not _opened:
		return
	_opened = false
	_first = ""
	get_tree().paused = _paused_before
	Input.mouse_mode = _mouse_before
	queue_free()
	closed.emit()


func is_open() -> bool:
	return _opened


func _unhandled_input(event: InputEvent) -> void:
	if not _opened:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_body.add_child(Book.label("食谱合成料理", 32, Book.GOLD))
	_body.add_child(Book.paragraph("随意搭配现有食材，像在食堂灶台试做一样。", 18, Book.MUTED))
	if _first == "":
		_body.add_child(Book.label("选两种食材", 19))
	else:
		_body.add_child(Book.label("已选　" + FoodData.ingredient_name(_first) + "　（再点一个即开始烹饪）", 19))
	var ids := RunState.cooking_inventory.ingredient_ids()
	if ids.is_empty():
		_body.add_child(Book.paragraph("背包里还没有食材，先去雪原捡一些吧。", 19, Book.MUTED))
	for id in ids:
		if id != _first:
			_cook_button(FoodData.ingredient_name(id), _select.bind(id))
	if _first != "":
		_cook_button("重选（清空已选）", func():
			_first = ""
			_refresh())
	_cook_button("返回游戏", close)


func _cook_button(title: String, action: Callable) -> void:
	var b := Book.button(title, false)
	b.pressed.connect(action)
	_body.add_child(b)


func _select(id: String) -> void:
	if _first == "":
		_first = id
		_refresh()
		return
	var inv = RunState.cooking_inventory
	var pair := [_first, id]
	if not inv.has_ingredient(pair[0]) or not inv.has_ingredient(pair[1]):
		_first = ""
		_refresh()
		return
	var found := ""
	for data in _recipes():
		if pair.has(data[2]) and pair.has(data[3]):
			found = data[0]
			break
	inv.take_pair(pair[0], pair[1])
	if found != "":
		inv.add_dish(found, 1)
		RunState.record_cooked_recipe(found)
		_hint("食谱合成料理 · " + FoodData.dish_name(found) + " ×1 已放入背包")
	else:
		inv.add_ingredient(FoodData.BURNT)
		_hint("食谱合成料理 · 糊掉的东西")
	RunState.save_progress()
	_first = ""
	_refresh()


func _recipes() -> Array:
	var result := []
	for id in Recipes.RECIPE_DETAILS:
		var p: Array = Recipes.RECIPE_DETAILS[id].ingredients
		if p.size() == 2:
			result.append([id, id, p[0], p[1]])
	for data in FoodData.RECIPES:
		result.append([data.id, data.dish, data.inputs[0], data.inputs[1]])
	return result


func _hint(text: String) -> void:
	for node in get_tree().root.get_children():
		if node.has_method("_show_recipe_arrival") and node.get("hud") != null:
			var hud = node.get("hud")
			if hud != null and hud.has_method("show_notice"):
				hud.show_notice(text)
			return
