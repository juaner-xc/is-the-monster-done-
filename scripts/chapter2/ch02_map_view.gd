class_name Ch02MapView
extends Control

signal close_requested
## 第二章「火山工坊路线图」。
## 画风照第一章的雪原路线图（半透明铁板 + 淡网格 + 手绘符号），配色改成火山砖红/炉火橙。
## 两种形态：
##   mini  —— 右上角常驻小图，半透明、不挡视线（和第一章 map_mini 一样）
##   large —— 按 M 展开的居中大图，暂停游戏，M/Esc 收起
## 地图本身是摊在餐车车盖上的那张旧烤炉门，随剧情推进逐块点开：
## 没去过的地方只画一块毛边空白，去过的地方才有墨线。

const ORANGE := Color("f28b2f")
const CREAM := Color("fff2cf")
const INK := Color("f0dcc0")
const MUTED := Color("8d7a65")
const C_GRID := Color(0.85, 0.62, 0.38, 0.10)
const C_PATH := Color(0.92, 0.62, 0.30, 0.62)

var player: Node3D
var accepts_input := true
## 常驻小图：半透明、缩小字号、不带图例和提示
var mini := false
var _markers: Array = []
var _bounds := Rect2()
var _font: Font
var _t := 0.0
var _hint: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not mini:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_build_hint()
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimSun"])
	visible = false


func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = "M / Esc  收起地图"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", MUTED)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -260.0
	_hint.offset_top = -58.0
	_hint.offset_right = -34.0
	_hint.offset_bottom = -26.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)


## markers: [{"title": String, "pos": Vector3, "kind": String, "known": bool}]
func set_markers(markers: Array) -> void:
	_markers = markers
	_compute_bounds()


func _compute_bounds() -> void:
	if _markers.is_empty():
		_bounds = Rect2(-20.0, -20.0, 40.0, 40.0)
		return
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for m in _markers:
		var p: Vector3 = m.get("pos", Vector3.ZERO)
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	if player != null and is_instance_valid(player):
		var pp := player.global_position
		min_x = minf(min_x, pp.x)
		max_x = maxf(max_x, pp.x)
		min_z = minf(min_z, pp.z)
		max_z = maxf(max_z, pp.z)
	min_x -= 14.0
	max_x += 14.0
	min_z -= 14.0
	max_z += 14.0
	_bounds = Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


func open() -> void:
	visible = true
	_t = 0.0
	if accepts_input:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func close() -> void:
	visible = false
	if accepts_input:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not accepts_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if k == KEY_M or k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_requested.emit()


# ---------------------------------------------------------------- 绘制
## 手绘地图不按比例：两个方向各自铺满纸面，不然火山这条南北走廊会被压成一条竖线
func _scale_for(rect: Rect2) -> Vector2:
	return Vector2(rect.size.x / maxf(_bounds.size.x, 1.0),
		rect.size.y / maxf(_bounds.size.y, 1.0)) * 0.88


func _project(p: Vector2, rect: Rect2, s: Vector2) -> Vector2:
	var c := rect.get_center()
	var wx := (p.x - _bounds.get_center().x) * s.x
	var wz := (p.y - _bounds.get_center().y) * s.y
	return c + Vector2(wx, wz)


func _draw() -> void:
	if _font == null or _markers.is_empty():
		return
	# 小图按宽度缩字号与间距；大图 k = 1.0
	var k := clampf(size.x / 760.0, 0.40, 1.0)
	var pad := Vector2(28.0, 22.0) if mini else Vector2(64.0, 56.0) * k
	var board := Rect2(pad, size - pad * 2.0)
	if board.size.x < 150.0 or board.size.y < 120.0:
		return
	# 标题占掉的头部不进绘图区，否则最北的两个地标会压在标题上
	var head := 44.0 if mini else 92.0
	var foot := 6.0 if mini else 34.0
	var area := Rect2(board.position + Vector2(0.0, head),
		board.size - Vector2(0.0, head + foot))
	var s := _scale_for(area)

	# 纸面：旧烤炉门压出来的暗铁色，边上一圈炉火橙。小图半透明，和第一章右上角小图一致
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.065, 0.045, 0.46 if mini else 0.94)
	sb.set_border_width_all(2 if not mini else 1)
	sb.border_color = Color(0.95, 0.55, 0.20, 0.55 if mini else 0.75)
	sb.set_corner_radius_all(14 if not mini else 10)
	draw_style_box(sb, board)

	# 网格（铁板上的划线）
	var step := 24.0 # 世界单位
	var x0 := floorf(_bounds.position.x / step) * step
	var gx := x0
	while gx <= _bounds.end.x:
		var a := _project(Vector2(gx, _bounds.position.y), area, s)
		var b := _project(Vector2(gx, _bounds.end.y), area, s)
		draw_line(a, b, C_GRID, 1.0)
		gx += step
	var gz := floorf(_bounds.position.y / step) * step
	while gz <= _bounds.end.y:
		var a := _project(Vector2(_bounds.position.x, gz), area, s)
		var b := _project(Vector2(_bounds.end.x, gz), area, s)
		draw_line(a, b, C_GRID, 1.0)
		gz += step

	# 标题（摊在车盖上的说法）
	draw_string(_font, board.position + Vector2(18.0, 30.0) * k, "火山工坊 · 路线图",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(30.0 * k), INK)
	if not mini:
		draw_string(_font, board.position + Vector2(26.0, 68.0), "旧烤炉门的背面，用粉笔和机油画的",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
		draw_string(_font, board.position + Vector2(board.size.x - 90.0, 44.0), "北 ↑",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ORANGE)

	# 主路：生活区 → 运输站 → 控制区 → 千席宴炉
	var route: Array = []
	for m in _markers:
		if bool(m.get("known", false)):
			route.append(_project(Vector2((m.get("pos", Vector3.ZERO) as Vector3).x,
				(m.get("pos", Vector3.ZERO) as Vector3).z), area, s))
	for i in range(route.size() - 1):
		draw_dashed_line(route[i], route[i + 1], C_PATH, 2.4 * k, 7.0 * k)

	# 地标
	var idx := 0
	for m in _markers:
		_draw_marker(m, area, s, k, idx)
		idx += 1

	# 玩家
	if player != null and is_instance_valid(player):
		var pp := player.global_position
		var dot := _project(Vector2(pp.x, pp.z), area, s)
		var pulse := (7.0 + sin(_t * 3.0) * 2.0) * k
		draw_circle(dot, pulse + 5.0 * k, Color(0.98, 0.62, 0.24, 0.18))
		draw_circle(dot, 6.0 * k, Color("ffd79a"))
		draw_arc(dot, 6.0 * k, 0.0, TAU, 20, Color(0.35, 0.16, 0.06, 0.9), 1.5)
		if not mini:
			draw_string(_font, dot + Vector2(10.0, -8.0), "你在这里",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd79a"))

	# 图例
	if not mini:
		var legend := board.position + Vector2(26.0, board.size.y - 26.0)
		draw_string(_font, legend, "实线：走过的路   虚线：只在纸上   空白：还没人去过",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)


func _draw_marker(m: Dictionary, board: Rect2, s: Vector2, k: float, index: int) -> void:
	var p: Vector3 = m.get("pos", Vector3.ZERO)
	var at := _project(Vector2(p.x, p.z), board, s)
	var title := String(m.get("title", ""))
	var known := bool(m.get("known", false))
	var kind := String(m.get("kind", ""))
	var ink := INK if known else Color(0.62, 0.55, 0.47, 0.55)
	var r := 13.0 * k
	# 当前任务指向的地标：一圈呼吸环，玩家一眼知道往哪走
	if bool(m.get("objective", false)):
		var pulse := 0.55 + 0.25 * sin(float(Time.get_ticks_msec()) * 0.004)
		draw_arc(at, r + 9.0 * k, 0.0, TAU, 32, Color(1.0, 0.66, 0.30, pulse), 2.0)
	match kind:
		"boss":
			draw_circle(at, r + 3.0 * k, Color(0.85, 0.26, 0.10, 0.22))
			draw_arc(at, r + 3.0 * k, 0.0, TAU, 24, Color(0.98, 0.52, 0.22, 0.8), 2.0)
			draw_circle(at, r * 0.55, Color(0.98, 0.52, 0.22, 0.7))
		"elevator":
			draw_rect(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), ink, false, 2.0)
			draw_line(at + Vector2(0, -r), at + Vector2(0, r), ink, 1.5)
		"tent":
			var pts := PackedVector2Array([
				at + Vector2(-r, r * 0.7), at + Vector2(0, -r), at + Vector2(r, r * 0.7)])
			draw_polyline(pts, ink, 2.0)
		"kitchen", "warehouse":
			draw_rect(Rect2(at - Vector2(r * 0.8, r * 0.6), Vector2(r, r) * 1.6), ink, false, 2.0)
		"station":
			draw_line(at + Vector2(-r, r * 0.6), at + Vector2(r, r * 0.6), ink, 2.0)
			draw_line(at + Vector2(-r, r * 0.6), at + Vector2(-r, -r * 0.2), ink, 2.0)
			draw_line(at + Vector2(r, r * 0.6), at + Vector2(r, -r * 0.2), ink, 2.0)
		_:
			draw_circle(at, r * 0.6, ink)

	# 小图只画符号，名字挤在一起没法看；大图才写字，并且左右交错避免叠字
	if mini:
		return
	var size_px := int(17.0 * k)
	var text := title if known else "?"
	# 奇数号往左挂、偶数号往右挂，路线两侧各占一行
	if index % 2 == 1:
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(_font, at + Vector2(-r - 8.0 - w, 5.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)
	else:
		draw_string(_font, at + Vector2(r + 6.0, 5.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)
