extends SceneTree
# 程序化生成灯塔网格（顶点色条纹），保存到 res://assets/meshes/lighthouse.tres

const SEG := 28
const C_STONE := Color(0.55, 0.53, 0.50)
const C_STONE2 := Color(0.63, 0.61, 0.58)
const C_CREAM := Color(0.85, 0.80, 0.72)
const C_BAND := Color(0.56, 0.38, 0.32)
const C_WEATHER := Color(0.70, 0.66, 0.61)
const C_DARK := Color(0.25, 0.23, 0.20)
const C_GLASS := Color(0.92, 0.86, 0.62)

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()

func _initialize() -> void:
	_build()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var err := ResourceSaver.save(mesh, "res://assets/meshes/lighthouse.tres")
	print("LH_SAVE err=", err, " verts=", verts.size(), " tris=", idx.size() / 3)
	quit()

func _build() -> void:
	# 圆形基座平台 + 木桩环
	_lathe([[0.0, 6.0, C_STONE], [0.8, 6.0, C_STONE]])
	_cap(0.0, 6.0, C_STONE, false)
	_cap(0.8, 6.0, C_STONE2, true)
	for k in 20:
		var ang := TAU * float(k) / 20.0
		var off := Vector3(cos(ang), 0, sin(ang)) * 5.45
		_lathe([[0.0, 0.13, C_DARK], [1.25, 0.13, C_DARK]], 6, off)
	# 第二级基座
	_lathe([[0.8, 3.3, C_STONE2], [1.8, 3.3, C_STONE2]])
	_cap(1.8, 3.3, C_STONE, true)
	# 塔身（锥形条纹）
	var rows: Array = []
	var ycs := [
		[1.6, C_CREAM], [3.0, C_CREAM], [4.5, C_CREAM], [6.0, C_CREAM],
		[7.48, C_CREAM], [7.52, C_BAND], [9.0, C_BAND], [10.5, C_BAND],
		[11.48, C_BAND], [11.52, C_CREAM], [13.0, C_CREAM], [14.5, C_CREAM],
		[16.0, C_CREAM], [17.5, C_CREAM], [18.98, C_CREAM], [19.02, C_WEATHER],
		[20.5, C_WEATHER], [22.0, C_WEATHER],
	]
	for yc in ycs:
		rows.append([yc[0], _tower_r(yc[0]), yc[1]])
	_lathe(rows)
	_cap(1.6, _tower_r(1.6), C_DARK, false)
	# 观景台
	_lathe([[22.0, 1.15, C_DARK], [22.15, 1.8, C_DARK], [22.4, 1.8, C_DARK]])
	_cap(22.4, 1.8, C_DARK, true)
	_cap(22.15, 1.8, C_DARK, false)
	for k in 12:
		var ang2 := TAU * float(k) / 12.0
		var off2 := Vector3(cos(ang2), 0, sin(ang2)) * 1.68
		_lathe([[22.4, 0.045, C_DARK], [23.5, 0.045, C_DARK]], 6, off2)
	_lathe([[22.85, 1.68, C_DARK], [22.95, 1.68, C_DARK]])
	_lathe([[23.42, 1.68, C_DARK], [23.54, 1.68, C_DARK]])
	# 灯室：锈色环廊 + 玻璃灯房 + 顶盘
	_lathe([[22.4, 1.1, C_BAND], [23.6, 1.1, C_BAND]])
	_lathe([[23.6, 0.95, C_DARK], [23.75, 0.95, C_DARK]])
	_lathe([[23.75, 0.8, C_GLASS], [24.55, 0.8, C_GLASS]])
	_lathe([[24.55, 0.9, C_DARK], [24.75, 0.9, C_DARK]])
	_cap(24.75, 0.9, C_DARK, true)
	# 穹顶 + 顶针
	_dome(24.75, 0.92, C_DARK)
	_lathe([[25.65, 0.07, C_DARK], [25.95, 0.02, C_DARK]], 8)

func _tower_r(y: float) -> float:
	return lerpf(2.3, 1.15, clampf((y - 1.6) / 20.4, 0.0, 1.0))

func _dome(yb: float, r: float, c: Color) -> void:
	var rows: Array = []
	for j in 9:
		var phi := PI * 0.5 * float(j) / 8.0
		rows.append([yb + r * cos(phi), maxf(r * sin(phi), 0.02), c])
	_lathe(rows)

func _add_v(p: Vector3, n: Vector3, c: Color) -> int:
	verts.append(p)
	norms.append(n)
	cols.append(c)
	return verts.size() - 1

func _tri(a: int, b: int, c: int, hint: Vector3) -> void:
	# Godot 顺时针为正面：右手法线若朝外则翻转绕序
	var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if n.dot(hint) > 0.0:
		idx.append(a); idx.append(c); idx.append(b)
	else:
		idx.append(a); idx.append(b); idx.append(c)

func _ring(y: float, r: float, c: Color, seg: int, off: Vector3) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in seg + 1:
		var ang := TAU * float(k) / float(seg)
		var d := Vector3(cos(ang), 0, sin(ang))
		out.append(_add_v(Vector3(d.x * r, y, d.z * r) + off, d, c))
	return out

func _lathe(rows: Array, seg := SEG, off := Vector3.ZERO) -> void:
	var prev := PackedInt32Array()
	for row in rows:
		var cur := _ring(row[0], row[1], row[2], seg, off)
		if prev.size() > 0:
			for k in seg:
				var mid := TAU * (float(k) + 0.5) / float(seg)
				var hint := Vector3(cos(mid), 0, sin(mid))
				_tri(prev[k], prev[k + 1], cur[k + 1], hint)
				_tri(prev[k], cur[k + 1], cur[k], hint)
		prev = cur

func _cap(y: float, r: float, c: Color, up: bool) -> void:
	var n := Vector3.UP if up else Vector3.DOWN
	var center := _add_v(Vector3(0, y, 0), n, c)
	var ring := PackedInt32Array()
	for k in SEG:
		var ang := TAU * float(k) / float(SEG)
		ring.append(_add_v(Vector3(cos(ang) * r, y, sin(ang) * r), n, c))
	for k in SEG:
		_tri(center, ring[k], ring[(k + 1) % SEG], n)
