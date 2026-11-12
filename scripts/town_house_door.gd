extends Node3D
## 圣诞小镇「可进入房屋」：GLB 房屋是烘焙的封闭壳体，门只是墙上的贴图。
## 统一新建实体木门，开门方式照 ice_castle.gd 的冰城堡双扇滑门：
##   * 两扇 BoxMesh 门扇各占半宽，开门时分别向左右平移滑开，始终正对玩家；
##   * 门框 / 门挡 / 触发区全部以「真实外墙平面」_wall_d 为基准，
##     不能用 AABB 面（墙面向内缩约 1m，用 AABB 面会让门浮在墙外、中间能钻进去）；
##   * 墙体只在门矩形里挖真门洞，用挖空后的网格生成贴合碰撞。
## 唯一阻挡是冰城堡同款 DoorBlock：关门时把门洞完全封住，开门过半才禁用。

const DOOR_W := 2.6
const DOOR_H := 3.2
const CUT_IN := 8.0        # 门洞向屋内挖的深度（GLB 房屋是双层壁，必须挖穿）
const CUT_OUT := 1.2       # 向外多挖，清掉门口凸出的雪堆/台阶
const OPEN_SPEED := 2.0
const LEAF_T := 0.16       # 门扇厚度
const FRAME_W := 0.20      # 门框宽度
const FRAME_T := 0.16      # 门框厚度（沿墙法线，贴墙不凸出）
const SLIDE_GAP := 0.15    # 滑开后与门框的间隙
const NEAR_DIST := 5.5     # 距离兜底：玩家离门多近可按 F

var _side := "S"
var _outward := Vector3(0, 0, -1)       # 真实墙面的水平法线（斜墙会偏离世界轴）
var _horiz := Vector3(1, 0, 0)          # 沿墙面的切向，门扇沿它滑开
var _axis_outward := Vector3(0, 0, -1)  # 世界轴法线，仅用于挖洞的轴对齐 AABB
var _axis_horiz := Vector3(1, 0, 0)     # 世界轴切向，仅用于挖洞
var _yaw := 0.0                          # 真实墙面相对世界轴的偏角
var _center := Vector3.ZERO      # 真实外墙平面上的门中心（世界坐标）
var _hinge := Vector3.ZERO
var _wall_d := 0.0               # AABB 面 -> 真实外墙的位移，供诊断
var _door_w := DOOR_W
var _door_h := DOOR_H
var _half_w := DOOR_W * 0.5      # 单扇门宽
var _uv_override: Array = []
var _open_angle := 1.7
var _pivot: Node3D
var _leaf: MeshInstance3D
var _sliders: Array[Node3D] = []
var _slide_base := Vector3.ZERO  # 两扇门共用的墙面基准点
var _block: CollisionShape3D
var _hint: Label3D
var _near := false
var _area_near := false
var _open := false
var _open_t := 0.0
var _player: Node3D
var _mat_cache: Dictionary = {}


## w/h 可逐栋覆盖：拱门（037）外面一圈白色石框是独立立体几何，
## 收窄门扇范围才不会连石框、红白柱一起裁成门板。
func configure(house: MeshInstance3D, side: String, offset: float,
		w := 0.0, h := 0.0, uv: Array = []) -> void:
	_side = side
	_door_w = w if w > 0.0 else DOOR_W
	_door_h = h if h > 0.0 else DOOR_H
	# uv = [u0, v_top, u1, v_bottom]：逐栋指定图集里那扇门的矩形，
	# 用于 UV 仿射选错三角形时纠偏
	if uv.size() == 4:
		var u0 := float(uv[0])
		var vt := float(uv[1])
		var u1 := float(uv[2])
		var vb := float(uv[3])
		_uv_override = [Vector2(u0, vt), Vector2(u1, vt),
				Vector2(u1, vb), Vector2(u0, vb)]
	var wb: AABB = house.global_transform * house.get_aabb()
	var cx: float = wb.position.x + wb.size.x * 0.5
	var cz: float = wb.position.z + wb.size.z * 0.5
	match side:
		"S":
			cz = wb.position.z
			_outward = Vector3(0, 0, -1)
			_horiz = Vector3(1, 0, 0)
			_open_angle = 1.7
		"N":
			cz = wb.position.z + wb.size.z
			_outward = Vector3(0, 0, 1)
			_horiz = Vector3(1, 0, 0)
			_open_angle = -1.7
		"W":
			cx = wb.position.x
			_outward = Vector3(-1, 0, 0)
			_horiz = Vector3(0, 0, 1)
			_open_angle = -1.7
		"E":
			cx = wb.position.x + wb.size.x
			_outward = Vector3(1, 0, 0)
			_horiz = Vector3(0, 0, 1)
			_open_angle = 1.7
	_axis_outward = _outward
	_axis_horiz = _horiz
	_center = Vector3(cx, 0.0, cz) + _horiz * offset
	_hinge = _center - _horiz * (_door_w * 0.5)

	var hole := _region(-CUT_IN, CUT_OUT)
	_split_native_door(house, hole)
	_build_door_block()
	_build_interior(wb)
	_build_trigger()
	_build_hint()
	set_process(true)


## 以门中心为原点，沿「墙面横向」和「墙法线」构造世界轴对齐区域。
## nlo/nhi 是沿 outward 的距离：负值进屋，正值出屋。
func _region(nlo: float, nhi: float) -> AABB:
	var a := _center + _axis_outward * nlo - _axis_horiz * (_door_w * 0.5)
	var b := _center + _axis_outward * nhi + _axis_horiz * (_door_w * 0.5)
	# 洞口高度严格等于门扇高度，避免上下留出「一大块空的」缝
	var lo := Vector3(minf(a.x, b.x), 0.0, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), _door_h, maxf(a.z, b.z))
	return AABB(lo, hi - lo)


## 墙网格：只在门扇矩形里挖出真门洞，其余墙 / 柱 / 石框 / 屋顶一个三角形都不动。
## 门板：用墙面三角形的 UV 仿射反算出「原贴图里那一块门」的 UV 矩形，
## 生成一块只显示原门的平面。关门时门完整可见，开门时只有它转开。
func _split_native_door(house: MeshInstance3D, hole: AABB) -> void:
	var am := house.mesh as ArrayMesh
	if am == null:
		return
	var gt := house.global_transform
	# AABB 面往往不等于真实墙面（房屋被烘焙旋转 / 墙面内缩）。
	# 先把门中心从 AABB 面平移到真实外墙平面；之后门框 / 门扇 / 门挡 /
	# 触发区全部以这个 _center 为基准，门才不会浮在墙外、旁边留出能钻进去的缝。
	# 挖洞的世界范围保持不变：旧式 _region(d_wall-CUT_IN, d_wall+CUT_OUT)
	# 与新式（中心前移 d_wall 后）_region(-CUT_IN, CUT_OUT) 完全等价。
	var d_wall := _detect_wall_plane(am, gt)
	var wall_n := _detect_wall_normal(am, gt, d_wall)
	_wall_d = d_wall
	_center += _axis_outward * d_wall
	# 房屋被烘焙旋转时墙是斜的：把整组门构件按墙面法线转过去，
	# 门扇才不会一端嵌进墙、另一端浮在墙外（035 就是 30° 斜墙）。
	_yaw = _axis_outward.signed_angle_to(wall_n, Vector3.UP)
	# 只有明显斜墙才转：小角度多半是雪堆/装饰斜面带来的噪声，
	# 转了反而会让门洞与轴对齐碰撞错开，玩家进不去。
	if absf(_yaw) < 0.6:
		_yaw = 0.0
		wall_n = _axis_outward
	_outward = wall_n
	_horiz = _axis_horiz.rotated(Vector3.UP, _yaw)
	_hinge = _center - _horiz * (_door_w * 0.5)
	# 斜门扇在世界轴上的投影要仍等于轴对齐门洞宽，否则两侧会露缝
	_half_w = _door_w * 0.5 / maxf(cos(_yaw), 0.7)
	hole = _region(-CUT_IN, CUT_OUT)
	var wall_out := ArrayMesh.new()
	var wall_mat: Material = null
	var cut := 0
	for s in am.get_surface_count():
		var arrays := am.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var mat := am.surface_get_material(s)
		if mat == null:
			mat = house.get_active_material(s)
		if wall_mat == null and mat != null:
			wall_mat = mat
		var sw := SurfaceTool.new()
		sw.begin(Mesh.PRIMITIVE_TRIANGLES)
		if mat != null:
			sw.set_material(mat)
		var count: int = idx.size() if idx.size() > 0 else verts.size()
		var t := 0
		while t + 2 < count:
			var poly: Array = []
			for j in 3:
				var id: int = idx[t + j] if idx.size() > 0 else t + j
				var lp: Vector3 = verts[id]
				poly.append({
					"w": gt * lp,
					"l": lp,
					"uv": uvs[id] if uvs.size() > id else Vector2.ZERO,
					"n": norms[id].normalized() if norms.size() > id else Vector3.UP,
				})
			var w0: Vector3 = poly[0]["w"]
			var w1: Vector3 = poly[1]["w"]
			var w2: Vector3 = poly[2]["w"]
			var tri_box := AABB(w0, Vector3.ZERO).expand(w1).expand(w2)
			# 门洞里的雪堆 / 台阶 / 内壁一起挖通，否则玩家会被残留几何卡住；
			# 柱子和石框在门扇矩形之外，与 hole 不相交，原样留在墙上一动不动。
			if not tri_box.intersects(hole):
				_emit(sw, poly, Vector3.ZERO, false)
			else:
				cut += 1
				for part in _clip_outside(poly, hole):
					_emit(sw, part, Vector3.ZERO, false)
			t += 3
		sw.commit(wall_out)
	house.mesh = wall_out
	# 挖空后的网格直接生成贴合碰撞，不再用错位的轴对齐盒墙
	house.create_trimesh_collision()
	_build_modeled_door()
	print("TOWN_NATIVE_DOOR|%s|%s|cy=%.3f wall=%.2f yaw=%.2f cut=%d" % [
		String(house.name).substr(0, 8), _side, _center.y, d_wall, _yaw, cut])


## 参考 ice_castle.gd::_build_door：两扇实体 BoxMesh 门扇各占半宽，
## 开门时分别向左右平移滑开，门扇始终贴在真实外墙平面上。
## 门扇只做可视几何：实测移动中的 AnimatableBody3D 物理形状不会跟着
## slider 更新，开门后旧形状仍堵在门洞里。与冰城堡一致，阻挡统一交给
## DoorBlock；关门时两扇正好拼满门洞，静态门框永远不动。
## 方案②最开始的建模木门：棕色木门扇 + 门框 + 分格 + 把手，两扇左右滑开。
## 不贴任何反算贴图，全部用建模几何，外观统一可控。
func _build_modeled_door() -> void:
	var wood := _mat(Color(0.40, 0.22, 0.12))
	var trim := _mat(Color(0.58, 0.34, 0.18))
	var metal := _mat(Color(0.88, 0.70, 0.32), 0.12)
	var frame := _mat(Color(0.66, 0.60, 0.50))
	var axis_sn := _side == "S" or _side == "N"
	var fw := FRAME_W
	# 门套（框/楣）外表面与墙外表面齐平：中心向墙内收半个厚度，
	# 不再向外凸出，否则从侧面看门框会浮在深门洞之前。
	var fp_base := _center - _outward * (FRAME_T * 0.5)

	# 静态门框：左右柱 + 门楣，贴在外墙平面上，开门时和墙、石拱框一样不动
	for i in range(2):
		var s: float = -1.0 if i == 0 else 1.0
		var fp: Vector3 = fp_base + _horiz * (s * (_half_w + fw * 0.5)) \
				+ Vector3.UP * ((_door_h + fw) * 0.5)
		var fs: Vector3 = Vector3(fw, _door_h + fw, FRAME_T) if axis_sn \
				else Vector3(FRAME_T, _door_h + fw, fw)
		_box(self, "DoorFrame%s" % ("L" if s < 0.0 else "R"), fs, fp, frame)
	var lp: Vector3 = fp_base + Vector3.UP * (_door_h + fw * 0.5)
	var ls: Vector3 = Vector3(_door_w + fw * 2.0, fw, FRAME_T) if axis_sn \
			else Vector3(FRAME_T, fw, _door_w + fw * 2.0)
	_box(self, "DoorLintel", ls, lp, frame)

	# 门扇外表面与墙外表面齐平（中心向墙内收半个厚度），关门时嵌在洞口
	# 外缘、不向外凸，从侧面看是落在墙洞里的门，而不是浮在洞前的薄片。
	_slide_base = _center - _outward * (LEAF_T * 0.5) \
			+ Vector3.UP * (_door_h * 0.5)
	var leaf_size: Vector3 = Vector3(_half_w, _door_h, LEAF_T) if axis_sn \
			else Vector3(LEAF_T, _door_h, _half_w)
	var face := _outward * (LEAF_T * 0.5)
	for i in 2:
		var sl: float = -1.0 if i == 0 else 1.0
		var slider := Node3D.new()
		slider.name = "DoorSliderL" if i == 0 else "DoorSliderR"
		add_child(slider)
		slider.position = _slide_base + _horiz * (sl * _half_w * 0.5)
		_sliders.append(slider)

		var leaf := MeshInstance3D.new()
		leaf.name = "DoorLeafL" if i == 0 else "DoorLeafR"
		var bm := BoxMesh.new()
		bm.size = leaf_size
		leaf.mesh = bm
		leaf.material_override = wood
		slider.add_child(leaf)

		# 分格与把手是门扇子节点，随门一起滑动，只贴朝外的那一面
		for row in 3:
			var py: float = -leaf_size.y * 0.5 + leaf_size.y * (float(row) + 0.5) / 3.0
			var ps: Vector3 = Vector3(_half_w - 0.26, 0.09, 0.05) if axis_sn \
					else Vector3(0.05, 0.09, _half_w - 0.26)
			_box(leaf, "Panel%d" % row, ps, face + Vector3.UP * py, trim)
		_sphere(leaf, "Handle", Vector3(0.24, 0.24, 0.24),
				face * 1.5 + _horiz * (-sl * (_half_w * 0.5 - 0.24)), metal)

		# 不生成门扇碰撞：移动中的物理形状不会同步，开门后会残留一堵隐形墙。
		# 关门封洞由 DoorBlock 负责（见 _build_door_block）。


## 统计门区域附近「朝外的竖直面」沿墙法线的分布，取三角形最多的那层作为外墙。
func _detect_wall_plane(am: ArrayMesh, gt: Transform3D) -> float:
	var bins: Dictionary = {}
	for s in am.get_surface_count():
		var arrays := am.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count: int = idx.size() if idx.size() > 0 else verts.size()
		var t := 0
		while t + 2 < count:
			var i0: int = idx[t] if idx.size() > 0 else t
			var i1: int = idx[t + 1] if idx.size() > 0 else t + 1
			var i2: int = idx[t + 2] if idx.size() > 0 else t + 2
			var p0 := gt * verts[i0]
			var p1 := gt * verts[i1]
			var p2 := gt * verts[i2]
			var c := (p0 + p1 + p2) / 3.0
			if absf((c - _center).dot(_axis_horiz)) > _door_w * 0.85:
				t += 3
				continue
			if c.y < 0.0 or c.y > _door_h * 1.15:
				t += 3
				continue
			var n := (p1 - p0).cross(p2 - p0)
			if n.length() < 0.000001 or absf(n.normalized().dot(_axis_outward)) < 0.45:
				t += 3
				continue
			var d: float = (c - _center).dot(_axis_outward)
			# 只要 AABB 面附近的这一侧外墙，别把屋子对面的墙当成门面
			if d < -3.5 or d > 2.0:
				t += 3
				continue
			var key := int(round(d / 0.1))
			bins[key] = int(bins.get(key, 0)) + 1
			t += 3
	var best_key := 0
	var best_count := 0
	for k in bins.keys():
		var v: int = bins[k]
		if v > best_count or (v == best_count and k > best_key):
			best_count = v
			best_key = k
	return float(best_key) * 0.1


## 取外墙那一层里竖直面的平均水平法线，得到被烘焙旋转过的斜墙真实朝向。
func _detect_wall_normal(am: ArrayMesh, gt: Transform3D, d_wall: float) -> Vector3:
	var sum := Vector3.ZERO
	var cnt := 0
	for s in am.get_surface_count():
		var arrays := am.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count: int = idx.size() if idx.size() > 0 else verts.size()
		var t := 0
		while t + 2 < count:
			var i0: int = idx[t] if idx.size() > 0 else t
			var i1: int = idx[t + 1] if idx.size() > 0 else t + 1
			var i2: int = idx[t + 2] if idx.size() > 0 else t + 2
			var p0 := gt * verts[i0]
			var p1 := gt * verts[i1]
			var p2 := gt * verts[i2]
			var c := (p0 + p1 + p2) / 3.0
			t += 3
			if absf((c - _center).dot(_axis_horiz)) > _door_w * 0.85:
				continue
			if c.y < 0.2 or c.y > _door_h * 1.05:
				continue
			if absf((c - _center).dot(_axis_outward) - d_wall) > 0.6:
				continue
			var n := (p1 - p0).cross(p2 - p0)
			if n.length() < 0.000001:
				continue
			n = n.normalized()
			if absf(n.y) > 0.5:
				continue
			if n.dot(_axis_outward) < 0.0:
				n = -n
			sum += Vector3(n.x, 0.0, n.z)
			cnt += 1
	if cnt == 0:
		return _axis_outward
	var h := Vector3(sum.x, 0.0, sum.z)
	if h.length() < 0.001 or h.normalized().dot(_axis_outward) < 0.6:
		return _axis_outward
	return h.normalized()


func _emit(st: SurfaceTool, poly: Array, origin: Vector3, use_world: bool) -> int:
	if poly.size() < 3:
		return 0
	var added := 0
	for k in range(1, poly.size() - 1):
		for j in [0, k, k + 1]:
			var v: Dictionary = poly[j]
			st.set_normal(v["n"])
			st.set_uv(v["uv"])
			if use_world:
				var w: Vector3 = v["w"]
				st.add_vertex(w - origin)
			else:
				st.add_vertex(v["l"])
		added += 1
	return added


func _clip_inside(poly: Array, box: AABB) -> Array:
	var p := poly
	var lo := box.position
	var hi := box.position + box.size
	for axis in 3:
		if p.size() < 3:
			return []
		p = _clip_half(p, axis, lo[axis], true)
		p = _clip_half(p, axis, hi[axis], false)
	return p


## 凸多边形减去凸盒：按 6 个半空间逐层剥离，得到 <=6 个互不重叠的凸块。
func _clip_outside(poly: Array, box: AABB) -> Array:
	var parts: Array = []
	var cur := poly
	var lo := box.position
	var hi := box.position + box.size
	for axis in 3:
		if cur.size() < 3:
			break
		var outer := _clip_half(cur, axis, lo[axis], false)
		if outer.size() >= 3:
			parts.append(outer)
		cur = _clip_half(cur, axis, lo[axis], true)
		if cur.size() < 3:
			break
		outer = _clip_half(cur, axis, hi[axis], true)
		if outer.size() >= 3:
			parts.append(outer)
		cur = _clip_half(cur, axis, hi[axis], false)
	return parts


func _clip_half(poly: Array, axis: int, value: float, keep_greater: bool) -> Array:
	var out: Array = []
	var n := poly.size()
	for i in n:
		var a: Dictionary = poly[i]
		var b: Dictionary = poly[(i + 1) % n]
		var aw: Vector3 = a["w"]
		var bw: Vector3 = b["w"]
		var da: float = aw[axis] - value
		var db: float = bw[axis] - value
		var ina: bool = da >= 0.0 if keep_greater else da <= 0.0
		var inb: bool = db >= 0.0 if keep_greater else db <= 0.0
		if ina:
			out.append(a)
		if ina != inb:
			out.append(_lerp_vertex(a, b, da / (da - db)))
	return out


func _lerp_vertex(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var aw: Vector3 = a["w"]
	var bw: Vector3 = b["w"]
	var al: Vector3 = a["l"]
	var bl: Vector3 = b["l"]
	var au: Vector2 = a["uv"]
	var bu: Vector2 = b["uv"]
	var an: Vector3 = a["n"]
	var bn: Vector3 = b["n"]
	return {
		"w": aw.lerp(bw, t),
		"l": al.lerp(bl, t),
		"uv": au.lerp(bu, t),
		"n": an.lerp(bn, t).normalized(),
	}


## 门挡是冰城堡 DoorBlock 的同款兜底：关门时封住门洞，开门过半才禁用。
## 尺寸略大于门洞，边缘压在墙上，避免胶囊从门框与墙之间的缝里挤进去。
func _build_door_block() -> void:
	var body := StaticBody3D.new()
	body.name = "DoorBlockBody"
	add_child(body)
	var bs := BoxShape3D.new()
	# 只封「门洞截面」这一片，尺寸略大于洞口：关门堵死任何方向，
	# 开门整片禁用后内外畅通。不做成长条——长条会延伸到屋内，把进屋的
	# 玩家包在实心块里，反而造成「进得去出不来」。
	if _side == "S" or _side == "N":
		bs.size = Vector3(_door_w + 0.3, _door_h + 0.3, 0.7)
	else:
		bs.size = Vector3(0.7, _door_h + 0.3, _door_w + 0.3)
	_block = CollisionShape3D.new()
	_block.name = "DoorBlock"
	_block.shape = bs
	_block.position = _center + Vector3.UP * (_door_h * 0.5)
	body.add_child(_block)


func _mat(c: Color, emission := 0.0) -> Material:
	var key: String = "%s_%.2f" % [c.to_html(), emission]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.78
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m


func _box(parent: Node3D, nm: String, size: Vector3,
		pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, nm: String, sz: Vector3,
		pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	mi.scale = sz
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_interior(wb: AABB) -> void:
	var cx: float = wb.position.x + wb.size.x * 0.5
	var cz: float = wb.position.z + wb.size.z * 0.5
	var floorc := _mat(Color(0.42, 0.28, 0.17))
	var wood := _mat(Color(0.36, 0.22, 0.12))
	var stone := _mat(Color(0.52, 0.50, 0.46))
	var rugc := _mat(Color(0.52, 0.11, 0.12))
	var flame := _mat(Color(1.0, 0.55, 0.18), 1.2)
	var green := _mat(Color(0.09, 0.34, 0.16))
	var warm := _mat(Color(0.92, 0.72, 0.34), 0.35)
	# 桌子/地毯别正对门洞：从外面看会像「开了门里面还有一扇棕色门板」。
	# 沿墙面横向挪到侧后方，门洞正中让出通道。
	var shift := -_outward * 1.0 + _axis_horiz * 1.7

	# 房屋 AABB 包含门廊、烟囱等凸出物，直接用 wb.size-2 会让棕色地板
	# 大片伸出屋外（034 实测玩家站在屋外地板上）。收一半并居中，
	# 保证地板只铺在墙体内部。
	_box(self, "IndoorFloor", Vector3(wb.size.x * 0.5, 0.08, wb.size.z * 0.5),
		Vector3(cx, 0.04, cz), floorc)
	_box(self, "Rug", Vector3(3.6, 0.03, 2.6), Vector3(cx, 0.09, cz + 0.6) + shift, rugc)
	_box(self, "IndoorTable", Vector3(2.2, 0.16, 1.0),
		Vector3(cx, 1.02, cz) + shift, wood)
	for si in [-1.0, 1.0]:
		var s: float = si
		_box(self, "IndoorBench%s" % int(s * 10), Vector3(2.2, 0.14, 0.44),
			Vector3(cx, 0.58, cz + s * 0.9) + shift, wood)
	# 壁炉要放在门的正对面：否则从门口望进去会像「门洞里还有一扇灰门」
	var fp := Vector3(cx, 1.05, wb.position.z + wb.size.z - 1.0)
	var foff := Vector3(0, 0, -0.34)
	match _side:
		"N":
			fp.z = wb.position.z + 1.0
			foff.z = 0.34
		"E":
			fp.x = wb.position.x + 1.0
			foff = Vector3(0.34, 0, 0)
		"W":
			fp.x = wb.position.x + wb.size.x - 1.0
			foff = Vector3(-0.34, 0, 0)
	_box(self, "Fireplace", Vector3(2.2, 2.1, 0.6), fp, stone)
	_box(self, "Fire", Vector3(1.3, 1.1, 0.12),
			fp - Vector3.UP * 0.30 + foff, flame)
	var tx: float = wb.position.x + 2.2
	var tz: float = cz + wb.size.z * 0.24
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.8
	cm.height = 2.1
	var tree := MeshInstance3D.new()
	tree.name = "IndoorTree"
	tree.mesh = cm
	tree.material_override = green
	tree.position = Vector3(tx, 1.05, tz)
	add_child(tree)
	for k in 8:
		var a := TAU * float(k) / 8.0
		_sphere(tree, "Orb%d" % k, Vector3(0.14, 0.14, 0.14),
			Vector3(cos(a) * 0.5, -0.35 - float(k % 3) * 0.3, sin(a) * 0.5), warm)

	var lamp := OmniLight3D.new()
	lamp.name = "IndoorWarmLight"
	lamp.light_color = Color(1.0, 0.78, 0.50)
	lamp.light_energy = 3.0
	lamp.omni_range = 13.0
	lamp.position = Vector3(cx, 2.8, cz)
	add_child(lamp)


func _build_trigger() -> void:
	var area := Area3D.new()
	area.name = "DoorTrigger"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var span := NEAR_DIST * 2.0 + 2.0
	if _side == "S" or _side == "N":
		bs.size = Vector3(_door_w + 4.5, 4.5, span)
	else:
		bs.size = Vector3(span, 4.5, _door_w + 4.5)
	cs.shape = bs
	area.add_child(cs)
	# 以门中心为中点，门外与屋内两侧都覆盖，玩家进屋后照样能按 F 开门出去
	area.position = _center + Vector3.UP * 2.2
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.name = "DoorHint"
	_hint.text = "按 F 开门"
	_hint.font_size = 34
	_hint.pixel_size = 0.016
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.position = _center + _outward * 1.7 + Vector3.UP * (_door_h + 1.1)
	_hint.modulate = Color(1.0, 0.93, 0.72)
	_hint.visible = false
	add_child(_hint)


func _process(delta: float) -> void:
	var target := 1.0 if _open else 0.0
	_open_t = move_toward(_open_t, target, delta * OPEN_SPEED)
	# 与 ice_castle.gd::_process 一致：两扇门分别向左右平移，DoorBlock 延迟禁用
	for i in _sliders.size():
		var s: float = -1.0 if i == 0 else 1.0
		_sliders[i].position = _slide_base + _horiz * (
				s * (_half_w * 0.5 + _open_t * (_half_w + SLIDE_GAP)))
	if _block != null:
		_block.disabled = _open_t > 0.5
	_near = _area_near or _player_in_range()
	if _hint != null:
		_hint.visible = _near
		_hint.text = "按 F 关门" if _open else "按 F 开门"


## 触发区兜底：玩家可能生成在区域内（不会触发 body_entered）、可能不在
## Player 组，或 Area3D 与玩家 layer 不匹配。再用「门外 + 横向对齐 + 距离」
## 独立算一次，保证 10 栋都能按 F 开门。
func _player_in_range() -> bool:
	var p := _find_player()
	if p == null:
		return false
	var v: Vector3 = p.global_position - _center
	# 门外与屋内两侧都要能开门：旧版 depth < -1.2 直接返回 false，
	# 玩家进屋后 _near 变 false，关着的门挡就把人困在屋里出不来。
	if absf(v.dot(_outward)) > NEAR_DIST:
		return false
	return absf(v.dot(_horiz)) < _half_w + 2.0


func _find_player() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	var p := get_tree().get_first_node_in_group("Player") as Node3D
	if p == null and Engine.get_process_frames() % 30 == 0:
		p = _find_character(get_tree().root)
	if p != null:
		_player = p
	return p


func _find_character(n: Node) -> Node3D:
	if n is CharacterBody3D:
		return n as Node3D
	for c in n.get_children():
		var r := _find_character(c)
		if r != null:
			return r
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not _near:
		return
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var ek := event as InputEventKey
		if ek.pressed and not ek.echo and (ek.keycode == KEY_F
				or ek.physical_keycode == KEY_F or ek.keycode == KEY_ENTER
				or ek.keycode == KEY_KP_ENTER):
			toggle()
			get_viewport().set_input_as_handled()


func _on_body_entered(b: Node3D) -> void:
	if b.is_in_group("Player") or b is CharacterBody3D:
		_area_near = true


func _on_body_exited(b: Node3D) -> void:
	if b.is_in_group("Player") or b is CharacterBody3D:
		_area_near = false


func toggle() -> void:
	_open = not _open


func open_door() -> void:
	_open = true


func close_door() -> void:
	_open = false


func is_open() -> bool:
	return _open


func door_position() -> Vector3:
	return _center


func door_outward() -> Vector3:
	return _outward


func door_horiz() -> Vector3:
	return _horiz


## 供验证脚本读取内部几何状态，避免 Object.get() 读私有脚本变量的坑。
func diagnostics() -> Dictionary:
	return {
		"wall_d": _wall_d,
		"center": _center,
		"outward": _outward,
		"horiz": _horiz,
		"half_w": _half_w,
		"door_w": _door_w,
		"door_h": _door_h,
		"slide_base": _slide_base,
		"near": _near,
		"open_t": _open_t,
		"slider_count": _sliders.size(),
	}
