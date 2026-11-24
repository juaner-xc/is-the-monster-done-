extends PanelContainer

var _level: Label
var _count: Label
var _bar: ProgressBar
var _snow_row := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = 214
	var frame := _strip(Color("211929e9"))
	frame.border_width_left = 2
	frame.border_width_bottom = 1
	frame.content_margin_left = 10
	frame.content_margin_right = 10
	frame.content_margin_top = 5
	frame.content_margin_bottom = 7
	add_theme_stylebox_override("panel", frame)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	add_child(stack)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(row)
	_level = Label.new()
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level.add_theme_font_size_override("font_size", 15)
	_level.add_theme_color_override("font_color", Color("fff1df"))
	row.add_child(_level)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 13)
	row.add_child(_count)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 6
	_bar.add_theme_stylebox_override("background", _strip(Color("422f4e")))
	_bar.add_theme_stylebox_override("fill", _strip(Color("c4a3f2")))
	stack.add_child(_bar)
	update_magic(0, 35, 1)


func update_magic(current: int, needed: int, level: int) -> void:
	_level.text = ("✧  魔力 %d 级" if _snow_row else "✧  魔力  Lv.%d") % level
	_count.text = "%d / %d" % [mini(current, needed), needed]
	_bar.max_value = needed
	_bar.value = current


func use_snow_row() -> void:
	_snow_row = true
	update_magic(0, 35, 1)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_count.add_theme_color_override("font_color", Color("e7cdf9"))
	_bar.add_theme_stylebox_override("background", _strip(Color("372d47")))


func set_trim(color: Color) -> void:
	var frame := get_theme_stylebox("panel") as StyleBoxFlat
	frame.border_color = color
	_count.add_theme_color_override("font_color", color.lightened(0.22))


func _strip(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style

