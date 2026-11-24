extends Control
## Short location titles shared by the chapter scenes.

enum ThemeKind { SNOW, VOLCANO, BANQUET }

const TITLE_FONT := preload("res://assets/ui/study/ye_font_liu_ye_ti.ttf")
const PALETTES := [Color("b9d7dd"), Color("e7a165"), Color("dcb281")]

var _kind := ThemeKind.VOLCANO
var _title: Label
var _animation: Tween
var _age := 0.0


func announce(host: Node, kind: ThemeKind, title: String) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 8
	host.add_child(canvas)
	canvas.add_child(self)
	show_location(kind, title)
	_animation.tween_callback(canvas.queue_free)


func _ready() -> void:
	name = "LocationBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	set_anchor(SIDE_TOP, 0.09)
	set_anchor(SIDE_BOTTOM, 0.09)
	offset_top = -21
	offset_bottom = 85
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.offset_top = 29
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_color_override("font_color", Color("fff4dd"))
	_title.add_theme_color_override("font_outline_color", Color("160f10d9"))
	_title.add_theme_constant_override("outline_size", 6)
	hide()


func show_location(kind: ThemeKind, title: String, chapter := true) -> void:
	if _animation != null:
		_animation.kill()
	_kind = kind
	_age = 0.0
	_title.text = title
	_title.add_theme_font_size_override("font_size", 43 if chapter else 32)
	modulate.a = 0.0
	show()
	_animation = create_tween()
	_animation.tween_property(self, "modulate:a", 1.0, 0.36)
	_animation.tween_interval(1.48 if chapter else 1.1)
	_animation.tween_property(self, "modulate:a", 0.0, 0.46)
	_animation.tween_callback(hide)


func dismiss() -> void:
	if _animation != null:
		_animation.kill()
	hide()


func _process(delta: float) -> void:
	if visible:
		_age += delta
		queue_redraw()


func _draw() -> void:
	var color: Color = PALETTES[_kind]
	var center := Vector2(size.x * 0.5, 25)
	for side in [-1.0, 1.0]:
		for i in 15:
			var from := center + Vector2(side * (22 + i * 10), 2)
			draw_line(from, from + Vector2(side * 10, 0), Color(color, 0.83 * (1.0 - i / 15.0)), 1.2, true)
	var mark := PackedVector2Array()
	match _kind:
		ThemeKind.SNOW:
			for i in 6:
				var arm := Vector2.UP.rotated(i * TAU / 6.0) * 12
				draw_line(center, center + arm, color, 1.6, true)
				for side in [-1.0, 1.0]:
					draw_line(center + arm * .62, center + arm * .62 + arm.rotated(side * 1.05) * .38, color, 1.2, true)
		ThemeKind.VOLCANO:
			mark = PackedVector2Array([Vector2(-14, 10), Vector2(-6, -4), Vector2(-2, -4),
				Vector2(2, -1), Vector2(6, -4), Vector2(14, 10), Vector2(-14, 10)])
			draw_line(center + Vector2(-2, -9), center + Vector2(2, -15), color, 1.4, true)
		ThemeKind.BANQUET:
			mark = PackedVector2Array([Vector2(-13, -7), Vector2(13, -7), Vector2(16, 8),
				Vector2(-16, 8), Vector2(-13, -7)])
			draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), color, 1.2, true)
	if not mark.is_empty():
		for i in mark.size():
			mark[i] += center
		draw_polyline(mark, color, 1.5, true)
	for i in 7:
		var rise := fposmod(_age * 24.0 + i * 8.7, 32.0)
		var drift := sin(_age * 1.6 + i) * 7.0
		var at := center + Vector2((i - 3) * 36 + drift, 23.0 - rise)
		draw_circle(at, 1.0 + (i % 2) * 0.65, Color(color, 0.62 * sin(PI * rise / 32.0)))

