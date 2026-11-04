extends SceneTree
# 程序化生成：饼干(biscuit.tres) 与 饼干预盾(biscuit_shield.tres)
# 复用灯塔的 _tri 自动翻面约定（右手法线若朝外则翻转绕序，正面=顺时针）。

const SEG := 30
const S_SHD := 24

const C_BISCUIT := Color(0.93, 0.72, 0.27)
const C_BISCUIT2 := Color(0.88, 0.66, 0.22)
const C_CREAM := Color(0.97, 0.95, 0.90)
const C_BISCUIT_DARK := Color(0.60, 0.43, 0.14)
const C_METAL := Color(0.56, 0.58, 0.63)

func _av(a: Dictionary, v: Vector3, n: Vector3, c: Color) -> int:
	a["verts"].append(v)
	a["norms"].append(n)
	a["cols"].append(c)
	return a["verts"].size() - 1

func _tri(a: Dictionary, ia: int, ib: int, ic: int, hint: Vector3) -> void:
	var n: Vector3 = (a["verts"][ib] - a["verts"][ia]).cross(a["verts"][ic] - a["verts"][ia])
	var idx: PackedInt32Array = a["idx"]
	if n.dot(hint) > 0.0:
		idx.append(ia); idx.append(ic); idx.append(ib)
	else:
		idx.append(ia); idx.append(ib); idx.append(ic)

func _new_a() -> Dictionary:
	return {"verts": PackedVector3Array(), "norms": PackedVector3Array(), "cols": PackedColorArray(), "idx": PackedInt32Array()}

func _arrs(a: Dictionary) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = a["verts"]
	out[Mesh.ARRAY_NORMAL] = a["norms"]
	out[Mesh.ARRAY_COLOR] = a["cols"]
	out[Mesh.ARRAY_INDEX] = a["idx"]
	return out

func _squircle(a: float, b: float, n: float, th: float) -> Vector2:
	var cx := cos(th); var sy := sin(th)
	var ax: float = abs(cx); var ay: float = abs(sy)
	return Vector2(a * sign(cx) * pow(ax, 2.0 / n), b * sign(sy) * pow(ay, 2.0 / n))

# 单层饼干（带扇贝边 + 圆角矩形 + 顶部/底部穹顶 + 可选凹点）
func _biscuit_layer(a: Dictionary, yc: float, ha: float, hb: float, slab_top: float, dome: float, col: Color, scallop: float, scallop_n: int, dim_top: bool, dim_bot: bool) -> void:
	var M := SEG
	var Rmax := sqrt(ha * ha + hb * hb)
	var top := PackedInt32Array(); var bot := PackedInt32Array()
	for k in M + 1:
		var th := TAU * float(k) / float(M)
		var base := _squircle(ha, hb, 4.0, th)
		var sc := 1.0 + scallop * cos(float(scallop_n) * th)
		var p := base * sc
		var r := p.length() / Rmax
		var dy := dome * (1.0 - r * r)
		var ytop := yc + slab_top + dy
		var ybot := yc - slab_top - dy
		top.append(_av(a, Vector3(p.x, ytop, p.y), Vector3(0, 1, 0), col))
		bot.append(_av(a, Vector3(p.x, ybot, p.y), Vector3(0, -1, 0), col))
	var ctop := _av(a, Vector3(0, yc + slab_top + dome, 0), Vector3(0, 1, 0), col)
	var cbot := _av(a, Vector3(0, yc - slab_top - dome, 0), Vector3(0, -1, 0), col)
	for k in M:
		var mid := TAU * (float(k) + 0.5) / float(M)
		var hint := Vector3(cos(mid), 0, sin(mid))
		_tri(a, ctop, top[k], top[k + 1], Vector3(0, 1, 0))
		_tri(a, cbot, bot[k + 1], bot[k], Vector3(0, -1, 0))
		_tri(a, top[k], bot[k], bot[k + 1], hint)
		_tri(a, top[k], bot[k + 1], top[k + 1], hint)
	if dim_top:
		_dots(a, true, yc + slab_top + 0.002, C_BISCUIT_DARK)
	if dim_bot:
		_dots(a, false, yc - slab_top - 0.002, C_BISCUIT_DARK)

func _dots(a: Dictionary, up: bool, ylev: float, col: Color) -> void:
	var pts := [
		Vector2(-0.45, -0.30), Vector2(0.0, -0.36), Vector2(0.45, -0.30),
		Vector2(-0.45, 0.0), Vector2(0.0, 0.0), Vector2(0.45, 0.0),
		Vector2(-0.45, 0.30), Vector2(0.0, 0.36), Vector2(0.45, 0.30),
	]
	var n: Vector3 = Vector3(0, 1, 0) if up else Vector3(0, -1, 0)
	for p in pts:
		var c := _av(a, Vector3(p.x, ylev, p.y), n, col)
		var ring := PackedInt32Array()
		for j in 12:
			var ang := TAU * float(j) / 12.0
			ring.append(_av(a, Vector3(p.x + cos(ang) * 0.05, ylev, p.y + sin(ang) * 0.05), n, col))
		for j in 12:
			if up:
				_tri(a, c, ring[j], ring[(j + 1) % 12], n)
			else:
				_tri(a, c, ring[(j + 1) % 12], ring[j], n)

# ---- 盾牌 ----
func _ring_xy(a: Dictionary, r: float, z: float, col: Color, seg: int, nrm: Vector3) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in seg + 1:
		var ang := TAU * float(k) / float(seg)
		out.append(_av(a, Vector3(cos(ang) * r, sin(ang) * r, z), nrm, col))
	return out

func _shield_face(a: Dictionary, Rf: float, Zf: float, col: Color, seg: int) -> void:
	var center := _av(a, Vector3(0, 0, Zf + 0.02), Vector3(0, 0, 1), col)
	var prev := PackedInt32Array()
	for j in 8:
		var t := float(j) / 7.0
		var r := Rf * t
		var z := 0.02 + Zf * (1.0 - t * t)
		var comp := 2.0 * Zf * r / (Rf * Rf)
		var ring := PackedInt32Array()
		for k in seg + 1:
			var ang := TAU * float(k) / float(seg)
			var nrm := Vector3(cos(ang) * comp, sin(ang) * comp, 1.0).normalized()
			ring.append(_av(a, Vector3(cos(ang) * r, sin(ang) * r, z), nrm, col))
		if prev.is_empty():
			for k in seg:
				_tri(a, center, ring[k], ring[k + 1], Vector3(0, 0, 1))
		else:
			for k in seg:
				var hint := Vector3(cos(TAU * (float(k) + 0.5) / float(seg)), sin(TAU * (float(k) + 0.5) / float(seg)), 1.0).normalized()
				_tri(a, prev[k], ring[k], ring[k + 1], hint)
				_tri(a, prev[k], ring[k + 1], prev[k + 1], hint)
		prev = ring

func _dome_xy(a: Dictionary, cx: float, cy: float, R: float, base_z: float, peak_z: float, col: Color, sseg: int) -> void:
	var cent := _av(a, Vector3(cx, cy, peak_z), Vector3(0, 0, 1), col)
	var rings := []
	for j in sseg + 1:
		var t := float(j) / float(sseg)
		var r := R * t
		var z := base_z + (peak_z - base_z) * sqrt(maxf(0.0, 1.0 - t * t))
		var ring := PackedInt32Array()
		for k in sseg + 1:
			var ang := TAU * float(k) / float(sseg)
			var nrm := Vector3(cos(ang) * t, sin(ang) * t, sqrt(maxf(0.0, 1.0 - t * t))).normalized()
			ring.append(_av(a, Vector3(cx + cos(ang) * r, cy + sin(ang) * r, z), nrm, col))
		rings.append(ring)
	for k in sseg:
		_tri(a, cent, rings[0][k], rings[0][k + 1], Vector3(0, 0, 1))
	for j in sseg - 1:
		for k in sseg:
			var hint := Vector3(cos(TAU * (float(k) + 0.5) / float(sseg)) * (float(j) / float(sseg)), sin(TAU * (float(k) + 0.5) / float(sseg)) * (float(j) / float(sseg)), 0.4).normalized()
			_tri(a, rings[j][k], rings[j][k + 1], rings[j + 1][k + 1], hint)
			_tri(a, rings[j][k], rings[j + 1][k + 1], rings[j + 1][k], hint)

func _shield_metal(sh: Dictionary, me: Dictionary, Rf: float, Rr: float) -> void:
	# 前金属环带（齐平 z=0.02）
	var rin := _ring_xy(sh, Rf, 0.02, C_METAL, S_SHD, Vector3(0, 0, 1))
	var rout := _ring_xy(sh, Rr, 0.02, C_METAL, S_SHD, Vector3(0, 0, 1))
	for k in S_SHD:
		_tri(sh, rin[k], rout[k], rout[k + 1], Vector3(0, 0, 1))
		_tri(sh, rin[k], rout[k + 1], rin[k + 1], Vector3(0, 0, 1))
	# 后金属环带（z=-0.05）
	var rinb := _ring_xy(sh, Rf, -0.05, C_METAL, S_SHD, Vector3(0, 0, -1))
	var routb := _ring_xy(sh, Rr, -0.05, C_METAL, S_SHD, Vector3(0, 0, -1))
	for k in S_SHD:
		_tri(sh, rinb[k], routb[k + 1], routb[k], Vector3(0, 0, -1))
		_tri(sh, rinb[k], rinb[k + 1], routb[k + 1], Vector3(0, 0, -1))
	# 外圈波浪壁
	var fr := PackedInt32Array(); var ba := PackedInt32Array()
	for k in S_SHD + 1:
		var th := TAU * float(k) / float(S_SHD)
		var R := Rr + 0.035 * cos(18.0 * th)
		fr.append(_av(me, Vector3(cos(th) * R, sin(th) * R, 0.02), Vector3(cos(th), sin(th), 0), C_METAL))
		ba.append(_av(me, Vector3(cos(th) * R, sin(th) * R, -0.05), Vector3(cos(th), sin(th), 0), C_METAL))
	for k in S_SHD:
		var hint := Vector3(cos(TAU * (float(k) + 0.5) / float(S_SHD)), sin(TAU * (float(k) + 0.5) / float(S_SHD)), 0)
		_tri(me, fr[k], ba[k], ba[k + 1], hint)
		_tri(me, fr[k], ba[k + 1], fr[k + 1], hint)
	# 中心铆钉 x8
	for i in 8:
		var ang := TAU * float(i) / 8.0
		_dome_xy(me, cos(ang) * 0.9, sin(ang) * 0.9, 0.05, 0.06, 0.14, C_METAL, 10)
	# 中心凸台
	_dome_xy(me, 0, 0, 0.22, 0.14, 0.34, C_METAL, 14)

func _biscuit_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	return m

func _metal_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.metallic = 0.55
	m.roughness = 0.35
	return m

func _build_biscuit() -> ArrayMesh:
	var bis := _new_a()
	_biscuit_layer(bis, -0.17, 0.95, 0.68, 0.085, 0.05, C_BISCUIT, 0.045, 22, false, true)
	_biscuit_layer(bis, 0.0, 0.88, 0.62, 0.075, 0.02, C_CREAM, 0.04, 22, false, false)
	_biscuit_layer(bis, 0.17, 0.95, 0.68, 0.085, 0.05, C_BISCUIT, 0.045, 22, true, false)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrs(bis))
	m.surface_set_material(0, _biscuit_material())
	return m

func _build_shield() -> ArrayMesh:
	var sh := _new_a()
	var me := _new_a()
	_shield_face(sh, 0.95, 0.12, C_BISCUIT, S_SHD)
	# 前脸上凹点
	for p in [Vector2(-0.4, -0.25), Vector2(0.4, -0.25), Vector2(-0.4, 0.25), Vector2(0.4, 0.25), Vector2(0, 0)]:
		var c := _av(sh, Vector3(p.x, p.y, 0.13), Vector3(0, 0, 1), C_BISCUIT_DARK)
		var ring := PackedInt32Array()
		for j in 10:
			var ang := TAU * float(j) / 10.0
			ring.append(_av(sh, Vector3(p.x + cos(ang) * 0.05, p.y + sin(ang) * 0.05, 0.13), Vector3(0, 0, 1), C_BISCUIT_DARK))
		for j in 10:
			_tri(sh, c, ring[j], ring[(j + 1) % 10], Vector3(0, 0, 1))
	_shield_metal(sh, me, 0.92, 1.12)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrs(sh))
	m.surface_set_material(0, _biscuit_material())
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrs(me))
	m.surface_set_material(1, _metal_material())
	return m

func _initialize() -> void:
	var mb := _build_biscuit()
	var e1 := ResourceSaver.save(mb, "res://assets/meshes/biscuit.tres")
	print("BISCUIT_SAVE err=", e1)
	var ms := _build_shield()
	var e2 := ResourceSaver.save(ms, "res://assets/meshes/biscuit_shield.tres")
	print("SHIELD_SAVE err=", e2)
	quit()
