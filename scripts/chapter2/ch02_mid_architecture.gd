class_name Ch02MidArchitecture
extends Node3D
## 2F 中央广场的基台补全：下方支撑、房间围合+窗、桥拱、广场柱列、非房间区栏杆。
## 只负责 2F，不动 1F / 3F / 4F 的既有内容。

const FENCE_MODEL := "res://assets/chapter2/models/spooky_fence.glb"

const FLOOR_Y := 5.22
const WALL_H := 9.5
const WALL_T := 0.5
const SILL := 3.5
const HEAD := 7.25
const BASE_Y := 0.54

var stone: StandardMaterial3D


func setup(_host: Node, mat: Material) -> void:
	stone = (mat as StandardMaterial3D).duplicate() if mat is StandardMaterial3D else _make_stone()
	_build_supports()
	_build_rooms()
	_build_door_signs()
	_build_plaza_columns()
	_build_roofs()
	_build_boss_room()
	_build_arcade_facades()
	_build_fences()


func _make_stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.215, 0.225, 0.25)
	m.roughness = 0.95
	var tex := load("res://assets/chapter2/textures/rock_diffuse.png") as Texture2D
	if tex != null:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, collide := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
	add_child(body)
	return body


func _cyl(radius: float, height: float, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body


func _build_door_signs() -> void:
	_door_sign(Vector3(-47.8, 12.75, -14.0), PI * 0.5, "仓库")
	_door_sign(Vector3(-31.2, 12.75, -14.0), -PI * 0.5, "备用厨房")


func _door_sign(pos: Vector3, yaw: float, text: String) -> void:
	_box(Vector3(0.18, 1.15, 3.1), pos, _warm_stone(Color(0.16, 0.12, 0.08)), false)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimHei", "SimSun"])
	var label := Label3D.new()
	label.name = "DoorSign_%s" % text
	label.text = text
	label.font = font
	label.font_size = 96
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.86, 0.56)
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.03, 0.015)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.rotation.y = yaw
	label.position = pos + Vector3(0.18 if yaw > 0.0 else -0.18, 0.0, 0.0)
	add_child(label)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0.8 if yaw > 0.0 else -0.8, 0.0, 0.0)
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 1.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)


# ---------------------------------------------------------------- 下方支撑
func _build_supports() -> void:
	# 2F 下方做成连续的石拱桥/拱廊，取代原来的方墩 + 平梁。
	_arcade_x(-6.0, -74.0, -48.0)    # 仓库南
	_arcade_x(-22.0, -74.0, -48.0)   # 仓库北
	_arcade_z(-74.0, -22.0, -6.0)    # 仓库西
	_arcade_x(-4.0, -31.0, -3.0)     # 厨房南
	_arcade_x(-24.0, -31.0, -3.0)    # 厨房北
	_arcade_z(-3.0, -24.0, -4.0)     # 厨房东
	_arcade_x(-6.0, -49.0, -29.0)    # 广场南
	_arcade_x(-22.0, -49.0, -29.0)   # 广场北


func _arcade_x(z: float, x0: float, x1: float) -> void:
	var length := x1 - x0
	var spans := maxi(2, int(round(length / 5.6)))
	var span := length / float(spans)
	var pw := 1.0
	var base := BASE_Y
	var top := 5.10
	for i in range(spans + 1):
		var px := x0 + span * float(i)
		_box(Vector3(pw, 2.7, 0.95), Vector3(px, base + 1.35, z), stone, false)
	for i in range(spans):
		var cx := x0 + span * (float(i) + 0.5)
		var inner := span - pw
		var radius := inner * 0.5
		var spring := clampf(4.8 - radius, 1.5, 2.6)
		var crown := spring + radius
		var blocks := 9
		for b in range(blocks):
			var a0 := PI * float(b) / float(blocks)
			var a1 := PI * float(b + 1) / float(blocks)
			var am := (a0 + a1) * 0.5
			var px := cx + radius * cos(am)
			var py := spring + radius * sin(am)
			var seg := radius * (a1 - a0) * 1.12
			var block := _box(Vector3(seg, 0.42, 0.95),
				Vector3(px, py, z), stone, false)
			block.rotation.z = am + PI * 0.5
		if crown < top:
			_box(Vector3(span, top - crown, 0.95),
				Vector3(cx, (crown + top) * 0.5, z), stone, false)


func _arcade_z(x: float, z0: float, z1: float) -> void:
	var length := z1 - z0
	var spans := maxi(2, int(round(length / 5.6)))
	var span := length / float(spans)
	var pw := 1.0
	var base := BASE_Y
	var top := 5.10
	for i in range(spans + 1):
		var pz := z0 + span * float(i)
		_box(Vector3(0.95, 2.7, pw), Vector3(x, base + 1.35, pz), stone, false)
	for i in range(spans):
		var cz := z0 + span * (float(i) + 0.5)
		var inner := span - pw
		var radius := inner * 0.5
		var spring := clampf(4.8 - radius, 1.5, 2.6)
		var crown := spring + radius
		var blocks := 9
		for b in range(blocks):
			var a0 := PI * float(b) / float(blocks)
			var a1 := PI * float(b + 1) / float(blocks)
			var am := (a0 + a1) * 0.5
			var pz := cz + radius * cos(am)
			var py := spring + radius * sin(am)
			var seg := radius * (a1 - a0) * 1.12
			var block := _box(Vector3(0.95, 0.42, seg),
				Vector3(x, py, pz), stone, false)
			block.rotation.x = am + PI * 0.5
		if crown < top:
			_box(Vector3(0.95, top - crown, span),
				Vector3(x, (crown + top) * 0.5, cz), stone, false)


func _pier(pos: Vector3, width: float) -> void:
	var h := 4.82 - BASE_Y
	_box(Vector3(width, 0.45, width), Vector3(pos.x, BASE_Y + 0.22, pos.z), stone)
	_box(Vector3(width, h, width), Vector3(pos.x, BASE_Y + h * 0.5, pos.z), stone)
	_box(Vector3(width * 1.4, 0.38, width * 1.4), Vector3(pos.x, 4.82, pos.z), stone)


func _beam(pos: Vector3, size: Vector3) -> void:
	_box(size, pos, stone)


# ---------------------------------------------------------------- 房间围合
func _build_rooms() -> void:
	# 仓库：北/南/西三面留窗，东面朝广场开门
	_wall_x(-22.0, -74.0, -48.0, [-69.0, -61.0, -53.0], 3.2)
	_wall_x(-6.0, -74.0, -48.0, [-69.0, -61.0, -53.0], 3.2)
	_wall_z(-74.0, -22.0, -6.0, [-18.0, -10.0], 2.8)
	_wall_z_door(-48.0, -22.0, -6.0, -14.0, 4.0, 6.0)

	# 厨房：北/南/东三面留窗，西面朝广场开门
	_wall_x(-24.0, -31.0, -3.0, [-27.0, -17.0, -7.0], 3.6)
	_wall_x(-4.0, -31.0, -3.0, [-27.0, -17.0, -7.0], 3.6)
	_wall_z(-3.0, -24.0, -4.0, [-20.0, -14.0, -8.0], 3.0)
	_wall_z_door(-31.0, -24.0, -4.0, -14.0, 3.5, 6.0)


## 沿 X 方向的墙，窗户在窗户中心处开洞。
func _wall_x(z: float, x0: float, x1: float, windows: Array, win_w: float) -> void:
	var length := x1 - x0
	var cx := (x0 + x1) * 0.5
	# 下槛、上楣
	_box(Vector3(length, SILL, WALL_T), Vector3(cx, FLOOR_Y + SILL * 0.5, z), stone)
	var top_h := WALL_H - HEAD
	_box(Vector3(length, top_h, WALL_T), Vector3(cx, FLOOR_Y + HEAD + top_h * 0.5, z), stone)
	# 窗间墙
	var cuts: Array = []
	for wc in windows:
		cuts.append([float(wc) - win_w * 0.5, float(wc) + win_w * 0.5])
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var cursor := x0
	for cut in cuts:
		_pier_x(z, cursor, cut[0])
		cursor = cut[1]
	_pier_x(z, cursor, x1)
	# 窗框
	for wc in windows:
		_frame_x(z, float(wc), win_w)


func _pier_x(z: float, x0: float, x1: float) -> void:
	var w := x1 - x0
	if w < 0.05:
		return
	var h := HEAD - SILL
	_box(Vector3(w, h, WALL_T), Vector3((x0 + x1) * 0.5, FLOOR_Y + SILL + h * 0.5, z), stone)


func _frame_x(z: float, cx: float, win_w: float) -> void:
	var h := HEAD - SILL
	var fw := 0.12
	for side in [-1.0, 1.0]:
		_box(Vector3(fw, h, WALL_T + 0.12),
			Vector3(cx + side * win_w * 0.5, FLOOR_Y + SILL + h * 0.5, z), stone)
	_box(Vector3(win_w + fw * 2.0, fw, WALL_T + 0.12),
		Vector3(cx, FLOOR_Y + SILL, z), stone)
	_box(Vector3(win_w + fw * 2.0, fw, WALL_T + 0.12),
		Vector3(cx, FLOOR_Y + HEAD, z), stone)


## 沿 Z 方向的墙，窗户在窗户中心处开洞。
func _wall_z(x: float, z0: float, z1: float, windows: Array, win_w: float) -> void:
	var length := z1 - z0
	var cz := (z0 + z1) * 0.5
	_box(Vector3(WALL_T, SILL, length), Vector3(x, FLOOR_Y + SILL * 0.5, cz), stone)
	var top_h := WALL_H - HEAD
	_box(Vector3(WALL_T, top_h, length), Vector3(x, FLOOR_Y + HEAD + top_h * 0.5, cz), stone)
	var cuts: Array = []
	for wc in windows:
		cuts.append([float(wc) - win_w * 0.5, float(wc) + win_w * 0.5])
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var cursor := z0
	for cut in cuts:
		_pier_z(x, cursor, cut[0])
		cursor = cut[1]
	_pier_z(x, cursor, z1)
	for wc in windows:
		_frame_z(x, float(wc), win_w)


func _pier_z(x: float, z0: float, z1: float) -> void:
	var w := z1 - z0
	if w < 0.05:
		return
	var h := HEAD - SILL
	_box(Vector3(WALL_T, h, w), Vector3(x, FLOOR_Y + SILL + h * 0.5, (z0 + z1) * 0.5), stone)


func _frame_z(x: float, cz: float, win_w: float) -> void:
	var h := HEAD - SILL
	var fw := 0.12
	for side in [-1.0, 1.0]:
		_box(Vector3(WALL_T + 0.12, h, fw),
			Vector3(x, FLOOR_Y + SILL + h * 0.5, cz + side * win_w * 0.5), stone)
	_box(Vector3(WALL_T + 0.12, fw, win_w + fw * 2.0),
		Vector3(x, FLOOR_Y + SILL, cz), stone)
	_box(Vector3(WALL_T + 0.12, fw, win_w + fw * 2.0),
		Vector3(x, FLOOR_Y + HEAD, cz), stone)


## 带门洞的 Z 向墙：门两侧整高墙 + 门楣。
func _wall_z_door(x: float, z0: float, z1: float, door_z: float,
		door_w: float, door_h: float) -> void:
	var a0 := z0
	var a1 := door_z - door_w * 0.5
	var b0 := door_z + door_w * 0.5
	var b1 := z1
	for seg in [[a0, a1], [b0, b1]]:
		var w: float = seg[1] - seg[0]
		if w <= 0.05:
			continue
		_box(Vector3(WALL_T, WALL_H, w),
			Vector3(x, FLOOR_Y + WALL_H * 0.5, (seg[0] + seg[1]) * 0.5), stone)
	var lintel_h := WALL_H - door_h
	_box(Vector3(WALL_T, lintel_h, door_w),
		Vector3(x, FLOOR_Y + door_h + lintel_h * 0.5, door_z), stone)
	# 门框
	for side in [-1.0, 1.0]:
		_box(Vector3(WALL_T + 0.16, door_h, 0.14),
			Vector3(x, FLOOR_Y + door_h * 0.5, door_z + side * door_w * 0.5), stone)


# ---------------------------------------------------------------- 广场柱列
func _build_plaza_columns() -> void:
	var spots := [
		[-48.2, -21.2], [-48.2, -6.8], [-29.8, -21.2], [-29.8, -6.8],
		[-48.2, -18.2], [-48.2, -9.8], [-29.8, -18.2], [-29.8, -9.8],
		[-43.0, -21.2], [-35.0, -21.2], [-43.0, -6.8], [-35.0, -6.8],
	]
	for spot in spots:
		var p := Vector3(float(spot[0]), 0.0, float(spot[1]))
		_box(Vector3(0.95, 0.3, 0.95), Vector3(p.x, FLOOR_Y + 0.15, p.z), stone)
		_cyl(0.34, 3.3, Vector3(p.x, FLOOR_Y + 1.95, p.z), stone)
		_box(Vector3(0.9, 0.28, 0.9), Vector3(p.x, FLOOR_Y + 3.72, p.z), stone)


# ---------------------------------------------------------------- GLB 工具
func _place_glb(path: String, center: Vector3, scale_factor: float, yaw: float,
		label: String, top_y: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("missing model: " + path)
		return
	var node := packed.instantiate() as Node3D
	if node == null:
		return
	node.name = label
	add_child(node)
	node.scale = Vector3.ONE * scale_factor
	node.rotation.y = yaw
	var aabb := _aabb_of(node)
	aabb = _aabb_of(node)
	node.global_position += Vector3(center.x, 0, center.z) - Vector3(
		aabb.position.x + aabb.size.x * 0.5, 0, aabb.position.z + aabb.size.z * 0.5)
	aabb = _aabb_of(node)
	node.global_position.y += top_y - aabb.end.y


func _aabb_of(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		result = b if first else result.merge(b)
		first = false
	return result


# ---------------------------------------------------------------- 哥特屋顶
func _build_roofs() -> void:
	_roof_for("WarehouseRoof", Rect2(-74.0, -22.0, 26.0, 16.0), 20.0)
	_roof_for("KitchenRoof", Rect2(-31.0, -24.0, 28.0, 20.0), 21.0)


func _roof_for(label: String, rect: Rect2, ridge_y: float) -> void:
	var eave := FLOOR_Y + WALL_H
	var over := 0.7
	var x0 := rect.position.x - over
	var x1 := rect.position.x + rect.size.x + over
	var z0 := rect.position.y - over
	var z1 := rect.position.y + rect.size.y + over
	var xc := (x0 + x1) * 0.5
	var zc := (z0 + z1) * 0.5
	var roof_stone := _warm_stone(Color(0.60, 0.45, 0.24))
	var roof_tile := _plain_warm(Color(0.55, 0.40, 0.20))
	var marker := Node3D.new()
	marker.name = label
	add_child(marker)

	# 双坡屋面：脊线沿 Z，南面就是玩家看得到的山墙正面
	var half := (x1 - x0) * 0.5
	var rise := ridge_y - eave
	var slope_len := sqrt(half * half + rise * rise)
	var angle := atan2(rise, half)
	for side in [-1.0, 1.0]:
		var slope := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(slope_len, 0.35, z1 - z0)
		slope.mesh = bm
		slope.material_override = roof_tile
		slope.position = Vector3((x0 + xc) * 0.5 if side < 0.0 else (xc + x1) * 0.5,
			(eave + ridge_y) * 0.5, zc)
		slope.rotation.z = angle if side < 0.0 else -angle
		add_child(slope)

	# 南北山墙三角
	for z in [z0 + 0.25, z1 - 0.25]:
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(x1 - x0, rise, 0.5)
		prism.left_to_right = 0.5
		gable.mesh = prism
		gable.material_override = roof_stone
		gable.position = Vector3(xc, eave + rise * 0.5, z)
		add_child(gable)

	# 屋脊
	_box(Vector3(0.5, 0.4, z1 - z0 - 0.3),
		Vector3(xc, ridge_y + 0.05, zc), roof_stone, false)

	# 四角塔 + 尖顶（放在檐角，南面也能看到）
	for sx in [x0 + 0.8, x1 - 0.8]:
		for sz in [z0 + 0.8, z1 - 0.8]:
			_box(Vector3(1.2, 2.4, 1.2), Vector3(sx, eave + 1.2, sz), roof_stone, false)
			var spire := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.03
			cone.bottom_radius = 0.55
			cone.height = 7.2
			cone.radial_segments = 8
			spire.mesh = cone
			spire.material_override = roof_stone
			spire.position = Vector3(sx, eave + 2.4 + 3.6, sz)
			add_child(spire)
			var tip := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = 0.12
			ball.height = 0.24
			tip.mesh = ball
			tip.material_override = roof_tile
			tip.position = Vector3(sx, eave + 2.4 + 7.25, sz)
			add_child(tip)

	# 南北山墙顶小尖塔
	for z in [z0 + 0.3, z1 - 0.3]:
		var finial := MeshInstance3D.new()
		var fs := CylinderMesh.new()
		fs.top_radius = 0.02
		fs.bottom_radius = 0.34
		fs.height = 3.2
		fs.radial_segments = 8
		finial.mesh = fs
		finial.material_override = roof_stone
		finial.position = Vector3(xc, ridge_y + 1.6, z)
		add_child(finial)

	# 南北山墙：三角形镂空窗 + 灰白边框（取代原来的圆形花窗）
	for z in [z0 + 0.02, z1 - 0.02]:
		var tri_base := eave + 3.55
		var tri_h := clampf(ridge_y - tri_base - 0.12, 1.0, 1.6)
		_tri_window_z(z, xc, tri_base, 2.6, tri_h)
		_gable_arch_z(z, xc, eave, roof_stone)

	# 外侧扶壁：东西两侧 + 北侧，南立面留给花窗和尖顶
	for side in [x0, x1]:
		for i in 4:
			var bz := lerpf(z0 + 3.0, z1 - 3.0, float(i) / 3.0)
			_box(Vector3(1.1, 6.5, 0.85), Vector3(side, FLOOR_Y + 3.25, bz), roof_stone, false)
	for i in 4:
		var bx := lerpf(x0 + 4.0, x1 - 4.0, float(i) / 3.0)
		_box(Vector3(0.85, 6.5, 1.1), Vector3(bx, FLOOR_Y + 3.25, z0), roof_stone, false)


func _tri_window_z(z: float, xc: float, base_y: float, width: float, height: float) -> void:
	var w := width * 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.015, 0.010, 0.008)
	dark.roughness = 1.0
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(xc - w, base_y, z), Vector3(xc + w, base_y, z),
			Vector3(xc, base_y + height, z)]:
		st.add_vertex(p)
	st.generate_normals()
	var hole := MeshInstance3D.new()
	hole.mesh = st.commit()
	hole.material_override = dark
	add_child(hole)

	var frame_mat := _warm_stone(Color(0.74, 0.74, 0.72))
	var p0 := Vector2(xc - w, base_y)
	var p1 := Vector2(xc + w, base_y)
	var p2 := Vector2(xc, base_y + height)
	for seg in [[p0, p1], [p0, p2], [p2, p1]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var d := b - a
		var length := d.length()
		var mid := (a + b) * 0.5
		var beam := _box(Vector3(length, 0.18, 0.22),
			Vector3(mid.x, mid.y, z + 0.06), frame_mat, false)
		beam.rotation.z = atan2(d.y, d.x)


func _gable_arch_z(z: float, xc: float, eave: float, mat: Material) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.10, 0.075, 0.05)
	dark.emission_enabled = true
	dark.emission = Color(0.72, 0.42, 0.14)
	dark.emission_energy_multiplier = 0.55
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var base_y := eave + 0.10
	_box(Vector3(2.2, 2.2, 0.12), Vector3(xc, base_y + 1.1, z), dark, false)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(xc - 1.1, base_y + 2.2, z), Vector3(xc + 1.1, base_y + 2.2, z),
			Vector3(xc, base_y + 3.35, z)]:
		st.add_vertex(p)
	st.generate_normals()
	var tip := MeshInstance3D.new()
	tip.mesh = st.commit()
	tip.material_override = dark
	add_child(tip)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.22, 2.7, 0.2),
			Vector3(xc + side * 1.2, base_y + 1.35, z), mat, false)


func _warm_stone(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	var tex := load("res://assets/chapter2/textures/rock_diffuse.png") as Texture2D
	if tex != null:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.32, 0.32, 0.32)
	m.emission_enabled = true
	m.emission = Color(0.10, 0.075, 0.045)
	m.emission_energy_multiplier = 0.2
	return m


func _plain_warm(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(0.14, 0.09, 0.04)
	m.emission_energy_multiplier = 0.18
	return m


# ---------------------------------------------------------------- Boss 厅
func _build_boss_room() -> void:
	var marker := Node3D.new()
	marker.name = "BossHall"
	add_child(marker)
	var floor_y := 14.53
	var h := 9.5
	var x0 := -55.0
	var x1 := -23.0
	var z0 := -102.0
	var z1 := -86.0
	var eave := floor_y + h
	var ridge := 31.0
	var xc := (x0 + x1) * 0.5
	var zc := (z0 + z1) * 0.5
	var mat := _warm_stone(Color(0.60, 0.45, 0.24))
	var tile := _plain_warm(Color(0.55, 0.40, 0.20))

	# 两侧墙，各留 3 扇高窗
	_boss_wall_z(x0, z0, z1, floor_y, h, mat)
	_boss_wall_z(x1, z0, z1, floor_y, h, mat)

	# 正面只留 4m 门垛 + 巨型尖拱，中间 24m 全开，保证一楼能看见熔炉口
	for sx in [x0 + 2.0, x1 - 2.0]:
		_box(Vector3(4.0, h, 1.2), Vector3(sx, floor_y + h * 0.5, z1), mat, false)
		_box(Vector3(1.4, 3.0, 1.6), Vector3(sx, floor_y + h + 1.5, z1), mat, false)
	var arch_h := ridge - 0.8
	_arch_band(Vector3(x0 + 4.0, eave, z1), Vector3(xc, arch_h, z1), mat)
	_arch_band(Vector3(x1 - 4.0, eave, z1), Vector3(xc, arch_h, z1), mat)
	_box(Vector3(2.2, 1.6, 1.6), Vector3(xc, arch_h, z1), mat, false)

	# 双坡屋顶（只盖前半间，后半间敞开对着熔炉口）
	var half := (x1 - x0) * 0.5
	var rise := ridge - eave
	var slope_len := sqrt(half * half + rise * rise)
	var angle := atan2(rise, half)
	for side in [-1.0, 1.0]:
		var slope := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(slope_len, 0.4, z1 - z0)
		slope.mesh = bm
		slope.material_override = tile
		slope.position = Vector3((x0 + xc) * 0.5 if side < 0.0 else (xc + x1) * 0.5,
			(eave + ridge) * 0.5, zc)
		slope.rotation.z = angle if side < 0.0 else -angle
		add_child(slope)
	_box(Vector3(0.6, 0.45, z1 - z0), Vector3(xc, ridge + 0.05, zc), mat, false)

	# 正面两角尖塔
	for sx in [x0 + 2.0, x1 - 2.0]:
		var spire := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.03
		cone.bottom_radius = 0.65
		cone.height = 8.0
		cone.radial_segments = 8
		spire.mesh = cone
		spire.material_override = mat
		spire.position = Vector3(sx, eave + 4.0, z1 - 1.0)
		add_child(spire)


func _boss_wall_z(x: float, z0: float, z1: float, floor_y: float, h: float,
		mat: Material) -> void:
	var sill := 3.0
	var head := 6.6
	var length := z1 - z0
	var cz := (z0 + z1) * 0.5
	_box(Vector3(0.7, sill, length), Vector3(x, floor_y + sill * 0.5, cz), mat, false)
	_box(Vector3(0.7, h - head, length), Vector3(x, floor_y + head + (h - head) * 0.5, cz), mat, false)
	var centers := [z0 + 4.0, z0 + 8.0, z0 + 12.0]
	var win := 3.2
	var cursor := z0
	for c in centers:
		var a: float = float(c) - win * 0.5
		var b: float = float(c) + win * 0.5
		if a > cursor:
			_box(Vector3(0.7, head - sill, a - cursor),
				Vector3(x, floor_y + (sill + head) * 0.5, (cursor + a) * 0.5), mat, false)
		cursor = b
	if z1 > cursor:
		_box(Vector3(0.7, head - sill, z1 - cursor),
			Vector3(x, floor_y + (sill + head) * 0.5, (cursor + z1) * 0.5), mat, false)


func _arch_band(a: Vector3, b: Vector3, mat: Material) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var length := Vector2(d.x, d.y).length()
	if length < 0.1:
		return
	var block := _box(Vector3(length, 1.0, 0.8), mid, mat, false)
	block.rotation.z = atan2(d.y, d.x)


# ---------------------------------------------------------------- 双层拱廊
func _build_arcade_facades() -> void:
	var marker := Node3D.new()
	marker.name = "DoubleArcadeFacade"
	add_child(marker)
	var mat := _warm_stone(Color(0.70, 0.70, 0.68))
	_facade_x(-4.6, -74.0, -48.0, [-69.0, -61.0, -53.0], 7.2, mat)
	_facade_x(-2.6, -31.0, -3.0, [-27.0, -17.0, -7.0], 8.0, mat)


func _facade_x(z: float, x0: float, x1: float, centers: Array, span: float,
		mat: Material) -> void:
	var base := BASE_Y
	var top := 14.72
	var depth := 1.3
	var edges: Array = []
	for c in centers:
		edges.append(float(c) - span * 0.5)
		edges.append(float(c) + span * 0.5)
	edges.sort()
	# 端柱
	for ex in [x0, x1]:
		var exists := false
		for e in edges:
			if absf(float(e) - ex) < 0.2:
				exists = true
				break
		if not exists:
			edges.append(ex)
	edges.sort()

	for e in edges:
		_box(Vector3(1.1, top - base, depth), Vector3(float(e), (base + top) * 0.5, z),
			mat, false)
		_pier_cracks(float(e), z, depth)
		for yy in [6.2, 8.7, 12.5, 14.4]:
			_box(Vector3(1.35, 0.18, depth + 0.12), Vector3(float(e), float(yy), z),
				mat, false)

	for c in centers:
		var cc := float(c)
		var spring := 12.47 - span * 0.5
		_arch_ring_x(cc, z, span * 0.5, spring, depth, mat)
		_arch_cracks(cc, z, span * 0.5, spring, depth)
		# 上层小拱
		_arch_ring_x(cc, z, span * 0.27, 12.62, depth, mat)
		# 拱心石
		_box(Vector3(0.65, 0.9, depth + 0.18),
			Vector3(cc, 12.47 + 0.35, z), mat, false)

	# 横带与顶部雉堞
	_box(Vector3(x1 - x0, 0.25, depth + 0.1),
		Vector3((x0 + x1) * 0.5, 12.5, z), mat, false)
	_box(Vector3(x1 - x0, 0.3, depth + 0.1),
		Vector3((x0 + x1) * 0.5, 14.55, z), mat, false)
	var count := int(round((x1 - x0) / 1.6))
	for i in range(count + 1):
		var mx := lerpf(x0, x1, float(i) / float(count))
		_box(Vector3(0.55, 0.55, depth + 0.15),
			Vector3(mx, 14.95, z), mat, false)

	# 拱间旗帜
	for i in range(centers.size() - 1):
		var px := (float(centers[i]) + float(centers[i + 1])) * 0.5
		_banner(px, z + depth * 0.5 + 0.08, 10.0)


func _arch_ring_x(cx: float, z: float, radius: float, spring: float,
		depth: float, mat: Material) -> void:
	var blocks := 11
	for b in range(blocks):
		var a0 := PI * float(b) / float(blocks)
		var a1 := PI * float(b + 1) / float(blocks)
		var am := (a0 + a1) * 0.5
		var seg := radius * (a1 - a0) * 1.1
		var block := _box(Vector3(seg, 0.5, depth),
			Vector3(cx + radius * cos(am), spring + radius * sin(am), z), mat, false)
		block.rotation.z = am + PI * 0.5


func _arch_cracks(cx: float, z: float, radius: float, spring: float, depth: float) -> void:
	var cm := _crack_mat()
	for k in 3:
		var a := 0.55 + float(k) * 0.78
		var px := cx + (radius + 0.02) * cos(a)
		var py := spring + (radius + 0.02) * sin(a)
		var seg := _box(Vector3(0.12, 0.85, depth + 0.07),
			Vector3(px, py, z), cm, false)
		seg.rotation.z = a + 0.3


func _pier_cracks(x: float, z: float, depth: float) -> void:
	var cm := _crack_mat()
	for k in 3:
		var yy := 6.4 + float(k) * 2.6
		var seg := _box(Vector3(0.08, 1.15, depth + 0.07),
			Vector3(x + 0.18, yy, z), cm, false)
		seg.rotation.z = -0.16 + float(k) * 0.12


func _crack_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.12, 0.03)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.22, 0.04)
	m.emission_energy_multiplier = 2.2
	m.roughness = 0.6
	return m


func _banner(x: float, z: float, y: float) -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.25, 0.035, 0.025)
	cloth.roughness = 0.95
	_box(Vector3(1.2, 3.4, 0.06), Vector3(x, y + 1.7, z), cloth, false)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.62, 0.22)
	gold.metallic = 0.5
	gold.roughness = 0.35
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 0.08
	cyl.radial_segments = 16
	disc.mesh = cyl
	disc.material_override = gold
	disc.rotation.x = PI * 0.5
	disc.position = Vector3(x, y + 2.2, z + 0.06)
	add_child(disc)


# ---------------------------------------------------------------- 栏杆
func _build_fences() -> void:
	var index := 0
	# 广场四边，留出南/北楼梯口与东/西桥口
	for seg in [
		[Vector3(-43.2, 0, -21.6), 0.0], [Vector3(-34.8, 0, -21.6), 0.0],
		[Vector3(-43.2, 0, -6.4), 0.0], [Vector3(-34.8, 0, -6.4), 0.0],
		[Vector3(-48.6, 0, -18.2), PI * 0.5], [Vector3(-48.6, 0, -9.8), PI * 0.5],
		[Vector3(-29.4, 0, -18.2), PI * 0.5], [Vector3(-29.4, 0, -9.8), PI * 0.5],
	]:
		_place_glb(FENCE_MODEL, seg[0], 1.05 / 1.193, seg[1], "Fence_%d" % index, 5.23)
		index += 1
