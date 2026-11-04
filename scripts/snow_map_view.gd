extends Control
## 第一章雪原布局图（雪地风，丰富版）：运行时自动抓取场景里的树 + 各类小物件
## 按类型画不同图形符号，地标用图形符号区分，暂不标名字
## 注意：LANDMARKS/ROUTES 是无类型数组，取值必须显式 as 转换，否则 Godot 无法推断类型（报 Parse Error）
var game
var font: Font
var accepts_input := false   # 只有大图响应 M/Esc 关闭（暂停中 game._input 收不到输入）
signal close_requested
const EXTENT := 185.0   # 世界半径：雪山 z=-170、冰湖 x≈174 都要装进图里
var _obj_pts: Array = []   # 元素为 {"type": String, "pos": Vector2}
var _objs_done := false
var _lake_center: Vector2 = Vector2.ZERO
var _lake_radii: PackedFloat32Array = PackedFloat32Array()
var _bridge_rect: Rect2 = Rect2()
var _t := 0.0

# [世界中心, 世界尺寸, 类型]  类型决定图形符号（不标名字）
const LANDMARKS: Array = [
	[Vector2(10.65, 0), Vector2(19, 16), "house"],   # 肯德齐食堂
	[Vector2(3, 12), Vector2(7, 6), "stall"],    # 包子摊
	[Vector2(-55, -20), Vector2(13, 9), "berm"], # 雪障·绳梯
	[Vector2(-55, -50), Vector2(13, 13), "cave"],# 冰洞
	[Vector2(88, -34), Vector2(9, 9), "tower"],  # 灯塔
	[Vector2(24, 6), Vector2(6, 6), "rock"],     # 巨石
]
# 连接主要地点的小径
const ROUTES: Array = [
	[Vector2(0, 0), Vector2(8, 0)],
	[Vector2(8, 0), Vector2(3, 12)],
	[Vector2(0, 0), Vector2(-55, -20)],
	[Vector2(-55, -20), Vector2(-55, -50)],
	[Vector2(8, 0), Vector2(88, -34)],
	[Vector2(0, 0), Vector2(38, -160)],
	[Vector2(38, -160), Vector2(0, -170)],
]
const C_HOUSE := Color("b5793f")
const C_STALL := Color("e0a040")
const C_BERM := Color("c8d2dc")
const C_CAVE := Color("3a4a58")
const C_TOWER := Color("e8e8ee")
const C_ROCK := Color("9aa6b0")
const C_MOUNTAIN := Color("dfe7f2")
const C_LAKE := Color(0.32, 0.58, 0.74, 0.5)
const C_LAKE_RIM := Color(0.55, 0.8, 0.95, 0.8)
const C_PATH := Color(0.42, 0.58, 0.72, 0.55)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei"])
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not accepts_input or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if k == KEY_M or k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_requested.emit()


func project(p: Vector2) -> Vector2:
	var scale_ := minf((size.x - 30.0) / (EXTENT * 2.0), (size.y - 52.0) / (EXTENT * 2.0))
	return Vector2(size.x / 2.0, size.y / 2.0 + 8.0) + p * scale_


func _scale() -> float:
	return minf((size.x - 30.0) / (EXTENT * 2.0), (size.y - 52.0) / (EXTENT * 2.0))


## 只查一次：递归遍历整棵场景树，按节点名识别树 / 推车 / 板条箱 / 货箱 / 大包 / 冰桶 / 冰粽 / 巨石
## 注意本版本 Node.find_children() 对运行时节点返回空，故自己递归
func _cache_objects() -> void:
	if _objs_done or game == null or not is_instance_valid(game):
		return
	_objs_done = true
	_collect_objects(game)


func _collect_objects(node: Node) -> void:
	var n3 := node as Node3D
	if n3 != null:
		var nm: String = n3.name
		if nm == "WaterZone" or n3.is_in_group("water_zone"):
			_cache_lake(n3)
		elif nm == "Bridge":
			_cache_bridge(n3)
		else:
			var t := _obj_type(nm)
			if t != "":
				_obj_pts.append({"type": t, "pos": Vector2(n3.global_position.x, n3.global_position.z)})
	for c in node.get_children():
		_collect_objects(c)


## 读取 WaterZone 的真实径向轮廓（由水面网格算出）作为湖形，中心对齐其 center
func _cache_lake(nz: Node) -> void:
	var c: Variant = nz.get("center")
	if c != null:
		var c3 := c as Vector3
		_lake_center = Vector2(c3.x, c3.z)
	var rm: Variant = nz.get("_r_max")
	if rm != null and typeof(rm) == TYPE_PACKED_FLOAT32_ARRAY:
		var arr := rm as PackedFloat32Array
		var mx := 0.0
		for b in arr:
			if b > mx:
				mx = b
		if mx > 0.0:
			_lake_radii = arr


## 读取 Bridge 子网格的世界 AABB（XZ 投影）作为桥面矩形
func _cache_bridge(nb: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for c in nb.get_children():
		var m := c as MeshInstance3D
		if m != null and m.mesh != null:
			var wa := m.global_transform * m.mesh.get_aabb()
			if first:
				aabb = wa
				first = false
			else:
				aabb = aabb.merge(wa)
	if not first:
		_bridge_rect = Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z)


func _obj_type(nm: String) -> String:
	if "Tree" in nm: return "tree"
	if "Cart" in nm: return "cart"
	if "Crate" in nm: return "crate"
	if "Cargo" in nm: return "cargo"
	if "Bigbag" in nm: return "bag"
	if "Tub" in nm: return "tub"
	if "Dumpling" in nm: return "dumpling"
	if "Boulder" in nm: return "boulder"
	return ""


func _draw() -> void:
	if font == null:
		return
	_cache_objects()
	var small := size.x < 400
	var s := _scale()

	# 雪地风面板：半透明浅蓝白雪色 + 冰蓝描边（降低对视野的遮挡）
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.918, 0.949, 0.984, 0.42)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.663, 0.796, 0.902, 0.55)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))

	# 雪原网格（淡淡）
	for gx in range(-180, 181, 30):
		var ga := project(Vector2(float(gx), -185.0))
		var gb := project(Vector2(float(gx), 185.0))
		draw_line(ga, gb, Color(0.55, 0.72, 0.88, 0.12), 1)
	for gz in range(-180, 181, 30):
		var ga := project(Vector2(-185.0, float(gz)))
		var gb := project(Vector2(185.0, float(gz)))
		draw_line(ga, gb, Color(0.55, 0.72, 0.88, 0.12), 1)

	# 可活动范围（边界墙）：冰蓝细圈
	draw_arc(project(Vector2.ZERO), 94.6 * s, 0, TAU, 80, Color(0.45, 0.62, 0.78, 0.5), 1)

	# 雪山等高线
	for cr in [35.0, 60.0, 85.0]:
		draw_arc(project(Vector2(0, -170)), cr * s, 0, TAU, 48, Color(0.7, 0.8, 0.9, 0.18), 1)

	# 小径路网
	for rt in ROUTES:
		var ra := project(rt[0] as Vector2)
		var rb := project(rt[1] as Vector2)
		draw_line(ra, rb, C_PATH, 2)

	# 冰湖（按 WaterZone 从真实水面网格算出的径向轮廓绘制，形状与实际一致）
	if _lake_radii.size() > 0:
		var bins := _lake_radii.size()
		var pts := PackedVector2Array()
		for b in bins:
			var ang := (float(b) / float(bins)) * TAU - PI
			var wp := _lake_center + Vector2(cos(ang), sin(ang)) * _lake_radii[b]
			pts.append(project(wp))
		draw_colored_polygon(pts, C_LAKE)
		for i in bins:
			draw_line(pts[i], pts[(i + 1) % bins], C_LAKE_RIM, 1.5)
		# 桥（覆盖在湖上，按 Bridge 网格世界 AABB 绘制）
		if _bridge_rect.size.x > 0.0 and _bridge_rect.size.y > 0.0:
			var tl := project(Vector2(_bridge_rect.position.x, _bridge_rect.position.y))
			var tr := project(Vector2(_bridge_rect.end.x, _bridge_rect.position.y))
			var br := project(Vector2(_bridge_rect.end.x, _bridge_rect.end.y))
			var bl := project(Vector2(_bridge_rect.position.x, _bridge_rect.end.y))
			draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), Color(0.55, 0.4, 0.25, 0.85))
	else:
		# 兜底：拿不到轮廓时画圆形
		var lake := project(Vector2(129.5, -49.7))
		draw_circle(lake, 44.0 * s, C_LAKE)
		draw_arc(lake, 44.0 * s, 0, TAU, 56, C_LAKE_RIM, 2)

	# 雪山（带阴影的雪峰）
	var m := project(Vector2(0, -170))
	var ms := 22.0 * s
	draw_colored_polygon(PackedVector2Array([m + Vector2(-1.1, 0.55) * ms, m + Vector2(1.1, 0.55) * ms, m + Vector2(0, -1.0) * ms]), C_MOUNTAIN)
	draw_colored_polygon(PackedVector2Array([m + Vector2(-1.1, 0.55) * ms, m + Vector2(0, 0.55) * ms, m + Vector2(0, -0.15) * ms]), Color(0.55, 0.62, 0.72, 0.6))

	# 摩天轮（金圈高亮，可乘坐）
	var w := project(Vector2(38, -160))
	var wr := 9.0 * s * 2.2
	draw_circle(w, wr, Color(0.9, 0.72, 0.3, 0.16))
	draw_arc(w, wr, 0, TAU, 28, Color("e8bc66"), 2)
	draw_line(w + Vector2(-wr, 0), w + Vector2(wr, 0), Color(0.9, 0.72, 0.3, 0.5), 1)
	draw_line(w + Vector2(0, -wr), w + Vector2(0, wr), Color(0.9, 0.72, 0.3, 0.5), 1)

	# 树 / 推车 / 板条箱 / 货箱 / 大包 / 冰桶 / 冰粽 / 巨石（运行时抓取，按类型画符号）
	var ti := 0
	for e in _obj_pts:
		var op: Vector2 = e["pos"]
		var t := e["type"] as String
		var t2 := project(op)
		match t:
			"tree":
				var jitter := sin(float(ti) * 12.9898) * 43758.5453
				jitter = jitter - floor(jitter)
				var shade := Color(0.12 + 0.06 * jitter, 0.32 + 0.1 * jitter, 0.2 + 0.06 * jitter, 0.92)
				var sz := 3.0 + jitter * 1.8
				draw_colored_polygon(PackedVector2Array([t2 + Vector2(-sz, sz), t2 + Vector2(sz, sz), t2 + Vector2(0, -sz * 1.4)]), shade)
				draw_circle(t2 + Vector2(0, -sz * 1.4), sz * 0.35, Color("ffffff"))
			"cart":
				draw_rect(Rect2(t2 - Vector2(2.4, 2.0), Vector2(4.8, 4.0)), Color("9a6b3f"))
				draw_circle(t2 + Vector2(-1.4, 2.4), 0.9, Color("3a2a18"))
				draw_circle(t2 + Vector2(1.4, 2.4), 0.9, Color("3a2a18"))
			"crate":
				draw_rect(Rect2(t2 - Vector2(2.2, 2.2), Vector2(4.4, 4.4)), Color("c9a36a"))
			"cargo":
				draw_rect(Rect2(t2 - Vector2(2.6, 2.2), Vector2(5.2, 4.4)), Color("8c8f96"))
			"bag":
				draw_circle(t2, 2.7, Color("3f5a7a"))
			"tub":
				draw_arc(t2, 2.9, 0, TAU, 14, Color("aee0f0"), 1.6)
			"dumpling":
				draw_circle(t2, 2.6, Color("f3ecd2"))
				draw_arc(t2, 2.6, 0, TAU, 14, Color("caa64a"), 1)
			"boulder":
				draw_circle(t2, 3.0, Color("9aa6b0"))
		ti += 1

	# 地标图形符号（不标名字）
	for lm in LANDMARKS:
		var c := project(lm[0] as Vector2)
		var dim: Vector2 = (lm[1] as Vector2) * s
		var kind := lm[2] as String
		match kind:
			"house":
				draw_rect(Rect2(c - dim * 0.5, dim), C_HOUSE)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-dim.x * 0.5, -dim.y * 0.5), c + Vector2(dim.x * 0.5, -dim.y * 0.5), c + Vector2(0, -dim.y * 0.5 - 7.0 * s)]), C_HOUSE)
			"stall":
				draw_circle(c, dim.x * 0.5, C_STALL)
			"berm":
				draw_arc(c, dim.x * 0.5, PI, TAU, 16, C_BERM, 4)
			"cave":
				draw_arc(c, dim.x * 0.5, PI, TAU, 18, C_CAVE, 5)
			"tower":
				draw_rect(Rect2(c - Vector2(2.5 * s, dim.y * 0.5), Vector2(5.0 * s, dim.y)), C_TOWER)
				draw_circle(c + Vector2(0, -dim.y * 0.5 - 3.0 * s), 3.0 * s, Color("ffd98a"))
			"rock":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-dim.x * 0.5, dim.y * 0.4), c + Vector2(-dim.x * 0.1, -dim.y * 0.5), c + Vector2(dim.x * 0.5, dim.y * 0.4)]), C_ROCK)

	# 出生点：白环
	draw_arc(project(Vector2.ZERO), 5.0 * s, 0, TAU, 18, Color("ffffff"), 2)

	# 飘雪动画
	var sn := 70 if not small else 34
	for i in sn:
		var jitter := sin(float(i) * 12.9898) * 43758.5453
		jitter = jitter - floor(jitter)
		var sx := fmod(jitter * size.x + _t * 7.0 + float(i) * 11.3, size.x)
		var sy := fmod(float(i) * 17.7 + _t * 16.0, size.y)
		draw_circle(Vector2(sx, sy), 1.1 + jitter * 0.8, Color(1.0, 1.0, 1.0, 0.45))

	# 玩家实时位置
	if game != null and is_instance_valid(game.player):
		var pos: Vector3 = game.player.global_position
		var at := project(Vector2(pos.x, pos.z))
		draw_circle(at, 4.5 if small else 6.5, Color("1f9bd1"))
		draw_arc(at, (7 if small else 10), 0, TAU, 20, Color("1f9bd1"), 1)
