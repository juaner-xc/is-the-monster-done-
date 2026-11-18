extends Node3D

## 木制指路牌（参考图造型）：深棕立柱 + 三块横木板（板间留缝、深浅不一）
## + 背板条 + 顶部铁钉，整体微倾。牌面中央贴「雪原路线图」。
## 地图优先用 assets/ui/snow_route_map.png（放进项目即自动生效）；
## 没有真图时用内置程序绘制的占位版，无需改代码。

const MAP_PATH := "res://assets/ui/snow_route_map.png"
const MAP_W := 736
const MAP_H := 976

var _map_mat: StandardMaterial3D


class MapPainter extends Node2D:
	var font: Font

	func _draw() -> void:
		var paper := Color(0.945, 0.937, 0.902)
		var ink := Color(0.19, 0.22, 0.25)
		var blue := Color(0.25, 0.47, 0.78)
		var green := Color(0.24, 0.62, 0.42)
		var snow1 := Color(0.81, 0.86, 0.91)
		var snow2 := Color(0.72, 0.79, 0.87)
		draw_rect(Rect2(0, 0, 736, 976), paper)
		_blob(Vector2(100, 220), 160, 70, snow1)
		_blob(Vector2(620, 180), 150, 80, snow2)
		_blob(Vector2(680, 480), 140, 90, snow1)
		_blob(Vector2(90, 620), 130, 80, snow2)
		_blob(Vector2(160, 880), 170, 70, snow1)
		_blob(Vector2(560, 820), 150, 70, snow2)
		for t in [[110, 330, 1.0], [185, 250, 0.75], [655, 250, 1.0], [600, 140, 0.7],
				[95, 570, 0.8], [680, 720, 0.9], [200, 860, 0.75], [640, 880, 0.8],
				[520, 110, 0.65], [130, 460, 0.7]]:
			_tree(float(t[0]), float(t[1]), float(t[2]), Color(0.31, 0.5, 0.38))
		draw_string(font, Vector2(36, 84), "雪原路线图", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, ink)
		draw_rect(Rect2(36, 98, 214, 5), ink)
		draw_string(font, Vector2(664, 62), "北", HORIZONTAL_ALIGNMENT_CENTER, 60, 32, ink)
		draw_line(Vector2(694, 78), Vector2(694, 128), ink, 4.0, true)
		_arrow(Vector2(694, 132), Vector2(0, 1), ink)
		_house(Vector2(398, 182), 44, 34, Color(0.85, 0.66, 0.4), Color(0.55, 0.36, 0.24))
		_house(Vector2(444, 170), 40, 30, Color(0.8, 0.6, 0.36), Color(0.55, 0.36, 0.24))
		_house(Vector2(482, 188), 36, 28, Color(0.85, 0.66, 0.4), Color(0.55, 0.36, 0.24))
		_tree(524, 196, 0.7, Color(0.31, 0.5, 0.38))
		_house(Vector2(300, 322), 76, 58, Color(0.83, 0.63, 0.38), Color(0.52, 0.34, 0.22))
		draw_line(Vector2(372, 472), Vector2(372, 430), Color(0.4, 0.42, 0.45), 5.0, true)
		draw_circle(Vector2(372, 424), 10, Color(1.0, 0.84, 0.4))
		var icec := Color(0.62, 0.78, 0.92)
		draw_colored_polygon(PackedVector2Array([Vector2(288, 578), Vector2(270, 652), Vector2(306, 652)]), icec)
		draw_colored_polygon(PackedVector2Array([Vector2(258, 612), Vector2(244, 656), Vector2(274, 656)]), icec.lightened(0.12))
		draw_colored_polygon(PackedVector2Array([Vector2(318, 612), Vector2(302, 656), Vector2(334, 656)]), icec.lightened(0.05))
		draw_arc(Vector2(560, 598), 52, 0, TAU, 48, Color(0.45, 0.52, 0.6), 5.0, true)
		for i in range(6):
			var a := TAU * float(i) / 6.0
			var p := Vector2(560, 598) + Vector2(cos(a), sin(a)) * 52.0
			draw_line(Vector2(560, 598), p, Color(0.45, 0.52, 0.6), 3.0, true)
			draw_circle(p + (Vector2(560, 598) - p).normalized() * 8.0, 9.0, Color(0.9, 0.72, 0.3))
		draw_circle(Vector2(560, 598), 8, Color(0.5, 0.55, 0.62))
		var arch := PackedVector2Array()
		for i in range(13):
			var a2 := PI - PI * float(i) / 12.0
			arch.append(Vector2(390 + cos(a2) * 44, 856 - sin(a2) * 44))
		arch.append(Vector2(434, 862))
		arch.append(Vector2(346, 862))
		draw_colored_polygon(arch, Color(0.38, 0.43, 0.5))
		draw_line(Vector2(322, 878), Vector2(418, 878), Color(0.45, 0.5, 0.55), 4.0, true)
		draw_line(Vector2(322, 894), Vector2(418, 894), Color(0.45, 0.5, 0.55), 4.0, true)
		for i in range(7):
			draw_line(Vector2(330 + i * 14, 872), Vector2(330 + i * 14, 900), Color(0.6, 0.55, 0.45), 5.0, true)
		var main := PackedVector2Array([Vector2(368, 900), Vector2(398, 872), Vector2(398, 838),
			Vector2(380, 790), Vector2(330, 745), Vector2(300, 695), Vector2(288, 655),
			Vector2(310, 600), Vector2(355, 555), Vector2(372, 505), Vector2(360, 455),
			Vector2(325, 410), Vector2(300, 372), Vector2(315, 328), Vector2(360, 288),
			Vector2(415, 242), Vector2(434, 218)])
		draw_polyline(main, blue, 9.0, true)
		_arrow(Vector2(438, 214), Vector2(0.4, -0.55), blue)
		var side := PackedVector2Array([Vector2(602, 636), Vector2(646, 556), Vector2(656, 460),
			Vector2(636, 362), Vector2(582, 288), Vector2(508, 244), Vector2(468, 220)])
		_dashed(side, green, 8.0)
		_arrow(Vector2(464, 216), Vector2(-0.55, -0.35), green)
		_label(430, 252, "圣诞小镇", 30, ink)
		_label(300, 396, "肯德齐食堂", 28, ink)
		_label(372, 508, "路灯", 26, ink)
		_label(288, 692, "雪原礼堂", 28, ink)
		_label(560, 706, "摩天轮", 28, ink)
		_label(470, 852, "山口", 28, ink)
		_label(368, 922, "旧运输通道", 26, ink)
		_label(368, 948, "通往火山工坊", 24, ink)
		draw_line(Vector2(368, 956), Vector2(368, 968), ink, 3.0, true)
		draw_line(Vector2(210, 966), Vector2(270, 966), blue, 6.0, true)
		_arrow(Vector2(274, 966), Vector2(1, 0), blue)
		draw_string(font, Vector2(284, 976), "主线", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
		_dashed(PackedVector2Array([Vector2(420, 966), Vector2(480, 966)]), green, 6.0)
		_arrow(Vector2(484, 966), Vector2(1, 0), green)
		draw_string(font, Vector2(494, 976), "支线", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)

	func _label(cx: float, y: float, text: String, size: int, col: Color) -> void:
		var pos := Vector2(cx - 150, y)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 300, size, 6, Color(0.98, 0.98, 0.95))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 300, size, col)

	func _arrow(at: Vector2, dir: Vector2, col: Color) -> void:
		var d := dir.normalized()
		var p := d * 17.0
		var s := Vector2(-d.y, d.x) * 7.5
		draw_colored_polygon(PackedVector2Array([at + p, at - p * 0.6 + s, at - p * 0.6 - s]), col)

	func _blob(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(10):
			var a := TAU * float(i) / 10.0
			var j := 0.75 + 0.35 * sin(float(i) * 2.3)
			pts.append(c + Vector2(cos(a) * rx * j, sin(a) * ry * j))
		draw_colored_polygon(pts, col)

	func _tree(x: float, y: float, s: float, c: Color) -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 46 * s), Vector2(x - 20 * s, y - 8 * s), Vector2(x + 20 * s, y - 8 * s)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 30 * s), Vector2(x - 26 * s, y + 10 * s), Vector2(x + 26 * s, y + 10 * s)]), c)
		draw_rect(Rect2(x - 4 * s, y + 8 * s, 8 * s, 13 * s), Color(0.42, 0.32, 0.24))

	func _house(c: Vector2, w: float, h: float, body: Color, roof: Color) -> void:
		draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.35, w, h * 0.7), body)
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.62, c.y - h * 0.35), Vector2(c.x, c.y - h), Vector2(c.x + w * 0.62, c.y - h * 0.35)]), roof)
		draw_rect(Rect2(c.x - 5, c.y + h * 0.35 - 14, 10, 14), Color(0.45, 0.3, 0.2))

	func _dashed(path: PackedVector2Array, col: Color, width: float) -> void:
		var dash := 16.0
		var gap := 11.0
		var on := true
		var left := dash
		for i in range(path.size() - 1):
			var a := path[i]
			var b := path[i + 1]
			var seg_len := a.distance_to(b)
			var t := 0.0
			while t < seg_len - 0.001:
				var step := minf(left, seg_len - t)
				if on:
					draw_line(a + (b - a) * (t / seg_len), a + (b - a) * ((t + step) / seg_len), col, width, true)
				t += step
				left -= step
				if left <= 0.001:
					on = not on
					left = dash if on else gap


func _ready() -> void:
	_build_sign()
	_apply_map()


func _build_sign() -> void:
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.24, 3.0, 0.24)
	post.mesh = pm
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.28, 0.2, 0.14)
	post_mat.roughness = 1.0
	post.material_override = post_mat
	post.position = Vector3(0, 1.5, 0)
	add_child(post)
	var root := Node3D.new()
	root.name = "Board"
	root.position = Vector3(0, 1.72, 0.2)
	root.rotation = Vector3(0, 0.06, 0.03)
	add_child(root)
	var tints: Array[Color] = [Color(0.62, 0.44, 0.26), Color(0.56, 0.4, 0.24), Color(0.66, 0.47, 0.28)]
	for k in 3:
		var plank := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(2.3, 0.5, 0.1)
		plank.mesh = bmesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tints[k]
		mat.roughness = 0.92
		plank.material_override = mat
		plank.position = Vector3(0, 0.51 - 0.51 * float(k), 0)
		root.add_child(plank)
	for sx in [-1.02, 1.02]:
		var batten := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.14, 1.62, 0.12)
		batten.mesh = bb
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.45, 0.33, 0.2)
		bmat.roughness = 0.95
		batten.material_override = bmat
		batten.position = Vector3(sx, 0, -0.09)
		root.add_child(batten)
	var nail := MeshInstance3D.new()
	var ns := SphereMesh.new()
	ns.radius = 0.05
	ns.height = 0.1
	nail.mesh = ns
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(0.7, 0.72, 0.75)
	nmat.metallic = 0.6
	nmat.roughness = 0.4
	nail.material_override = nmat
	nail.position = Vector3(0, 0.74, 0.062)
	root.add_child(nail)
	_map_mat = StandardMaterial3D.new()
	_map_mat.albedo_color = Color(1, 1, 1, 1)
	_map_mat.roughness = 0.75
	var quad := MeshInstance3D.new()
	var qm := PlaneMesh.new()
	# 贴面为竖幅地图（736×976，比例≈0.755），尺寸按比例铺满牌面高度，避免拉伸变形
	qm.size = Vector2(1.13, 1.5)
	qm.orientation = PlaneMesh.FACE_Z
	quad.mesh = qm
	quad.material_override = _map_mat
	quad.position = Vector3(0, -0.02, 0.056)
	root.add_child(quad)


func _apply_map() -> void:
	if ResourceLoader.exists(MAP_PATH):
		_map_mat.albedo_texture = load(MAP_PATH)
		return
	var sv := SubViewport.new()
	sv.size = Vector2i(MAP_W, MAP_H)
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var painter := MapPainter.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	painter.font = font
	sv.add_child(painter)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var img := sv.get_texture().get_image()
	if img != null:
		_map_mat.albedo_texture = ImageTexture.create_from_image(img)
	sv.queue_free()
