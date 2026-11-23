class_name Ch02MidArchitecture
extends Node3D
## 2F 涓ぎ骞垮満鐨勫熀鍙拌ˉ鍏細涓嬫柟鏀拺銆佹埧闂村洿鍚?绐椼€佹ˉ鎷便€佸箍鍦烘煴鍒椼€侀潪鎴块棿鍖烘爮鏉嗐€?
## 鍙礋璐?2F锛屼笉鍔?1F / 3F / 4F 鐨勬棦鏈夊唴瀹广€?

const FENCE_MODEL := "res://assets/chapter2/models/spooky_fence.glb"
const MAT := preload("res://scripts/chapter2/ch02_materials.gd")

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
	_door_sign(Vector3(-47.8, 12.75, -14.0), PI * 0.5, "备用小厨房")
	_door_sign(Vector3(-31.2, 12.75, -14.0), -PI * 0.5, "原料仓库")


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


# ---------------------------------------------------------------- 涓嬫柟鏀拺
func _build_supports() -> void:
	# 2F 涓嬫柟鍋氭垚杩炵画鐨勭煶鎷辨ˉ/鎷卞粖锛屽彇浠ｅ師鏉ョ殑鏂瑰ⅸ + 骞虫銆?
	_arcade_x(-6.0, -74.0, -48.0)    # 浠撳簱鍗?
	_arcade_x(-22.0, -74.0, -48.0)   # 浠撳簱鍖?
	_arcade_z(-74.0, -22.0, -6.0)    # 浠撳簱瑗?
	_arcade_x(-4.0, -31.0, -3.0)     # 鍘ㄦ埧鍗?
	_arcade_x(-24.0, -31.0, -3.0)    # 鍘ㄦ埧鍖?
	_arcade_z(-3.0, -24.0, -4.0)     # 鍘ㄦ埧涓?
	_arcade_x(-6.0, -49.0, -29.0)    # 骞垮満鍗?
	_arcade_x(-22.0, -49.0, -29.0)   # 骞垮満鍖?


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


# ---------------------------------------------------------------- 鎴块棿鍥村悎
func _build_rooms() -> void:
	# 浠撳簱锛氬寳/鍗?瑗夸笁闈㈢暀绐楋紝涓滈潰鏈濆箍鍦哄紑闂?
	_wall_x(-22.0, -74.0, -48.0, [-69.0, -61.0, -53.0], 3.2)
	_wall_x(-6.0, -74.0, -48.0, [-69.0, -61.0, -53.0], 3.2)
	_wall_z(-74.0, -22.0, -6.0, [-18.0, -10.0], 2.8)
	_wall_z_door(-48.0, -22.0, -6.0, -14.0, 4.0, 6.0)

	# 鍘ㄦ埧锛氬寳/鍗?涓滀笁闈㈢暀绐楋紝瑗块潰鏈濆箍鍦哄紑闂?
	_wall_x(-24.0, -31.0, -3.0, [-27.0, -17.0, -7.0], 3.6)
	_wall_x(-4.0, -31.0, -3.0, [-27.0, -17.0, -7.0], 3.6)
	_wall_z(-3.0, -24.0, -4.0, [-20.0, -14.0, -8.0], 3.0)
	_wall_z_door(-31.0, -24.0, -4.0, -14.0, 3.5, 6.0)


## 娌?X 鏂瑰悜鐨勫锛岀獥鎴峰湪绐楁埛涓績澶勫紑娲炪€?
func _wall_x(z: float, x0: float, x1: float, windows: Array, win_w: float) -> void:
	var length := x1 - x0
	var cx := (x0 + x1) * 0.5
	# 涓嬫銆佷笂妤?
	_box(Vector3(length, SILL, WALL_T), Vector3(cx, FLOOR_Y + SILL * 0.5, z), stone)
	var top_h := WALL_H - HEAD
	_box(Vector3(length, top_h, WALL_T), Vector3(cx, FLOOR_Y + HEAD + top_h * 0.5, z), stone)
	# 绐楅棿澧?
	var cuts: Array = []
	for wc in windows:
		cuts.append([float(wc) - win_w * 0.5, float(wc) + win_w * 0.5])
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var cursor := x0
	for cut in cuts:
		_pier_x(z, cursor, cut[0])
		cursor = cut[1]
	_pier_x(z, cursor, x1)
	# 绐楁
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


## 娌?Z 鏂瑰悜鐨勫锛岀獥鎴峰湪绐楁埛涓績澶勫紑娲炪€?
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


## 甯﹂棬娲炵殑 Z 鍚戝锛氶棬涓や晶鏁撮珮澧?+ 闂ㄦィ銆?
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
	# 闂ㄦ
	for side in [-1.0, 1.0]:
		_box(Vector3(WALL_T + 0.16, door_h, 0.14),
			Vector3(x, FLOOR_Y + door_h * 0.5, door_z + side * door_w * 0.5), stone)


# ---------------------------------------------------------------- 骞垮満鏌卞垪
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


# ---------------------------------------------------------------- GLB 宸ュ叿
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


# ---------------------------------------------------------------- 鍝ョ壒灞嬮《
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

	# 鍙屽潯灞嬮潰锛氳剨绾挎部 Z锛屽崡闈㈠氨鏄帺瀹剁湅寰楀埌鐨勫北澧欐闈?
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

	# 鍗楀寳灞卞涓夎
	for z in [z0 + 0.25, z1 - 0.25]:
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(x1 - x0, rise, 0.5)
		prism.left_to_right = 0.5
		gable.mesh = prism
		gable.material_override = roof_stone
		gable.position = Vector3(xc, eave + rise * 0.5, z)
		add_child(gable)

	# 灞嬭剨
	_box(Vector3(0.5, 0.4, z1 - z0 - 0.3),
		Vector3(xc, ridge_y + 0.05, zc), roof_stone, false)

	# 鍥涜濉?+ 灏栭《锛堟斁鍦ㄦ獝瑙掞紝鍗楅潰涔熻兘鐪嬪埌锛?
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

	# 鍗楀寳灞卞椤跺皬灏栧
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

	# 鍗楀寳灞卞锛氫笁瑙掑舰闀傜┖绐?+ 鐏扮櫧杈规锛堝彇浠ｅ師鏉ョ殑鍦嗗舰鑺辩獥锛?
	for z in [z0 + 0.02, z1 - 0.02]:
		var tri_base := eave + 3.55
		var tri_h := clampf(ridge_y - tri_base - 0.12, 1.0, 1.6)
		_tri_window_z(z, xc, tri_base, 2.6, tri_h)
		_gable_arch_z(z, xc, eave, roof_stone)

	# 澶栦晶鎵跺锛氫笢瑗夸袱渚?+ 鍖椾晶锛屽崡绔嬮潰鐣欑粰鑺辩獥鍜屽皷椤?
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


# ---------------------------------------------------------------- Boss 鍘?
func _build_boss_room() -> void:
	var marker := Node3D.new()
	marker.name = "BossHall"
	add_child(marker)
	var floor_y := 14.53
	var h := 9.5
	var center := Vector3(-39.0, floor_y, -102.0)
	var radius := 18.0
	var eave := floor_y + h
	var stone := MAT.stone(Color(0.19, 0.21, 0.24))
	var dark := MAT.dark_stone(Color(0.105, 0.11, 0.12))
	var tile := MAT.stone(Color(0.18, 0.19, 0.20))

	_boss_floor(center, radius, floor_y)

	var segments := 16
	var gap_half := deg_to_rad(22.0)
	# 鍚庡锛氫竴鍦堝疄蹇冩殫鐭冲锛屾嫳寤婂彧鏄畠鐨勬闈㈣楗?
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var mid := (a0 + a1) * 0.5
		if _in_boss_gap(mid, gap_half):
			continue
		var chord := 2.0 * radius * sin((a1 - a0) * 0.5)
		var wall := _box(Vector3(chord + 0.25, h, 0.9),
			center + Vector3(cos(mid) * (radius + 0.45), h * 0.5, sin(mid) * (radius + 0.45)),
			dark, true)
		wall.rotation.y = _ring_yaw(mid)
		# 鍩庡灈
		for k in 3:
			var t := (float(k) + 0.5) / 3.0
			var ca := lerpf(a0, a1, t)
			_box(Vector3(0.55, 0.7, 0.7),
				center + Vector3(cos(ca) * (radius + 0.4), h + 0.35, sin(ca) * (radius + 0.4)),
				stone, false)

	# 鐭虫煴
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		if _in_boss_gap(a, gap_half):
			continue
		var p := center + Vector3(cos(a) * (radius - 0.65), 0.0, sin(a) * (radius - 0.65))
		_box(Vector3(1.2, h, 1.2), p + Vector3(0, h * 0.5, 0), stone, false)
		_box(Vector3(1.8, 0.45, 1.8), p + Vector3(0, 0.22, 0), stone, false)
		_box(Vector3(1.65, 0.4, 1.65), p + Vector3(0, h - 0.2, 0), stone, false)

	# 鎷卞埜锛氭瘡涓紑闂翠竴涓崐鍦嗘嫳
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var mid := (a0 + a1) * 0.5
		if _in_boss_gap(mid, gap_half):
			continue
		_boss_ring_arch(center, radius - 0.6, mid, floor_y + 5.0, 3.0, stone)
		# 鎷遍棿鏃楀笢锛氭湞鍚戝満鍐?
		if i % 2 == 0:
			_boss_ring_banner(center, radius - 1.15, mid, floor_y + 7.4)

	# 鍗椾晶鏍囧噯鎷遍棬锛?2m 瀹斤級锛屼繚鐣欎竴绾跨啍鐐夊彛瑙嗛噹
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.015, 0.012, 0.010, 0.42)
	soot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(12):
		var a := TAU * float(i) / 12.0 + 0.13
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2.2 + 0.8 * absf(sin(float(i) * 1.4)), 4.0 + 1.8 * absf(cos(float(i) * 1.1)))
		q.mesh = qm
		q.position = center + Vector3(cos(a) * 17.15, 18.0 + 1.2 * sin(float(i) * 2.0), sin(a) * 17.15)
		q.rotation.y = atan2(-cos(a), -sin(a))
		q.material_override = soot
		add_child(q)

	# 标准 12m 入口拱门
	var portal_z := -86.0
	for sx in [-6.0, 6.0]:
		_box(Vector3(1.8, 6.0, 1.5),
			Vector3(center.x + sx, floor_y + 3.0, portal_z), stone, true)
	_arch_ring_x(center.x, portal_z, 6.0, floor_y + 6.0, 1.4, stone)
	_box(Vector3(13.2, 0.45, 1.8),
		Vector3(center.x, floor_y + 6.0, portal_z), stone, true)
	for sx in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		_box(Vector3(0.6, 0.7, 0.9),
			Vector3(center.x + sx, floor_y + 13.2, portal_z), stone, false)

	# 宸︿晶瑁呴グ鎺у埗鍙?+ 鍙伴樁
	_build_boss_console(Vector3(center.x - 11.0, floor_y, center.z + 2.0), stone, dark)

	# 娲為《閿侀摼
	var chain_mat := StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.09, 0.085, 0.08)
	chain_mat.metallic = 0.7
	chain_mat.roughness = 0.5
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.2
		var top := center + Vector3(cos(a) * 8.0, 22.0, sin(a) * 8.0)
		_boss_chain(top, top + Vector3(0, 8.0, 0), chain_mat)
	# 更高一层的交叉锁链
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.45
		var inner := center + Vector3(cos(a) * 6.0, 33.0, sin(a) * 6.0)
		var outer := center + Vector3(cos(a) * 15.0, 39.0, sin(a) * 15.0)
		_boss_chain(inner, outer, chain_mat)

	# 高空蓝雾：用大量 billboard 雾团，而不是一整块平面
	var fog := CPUParticles3D.new()
	fog.name = "BossFog"
	fog.amount = 64
	fog.lifetime = 16.0
	fog.preprocess = 14.0
	fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fog.emission_box_extents = Vector3(20.0, 8.0, 20.0)
	fog.position = center + Vector3(0, 35.0, 0)
	fog.direction = Vector3.UP
	fog.spread = 24.0
	fog.gravity = Vector3(0.0, 0.01, 0.0)
	fog.initial_velocity_min = 0.04
	fog.initial_velocity_max = 0.20
	fog.scale_amount_min = 0.8
	fog.scale_amount_max = 1.8
	var fog_mesh := QuadMesh.new()
	fog_mesh.size = Vector2(14.0, 14.0)
	fog.mesh = fog_mesh
	fog.material_override = MAT.haze_material()
	add_child(fog)
	# 伪体积光柱：高空落下的冷蓝光锥，叠在雾团上增加纵深
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.25, 0.42, 0.65, 0.045)
	shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for sx in [-9.0, 0.0, 9.0]:
		var shaft := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.25
		sc.bottom_radius = 5.5
		sc.height = 28.0
		sc.radial_segments = 20
		shaft.mesh = sc
		shaft.position = center + Vector3(sx, 27.0, -2.0)
		shaft.material_override = shaft_mat
		add_child(shaft)

	# 鍐疯摑椤跺厜 + 鏆栨鐐夊厜
	var cold := OmniLight3D.new()
	cold.position = center + Vector3(0, 24.0, 0)
	cold.light_color = Color(0.38, 0.52, 0.72)
	cold.light_energy = 3.2
	cold.omni_range = 52.0
	cold.shadow_enabled = false
	add_child(cold)
	var warm := OmniLight3D.new()
	warm.position = center + Vector3(0, 3.5, -7.0)
	warm.light_color = Color(1.0, 0.40, 0.13)
	warm.light_energy = 3.0
	warm.omni_range = 28.0
	warm.shadow_enabled = false
	add_child(warm)


func _in_boss_gap(angle: float, half: float) -> bool:
	return absf(wrapf(angle - PI * 0.5, -PI, PI)) < half


func _ring_yaw(angle: float) -> float:
	var tangent := Vector3(-sin(angle), 0.0, cos(angle))
	return atan2(-tangent.z, tangent.x)


func _boss_floor(center: Vector3, radius: float, floor_y: float) -> void:
	var stone := MAT.floor_stone(Color(0.40, 0.38, 0.34))
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.08
	disc.radial_segments = 48
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = disc
	floor_mesh.scale = Vector3(radius, 1.0, radius)
	floor_mesh.position = center + Vector3(0, 0.02, 0)
	floor_mesh.material_override = stone
	add_child(floor_mesh)

	# 鏀惧皠鐮栫紳 + 鍚屽績鐜?
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(0.08, 0.07, 0.06)
	line.roughness = 1.0
	for i in range(16):
		var a := TAU * float(i) / 16.0
		var seg := _box(Vector3(radius - 1.2, 0.02, 0.07),
			center + Vector3(cos(a) * (radius - 1.2) * 0.5, 0.08, sin(a) * (radius - 1.2) * 0.5),
			line, false)
		seg.rotation.y = a
	for r in [5.0, 9.0, 13.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = r - 0.045
		torus.outer_radius = r + 0.045
		torus.rings = 48
		torus.ring_segments = 4
		ring.mesh = torus
		ring.position = center + Vector3(0, 0.09, 0)
		ring.material_override = line
		add_child(ring)

	# 不规则石板：覆盖掉过于干净的放射线地面
	var slab_colors := [Color(0.23, 0.21, 0.18), Color(0.27, 0.24, 0.20),
			Color(0.20, 0.19, 0.17), Color(0.30, 0.26, 0.21)]
	for ring_i in range(4):
		var rr := 4.0 + float(ring_i) * 3.2
		var count := 8 + ring_i * 2
		for i in range(count):
			var a := TAU * float(i) / float(count) + float(ring_i) * 0.31
			var x := cos(a) * rr
			var z := sin(a) * rr
			if absf(x) < 1.4:
				continue
			var size := Vector3(1.1 + 0.7 * absf(sin(float(i) * 1.7)),
				0.035, 0.9 + 0.55 * absf(cos(float(i) * 1.3)))
			var slab := _box(size, center + Vector3(x, 0.115, z),
				_warm_stone(slab_colors[(i + ring_i) % slab_colors.size()]), false)
			slab.rotation.y = a + 0.35 * sin(float(i) * 2.2)

	# 杈圭紭鐏拌壊鐏北宀╃鐭筹紝閬垮厤鍦嗗舰鍦哄湴鏄惧緱澶┖
	var rubble_mat := _warm_stone(Color(0.23, 0.215, 0.20))
	for i in range(10):
		var a := TAU * float(i) / 10.0 + 0.23
		var rr := 13.4 + 0.5 * sin(float(i) * 2.1)
		var b := _box(Vector3(1.4 + 0.5 * sin(float(i)), 0.65 + 0.35 * cos(float(i) * 1.3), 1.0),
			center + Vector3(cos(a) * rr, 0.4, sin(a) * rr), rubble_mat, false)
		b.rotation.y = a + 0.4

	# 涓ぎ鐔斿博娌燂細瑙嗚涓婂嚬涓嬪幓锛屽疄闄呬笉鏀瑰湴鏉跨鎾?
	var trench := _box(Vector3(1.8, 0.02, 28.0),
		center + Vector3(0, 0.10, 0), line, false)
	trench.rotation.y = 0.0
	var lava := MeshInstance3D.new()
	var lmesh := BoxMesh.new()
	lmesh.size = Vector3(1.5, 0.025, 27.4)
	lava.mesh = lmesh
	lava.position = center + Vector3(0, 0.12, 0)
	lava.material_override = MAT.lava_pool()
	add_child(lava)
	for sx in [-1.15, 1.15]:
		_box(Vector3(0.4, 0.35, 28.0),
			center + Vector3(sx, 0.30, 0), MAT.stone(Color(0.22, 0.20, 0.18)), false)
	# 熔岩沟两侧的破碎石块，打掉直边
	for side in [-1.0, 1.0]:
		for i in range(14):
			var z := -13.0 + float(i) * 2.0 + 0.3 * sin(float(i) * 1.7)
			var x: float = side * (1.5 + 0.5 * absf(sin(float(i) * 2.1)))
			var rock := _box(Vector3(0.55 + 0.4 * absf(cos(float(i))),
				0.35 + 0.3 * absf(sin(float(i) * 1.3)), 0.7 + 0.4 * absf(sin(float(i) * 2.7))),
				center + Vector3(x, 0.30, z), MAT.dark_stone(Color(0.16, 0.14, 0.13)), false)
			rock.rotation.y = float(i) * 0.7
	# 涓夊潡鍙俯鏂煶
	for z in [-8.0, 0.0, 8.0]:
		_box(Vector3(2.5, 0.14, 1.2),
			center + Vector3(0, 0.38, z), MAT.stone(Color(0.34, 0.30, 0.25)), false)


func _boss_ring_arch(center: Vector3, radius: float, angle: float,
		spring: float, arch_r: float, mat: Material) -> void:
	var root := Node3D.new()
	var tangent := Vector3(-sin(angle), 0.0, cos(angle)).normalized()
	var zaxis := tangent.cross(Vector3.UP)
	root.transform = Transform3D(Basis(tangent, Vector3.UP, zaxis),
		center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	add_child(root)
	var blocks := 11
	for b in range(blocks):
		var t0 := PI * float(b) / float(blocks)
		var t1 := PI * float(b + 1) / float(blocks)
		var tm := (t0 + t1) * 0.5
		var seg := arch_r * (t1 - t0) * 1.15
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(seg, 0.5, 0.9)
		mi.mesh = bm
		mi.position = Vector3(arch_r * cos(tm), spring + arch_r * sin(tm), 0)
		mi.rotation.z = tm + PI * 0.5
		mi.material_override = mat
		root.add_child(mi)


func _boss_ring_banner(center: Vector3, radius: float, angle: float, y: float) -> void:
	var cloth := MAT.cloth(Color(0.25, 0.035, 0.025))
	var b := _box(Vector3(1.5, 3.8, 0.06),
		center + Vector3(cos(angle) * radius, y, sin(angle) * radius), cloth, false)
	b.rotation.y = _ring_yaw(angle)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.62, 0.22)
	gold.metallic = 0.5
	gold.roughness = 0.3
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = 0.07
	disc.mesh = cyl
	disc.rotation.x = PI * 0.5
	disc.position = center + Vector3(cos(angle) * (radius - 0.08), y + 1.0, sin(angle) * (radius - 0.08))
	disc.material_override = gold
	add_child(disc)


func _boss_chain(a: Vector3, b: Vector3, mat: Material) -> void:
	var length := a.distance_to(b)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = length
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.position = (a + b) * 0.5
	mi.material_override = mat
	add_child(mi)
	for i in range(1, 8):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.16
		torus.outer_radius = 0.25
		torus.rings = 12
		torus.ring_segments = 5
		ring.mesh = torus
		ring.position = a.lerp(b, float(i) / 8.0)
		ring.rotation.x = PI * 0.5
		ring.material_override = mat
		add_child(ring)


func _build_boss_console(base: Vector3, stone: Material, dark: Material) -> void:
	var brass := MAT.brass()
	var iron := MAT.iron()
	var porcelain := StandardMaterial3D.new()
	porcelain.albedo_color = Color(0.82, 0.76, 0.62)
	porcelain.roughness = 0.5
	# 石台与踏步
	_box(Vector3(6.0, 0.7, 3.4), base + Vector3(0, 0.35, 0), stone, true)
	for i in 3:
		_box(Vector3(0.9, 0.25, 0.8), base + Vector3(-2.4 + i * 0.9, 0.12, -1.8),
			stone, false)
	# 铸铁台体 + 黄铜台面
	_box(Vector3(4.6, 0.75, 1.7), base + Vector3(0, 1.0, 0), iron, true)
	var top := _box(Vector3(4.8, 0.12, 1.8), base + Vector3(0, 1.43, 0), brass, false)
	top.rotation.x = -0.08
	for sx in [-2.0, 2.0]:
		_box(Vector3(0.22, 1.1, 0.22), base + Vector3(sx, 0.55, -1.05), iron, false)
	# 仪表：黄铜外圈 + 深色表盘
	for sx in [-1.5, 0.0, 1.5]:
		var bezel := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.4
		bc.bottom_radius = 0.4
		bc.height = 0.12
		bc.radial_segments = 20
		bezel.mesh = bc
		bezel.rotation.x = PI * 0.5
		bezel.position = base + Vector3(sx, 1.72, -0.7)
		bezel.material_override = brass
		add_child(bezel)
		var face := MeshInstance3D.new()
		var fc := CylinderMesh.new()
		fc.top_radius = 0.3
		fc.bottom_radius = 0.3
		fc.height = 0.14
		fc.radial_segments = 20
		face.mesh = fc
		face.rotation.x = PI * 0.5
		face.position = base + Vector3(sx, 1.72, -0.65)
		face.material_override = porcelain
		add_child(face)
	# 拉杆与手轮
	for sx in [-1.9, 1.9]:
		_box(Vector3(0.12, 1.0, 0.12), base + Vector3(sx, 1.9, 0.45), brass, false)
		var knob := MeshInstance3D.new()
		var ks := SphereMesh.new()
		ks.radius = 0.16
		ks.height = 0.3
		knob.mesh = ks
		knob.position = base + Vector3(sx, 2.42, 0.45)
		knob.material_override = brass
		add_child(knob)
	# 控制台接出的两根粗管
	for sx in [-2.3, 2.3]:
		var pipe := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.16
		pc.bottom_radius = 0.16
		pc.height = 2.2
		pipe.mesh = pc
		pipe.rotation.z = PI * 0.5
		pipe.position = base + Vector3(sx, 0.7, -1.3)
		pipe.material_override = iron
		add_child(pipe)
		var flange := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.3
		fm.bottom_radius = 0.3
		fm.height = 0.12
		fm.radial_segments = 16
		flange.mesh = fm
		flange.rotation.z = PI * 0.5
		flange.position = base + Vector3(sx * 0.72, 0.7, -1.3)
		flange.material_override = brass
		add_child(flange)
	# 铭牌 + 铆钉
	_box(Vector3(2.3, 0.4, 0.06), base + Vector3(0, 1.62, 0.92), brass, false)
	for sx in [-1.0, -0.55, 0.55, 1.0]:
		var bolt := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.07
		bs.height = 0.12
		bolt.mesh = bs
		bolt.position = base + Vector3(sx, 1.62, 0.99)
		bolt.material_override = iron
		add_child(bolt)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimHei", "SimSun"])
	var plate := Label3D.new()
	plate.text = "主炉控制台"
	plate.font = font
	plate.font_size = 56
	plate.pixel_size = 0.006
	plate.modulate = Color(0.92, 0.72, 0.32)
	plate.outline_size = 10
	plate.outline_modulate = Color(0.05, 0.03, 0.01)
	plate.position = base + Vector3(0, 1.62, 0.96)
	add_child(plate)


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


# ---------------------------------------------------------------- 鍙屽眰鎷卞粖
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
	# 绔煴
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
		# 涓婂眰灏忔嫳
		_arch_ring_x(cc, z, span * 0.27, 12.62, depth, mat)
		# 鎷卞績鐭?
		_box(Vector3(0.65, 0.9, depth + 0.18),
			Vector3(cc, 12.47 + 0.35, z), mat, false)

	# 妯甫涓庨《閮ㄩ泬鍫?
	_box(Vector3(x1 - x0, 0.25, depth + 0.1),
		Vector3((x0 + x1) * 0.5, 12.5, z), mat, false)
	_box(Vector3(x1 - x0, 0.3, depth + 0.1),
		Vector3((x0 + x1) * 0.5, 14.55, z), mat, false)
	var count := int(round((x1 - x0) / 1.6))
	for i in range(count + 1):
		var mx := lerpf(x0, x1, float(i) / float(count))
		_box(Vector3(0.55, 0.55, depth + 0.15),
			Vector3(mx, 14.95, z), mat, false)

	# 鎷遍棿鏃楀笢
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
	var cloth := MAT.cloth(Color(0.25, 0.035, 0.025))
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


# ---------------------------------------------------------------- 鏍忔潌
func _build_fences() -> void:
	var index := 0
	# 骞垮満鍥涜竟锛岀暀鍑哄崡/鍖楁ゼ姊彛涓庝笢/瑗挎ˉ鍙?
	for seg in [
		[Vector3(-43.2, 0, -21.6), 0.0], [Vector3(-34.8, 0, -21.6), 0.0],
		[Vector3(-43.2, 0, -6.4), 0.0], [Vector3(-34.8, 0, -6.4), 0.0],
		[Vector3(-48.6, 0, -18.2), PI * 0.5], [Vector3(-48.6, 0, -9.8), PI * 0.5],
		[Vector3(-29.4, 0, -18.2), PI * 0.5], [Vector3(-29.4, 0, -9.8), PI * 0.5],
	]:
		_place_glb(FENCE_MODEL, seg[0], 1.05 / 1.193, seg[1], "Fence_%d" % index, 5.23)
		index += 1

