extends SceneTree
## 圣诞小镇居民 v2 —— 程序化"黏土"建模工具集
## 车削(lathe) / 扫掠(sweep) / 吹气饼干(cookie) / 参数曲面(surface)
## 运行：Godot --headless --path . --script res://tools/build_town_residents.gd

const OUT_DIR := "res://scenes/npcs/residents/"

# ---- 黏土调色板 ----------------------------------------------------------
const C_DOUGH := Color("b57a4f")
const C_DOUGH_D := Color("96603b")
const C_ICING := Color("efe6d4")
const C_TEAL := Color("6f9a94")
const C_TEAL_D := Color("5d827d")
const C_APRON := Color("d9ceba")
const C_EYE := Color("141110")
const C_WHITE := Color("f7f2e6")
const C_BROWN := Color("b4763f")
const C_BROWN_D := Color("93572c")
const C_RED := Color("b0453c")
const C_CREAM := Color("f0e4cd")
const C_MINT := Color("a9c4b4")
const C_HAT := Color("98a0a8")
const C_WOOD := Color("8d6a4a")
const C_GOLD := Color("b08d4a")
const C_METAL := Color("6b6257")

var BODY_PROFILE := PackedVector2Array([Vector2(0.0, 0.235), Vector2(0.22, 0.24),
		Vector2(0.33, 0.28), Vector2(0.40, 0.38), Vector2(0.428, 0.50), Vector2(0.432, 0.60),
		Vector2(0.418, 0.72), Vector2(0.380, 0.82), Vector2(0.330, 0.90), Vector2(0.284, 0.96),
		Vector2(0.262, 1.00), Vector2(0.0, 1.005)])

var _mat_cache := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if "--extra-residents" in OS.get_cmdline_user_args():
		_save_extra_resident(_build_orange_lamplighter(), "orange_lamplighter")
		_save_extra_resident(_build_chestnut_locksmith(), "chestnut_locksmith")
		_save_extra_resident(_build_waffle_courier(), "waffle_courier")
		_save_extra_resident(_build_mint_bellmaker(), "mint_bellmaker")
		quit()
		return
	_save(_build_cinnamon(), "cinnamon_vendor")
	_save(_build_gingerbread(), "gingerbread_watch")
	_save(_build_candy(), "candy_cane_watch")
	print("BUILD_OK")
	quit()


# ==========================================================================
# 材质 / 节点
# ==========================================================================

func _mat(color: Color, rough := 0.93, sss := 0.0, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), rough, sss, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.12
	if sss > 0.0:
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = sss
	_mat_cache[key] = m
	return m


func _cloth_mat(color: Color, rough := 0.95) -> StandardMaterial3D:
	var m := _mat(color, rough)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _node(parent: Node3D, name: String, pos := Vector3.ZERO, rot_deg := Vector3.ZERO,
		scl := Vector3.ONE) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	parent.add_child(n)
	return n


func _mi(parent: Node3D, name: String, mesh: Mesh, mat: Material, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, name: String, pos: Vector3, radii: Vector3, mat: Material,
		segs := 18, rings := 12) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = segs
	sm.rings = rings
	return _mi(parent, name, sm, mat, pos, Vector3.ZERO, radii)


# ==========================================================================
# 基础网格：车削
#  profile: 自下而上的 (半径, 高度) 序列；半径 0 表示极点
# ==========================================================================

func _lathe(name: String, profile: PackedVector2Array, segs: int, mat: Material,
		pos := Vector3.ZERO, rot_deg := Vector3.ZERO, squash := Vector3.ONE) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n := profile.size()
	var pn: Array[Vector2] = []
	for i in n:
		var a := profile[maxi(i - 1, 0)]
		var b := profile[mini(i + 1, n - 1)]
		var d := b - a
		if d.length() < 1e-5:
			d = Vector2(0.0, 1.0)
		d = d.normalized()
		pn.append(Vector2(d.y, -d.x))

	var rp: Array[PackedVector3Array] = []
	var rn: Array[PackedVector3Array] = []
	var pole: Array[bool] = []
	for i in n:
		var p := profile[i]
		if p.x < 1e-4:
			rp.append(PackedVector3Array([Vector3(0.0, p.y, 0.0)]))
			rn.append(PackedVector3Array([Vector3(0.0, signf(pn[i].y), 0.0)]))
			pole.append(true)
			continue
		var ps := PackedVector3Array()
		var ns := PackedVector3Array()
		for s in segs:
			var a := TAU * float(s) / float(segs)
			ps.append(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
			ns.append(Vector3(cos(a) * pn[i].x, pn[i].y, sin(a) * pn[i].x).normalized())
		rp.append(ps)
		rn.append(ns)
		pole.append(false)

	for i in n - 1:
		if pole[i] and pole[i + 1]:
			continue
		if pole[i]:
			for s in segs:
				var s2 := (s + 1) % segs
				_tri(st, [rp[i][0], rp[i + 1][s], rp[i + 1][s2]],
						[rn[i][0], rn[i + 1][s], rn[i + 1][s2]])
		elif pole[i + 1]:
			for s in segs:
				var s2 := (s + 1) % segs
				_tri(st, [rp[i + 1][0], rp[i][s2], rp[i][s]],
						[rn[i + 1][0], rn[i][s2], rn[i][s]])
		else:
			for s in segs:
				var s2 := (s + 1) % segs
				_tri(st, [rp[i][s], rp[i + 1][s], rp[i][s2]],
						[rn[i][s], rn[i + 1][s], rn[i][s2]])
				_tri(st, [rp[i][s2], rp[i + 1][s], rp[i + 1][s2]],
						[rn[i][s2], rn[i + 1][s], rn[i + 1][s2]])
	st.index()
	return _mi(_cur_parent(), name, st.commit(), mat, pos, rot_deg, squash)


var _parent_stack: Array[Node3D] = []


func _cur_parent() -> Node3D:
	return _parent_stack[-1]


func _push(n: Node3D) -> void:
	_parent_stack.push_back(n)


func _pop() -> void:
	_parent_stack.pop_back()


# ==========================================================================
# 扫掠：沿曲线扫圆 / 椭圆截面
# ==========================================================================

func _sweep(name: String, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int,
		mat: Material, ref := Vector3(0.0, 0.0, 1.0), flat := 1.0, caps := true,
		uv_scale := 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var acc := PackedFloat32Array([0.0])
	for i in range(1, n):
		acc.append(acc[i - 1] + pts[i].distance_to(pts[i - 1]))

	var rings: Array[PackedVector3Array] = []
	var nrms: Array[PackedVector3Array] = []
	var tangents: Array[Vector3] = []
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if t.length() < 0.5:
			t = Vector3.UP
		var side := t.cross(ref)
		if side.length() < 1e-4:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(t).normalized()
		tangents.append(t)
		var ps := PackedVector3Array()
		var ns := PackedVector3Array()
		for s in sides:
			var a := TAU * float(s) / float(sides)
			var off := side * cos(a) * radii[i] + up * sin(a) * radii[i] * flat
			ps.append(pts[i] + off)
			ns.append((side * cos(a) + up * sin(a) * flat).normalized())
		rings.append(ps)
		nrms.append(ns)

	for i in n - 1:
		var v0 := acc[i] * uv_scale
		var v1 := acc[i + 1] * uv_scale
		for s in sides:
			var s2 := (s + 1) % sides
			var u0 := float(s) / float(sides)
			var u1 := float(s + 1) / float(sides)
			_tri(st, [rings[i][s], rings[i + 1][s], rings[i][s2]],
					[nrms[i][s], nrms[i + 1][s], nrms[i][s2]],
					[Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v0)])
			_tri(st, [rings[i][s2], rings[i + 1][s], rings[i + 1][s2]],
					[nrms[i][s2], nrms[i + 1][s], nrms[i + 1][s2]],
					[Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v1)])

	if caps:
		_cap(st, pts[n - 1], tangents[n - 1], radii[n - 1], sides, 1.0, flat, 6)
		_cap(st, pts[0], -tangents[0], radii[0], sides, 1.0, flat, 6)
	st.index()
	return _mi(_cur_parent(), name, st.commit(), mat)


func _cap(st: SurfaceTool, center: Vector3, dir: Vector3, radius: float, sides: int,
		_scale: float, flat: float, steps: int) -> void:
	var side := dir.cross(Vector3(0.0, 0.0, 1.0))
	if side.length() < 1e-4:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var prev := PackedVector3Array()
	var prevn := PackedVector3Array()
	for s in sides:
		var a := TAU * float(s) / float(sides)
		prev.append(center + side * cos(a) * radius + up * sin(a) * radius * flat)
		prevn.append((side * cos(a) + up * sin(a) * flat).normalized())
	for k in range(1, steps):
		var ang := PI * 0.5 * float(k) / float(steps)
		var rr := radius * cos(ang)
		var hh := radius * sin(ang)
		var ring := PackedVector3Array()
		var rn := PackedVector3Array()
		for s in sides:
			var a := TAU * float(s) / float(sides)
			ring.append(center + dir * hh + side * cos(a) * rr + up * sin(a) * rr * flat)
			rn.append((side * cos(a) * cos(ang) + up * sin(a) * flat * cos(ang) + dir * sin(ang)).normalized())
		for s in sides:
			var s2 := (s + 1) % sides
			_tri(st, [prev[s], ring[s], prev[s2]], [prevn[s], rn[s], prevn[s2]])
			_tri(st, [prev[s2], ring[s], ring[s2]], [prevn[s2], rn[s], rn[s2]])
		prev = ring
		prevn = rn
	var tip := center + dir * radius
	for s in sides:
		var s2 := (s + 1) % sides
		_tri(st, [prev[s], tip, prev[s2]], [prevn[s], dir, prevn[s2]])


func _tri(st: SurfaceTool, ps: Array, ns: Array, uvs: Array = []) -> void:
	for i in 3:
		st.set_normal(ns[i])
		st.set_uv(uvs[i] if uvs.size() == 3 else Vector2.ZERO)
		st.add_vertex(ps[i])


# ==========================================================================
# 吹气饼干：2D 轮廓 + 圆角厚度（姜饼人就是一片饼干）
# ==========================================================================

func _cookie(name: String, outline: PackedVector2Array, half_t: float, bevel: float,
		mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= float(n)

	# 轮廓法线（外法线）：CCW 轮廓的右手法线
	var nrm: Array[Vector2] = []
	var area := 0.0
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var ccw := area > 0.0
	for i in n:
		var a := outline[maxi(i - 1, 0)]
		var b := outline[(i + 1) % n]
		var d := (b - a).normalized()
		var nn := Vector2(d.y, -d.x) if ccw else Vector2(-d.y, d.x)
		nrm.append(nn)

	var bevels := 4
	# 上表面外圈 → 侧面 → 下表面外圈
	var rings: Array[PackedVector3Array] = []
	var rnorms: Array[PackedVector3Array] = []
	for j in range(bevels, -1, -1):
		var th := PI * 0.5 * float(j) / float(bevels)
		var inset := bevel * (1.0 - cos(th))
		var z := half_t - bevel + bevel * sin(th)
		var ring := PackedVector3Array()
		var rn := PackedVector3Array()
		for i in n:
			var p := outline[i]
			var dirv := (p - c)
			var lenv := dirv.length()
			if lenv < 1e-4:
				dirv = nrm[i]
				lenv = 1.0
			var sc := maxf(0.02, 1.0 - inset / lenv)
			ring.append(Vector3(c.x + dirv.x * sc, c.y + dirv.y * sc, z))
			rn.append(Vector3(nrm[i].x * cos(th), nrm[i].y * cos(th), sin(th)).normalized())
		rings.append(ring)
		rnorms.append(rn)
	for j in range(0, bevels + 1):
		var th := PI * 0.5 * float(j) / float(bevels)
		var inset := bevel * (1.0 - cos(th))
		var z := -(half_t - bevel) - bevel * sin(th)
		var ring := PackedVector3Array()
		var rn := PackedVector3Array()
		for i in n:
			var p := outline[i]
			var dirv := (p - c)
			var lenv := dirv.length()
			if lenv < 1e-4:
				dirv = nrm[i]
				lenv = 1.0
			var sc := maxf(0.02, 1.0 - inset / lenv)
			ring.append(Vector3(c.x + dirv.x * sc, c.y + dirv.y * sc, z))
			rn.append(Vector3(nrm[i].x * cos(th), nrm[i].y * cos(th), -sin(th)).normalized())
		rings.append(ring)
		rnorms.append(rn)

	for j in rings.size() - 1:
		for i in n:
			var i2 := (i + 1) % n
			_tri(st, [rings[j][i], rings[j + 1][i], rings[j][i2]],
					[rnorms[j][i], rnorms[j + 1][i], rnorms[j][i2]])
			_tri(st, [rings[j][i2], rings[j + 1][i], rings[j + 1][i2]],
					[rnorms[j][i2], rnorms[j + 1][i], rnorms[j + 1][i2]])

	# 两个平面
	var top_inset := _inset_poly(outline, c, bevel)
	var bot_inset := _inset_poly(outline, c, bevel)
	_face(st, top_inset, half_t, true)
	_face(st, bot_inset, -half_t, false)

	st.index()
	return _mi(_cur_parent(), name, st.commit(), mat, pos)


func _inset_poly(outline: PackedVector2Array, c: Vector2, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in outline:
		var v := p - c
		var l := v.length()
		out.append(p if l < 1e-4 else c + v * maxf(0.02, 1.0 - d / l))
	return out


func _face(st: SurfaceTool, poly: PackedVector2Array, z: float, front: bool) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		push_warning("triangulate failed")
		return
	for t in range(0, idx.size(), 3):
		var a := poly[idx[t]]
		var b := poly[idx[t + 1]]
		var cc := poly[idx[t + 2]]
		var nz := 1.0 if front else -1.0
		var area := (b - a).cross(cc - a)
		var flip := (front and area < 0.0) or (not front and area > 0.0)
		var p0 := Vector3(a.x, a.y, z)
		var p1 := Vector3(b.x, b.y, z)
		var p2 := Vector3(cc.x, cc.y, z)
		var nn := Vector3(0.0, 0.0, nz)
		if flip:
			_tri(st, [p0, p1, p2], [nn, nn, nn])
		else:
			_tri(st, [p0, p2, p1], [nn, nn, nn])


# ==========================================================================
# 参数曲面
# ==========================================================================

func _surface(name: String, nu: int, nv: int, fn: Callable, mat: Material,
		pos := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nu:
		for j in nv:
			var u0 := float(i) / nu
			var u1 := float(i + 1) / nu
			var v0 := float(j) / nv
			var v1 := float(j + 1) / nv
			var p00: Vector3 = fn.call(u0, v0)
			var p10: Vector3 = fn.call(u1, v0)
			var p01: Vector3 = fn.call(u0, v1)
			var p11: Vector3 = fn.call(u1, v1)
			var n00 := _surf_normal(fn, u0, v0)
			var n10 := _surf_normal(fn, u1, v0)
			var n01 := _surf_normal(fn, u0, v1)
			var n11 := _surf_normal(fn, u1, v1)
			_surf_tri(st, p00, p01, p10, n00, n01, n10, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v0))
			_surf_tri(st, p10, p01, p11, n10, n01, n11, Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v1))
	st.index()
	return _mi(_cur_parent(), name, st.commit(), mat, pos)


func _surf_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_normal(na)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(nc)
	st.set_uv(uc)
	st.add_vertex(c)


func _surf_normal(fn: Callable, u: float, v: float) -> Vector3:
	var d := 0.004
	var du: Vector3 = fn.call(minf(u + d, 1.0), v) - fn.call(maxf(u - d, 0.0), v)
	var dv: Vector3 = fn.call(u, minf(v + d, 1.0)) - fn.call(u, maxf(v - d, 0.0))
	return dv.cross(du).normalized()




# ==========================================================================
# SDF 轮廓（marching squares）—— 把 2D 有向距离场变成饼干轮廓
# ==========================================================================

func _sd_cap2(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var t := clampf(pa.dot(ba) / maxf(ba.dot(ba), 1e-6), 0.0, 1.0)
	return pa.distance_to(ba * t) - r


func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


func _sdf_outline(sd: Callable, bmin: Vector2, bmax: Vector2, res: int) -> PackedVector2Array:
	var nx := res
	var ny := maxi(8, int(round(float(res) * (bmax.y - bmin.y) / (bmax.x - bmin.x))))
	var step := Vector2((bmax.x - bmin.x) / float(nx), (bmax.y - bmin.y) / float(ny))
	var vals := PackedFloat32Array()
	vals.resize((nx + 1) * (ny + 1))
	for j in ny + 1:
		for i in nx + 1:
			vals[j * (nx + 1) + i] = float(sd.call(bmin + Vector2(i, j) * step))
	var segs: Array = []
	for j in ny:
		for i in nx:
			var v0 := vals[j * (nx + 1) + i]
			var v1 := vals[j * (nx + 1) + i + 1]
			var v2 := vals[(j + 1) * (nx + 1) + i + 1]
			var v3 := vals[(j + 1) * (nx + 1) + i]
			var idx := 0
			if v0 < 0.0:
				idx += 1
			if v1 < 0.0:
				idx += 2
			if v2 < 0.0:
				idx += 4
			if v3 < 0.0:
				idx += 8
			if idx == 0 or idx == 15:
				continue
			var o := bmin + Vector2(i, j) * step
			var B := o + Vector2(_et(v0, v1), 0.0) * step
			var R := o + Vector2(1.0, _et(v1, v2)) * step
			var T := o + Vector2(_et(v3, v2), 1.0) * step
			var L := o + Vector2(0.0, _et(v0, v3)) * step
			match idx:
				1:
					segs.append([L, B])
				2:
					segs.append([B, R])
				3:
					segs.append([L, R])
				4:
					segs.append([R, T])
				5:
					segs.append([L, T])
					segs.append([R, B])
				6:
					segs.append([B, T])
				7:
					segs.append([L, T])
				8:
					segs.append([L, T])
				9:
					segs.append([B, T])
				10:
					segs.append([L, B])
					segs.append([R, T])
				11:
					segs.append([R, T])
				12:
					segs.append([L, R])
				13:
					segs.append([B, R])
				14:
					segs.append([L, B])
	return _trace_longest(segs)


func _et(a: float, b: float) -> float:
	return clampf(a / (a - b), 0.0, 1.0)


func _trace_longest(segs: Array) -> PackedVector2Array:
	var used := {}
	var best := PackedVector2Array()
	for s in segs.size():
		if used.has(s):
			continue
		var loop := PackedVector2Array()
		var cur: Vector2 = segs[s][0]
		var nxt: Vector2 = segs[s][1]
		used[s] = true
		loop.append(cur)
		loop.append(nxt)
		var guard := 0
		while guard < segs.size() + 4:
			guard += 1
			var found := -1
			var flip := false
			for t in segs.size():
				if used.has(t):
					continue
				if (segs[t][0] as Vector2).distance_to(nxt) < 1e-5:
					found = t
					flip = false
					break
				if (segs[t][1] as Vector2).distance_to(nxt) < 1e-5:
					found = t
					flip = true
					break
			if found < 0:
				break
			used[found] = true
			nxt = segs[found][0] if flip else segs[found][1]
			loop.append(nxt)
		if loop.size() > best.size():
			best = loop
	if best.size() > 2 and best[0].distance_to(best[best.size() - 1]) < 1e-4:
		best.remove_at(best.size() - 1)
	return best


func _decimate(poly: PackedVector2Array, keep: int) -> PackedVector2Array:
	if poly.size() <= keep:
		return poly
	var out := PackedVector2Array()
	var stride := float(poly.size()) / float(keep)
	for i in keep:
		out.append(poly[mini(int(i * stride), poly.size() - 1)])
	return out


# ==========================================================================
# 斜条纹贴图（糖棍）
# ==========================================================================

func _stripe_mat(a: Color, b: Color, rough := 0.9) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var v := fmod(float(x) / 64.0 * 0.55 + float(y) / 64.0 * 2.2, 1.0)
			img.set_pixel(x, y, a if v < 0.5 else b)
	var m := _mat(Color.WHITE, rough)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	return m


# ==========================================================================
# 提灯（金属框 + 暖光玻璃）
# ==========================================================================

func _lantern(parent: Node3D, pos: Vector3, s := 1.0, name := "Lantern") -> Node3D:
	var root := _node(parent, name, pos, Vector3.ZERO, Vector3.ONE * s)
	_push(root)
	var metal := _mat(C_METAL, 0.48, 0.0, 0.55)
	var glow := _mat(Color(1.0, 0.66, 0.30), 0.38)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.66, 0.30)
	glow.emission_energy_multiplier = 2.4
	# 玻璃罩
	_lathe("LampGlass", PackedVector2Array([Vector2(0.0, -0.080), Vector2(0.052, -0.072),
			Vector2(0.068, -0.030), Vector2(0.068, 0.030), Vector2(0.052, 0.072),
			Vector2(0.0, 0.080)]), 20, glow)
	# 上下盖
	_lathe("LampTop", PackedVector2Array([Vector2(0.0, 0.074), Vector2(0.062, 0.078),
			Vector2(0.078, 0.094), Vector2(0.076, 0.108), Vector2(0.040, 0.120),
			Vector2(0.0, 0.122)]), 20, metal)
	_lathe("LampBase", PackedVector2Array([Vector2(0.0, -0.122), Vector2(0.040, -0.120),
			Vector2(0.076, -0.108), Vector2(0.078, -0.094), Vector2(0.062, -0.078),
			Vector2(0.0, -0.074)]), 20, metal)
	# 立柱
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		_box(root, "LampBar%d" % i, Vector3(cos(a) * 0.062, 0.0, sin(a) * 0.062),
				Vector3(0.016, 0.150, 0.016), metal)
	_torus(root, "LampHandle", Vector3(0, 0.150, 0), 0.032, 0.009, metal, Vector3(90, 0, 0))
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.76, 0.44)
	light.light_energy = 0.85
	light.omni_range = 2.2
	light.shadow_enabled = false
	root.add_child(light)
	_pop()
	return root


func _cyl(parent: Node3D, name: String, pos: Vector3, rt: float, rb: float, h: float,
		mat: Material, segs := 16) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return _mi(parent, name, cm, mat, pos)


func _torus(parent: Node3D, name: String, pos: Vector3, major: float, minor: float,
		mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(major - minor, 0.005)
	tm.outer_radius = major + minor
	tm.rings = 28
	tm.ring_segments = 10
	return _mi(parent, name, tm, mat, pos, rot_deg)


func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	return _mi(parent, name, _box_mesh(size), mat, pos, rot_deg)


# ==========================================================================
# 程序化纹理（针织 / 面团颗粒 / 围裙污渍）—— 贴图挂到 UV 上，省几何
# ==========================================================================

func _noise2(x: int, y: int, seed_v := 0) -> float:
	var v := sin(float(x) * 12.9898 + float(y) * 78.233 + float(seed_v) * 37.719) * 43758.5453
	return v - floor(v)


func _pattern_mat(base: Color, kind: String, rough := 0.95, tiling := 1.0) -> StandardMaterial3D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u := float(x) / float(n)
			var v := float(y) / float(n)
			var c := base
			match kind:
				"knit":
					var rib := 0.5 + 0.5 * sin(v * TAU * 7.0)
					var stitch := 0.5 + 0.5 * cos(u * TAU * 12.0 + sin(v * TAU * 7.0) * 1.6)
					c = base * (0.84 + 0.11 * rib + 0.09 * stitch)
				"crumb":
					var nz := _noise2(x, y, 3) * 0.5 + _noise2(x / 2, y / 2, 9) * 0.5
					c = base * (0.93 + 0.13 * nz)
				"dough":
					var nz2 := _noise2(x, y, 5) * 0.6 + _noise2(x / 3, y / 3, 11) * 0.4
					c = base * (0.95 + 0.09 * nz2)
					if _noise2(x / 4, y / 4, 21) > 0.93:
						c = c.darkened(0.10)
				"cloth":
					var nz3 := _noise2(x / 2, y / 2, 7) * 0.7 + _noise2(x / 6, y / 6, 13) * 0.3
					c = base * (0.94 + 0.10 * nz3)
					if _noise2(x / 8, y / 8, 31) > 0.88:
						c = c.darkened(0.07)
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = rough
	m.metallic_specular = 0.12
	m.uv1_scale = Vector3(tiling, tiling, 1.0)
	return m

# ==========================================================================
# 存盘
# ==========================================================================

func _save(root: Node3D, file: String) -> void:
	_own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_DIR + file + ".tscn")
	print("SAVE ", file, " err=", err)
	root.free()


func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own(c, owner_node)


# ==========================================================================
# 肉桂卷摊贩
# ==========================================================================

func _build_cinnamon() -> Node3D:
	var root := Node3D.new()
	root.name = "CinnamonVendor"
	_push(root)

	var dough := _pattern_mat(C_DOUGH, "dough", 0.95, 1.6)
	var dough_d := _mat(C_DOUGH_D, 0.95, 0.30)
	var icing := _mat(C_ICING, 0.70, 0.15)
	var teal := _pattern_mat(C_TEAL, "knit", 0.98, 2.5)
	var eye := _mat(C_EYE, 0.40)
	var apron_m := _cloth_mat(Color("d3c6b0"), 0.95)
	apron_m.albedo_texture = _pattern_mat(Color.WHITE, "cloth", 0.95, 2.2).albedo_texture

	# ---- 腿 + 脚 ----
	for side in [-1.0, 1.0]:
		var x: float = 0.165 * side
		var sfx := "L" if side < 0.0 else "R"
		_lathe("Leg" + sfx, PackedVector2Array([
			Vector2(0.0, 0.015), Vector2(0.10, 0.025), Vector2(0.112, 0.12),
			Vector2(0.122, 0.22), Vector2(0.128, 0.29), Vector2(0.0, 0.295)]),
			20, dough, Vector3(x, 0.0, 0.0))
		_ball(root, "Foot" + sfx, Vector3(x, 0.052, -0.05), Vector3(0.142, 0.070, 0.185), dough, 18, 10)
		_ball(root, "Heel" + sfx, Vector3(x, 0.048, 0.055), Vector3(0.112, 0.058, 0.098), dough, 14, 8)

	# ---- 身体：梨形，前扁 ----
	var body := _node(root, "BodyG", Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.86))
	_push(body)
	_lathe("Body", BODY_PROFILE, 48, dough)
	_pop()

	# ---- 脸 ----
	var face_y := 0.868
	for side in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		_ball(root, "Eye" + sfx, Vector3(0.102 * side, face_y, -0.288),
				Vector3(0.038, 0.046, 0.028), eye, 16, 10)
		_ball(root, "Glint" + sfx, Vector3(0.102 * side - 0.011, face_y + 0.015, -0.306),
				Vector3(0.010, 0.010, 0.007), _mat(C_WHITE, 0.3), 8, 6)
	_ball(root, "Nose", Vector3(0.0, 0.826, -0.297), Vector3(0.026, 0.020, 0.018), dough_d, 12, 8)
	var mouth := PackedVector3Array()
	for i in 7:
		var t := float(i) / 6.0
		mouth.append(Vector3(lerpf(-0.066, 0.066, t), 0.782 - 0.018 * sin(t * PI), -0.290))
	_sweep("Mouth", mouth, PackedFloat32Array([0.008, 0.009, 0.010, 0.010, 0.010, 0.009, 0.008]),
			8, _mat(Color("5c3a2a"), 0.9))

	# ---- 针织围巾：绕颈一圈 + 一条垂尾 ----
	var scarf_pts := PackedVector3Array()
	var scarf_r := PackedFloat32Array()
	for i in 29:
		var a := TAU * float(i) / 28.0
		scarf_pts.append(Vector3(cos(a) * 0.268, 1.000 + 0.009 * cos(a * 2.0), sin(a) * 0.232))
		scarf_r.append(0.046)
	_sweep("Scarf", scarf_pts, scarf_r, 16, teal, Vector3.UP, 1.9)
	var tail := PackedVector3Array()
	var tail_r := PackedFloat32Array()
	for i in 9:
		var t := float(i) / 8.0
		tail.append(Vector3(-0.232 - 0.070 * sin(t * 1.7) - 0.03 * t, 0.985 - t * 0.40,
				-0.158 - 0.055 * t))
		tail_r.append(lerpf(0.050, 0.038, t))
	_sweep("ScarfTail", tail, tail_r, 12, teal, Vector3(0, 1, 0), 1.5)
	for i in 4:
		_ball(root, "Fringe%d" % i, Vector3(-0.280 - 0.026 * float(i), 0.578, -0.222),
				Vector3(0.010, 0.030, 0.010), teal, 8, 6)

	# ---- 围裙（腰部以下，前面一片）----
	var apron_fn := func(u: float, v: float) -> Vector3:
		var a := lerpf(-0.55, 0.55, u)
		var y := lerpf(0.262, 0.672, v)
		var rr := _body_radius(y)
		return Vector3(sin(a) * rr * 1.00, y, -cos(a) * rr * 0.86 - 0.034)
	_surface("Apron", 22, 16, apron_fn, apron_m)
	# 腰部系带
	var band := PackedVector3Array()
	var band_r := PackedFloat32Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		band.append(Vector3(cos(a) * 0.434, 0.670, sin(a) * 0.434 * 0.86))
		band_r.append(0.016)
	_sweep("ApronBand", band, band_r, 10, apron_m, Vector3.UP, 3.0)
	_ball(root, "ApronKnot", Vector3(0.0, 0.664, 0.372), Vector3(0.046, 0.040, 0.030), apron_m, 12, 8)
	for side in [-1.0, 1.0]:
		var bow := PackedVector3Array()
		var br := PackedFloat32Array()
		for i in 6:
			var t := float(i) / 5.0
			bow.append(Vector3(0.046 * float(side) + t * 0.090 * float(side),
					0.664 + 0.030 * sin(t * PI), 0.384 + 0.026 * t))
			br.append(0.018)
		_sweep("ApronBow" + ("L" if side < 0.0 else "R"), bow, br, 8, apron_m, Vector3.UP, 1.8)

	# ---- 手臂：肩 → 肘 → 手，捧着托盘 ----
	for side in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var arm := _bez(Vector3(0.300 * float(side), 0.830, -0.060),
				Vector3(0.470 * float(side), 0.790, -0.300),
				Vector3(0.318 * float(side), 0.606, -0.575), 12)
		var ar := PackedFloat32Array()
		for i in 12:
			ar.append(lerpf(0.080, 0.056, float(i) / 11.0))
		_sweep("Arm" + sfx, arm, ar, 14, dough, Vector3(0, 1, 0))
		_ball(root, "Hand" + sfx, Vector3(0.318 * float(side), 0.592, -0.600),
				Vector3(0.056, 0.048, 0.052), dough, 14, 8)

	# ---- 托盘 + 三个小肉桂卷 ----
	var tray_pos := Vector3(0, 0.588, -0.610)
	var wood := _mat(C_WOOD, 0.88)
	_mi(root, "Tray", _box_mesh(Vector3(0.60, 0.026, 0.275)), wood, tray_pos)
	for i in 3:
		var x := -0.175 + 0.175 * float(i)
		var roll := PackedVector3Array()
		var rr := PackedFloat32Array()
		for k in 30:
			var t := float(k) / 29.0
			var a := TAU * 1.5 * t
			var rad := 0.014 + 0.056 * t
			roll.append(tray_pos + Vector3(x + cos(a) * rad, 0.046, sin(a) * rad))
			rr.append(lerpf(0.026, 0.029, t))
		_sweep("MiniRoll%d" % i, roll, rr, 10, _mat(C_BROWN, 0.93))
		_ball(root, "MiniIcing%d" % i, tray_pos + Vector3(x, 0.074, 0.0),
				Vector3(0.018, 0.010, 0.018), icing, 10, 6)

	# ---- 头：实心面包盘 + 卷边 + 螺旋纹 + 糖霜 ----
	var head := _node(root, "HeadG", Vector3(0, 1.628, 0.015), Vector3(-6, 0, 0))
	_push(head)
	var disk := _node(head, "HeadDisk", Vector3.ZERO, Vector3(90, 0, 0))
	_push(disk)
	_lathe("BunDisk", PackedVector2Array([
		Vector2(0.0, -0.145), Vector2(0.20, -0.143), Vector2(0.33, -0.130), Vector2(0.41, -0.102),
		Vector2(0.448, -0.058), Vector2(0.455, 0.0), Vector2(0.448, 0.058), Vector2(0.41, 0.102),
		Vector2(0.33, 0.130), Vector2(0.20, 0.143), Vector2(0.0, 0.145)]), 56, dough)
	_pop()
	# 卷边
	var rim := PackedVector3Array()
	var rim_r := PackedFloat32Array()
	for i in 57:
		var a := TAU * float(i) / 56.0
		rim.append(Vector3(cos(a) * 0.442, sin(a) * 0.442, 0.0))
		rim_r.append(0.072)
	_sweep("BunRim", rim, rim_r, 12, dough, Vector3(0, 0, 1))
	# 面包卷隆起 + 糖霜（错开半圈）
	var turns := 2.05
	var ridge := PackedVector3Array()
	var ridge_r := PackedFloat32Array()
	for i in 120:
		var t := float(i) / 119.0
		var a := TAU * turns * t + PI - 0.6
		var rad := 0.085 + 0.335 * pow(t, 0.94)
		ridge.append(Vector3(cos(a) * rad, sin(a) * rad, -0.138))
		ridge_r.append(lerpf(0.080, 0.062, t))
	_sweep("BunRidge", ridge, ridge_r, 11, dough, Vector3(0, 0, 1))
	var glaze := PackedVector3Array()
	var glaze_r := PackedFloat32Array()
	for i in 120:
		var t := float(i) / 119.0
		var a := TAU * turns * t - 0.6
		var rad := 0.045 + 0.350 * pow(t, 0.94)
		glaze.append(Vector3(cos(a) * rad, sin(a) * rad, -0.150))
		glaze_r.append(lerpf(0.060, 0.044, t))
	_sweep("IcingSpiral", glaze, glaze_r, 10, icing, Vector3(0, 0, 1))
	# 糖霜从上方卷边往下淌
	for i in 6:
		var a := deg_to_rad(146.0 + 22.0 * float(i))
		var top := Vector3(cos(a) * 0.448, sin(a) * 0.448, 0.0)
		var drip := PackedVector3Array()
		var dr := PackedFloat32Array()
		for k in 7:
			var t := float(k) / 6.0
			drip.append(top + Vector3(cos(a) * 0.016 * t, -0.015 * t - 0.115 * t * t,
					lerpf(-0.035, -0.150, t) + 0.018 * sin(t * PI)))
			dr.append(lerpf(0.048, 0.020, t * t * 0.7 + t * 0.3))
		_sweep("Drip%d" % i, drip, dr, 10, icing, Vector3(0, 0, 1))
	_pop()

	# ---- 脖子上的小面包圈（藏在围巾后）----
	var collar := _node(root, "CollarG", Vector3(0, 1.058, 0.02), Vector3(3, 0, 0), Vector3(1.0, 1.0, 0.9))
	_push(collar)
	_lathe("CollarBun", PackedVector2Array([
		Vector2(0.0, -0.050), Vector2(0.22, -0.048), Vector2(0.30, -0.026), Vector2(0.330, 0.014),
		Vector2(0.318, 0.046), Vector2(0.26, 0.062), Vector2(0.0, 0.064)]), 40, dough)
	_pop()

	_pop()
	return root


func _build_gingerbread() -> Node3D:
	var root := Node3D.new()
	root.name = "GingerbreadWatch"
	_push(root)

	var dough := _pattern_mat(C_BROWN, "crumb", 0.93, 1.8)
	var dough_d := _mat(C_BROWN_D, 0.94)
	var icing := _mat(C_CREAM, 0.70, 0.12)
	var red := _pattern_mat(C_RED, "knit", 0.96, 2.6)
	var eye := _mat(C_EYE, 0.38)

	# ---- 饼干轮廓：SDF 并集 + 咬掉一口 ----
	var sd := func(p: Vector2) -> float:
		var d := _sd_cap2(p, Vector2(0.0, 1.300), Vector2(0.0, 1.300), 0.283)
		d = _smin(d, _sd_cap2(p, Vector2(0.0, 0.925), Vector2(0.0, 0.640), 0.286), 0.075)
		d = _smin(d, _sd_cap2(p, Vector2(0.190, 0.905), Vector2(0.455, 0.775), 0.110), 0.055)
		d = _smin(d, _sd_cap2(p, Vector2(-0.190, 0.905), Vector2(-0.455, 0.775), 0.110), 0.055)
		d = _smin(d, _sd_cap2(p, Vector2(0.152, 0.500), Vector2(0.162, 0.135), 0.133), 0.055)
		d = _smin(d, _sd_cap2(p, Vector2(-0.152, 0.500), Vector2(-0.162, 0.135), 0.133), 0.055)
		# 被咬掉的右臂
		d = maxf(d, -_sd_cap2(p, Vector2(-0.470, 0.830), Vector2(-0.462, 0.752), 0.098))
		d = maxf(d, -_sd_cap2(p, Vector2(-0.548, 0.880), Vector2(-0.548, 0.880), 0.046))
		d = maxf(d, -_sd_cap2(p, Vector2(-0.418, 0.712), Vector2(-0.418, 0.712), 0.038))
		return d

	var outline := _sdf_outline(sd, Vector2(-0.80, -0.02), Vector2(0.80, 1.63), 150)
	outline = _decimate(outline, 168)
	_cookie("Cookie", outline, 0.160, 0.100, dough)
	print("GINGER outline pts=", outline.size())

	# ---- 糖霜描边（沿轮廓一圈）----
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= float(outline.size())
	var edge := PackedVector3Array()
	for i in outline.size() + 1:
		var p := outline[i % outline.size()]
		var v := p - c
		var q := c + v * (1.0 - 0.055 / maxf(v.length(), 0.05))
		edge.append(Vector3(q.x, q.y, -0.146))
	_sweep("IcingEdge", edge, PackedFloat32Array(_fill(edge.size(), 0.019)), 6, icing,
			Vector3(0.0, 0.0, 1.0))

	# ---- 脸 ----
	for side in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		_ball(root, "Eye" + sfx, Vector3(0.098 * float(side), 1.345, -0.172),
				Vector3(0.046, 0.050, 0.028), eye, 16, 10)
		_ball(root, "Glint" + sfx, Vector3(0.098 * float(side) - 0.010, 1.360, -0.190),
				Vector3(0.012, 0.012, 0.008), _mat(C_WHITE, 0.3), 8, 6)
	var smile := PackedVector3Array()
	for i in 11:
		var t := float(i) / 10.0
		var a := lerpf(-0.78, 0.78, t)
		smile.append(Vector3(sin(a) * 0.098, 1.196 + 0.040 * cos(a) - 0.040, -0.166))
	_sweep("IcingSmile", smile, PackedFloat32Array(_fill(11, 0.016)), 7, icing, Vector3(0, 0, 1))

	# ---- 扣子 ----
	for i in 3:
		_ball(root, "Button%d" % i, Vector3(0.0, 1.02 - 0.115 * float(i), -0.170),
				Vector3(0.042, 0.042, 0.020), icing, 14, 8)

	# ---- 红围巾 + 结 ----
	var scarf := PackedVector3Array()
	var sr := PackedFloat32Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		scarf.append(Vector3(cos(a) * 0.276, 1.048 + 0.008 * cos(a * 2.0), sin(a) * 0.205))
		sr.append(0.036)
	_sweep("Scarf", scarf, sr, 12, red, Vector3.UP, 1.6)
	_ball(root, "ScarfKnot", Vector3(0.072, 1.010, -0.214), Vector3(0.046, 0.042, 0.032), red, 12, 8)
	var tail_a := PackedVector3Array()
	var tar := PackedFloat32Array()
	for i in 7:
		var t := float(i) / 6.0
		tail_a.append(Vector3(0.086 + 0.040 * t, 0.988 - 0.150 * t, -0.216 - 0.004 * t))
		tar.append(lerpf(0.050, 0.034, t))
	_sweep("ScarfTailA", tail_a, tar, 8, red, Vector3(0.0, 0.0, 1.0), 0.32)
	var tail_b := PackedVector3Array()
	var tbr := PackedFloat32Array()
	for i in 7:
		var t := float(i) / 6.0
		tail_b.append(Vector3(0.048 - 0.026 * t, 0.986 - 0.120 * t, -0.222 - 0.003 * t))
		tbr.append(lerpf(0.044, 0.030, t))
	_sweep("ScarfTailB", tail_b, tbr, 8, red, Vector3(0.0, 0.0, 1.0), 0.32)

	# ---- 提灯（左手）----
	var rope := PackedVector3Array()
	rope.append(Vector3(0.505, 0.800, -0.010))
	rope.append(Vector3(0.525, 0.700, -0.012))
	rope.append(Vector3(0.530, 0.620, -0.014))
	_sweep("LanternRope", rope, PackedFloat32Array([0.010, 0.009, 0.009]), 6,
			_mat(C_METAL, 0.6, 0.0, 0.4))
	_lantern(root, Vector3(0.530, 0.500, -0.014), 1.0, "Lantern")

	# ---- 断臂的碎屑 ----
	for i in 3:
		_ball(root, "Crumb%d" % i, Vector3(-0.60 - 0.03 * float(i), 0.90 + 0.05 * float(i), -0.06),
				Vector3(0.026, 0.020, 0.022), dough_d, 10, 6)

	_pop()
	return root


func _build_candy() -> Node3D:
	var root := Node3D.new()
	root.name = "CandyCaneWatch"
	_push(root)

	var stripes := _stripe_mat(Color("efe0c8"), Color("b4463c"), 0.92)
	var cream := _mat(C_CREAM, 0.9)
	var hat := _mat(C_HAT, 0.95)
	var tan := _pattern_mat(Color("c9b79a"), "knit", 0.96, 2.6)
	var eye := _mat(C_EYE, 0.38)

	# ---- 糖棍本体：竖直段 + 顶部 180° 弯钩（一体扫掠）----
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 26:
		var t := float(i) / 25.0
		pts.append(Vector3(0.0, 0.105 + t * 1.135, 0.0))
		rad.append(lerpf(0.150, 0.133, t))
	var R := 0.315
	for i in 21:
		var a := PI * float(i + 1) / 21.0
		pts.append(Vector3(-R + cos(a) * R, 1.240 + sin(a) * R, 0.0))
		rad.append(lerpf(0.132, 0.120, float(i) / 20.0))
	_sweep("Cane", pts, rad, 16, stripes, Vector3(0.0, 0.0, 1.0), 1.0, true, 0.85)

	# ---- 脚 ----
	for side in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		_ball(root, "Foot" + sfx, Vector3(0.098 * float(side), 0.058, -0.045),
				Vector3(0.125, 0.062, 0.170), cream, 16, 10)

	# ---- 眼睛 ----
	for side in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		_ball(root, "Eye" + sfx, Vector3(0.058 * float(side), 1.170, -0.120),
				Vector3(0.040, 0.045, 0.024), eye, 14, 8)
		_ball(root, "Glint" + sfx, Vector3(0.058 * float(side) - 0.009, 1.183, -0.134),
				Vector3(0.010, 0.010, 0.007), _mat(C_WHITE, 0.3), 8, 6)

	# ---- 贝雷帽（歪在弯钩上）----
	var beret := _node(root, "BeretG", Vector3(-0.318, 1.648, 0.0), Vector3(-18, 0, -30),
			Vector3(1.0, 1.0, 0.95))
	_push(beret)
	_lathe("Beret", PackedVector2Array([Vector2(0.0, 0.004), Vector2(0.120, 0.010),
			Vector2(0.165, 0.040), Vector2(0.176, 0.085), Vector2(0.150, 0.145),
			Vector2(0.082, 0.180), Vector2(0.0, 0.188)]), 32, hat)
	_torus(beret, "BeretBrim", Vector3(0, 0.012, 0), 0.168, 0.022, hat)
	_ball(beret, "BeretNub", Vector3(0.0, 0.194, 0.0), Vector3(0.026, 0.026, 0.026), hat, 12, 8)
	_pop()

	# ---- 针织围巾 + 蝴蝶结 ----
	var scarf := PackedVector3Array()
	var sr := PackedFloat32Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		scarf.append(Vector3(cos(a) * 0.182, 1.012 + 0.008 * cos(a * 2.0), sin(a) * 0.182))
		sr.append(0.050)
	_sweep("Scarf", scarf, sr, 14, tan, Vector3.UP, 1.8)
	_ball(root, "ScarfKnot", Vector3(0.0, 0.985, -0.168), Vector3(0.062, 0.058, 0.048), tan, 14, 8)
	for side in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var tail := PackedVector3Array()
		var tr := PackedFloat32Array()
		for i in 7:
			var t := float(i) / 6.0
			tail.append(Vector3(0.030 * float(side) - 0.006 * float(side) * t,
					0.968 - 0.150 * t, -0.180 - 0.010 * t))
			tr.append(lerpf(0.046, 0.030, t))
		_sweep("ScarfTail" + sfx, tail, tr, 8, tan, Vector3(0.0, 0.0, 1.0), 0.35)

	# ---- 腰间钥匙 ----
	var twine := PackedVector3Array()
	twine.append(Vector3(0.132, 0.940, -0.088))
	twine.append(Vector3(0.152, 0.880, -0.098))
	twine.append(Vector3(0.160, 0.830, -0.102))
	_sweep("KeyTwine", twine, PackedFloat32Array([0.010, 0.009, 0.009]), 6, tan)
	_torus(root, "KeyRing", Vector3(0.160, 0.805, -0.104), 0.028, 0.008, _mat(C_GOLD, 0.4, 0.0, 0.7),
			Vector3(90, 0, 0))
	_box(root, "KeyStem", Vector3(0.160, 0.752, -0.104), Vector3(0.016, 0.075, 0.014),
			_mat(C_GOLD, 0.4, 0.0, 0.7))
	_box(root, "KeyBit", Vector3(0.177, 0.722, -0.104), Vector3(0.028, 0.016, 0.014),
			_mat(C_GOLD, 0.4, 0.0, 0.7))

	# ---- 手臂 + 提灯 ----
	var arm := _bez(Vector3(0.110, 0.900, -0.040), Vector3(0.235, 0.870, -0.095),
			Vector3(0.335, 0.800, -0.122), 8)
	var ar := PackedFloat32Array()
	for i in 8:
		ar.append(lerpf(0.055, 0.042, float(i) / 7.0))
	_sweep("Arm", arm, ar, 10, cream, Vector3(0, 1, 0))
	_ball(root, "Hand", Vector3(0.342, 0.788, -0.126), Vector3(0.048, 0.044, 0.044), cream, 12, 8)
	var rope := PackedVector3Array()
	rope.append(Vector3(0.342, 0.762, -0.126))
	rope.append(Vector3(0.362, 0.690, -0.128))
	rope.append(Vector3(0.372, 0.630, -0.130))
	_sweep("LanternRope", rope, PackedFloat32Array([0.009, 0.008, 0.008]), 6,
			_mat(C_METAL, 0.6, 0.0, 0.4))
	_lantern(root, Vector3(0.372, 0.512, -0.130), 0.90, "Lantern")

	_pop()
	return root


func _bez(p0: Vector3, p1: Vector3, p2: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n:
		var t := float(i) / float(n - 1)
		var it := 1.0 - t
		out.append(p0 * it * it + p1 * 2.0 * it * t + p2 * t * t)
	return out


func _body_radius(y: float) -> float:
	if y <= BODY_PROFILE[0].y:
		return BODY_PROFILE[0].x
	for i in range(BODY_PROFILE.size() - 1):
		var a := BODY_PROFILE[i]
		var b := BODY_PROFILE[i + 1]
		if y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 1e-5))
	return 0.0


func _fill(n: int, v: float) -> Array:
	var a := []
	for i in n:
		a.append(v)
	return a


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _build_orange_lamplighter() -> Node3D:
	var root := Node3D.new()
	root.name = "OrangeLamplighter"
	var peel := _mat(Color("e29042"))
	var leaf := _mat(Color("567c62"))
	_ball(root, "Orange", Vector3(0, 0.57, 0), Vector3(0.40, 0.43, 0.33), peel)
	_cyl(root, "Stem", Vector3(0, 1.01, 0), 0.032, 0.045, 0.16, _mat(C_WOOD), 8)
	_ball(root, "Leaf", Vector3(0.12, 1.02, 0.01), Vector3(0.17, 0.033, 0.062), leaf, 10, 5).rotation_degrees.z = 21.0
	_winter_details(root, peel, _mat(Color("477879")), 0.65, -0.322)
	_cyl(root, "LanternGlass", Vector3(0.50, 0.37, -0.13), 0.073, 0.086, 0.17, _mat(Color("ffd281")), 8)
	for y in [0.27, 0.47]:
		_cyl(root, "LanternRim", Vector3(0.50, y, -0.13), 0.10, 0.10, 0.031, _mat(C_METAL), 8)
	_torus(root, "LanternHandle", Vector3(0.50, 0.51, -0.13), 0.042, 0.009, _mat(C_METAL), Vector3(90, 0, 0))
	return root


func _build_chestnut_locksmith() -> Node3D:
	var root := Node3D.new()
	root.name = "ChestnutLocksmith"
	var shell := _mat(Color("854f3b"))
	var base := _mat(Color("d5a474"))
	_push(root)
	var profile := PackedVector2Array([Vector2(0, 0.14), Vector2(0.24, 0.14),
		Vector2(0.40, 0.24), Vector2(0.43, 0.4), Vector2(0.39, 0.61),
		Vector2(0.29, 0.79), Vector2(0.12, 0.93), Vector2(0, 0.99)])
	_lathe("Chestnut", profile, 20, shell, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.84))
	_pop()
	_ball(root, "PaleBase", Vector3(0, 0.28, -0.12), Vector3(0.37, 0.15, 0.245), base)
	_winter_details(root, shell, _mat(Color("788a57")), 0.61, -0.324)
	var brass := _mat(Color("d0ac5f"), 0.58, 0.0, 0.25)
	_torus(root, "KeyBow", Vector3(0.47, 0.53, -0.22), 0.057, 0.014, brass, Vector3(90, 0, 0))
	_box(root, "KeyStem", Vector3(0.47, 0.403, -0.22), Vector3(0.025, 0.16, 0.024), brass)
	_box(root, "KeyBit", Vector3(0.499, 0.35, -0.22), Vector3(0.076, 0.035, 0.024), brass)
	return root


func _build_waffle_courier() -> Node3D:
	var root := Node3D.new()
	root.name = "WaffleCourier"
	var dough := _mat(Color("ce995f"))
	var browned := _mat(Color("996438"))
	var outline := PackedVector2Array([Vector2(-0.30, 0.17), Vector2(0.30, 0.17),
		Vector2(0.42, 0.29), Vector2(0.42, 0.89), Vector2(0.30, 1.01),
		Vector2(-0.30, 1.01), Vector2(-0.42, 0.89), Vector2(-0.42, 0.29)])
	_push(root)
	_cookie("Waffle", outline, 0.17, 0.047, dough)
	_pop()
	for row in 3:
		for col in 4:
			_box(root, "WafflePocket", Vector3((col - 1.5) * 0.17, 0.32 + row * 0.26, -0.17),
				Vector3(0.114, 0.115, 0.012), browned)
	_winter_details(root, dough, _mat(Color("9a5267")), 0.72, -0.175)
	var leather := _mat(Color("4a5874"))
	_box(root, "SatchelStrap", Vector3(-0.095, 0.60, -0.196), Vector3(0.062, 0.58, 0.04), leather, Vector3(0, 0, -32))
	_box(root, "Satchel", Vector3(-0.28, 0.37, -0.21), Vector3(0.30, 0.25, 0.13), leather, Vector3(0, 0, -10))
	_box(root, "Letter", Vector3(-0.28, 0.53, -0.245), Vector3(0.18, 0.15, 0.022), _mat(C_ICING), Vector3(0, 0, -22))
	_ball(root, "WaxSeal", Vector3(-0.28, 0.53, -0.263), Vector3(0.024, 0.024, 0.009), _mat(C_RED), 8, 4)
	return root


func _build_mint_bellmaker() -> Node3D:
	var root := Node3D.new()
	root.name = "MintBellmaker"
	var mint := _mat(Color("a5c9b7"))
	_push(root)
	var profile := PackedVector2Array([Vector2(0, 0.13), Vector2(0.26, 0.13),
		Vector2(0.36, 0.18), Vector2(0.39, 0.29), Vector2(0.37, 0.73),
		Vector2(0.33, 0.91), Vector2(0.24, 0.98), Vector2(0, 0.99)])
	_lathe("Marshmallow", profile, 20, mint, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.85))
	_pop()
	_ball(root, "Icing", Vector3(0, 0.87, -0.01), Vector3(0.334, 0.14, 0.28), _mat(C_ICING))
	_ball(root, "IcingDrip", Vector3(-0.21, 0.8, -0.189), Vector3(0.092, 0.12, 0.064), _mat(C_ICING), 12, 6)
	_winter_details(root, mint, _mat(Color("b05c58")), 0.65, -0.306)
	var bell := _mat(Color("d2a65b"), 0.48, 0.0, 0.4)
	_cyl(root, "Bell", Vector3(-0.46, 0.40, -0.135), 0.04, 0.11, 0.18, bell, 12)
	_torus(root, "BellLip", Vector3(-0.46, 0.32, -0.135), 0.099, 0.015, bell)
	_ball(root, "Clapper", Vector3(-0.46, 0.295, -0.135), Vector3.ONE * 0.037, _mat(C_METAL), 8, 4)
	return root


func _winter_details(root: Node3D, body: Material, fabric: Material, eye_y: float, face_z: float) -> void:
	for side in [-1.0, 1.0]:
		var x := float(side)
		_ball(root, "Boot", Vector3(x * 0.19, 0.085, -0.048),
			Vector3(0.13, 0.085, 0.15), fabric, 12, 6)
		_ball(root, "Mitten", Vector3(x * 0.45, 0.52, -0.13),
			Vector3(0.112, 0.087, 0.095), body, 12, 6)
		_ball(root, "Eye", Vector3(x * 0.118, eye_y, face_z),
			Vector3(0.039, 0.049, 0.025), _mat(C_EYE), 10, 5)
		_ball(root, "EyeGlint", Vector3(x * 0.118 - 0.008, eye_y + 0.014, face_z - 0.022),
			Vector3.ONE * 0.009, _mat(C_WHITE), 8, 4)
	_ball(root, "ScarfKnot", Vector3(0.18, eye_y - 0.14, face_z + 0.015),
		Vector3(0.112, 0.055, 0.063), fabric, 12, 6)
	_ball(root, "ScarfTail", Vector3(0.23, eye_y - 0.24, face_z),
		Vector3(0.052, 0.115, 0.027), fabric, 12, 6).rotation_degrees.z = 20.0


func _save_extra_resident(root: Node3D, filename: String) -> void:
	# Merge by material so the four residents don't draw each mitten and accessory separately.
	var batches: Dictionary[Material, SurfaceTool] = {}
	for node in root.get_children():
		var part := node as MeshInstance3D
		var material := part.material_override
		if not batches.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			batches[material] = surface
		batches[material].append_from(part.mesh, 0, part.transform)
		part.free()
	var combined := ArrayMesh.new()
	for surface in batches.values():
		surface.commit(combined)
	var model := MeshInstance3D.new()
	model.name = "ClayModel"
	model.mesh = combined
	root.add_child(model)
	_save(root, filename)
