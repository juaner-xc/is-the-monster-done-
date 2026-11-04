@tool
extends MeshInstance3D

func _ready() -> void:
	if mesh == null or mesh.get_faces().size() == 0:
		_build()

func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# 中心六角板
	_hex_prism(st, Vector3(0, 0, -0.035), Vector3(0, 0, 0.035), 0.2, 0.2)

	# 6 条主臂
	for k in 6:
		_arm(st, float(k) * TAU / 6.0)

	# 周围虚化雪点
	for i in 30:
		var ang := rng.randf() * TAU
		var zc := rng.randf_range(-1.0, 1.0)
		var dc := sqrt(1.0 - zc * zc)
		var dirv := Vector3(dc * cos(ang), dc * sin(ang), zc)
		var dist := rng.randf_range(2.6, 4.4)
		var r := rng.randf_range(0.02, 0.06)
		var c := dirv * dist
		_hex_prism(st, c + Vector3(0, 0, -r), c + Vector3(0, 0, r), r, r)

	var m := ArrayMesh.new()
	st.commit(m)
	mesh = m

func _arm(st: SurfaceTool, rot: float) -> void:
	# 主枝（微微收细）
	_hex_prism(st, _pt(0.08, 0, rot), _pt(1.45, 0, rot), 0.055, 0.04)
	# 尖梢（六棱锥尖）
	_hex_prism(st, _pt(1.45, 0, rot), _pt(1.75, 0, rot), 0.04, 0.004)
	# 成对分支，越靠中越短
	var ts := [0.35, 0.6, 0.85, 1.1]
	var ls := [0.3, 0.4, 0.48, 0.52]
	for i in 4:
		for sgn in [1.0, -1.0]:
			var start := _pt(ts[i], 0, rot)
			var endp := _pt(ts[i] + ls[i] * 0.5, sgn * ls[i] * 0.866, rot)
			_hex_prism(st, start, endp, 0.032, 0.008)
			# 长分支上的小次级冰针
			if i >= 2:
				var mx: float = ts[i] + ls[i] * 0.25
				var my: float = sgn * ls[i] * 0.433
				_hex_prism(st, _pt(mx, my, rot), _pt(mx + 0.12, my + sgn * 0.07, rot), 0.016, 0.004)

func _pt(x: float, y: float, rot: float) -> Vector3:
	return Vector3(x * cos(rot) - y * sin(rot), x * sin(rot) + y * cos(rot), 0)

func _hex_prism(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var dir := b - a
	var l := dir.length()
	if l < 0.0001:
		return
	dir /= l
	var ref := Vector3.UP if abs(dir.y) < 0.99 else Vector3.RIGHT
	var s1 := dir.cross(ref).normalized()
	var s2 := dir.cross(s1).normalized()
	var ring0 := []
	var ring1 := []
	for i in 6:
		var a1 := TAU * float(i) / 6.0
		var a2 := TAU * float(i + 1) / 6.0
		var p0a := a + (s1 * cos(a1) + s2 * sin(a1)) * r0
		var p0b := a + (s1 * cos(a2) + s2 * sin(a2)) * r0
		var p1a := b + (s1 * cos(a1) + s2 * sin(a1)) * r1
		var p1b := b + (s1 * cos(a2) + s2 * sin(a2)) * r1
		ring0.append(p0a)
		ring1.append(p1a)
		var mid := (p0a + p0b + p1a + p1b) * 0.25
		var axis_mid := (a + b) * 0.5
		_tri(st, p0a, p0b, p1b, mid - axis_mid)
		_tri(st, p0a, p1b, p1a, mid - axis_mid)
	# 端盖
	for i in 6:
		var i2 := (i + 1) % 6
		_tri(st, a, ring0[i], ring0[i2], -dir)
		_tri(st, b, ring1[i2], ring1[i], dir)

func _tri(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, outward: Vector3) -> void:
	var n := (p2 - p1).cross(p3 - p1)
	if n.dot(outward) < 0.0:
		var tmp := p2
		p2 = p3
		p3 = tmp
		n = -n
	st.set_normal(n.normalized())
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p3)
