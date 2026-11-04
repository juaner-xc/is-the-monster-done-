extends SceneTree
## 第二章「火山洞窟」场景生成器（仅产出美术资源与静态场景，不含任何玩法/交互脚本）
## 用法：Godot_v4.7.2-stable_win64.exe --headless --path . --script res://scripts/gen_cave02.gd
## 产出：
##   assets/chapter2/textures/rock_diffuse.png、smoke_puff.png
##   assets/chapter2/meshes/*.tres
##   scenes/chapter2/volcano_cave.tscn

const SCENE_PATH := "res://scenes/chapter2/volcano_cave.tscn"
const MESH_DIR := "res://assets/chapter2/meshes"
const TEXTURE_DIR := "res://assets/chapter2/textures"
const MAT_DIR := "res://assets/chapter2/materials"
const SHAPE_DIR := "res://assets/chapter2/shapes"

const ROOT_SCRIPT := "res://scripts/chapter2/volcano_cave.gd"
# 食材 / 料理台脚本与配置：当前阶段第二章为纯场景，暂不挂载，恢复玩法时照下面常量取用
const STATION_SCRIPT := "res://scripts/chapter2/cooking_station.gd"
const INGREDIENT_SCRIPT := "res://scripts/chapter2/cave_ingredient.gd"
const INGREDIENT_IDS := ["chocolate", "cream", "butter", "sugar"]
const INGREDIENT_PER_TYPE := 3

# 地面与第一章雪原同尺寸：第一章地面是 800×800 的平面（半径 400），这里取 399
# 让地形外沿刚好落在世界半径内侧。侧壁取消后，四周是开放远景（红褐色渐变）。
const TERRAIN_RADIUS := 399.0
const CAVE_RADIUS := 400.0
# 天花板：34 m 的穹顶，外沿一路收拢到地面，把洞重新"合上"（参考图是封闭洞窟，
# 不是露天旷野）。抬太高钟乳石就只剩小点，压太低又顶到视线。
const CAVE_HEIGHT := 34.0
# 半径从 60 涨到 400，网格必须同步加密：TERRAIN_BIAS 让环向"近密远疏"
# （近处活动区约 2~3 m 一格，远处几十米一格，远景本来就被雾吃掉）
const TERRAIN_RINGS := 80
const TERRAIN_SECTORS := 144
const TERRAIN_BIAS := 1.7
# 天花板是主背景，密度提上来才挂得住钟乳石和大块岩石轮廓
const CEILING_RINGS := 44
const CEILING_SECTORS := 128

# 空间变大，装饰物数量同步增加，避免地面空旷
const POOL_COUNT := 6
const TREE_COUNT := 11
const TENT_COUNT := 4
const UTENSIL_COUNT := 12
const ROCK_COUNT := 22
const STALACTITE_COUNT := 30
# 地面裂缝（参考图里岩板之间透出的橙光）
const CRACK_COUNT := 85
# 正前方的大熔岩湖：参考图的视觉主体，也是全场主要的暖光来源
const LAKE_Z := -96.0
const LAKE_RADIUS := 58.0
# 洞顶与钟乳石上的萤石簇数量（挂在钟乳石身上的另算）
const FLUORITE_COUNT := 90
const SEED := 20261028

# 装饰物整体放大倍率（缩放挂在父节点上，子节点的网格 / 碰撞会一起放大）
const TENT_SCALE := 2.0
const STOVE_SCALE := 1.5

# 碰撞层（数值即 collision_layer 位掩码）
const LAYER_WORLD := 1    # 地形 / 洞壁 / 装饰物静态碰撞
const LAYER_ACTOR := 2    # 角色（后续玩家、怪物）
const LAYER_LAVA := 4     # 岩浆区域（Area3D 标记）
const LAYER_INTERACT := 8 # 可交互区域（灶台等，预留）

var _pools := []
var _mats := {}


# ---------------------------------------------------------------- 网格累加器
class MeshBuilder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()

	func _push(p: Vector3, n: Vector3, c: Color, uv: Vector2) -> void:
		verts.append(p)
		normals.append(n)
		cols.append(c)
		uvs.append(uv)

	func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color,
			uva := Vector2(0.0, 0.0), uvb := Vector2(1.0, 0.0), uvc := Vector2(1.0, 1.0)) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() > 1e-8:
			n = n.normalized()
		else:
			n = Vector3.UP
		_push(a, n, col, uva)
		_push(b, n, col, uvb)
		_push(c, n, col, uvc)

	## 指定法线写三角形：绕序与法线解耦，用于需要"绕序朝内、法线朝外"的场合
	func _tri_n(a: Vector3, b: Vector3, c: Vector3, col: Color, n: Vector3,
			uva := Vector2(0.0, 0.0), uvb := Vector2(1.0, 0.0), uvc := Vector2(1.0, 1.0)) -> void:
		_push(a, n, col, uva)
		_push(b, n, col, uvb)
		_push(c, n, col, uvc)

	func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
		_tri(a, b, c, col, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
		_tri(a, c, d, col, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))

	func _quad_uv(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color,
			uva: Vector2, uvb: Vector2, uvc: Vector2, uvd: Vector2) -> void:
		_tri(a, b, c, col, uva, uvb, uvc)
		_tri(a, c, d, col, uva, uvc, uvd)

	func is_empty() -> bool:
		return verts.is_empty()

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if verts.is_empty():
			return mesh
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return mesh


# ---------------------------------------------------------------- 噪声
func _hashf(x: float, y: float, seed: int) -> float:
	var s := sin(x * 127.1 + y * 311.7 + float(seed) * 0.731) * 43758.5453
	return s - floor(s)


func _noise2(x: float, y: float, seed: int) -> float:
	var xi: float = floor(x)
	var yi: float = floor(y)
	var xf: float = x - xi
	var yf: float = y - yi
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = yf * yf * (3.0 - 2.0 * yf)
	var a := _hashf(xi, yi, seed)
	var b := _hashf(xi + 1.0, yi, seed)
	var c := _hashf(xi, yi + 1.0, seed)
	var d := _hashf(xi + 1.0, yi + 1.0, seed)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


func _fbm2(x: float, y: float, oct: int, seed: int) -> float:
	var sum := 0.0
	var amp := 0.5
	var norm := 0.0
	var f := 1.0
	for i in oct:
		sum += _noise2(x * f, y * f, seed + i * 97) * amp
		norm += amp
		amp *= 0.5
		f *= 2.0
	return sum / norm


func _wrapi(v: int, period: int) -> int:
	return ((v % period) + period) % period


func _hash_tile(xi: int, yi: int, period: int, seed: int) -> float:
	var s := sin(float(_wrapi(xi, period)) * 12.9898
			+ float(_wrapi(yi, period)) * 78.233 + float(seed) * 0.731) * 43758.5453
	return s - floor(s)


func _noise_tile(u: float, v: float, freq: int, seed: int) -> float:
	var x := u * float(freq)
	var y := v * float(freq)
	var xi := int(floor(x))
	var yi := int(floor(y))
	var xf := x - float(xi)
	var yf := y - float(yi)
	var s1 := xf * xf * (3.0 - 2.0 * xf)
	var s2 := yf * yf * (3.0 - 2.0 * yf)
	var a := _hash_tile(xi, yi, freq, seed)
	var b := _hash_tile(xi + 1, yi, freq, seed)
	var c := _hash_tile(xi, yi + 1, freq, seed)
	var d := _hash_tile(xi + 1, yi + 1, freq, seed)
	return lerpf(lerpf(a, b, s1), lerpf(c, d, s1), s2)


func _fbm_tile(u: float, v: float, base_freq: int, oct: int, seed: int) -> float:
	var sum := 0.0
	var amp := 0.5
	var norm := 0.0
	var f := base_freq
	for i in oct:
		sum += _noise_tile(u, v, f, seed + i * 131) * amp
		norm += amp
		amp *= 0.5
		f *= 2
	return sum / norm


# ---------------------------------------------------------------- 通用几何
func _tube(mb: MeshBuilder, p0: Vector3, p1: Vector3, r0: float, r1: float,
		seg: int, col: Color) -> void:
	var axis := (p1 - p0)
	if axis.length_squared() < 1e-6:
		return
	axis = axis.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 1e-4:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(axis).normalized()
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var v00 := p0 + d0 * r0
		var v01 := p0 + d1 * r0
		var v10 := p1 + d0 * r1
		var v11 := p1 + d1 * r1
		_oriented_quad(mb, v00, v01, v11, v10, col, d0)


func _cone(mb: MeshBuilder, base: Vector3, radius: float, height: float,
		seg: int, col: Color) -> void:
	var apex := base + Vector3(0.0, height, 0.0)
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var b0 := base + d0 * radius
		var b1 := base + d1 * radius
		var n := (d0 + d1).normalized()
		if height < 0.0:
			_tri_oriented(mb, apex, b1, b0, col, n)
		else:
			_tri_oriented(mb, apex, b0, b1, col, n)


## Godot 的可见面法线为 -((b-a)×(c-a))：绕序要让几何法线与 outward 反向，
## 存储法线仍取 outward，否则装饰物会被背面剔除（表现为"能看穿帐篷、只看到内壁"）。
func _tri_oriented(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3,
		col: Color, outward: Vector3) -> void:
	var geo := (b - a).cross(c - a)
	if geo.dot(outward) > 0.0:
		mb._tri_n(a, c, b, col, outward)
	else:
		mb._tri_n(a, b, c, col, outward)


func _oriented_quad(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		col: Color, outward: Vector3) -> void:
	var geo := (b - a).cross(c - a)
	if geo.dot(outward) > 0.0:
		mb._tri_n(a, c, b, col, outward)
		mb._tri_n(a, d, c, col, outward)
	else:
		mb._tri_n(a, b, c, col, outward)
		mb._tri_n(a, c, d, col, outward)


func _box(mb: MeshBuilder, center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	# +X / -X
	_oriented_quad(mb, center + Vector3(h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, h.z),
			center + Vector3(h.x, h.y, h.z), center + Vector3(h.x, h.y, -h.z), col, Vector3.RIGHT)
	_oriented_quad(mb, center + Vector3(-h.x, -h.y, h.z), center + Vector3(-h.x, -h.y, -h.z),
			center + Vector3(-h.x, h.y, -h.z), center + Vector3(-h.x, h.y, h.z), col, Vector3.LEFT)
	# +Y / -Y
	_oriented_quad(mb, center + Vector3(-h.x, h.y, -h.z), center + Vector3(h.x, h.y, -h.z),
			center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z), col, Vector3.UP)
	_oriented_quad(mb, center + Vector3(-h.x, -h.y, h.z), center + Vector3(h.x, -h.y, h.z),
			center + Vector3(h.x, -h.y, -h.z), center + Vector3(-h.x, -h.y, -h.z), col, Vector3.DOWN)
	# +Z / -Z
	_oriented_quad(mb, center + Vector3(h.x, -h.y, h.z), center + Vector3(-h.x, -h.y, h.z),
			center + Vector3(-h.x, h.y, h.z), center + Vector3(h.x, h.y, h.z), col, Vector3.BACK)
	_oriented_quad(mb, center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
			center + Vector3(h.x, h.y, -h.z), center + Vector3(-h.x, h.y, -h.z), col, Vector3.FORWARD)


func _blob(mb: MeshBuilder, center: Vector3, radius: float, seedv: int, col: Color,
		squash := 1.0) -> void:
	var rings := 6
	var sectors := 9
	for i in rings:
		var t0 := PI * float(i) / float(rings)
		var t1 := PI * float(i + 1) / float(rings)
		for j in sectors:
			var a0 := TAU * float(j) / float(sectors)
			var a1 := TAU * float(j + 1) / float(sectors)
			var p00 := _blob_point(t0, a0, radius, seedv, squash)
			var p01 := _blob_point(t0, a1, radius, seedv, squash)
			var p10 := _blob_point(t1, a0, radius, seedv, squash)
			var p11 := _blob_point(t1, a1, radius, seedv, squash)
			var ref := (center + (p00 + p01 + p10 + p11) * 0.25) - center
			_oriented_quad(mb, center + p00, center + p01, center + p11, center + p10, col, ref)


func _blob_point(t: float, a: float, radius: float, seedv: int, squash: float) -> Vector3:
	var dir := Vector3(sin(t) * cos(a), cos(t), sin(t) * sin(a))
	var n := _fbm2(dir.x * 2.0 + float(seedv), dir.z * 2.0 + dir.y * 1.7, 3, seedv + 7)
	var r := radius * (0.72 + 0.5 * n)
	return Vector3(dir.x * r, dir.y * r * squash, dir.z * r)


# ---------------------------------------------------------------- 贴图
func _gen_rock_texture() -> void:
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var v := float(y) / float(size)
		for x in size:
			var u := float(x) / float(size)
			var plate := _fbm_tile(u, v, 4, 3, 23)
			var grain := _fbm_tile(u, v, 16, 4, 11)
			var crack := 1.0 - smoothstep(0.0, 0.055, _fbm_tile(u, v, 6, 2, 37))
			var rust := smoothstep(0.52, 0.92, _fbm_tile(u, v, 3, 2, 51))
			var c := Color(0.30, 0.28, 0.26).lerp(Color(0.60, 0.57, 0.54), plate)
			c = c * (0.72 + 0.55 * grain)
			c = c.lerp(Color(0.52, 0.38, 0.30), rust * 0.55)
			c = c.lerp(Color(0.12, 0.11, 0.11), crack * 0.8)
			img.set_pixel(x, y, c)
	_save_png(img, "rock_diffuse.png")


func _gen_smoke_texture() -> void:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var v := float(y) / float(size)
		for x in size:
			var u := float(x) / float(size)
			var d := Vector2(u - 0.5, v - 0.5).length() * 2.0
			var a := 1.0 - smoothstep(0.15, 1.0, d)
			a *= a
			var n := _fbm_tile(u, v, 4, 3, 7)
			a *= 0.55 + 0.75 * n
			img.set_pixel(x, y, Color(0.80, 0.80, 0.80, clampf(a, 0.0, 1.0)))
	_save_png(img, "smoke_puff.png")


func _save_png(img: Image, file_name: String) -> void:
	var path := ProjectSettings.globalize_path(TEXTURE_DIR + "/" + file_name)
	var err := img.save_png(path)
	print("贴图 %s -> %d" % [file_name, err])


# ---------------------------------------------------------------- 地形与洞壁
func _terrain_height(x: float, z: float) -> float:
	var h := (_fbm2(x * 0.035, z * 0.035, 3, 101) - 0.5) * 3.0
	h += (_fbm2(x * 0.09, z * 0.09, 4, 202) - 0.5) * 1.1
	h += (_fbm2(x * 0.22, z * 0.22, 3, 303) - 0.5) * 0.32
	var rad := Vector2(x, z).length()
	h *= smoothstep(2.5, 13.0, rad)
	# 外沿只留一点点隆起（1.2 m）当地平线剪影：侧壁取消后如果还抬 3.4 m，
	# 远处会竖起一道土墙，把"红褐色渐变远景"整个挡住
	h += smoothstep(TERRAIN_RADIUS * 0.88, TERRAIN_RADIUS, rad) * 1.2
	for pool in _pools:
		var d := Vector2(x - pool.x, z - pool.z).length()
		if d < pool.bowl:
			h -= pool.depth * (1.0 - smoothstep(pool.radius * 0.45, pool.bowl, d))
	return h


func _terrain_normal(x: float, z: float) -> Vector3:
	var e := 0.6
	var hx := _terrain_height(x + e, z) - _terrain_height(x - e, z)
	var hz := _terrain_height(x, z + e) - _terrain_height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func _terrain_color(x: float, z: float, h: float) -> Color:
	# 暗紫玄武岩：整体压暗并往紫蓝偏，亮部靠熔岩的暖光染出来（参考图的地面色）
	var mottle := _fbm2(x * 0.14, z * 0.14, 3, 404)
	var plate := _fbm2(x * 0.042, z * 0.042, 3, 707)
	# 顶点色会和贴图（平均 0.45）相乘，所以这里必须给到 0.4~0.65，
	# 否则最终反照率只有 0.1，灯一打还是纯黑
	var c := Color(0.40, 0.34, 0.47).lerp(Color(0.62, 0.54, 0.66), mottle)
	c = c.lerp(Color(0.30, 0.25, 0.36), plate * 0.6)
	# 高处岩脊受光稍亮，低洼处更沉
	c = c * (0.84 + 0.30 * smoothstep(-1.4, 1.6, h))
	for pool in _pools:
		var d := Vector2(x - pool.x, z - pool.z).length()
		if d < pool.bowl * 1.9:
			# 池边被岩浆烤成暗红（越近越红），而不是简单地变黑
			var t := 1.0 - smoothstep(pool.radius * 0.55, pool.bowl * 1.9, d)
			c = c.lerp(Color(0.46, 0.17, 0.07), t * 0.92)
	return c


func _build_terrain() -> Array:
	var mb := MeshBuilder.new()
	var faces := PackedVector3Array()
	for i in TERRAIN_RINGS:
		# 径向加密：均匀分布的话 400 m 半径下每环 5 m，出生点附近全是粗格子，
		# 岩浆池的碗形会直接消失。pow(i/RINGS, BIAS) 让近处密、远处疏。
		var r0 := TERRAIN_RADIUS * pow(float(i) / float(TERRAIN_RINGS), TERRAIN_BIAS)
		var r1 := TERRAIN_RADIUS * pow(float(i + 1) / float(TERRAIN_RINGS), TERRAIN_BIAS)
		for j in TERRAIN_SECTORS:
			var a0 := TAU * float(j) / float(TERRAIN_SECTORS)
			var a1 := TAU * float(j + 1) / float(TERRAIN_SECTORS)
			var pts := []
			if i == 0:
				pts = [_at(0.0, 0.0), _at(r1, a0), _at(r1, a1)]
			else:
				pts = [_at(r0, a0), _at(r0, a1), _at(r1, a1), _at(r1, a0)]
			# Godot 的可见面法线为 -((b-a)×(c-a))：绕序要让几何法线与"朝上"的解析法线相反，
			# 否则地面会被背面剔除、trimesh 碰撞也挡不住角色（第二章曾整片踩空）。
			# 坑洼处几何法线本就朝下，必须逐面判断，不能无条件翻转。
			if i == 0:
				var na := _terrain_normal(0.0, 0.0)
				var ca := _terrain_color(0.0, 0.0, _terrain_height(0.0, 0.0))
				var nb := _terrain_normal(pts[1].x, pts[1].z)
				var cb := _terrain_color(pts[1].x, pts[1].z, pts[1].y)
				var nc := _terrain_normal(pts[2].x, pts[2].z)
				var cc := _terrain_color(pts[2].x, pts[2].z, pts[2].y)
				var ns3 := [na, nb, nc]
				var cs3 := [ca, cb, cc]
				var uvs3 := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
				faces = _push_face(mb, pts, ns3, cs3, uvs3, [0, 1, 2], faces)
			else:
				var ns := []
				var cs := []
				for p in pts:
					ns.append(_terrain_normal(p.x, p.z))
					cs.append(_terrain_color(p.x, p.z, p.y))
				var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
				faces = _push_face(mb, pts, ns, cs, uvs, [0, 1, 2], faces)
				faces = _push_face(mb, pts, ns, cs, uvs, [0, 2, 3], faces)
	return [mb.commit(), faces]


## 写一个地形三角形：几何法线与 UP 同向时反转绕序，使可见面（法线 = -(b-a)×(c-a)）朝上。
## faces 与顶点顺序保持一致，供 trimesh 碰撞使用（Packed 数组是值类型，所以要返回）。
func _push_face(mb: MeshBuilder, pts: Array, ns: Array, cs: Array, uvs: Array,
		idx: Array, faces: PackedVector3Array) -> PackedVector3Array:
	var p0: Vector3 = pts[idx[0]]
	var p1: Vector3 = pts[idx[1]]
	var p2: Vector3 = pts[idx[2]]
	var flip := (p1 - p0).cross(p2 - p0).dot(Vector3.UP) > 0.0
	var order := [idx[0], idx[2], idx[1]] if flip else [idx[0], idx[1], idx[2]]
	for k in order:
		var p: Vector3 = pts[k]
		mb._push(p, ns[k], cs[k], uvs[k])
		faces.append(p)
	return faces


func _at(r: float, a: float) -> Vector3:
	var x := cos(a) * r
	var z := sin(a) * r
	return Vector3(x, _terrain_height(x, z), z)


## 天花板高度：中心 58 m，向外一路收到地面（参考图是封闭洞窟，头顶必须有"顶"）。
## 收拢到 0 之后，站在任何位置平视都看不到洞外的天空，只有雾。
func _ceiling_height(r: float, a: float) -> float:
	var t := clampf(r / TERRAIN_RADIUS, 0.0, 1.0)
	var y := CAVE_HEIGHT * pow(maxf(1.0 - t, 0.0), 1.25) + 1.0
	# 岩面起伏：越往中心越夸张（钟乳石根部的团块感），外沿平缓免得出现锯齿
	var n := (_fbm2(cos(a) * 1.6 + r * 0.055, sin(a) * 1.6 - r * 0.055, 4, 505) - 0.5) * 17.0
	return y + n * (1.0 - t * 0.55)


## 天花板：原来这里生成的是"环形侧壁 + 顶盖"的封闭洞壳，现在侧壁取消，
## 只生成头顶这片岩顶。半径与地面外沿一致（TERRAIN_RADIUS），法线朝下（朝玩家）。
func _build_ceiling() -> Array:
	var mb := MeshBuilder.new()
	var faces := PackedVector3Array()
	for i in CEILING_RINGS:
		var r0 := TERRAIN_RADIUS * float(i) / float(CEILING_RINGS)
		var r1 := TERRAIN_RADIUS * float(i + 1) / float(CEILING_RINGS)
		for j in CEILING_SECTORS:
			var a0 := TAU * float(j) / float(CEILING_SECTORS)
			var a1 := TAU * float(j + 1) / float(CEILING_SECTORS)
			var q := [
				Vector3(cos(a0) * r0, _ceiling_height(r0, a0), sin(a0) * r0),
				Vector3(cos(a1) * r0, _ceiling_height(r0, a1), sin(a1) * r0),
				Vector3(cos(a1) * r1, _ceiling_height(r1, a1), sin(a1) * r1),
				Vector3(cos(a0) * r1, _ceiling_height(r1, a0), sin(a0) * r1),
			]
			var cols := []
			for p in q:
				var m := _fbm2(p.x * 0.11, p.z * 0.11, 3, 606)
				# 岩顶：靠熔岩的一圈是暖褐，往高处 / 远处沉进暗紫（参考图的天顶冷色）
				var c := Color(0.78, 0.46, 0.32).lerp(Color(0.34, 0.29, 0.44),
						smoothstep(24.0, 300.0, Vector2(p.x, p.z).length()))
				c = c * (0.70 + 0.55 * m)
				cols.append(c)
			var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			# 可见面法线 = -(b-a)×(c-a)，要让法线朝下（朝玩家）：
			# 几何法线朝上就保持绕序，朝下就翻转
			var qa: Vector3 = q[0]
			var qb: Vector3 = q[1]
			var qc: Vector3 = q[2]
			var geo := (qb - qa).cross(qc - qa)
			var order := [0, 2, 1, 0, 3, 2] if geo.dot(Vector3.DOWN) > 0.0 else [0, 1, 2, 0, 2, 3]
			for k in 6:
				var p: Vector3 = q[order[k]]
				mb._push(p, Vector3.DOWN, cols[order[k]], uvs[order[k]])
				faces.append(p)
	return [mb.commit(), faces]


# ---------------------------------------------------------------- 装饰物件
func _build_tree(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var col := Color(0.92, 0.88, 0.84)
	var h := 4.2 + rng.randf() * 2.8
	var pos := Vector3.ZERO
	var radius := 0.30
	for i in 4:
		var t1 := float(i + 1) / 4.0
		var nxt := pos + Vector3(rng.randf_range(-0.32, 0.32), h * 0.25, rng.randf_range(-0.32, 0.32))
		var r1 := maxf(radius * (1.0 - 0.72 * t1), 0.05)
		_tube(mb, pos, nxt, radius, r1, 7, col)
		if i >= 1 and rng.randf() < 0.8:
			var blen := 1.0 + rng.randf() * 1.7
			var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.35, 1.0),
					rng.randf_range(-1.0, 1.0)).normalized()
			_tube(mb, nxt, nxt + dir * blen, r1 * 0.65, 0.04, 6, col * 0.92)
		pos = nxt
		radius = r1
	for i in 5:
		var a := TAU * float(i) / 5.0 + rng.randf() * 0.6
		var rr := 0.55 + rng.randf() * 0.5
		_tube(mb, Vector3(cos(a) * 0.12, 0.28, sin(a) * 0.12),
				Vector3(cos(a) * rr, -0.18, sin(a) * rr), 0.14, 0.05, 5, col * 0.8)
	return mb.commit()


func _build_bone_rib(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var col := Color(1.0, 0.99, 0.96)
	var p := Vector3.ZERO
	var a := rng.randf() * TAU
	var dir := Vector3(cos(a), 0.0, sin(a))
	for i in 4:
		var nxt := p + dir * 0.16 + Vector3(0.0, rng.randf_range(-0.06, 0.05), 0.0)
		_tube(mb, p, nxt, 0.045, 0.032, 6, col)
		p = nxt
	return mb.commit()


func _build_bone_skull(_seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var col := Color(1.0, 0.99, 0.95)
	_box(mb, Vector3(0.0, 0.11, 0.0), Vector3(0.19, 0.15, 0.22), col)
	_box(mb, Vector3(0.0, 0.06, 0.13), Vector3(0.13, 0.08, 0.10), col * 0.95)
	for i in 2:
		var sx := -0.055 if i == 0 else 0.055
		_box(mb, Vector3(sx, 0.14, 0.05), Vector3(0.045, 0.045, 0.03), Color(0.22, 0.20, 0.19))
	return mb.commit()


func _build_bone_shards(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var col := Color(1.0, 0.99, 0.96)
	for i in 5:
		var a := rng.randf() * TAU
		var d := Vector3(cos(a), 0.0, sin(a))
		var length := 0.12 + rng.randf() * 0.16
		var p0 := d * rng.randf() * 0.25 + Vector3(0.0, 0.03 + rng.randf() * 0.05, 0.0)
		_tube(mb, p0, p0 + d * length, 0.035, 0.02, 5, col)
	return mb.commit()


func _build_tent_canvas(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var col := Color(0.88, 0.82, 0.74)
	var shade := Color(0.62, 0.56, 0.49)
	var wood := Color(0.50, 0.40, 0.32)
	var seg := 6
	# 尖顶必须落在中轴上：支架 tent_pole 固定在 x=z=0，偏了就会"顶和杆对不上"
	var apex := Vector3(0.0, 1.9, 0.0)
	var pts := []
	for i in seg:
		var a := TAU * float(i) / float(seg)
		var r := 1.55 + rng.randf_range(-0.14, 0.14)
		pts.append(Vector3(cos(a) * r, -0.05 + rng.randf_range(-0.08, 0.10), sin(a) * r))
	# 入口固定在朝向本地 +Z 的那一面（seg=6 时是第 1 面：60°~120°，中心 90°）
	var door_face := 1
	for i in seg:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % seg]
		var n := Vector3(p0.x + p1.x, 0.0, p0.z + p1.z).normalized()
		var c := col * (0.82 + 0.35 * _fbm2(p0.x, p0.z, 2, seedv + i))
		if i == door_face:
			_build_tent_door(mb, apex, p0, p1, n, c, shade, wood)
		else:
			_tri_oriented(mb, apex, p0, p1, c, n)
	_build_tent_guys(mb, pts, door_face, wood)
	return mb.commit()


## 帐篷入口：门洞 + 掀开系住的两片门帘 + 门框（立柱与门楣横杆）。
## 门洞内衬单独压暗并略微内凹，避免从外面直接看穿到空腔里。
func _build_tent_door(mb: MeshBuilder, apex: Vector3, p0: Vector3, p1: Vector3,
		n: Vector3, col: Color, shade: Color, wood: Color) -> void:
	var d0 := p0.lerp(p1, 0.26)
	var d1 := p0.lerp(p1, 0.74)
	var u0 := d0.lerp(apex, 0.55)
	var u1 := d1.lerp(apex, 0.55)
	var inner := -n * 0.12
	# 门楣与门洞两侧的帆布
	_tri_oriented(mb, apex, u0, u1, col, n)
	_oriented_quad(mb, apex, p0, d0, u0, col, n)
	_oriented_quad(mb, apex, u1, d1, p1, col, n)
	# 门洞内衬（暗）
	_oriented_quad(mb, d0 + inner, d1 + inner, u1 + inner, u0 + inner, shade * 0.32, n)
	# 掀开的门帘：底边张得开、顶边收得窄的梯形布片
	var f0 := d0 + n * 0.52
	var f1 := u0 + n * 0.30 + Vector3(0.0, 0.14, 0.0)
	_oriented_quad(mb, d0, u0, f1, f0, shade, n)
	var f2 := d1 + n * 0.52
	var f3 := u1 + n * 0.30 + Vector3(0.0, 0.14, 0.0)
	_oriented_quad(mb, d1, f2, f3, u1, shade, n)
	# 门框
	_tube(mb, d0 - Vector3(0.0, 0.04, 0.0), u0, 0.045, 0.036, 6, wood)
	_tube(mb, d1 - Vector3(0.0, 0.04, 0.0), u1, 0.045, 0.036, 6, wood)
	_tube(mb, u0, u1, 0.036, 0.036, 6, wood)


## 帐篷四周的拉绳与地钉：让帐篷是"扎在地上"的，而不是浮着的锥体（入口那侧留空）
func _build_tent_guys(mb: MeshBuilder, pts: Array, door_face: int, wood: Color) -> void:
	for i in pts.size():
		if i == door_face or i == (door_face + 1) % pts.size():
			continue
		var p: Vector3 = pts[i]
		var dir := Vector3(p.x, 0.0, p.z).normalized()
		var peg := Vector3(p.x + dir.x * 0.85, -0.10, p.z + dir.z * 0.85)
		var anchor := p.lerp(Vector3(0.0, 1.9, 0.0), 0.18)
		_tube(mb, anchor, peg, 0.014, 0.014, 4, Color(0.48, 0.42, 0.36))
		_tube(mb, peg + Vector3(0.0, 0.18, 0.0), peg + dir * 0.18 - Vector3(0.0, 0.06, 0.0),
				0.030, 0.018, 5, wood)


func _build_tent_pole() -> ArrayMesh:
	var mb := MeshBuilder.new()
	_tube(mb, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 2.05, 0.0), 0.055, 0.04, 6,
			Color(0.72, 0.68, 0.62))
	return mb.commit()


## 熔岩灶台：基石 + 三层石块错缝砌筑 + 炉膛火口（内腔 / 炭火 / 门框 / 烟熏）
## + 台面铁箅 + 侧面通风孔 + 三节石砌烟囱 + 靠着灶台的柴堆。
## 之前只是一个方盒 + 一根圆柱，远看完全没有"灶"的信息，所以这里补细节。
func _build_stove() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	var stone := Color(0.80, 0.76, 0.72)
	var stone_dark := Color(0.58, 0.54, 0.51)
	var stone_top := Color(0.32, 0.30, 0.29)
	var soot := Color(0.06, 0.05, 0.05)
	var wood := Color(0.44, 0.33, 0.24)

	_box(mb, Vector3(0.0, 0.06, 0.0), Vector3(1.34, 0.12, 1.04), stone_dark)
	# 砌体内芯：填住石块之间的缝，否则从缝里透光/积黑，看起来像散落的砖头
	_box(mb, Vector3(0.0, 0.42, 0.0), Vector3(1.16, 0.66, 0.86), stone_dark * 0.70)
	# 灶体：三层石块，逐层错缝（半块错位）并收窄，做出"石头垒出来的"而不是一个盒子
	for layer in 3:
		var y := 0.20 + float(layer) * 0.24
		var w := 1.25 - float(layer) * 0.05
		var d := 0.95 - float(layer) * 0.05
		var hw := w * 0.5
		var hd := d * 0.5
		var per_side := 4
		for side in 4:
			var lateral := side >= 2
			for k in per_side:
				var tk := (float(k) + 0.5 * float(layer % 2)) / float(per_side) - 0.5
				# 正面（z+）下两层留出拱形炉口，否则石头会把炉门糊死、正面看就是个石垛
				if side == 0 and layer <= 1 and absf(tk * w) < 0.34:
					continue
				var size := Vector3(0.30, 0.22, 0.26) if not lateral else Vector3(0.26, 0.22, 0.30)
				size.x += rng.randf_range(-0.03, 0.04)
				size.z += rng.randf_range(-0.03, 0.04)
				# 石块外侧与灶体表面齐平（中心内缩半个厚度），否则整圈石头会外凸，
				# 把炉膛口和台面都埋进去
				var inset := size.z * 0.5 - 0.02
				var pos := Vector3(
						(hw - inset) if side == 2 else (-(hw - inset) if side == 3 else tk * w), 0.0,
						(hd - inset) if side == 0 else (-(hd - inset) if side == 1 else tk * d))
				var jitter := Vector3(rng.randf_range(-0.02, 0.02),
						rng.randf_range(-0.015, 0.015), rng.randf_range(-0.02, 0.02))
				_box(mb, pos + Vector3(0.0, y, 0.0) + jitter, size,
						stone * (0.90 + 0.16 * rng.randf()))
	# 台面板（浅石台面，铁箅压在上面）与前沿挡石
	_box(mb, Vector3(0.0, 0.80, 0.0), Vector3(1.35, 0.12, 1.05), stone * 0.94)
	_box(mb, Vector3(0.0, 0.88, 0.50), Vector3(1.24, 0.08, 0.10), stone_top)
	# 炉膛：内腔（暗）+ 门框石（两根立柱 + 门楣）+ 炉口上方的烟熏
	# 炭火与铁箅拆到 _build_stove_ember / _build_stove_iron，各用各的材质
	_box(mb, Vector3(0.0, 0.44, 0.32), Vector3(0.56, 0.40, 0.34), soot)
	for i in 2:
		var sx := -0.34 if i == 0 else 0.34
		_box(mb, Vector3(sx, 0.46, 0.52), Vector3(0.11, 0.46, 0.14), stone)
	_box(mb, Vector3(0.0, 0.71, 0.52), Vector3(0.80, 0.11, 0.14), stone)
	_box(mb, Vector3(0.0, 0.62, 0.50), Vector3(0.62, 0.22, 0.05), Color(0.20, 0.17, 0.15))
	# 两侧通风孔
	for i in 2:
		var vx := -0.60 if i == 0 else 0.60
		_box(mb, Vector3(vx, 0.28, 0.0), Vector3(0.08, 0.14, 0.34), soot)
	# 烟囱：两节石砌（上下叠压无缝，避免一节一节断开）+ 根部烟熏 + 出烟口石沿
	_box(mb, Vector3(0.45, 0.92, -0.32), Vector3(0.46, 0.18, 0.46), Color(0.20, 0.17, 0.15))
	_box(mb, Vector3(0.45, 1.16, -0.32), Vector3(0.40, 0.36, 0.40), stone * 0.95)
	_box(mb, Vector3(0.45, 1.48, -0.32), Vector3(0.36, 0.36, 0.36), stone * 0.86)
	_box(mb, Vector3(0.45, 1.68, -0.32), Vector3(0.44, 0.08, 0.44), stone_top)
	# 靠着灶台斜立的柴堆
	for i in 3:
		var p0 := Vector3(-0.92 + float(i) * 0.05, 0.02, 0.34 + float(i) * 0.06)
		var p1 := Vector3(-0.52 + float(i) * 0.09, 0.44, 0.58 - float(i) * 0.10)
		_tube(mb, p0, p1, 0.055, 0.042, 6, wood * (0.85 + 0.25 * rng.randf()))
	return mb.commit()


## 灶台的铁件：台面铁箅 + 炉口前的铁栅（单独网格 → 用 mat_metal，和石材拉开材质对比）
func _build_stove_iron() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var iron := Color(0.42, 0.40, 0.38)
	for i in 4:
		_box(mb, Vector3(-0.45 + float(i) * 0.30, 0.89, 0.0), Vector3(0.06, 0.05, 0.92), iron)
	for i in 2:
		_box(mb, Vector3(-0.12 + float(i) * 0.24, 0.34, 0.50), Vector3(0.03, 0.34, 0.04), iron)
	return mb.commit()


## 炉膛里的炭火：单独网格 → mat_ember（自发光），让灶台在暗洞里"看得出在烧"
func _build_stove_ember() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3311
	var hot := Color(1.0, 0.52, 0.16)
	for i in 5:
		var s := rng.randf_range(0.04, 0.07)
		_box(mb, Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(0.26, 0.32),
				rng.randf_range(0.30, 0.42)), Vector3(s, s * 0.6, s),
				hot * (0.70 + 0.30 * rng.randf()))
	return mb.commit()


func _build_pot() -> ArrayMesh:
	var mb := MeshBuilder.new()
	_tube(mb, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.34, 0.0), 0.20, 0.24, 12,
			Color(0.86, 0.84, 0.81))
	_tube(mb, Vector3(0.0, 0.34, 0.0), Vector3(0.0, 0.38, 0.0), 0.26, 0.26, 12,
			Color(0.80, 0.78, 0.76))
	_tube(mb, Vector3(-0.24, 0.30, 0.0), Vector3(-0.36, 0.30, 0.0), 0.03, 0.03, 5,
			Color(0.80, 0.78, 0.76))
	_tube(mb, Vector3(0.24, 0.30, 0.0), Vector3(0.36, 0.30, 0.0), 0.03, 0.03, 5,
			Color(0.80, 0.78, 0.76))
	return mb.commit()


func _build_pan() -> ArrayMesh:
	var mb := MeshBuilder.new()
	_tube(mb, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.07, 0.0), 0.22, 0.24, 12,
			Color(0.84, 0.82, 0.80))
	_tube(mb, Vector3(0.22, 0.05, 0.0), Vector3(0.62, 0.09, 0.0), 0.035, 0.03, 6,
			Color(0.76, 0.73, 0.71))
	return mb.commit()


func _build_crate(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var s := 0.7 + rng.randf() * 0.3
	_box(mb, Vector3(0.0, s * 0.5, 0.0), Vector3(s, s, s), Color(0.74, 0.68, 0.60))
	_box(mb, Vector3(0.0, s * 0.85, 0.0), Vector3(s * 1.05, 0.06, s * 1.05), Color(0.62, 0.57, 0.50))
	return mb.commit()


func _build_barrel() -> ArrayMesh:
	var mb := MeshBuilder.new()
	_tube(mb, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.25, 0.0), 0.24, 0.28, 12,
			Color(0.68, 0.60, 0.50))
	_tube(mb, Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.62, 0.0), 0.28, 0.26, 12,
			Color(0.68, 0.60, 0.50))
	_tube(mb, Vector3(0.0, 0.62, 0.0), Vector3(0.0, 0.82, 0.0), 0.26, 0.24, 12,
			Color(0.62, 0.55, 0.46))
	return mb.commit()


func _build_rock_chunk(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	_blob(mb, Vector3.ZERO, 0.55 + float(seedv % 5) * 0.12, seedv, Color(0.78, 0.75, 0.72), 0.7)
	return mb.commit()


## 钟乳石：洞顶 58 m 高，原来 1~3 m 的锥体在这个尺度下只剩一个点，
## 所以做成"主锥 + 两簇偏挂的小锥"，长度 6~20 m，远看才有参考图那种垂挂岩块。
## 返回 [网格, 主锥长度]：场景装配要按长度把萤石簇挂到石身中段，
## 不然只能凭猜，晶石会浮在钟乳石外面。
func _build_stalactite(seedv: int) -> Array:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var r := 0.9 + rng.randf() * 1.9
	var length := 6.0 + rng.randf() * 14.0
	_cone(mb, Vector3.ZERO, r, -length, 8, Color(0.30, 0.26, 0.34))
	for k in 2:
		var off := Vector3(rng.randf_range(-r, r) * 0.9, 0.0, rng.randf_range(-r, r) * 0.9)
		var rr := r * (0.32 + rng.randf() * 0.28)
		_cone(mb, off, rr, -length * (0.30 + rng.randf() * 0.38), 6,
				Color(0.26, 0.22, 0.30))
	return [mb.commit(), length]


func _build_pool_surface(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var sectors := 30
	var pts := []
	for i in sectors:
		var a := TAU * float(i) / float(sectors)
		var wob := 0.80 + 0.26 * _fbm2(cos(a) * 1.3 + float(seedv), sin(a) * 1.3, 2, seedv + 11)
		pts.append(Vector3(cos(a) * wob, 0.0, sin(a) * wob))
	for i in sectors:
		# 法线朝上，绕序要让几何法线朝下（可见面 = -(b-a)×(c-a)），否则池面被剔除看不见
		mb._tri_n(Vector3.ZERO, pts[i], pts[(i + 1) % sectors], Color(1.0, 1.0, 1.0), Vector3.UP)
	return mb.commit()


func _build_fall_column(length: float, seedv: int, width := 0.55) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rows := 16
	for pass_i in 2:
		var rot := float(pass_i) * PI * 0.5
		for i in rows:
			var t0 := float(i) / float(rows)
			var t1 := float(i + 1) / float(rows)
			var sway0 := sin(t0 * 5.5 + float(seedv)) * 0.3 * t0
			var sway1 := sin(t1 * 5.5 + float(seedv)) * 0.3 * t1
			var w0 := width * (0.65 + 0.55 * t0)
			var w1 := width * (0.65 + 0.55 * t1)
			var raw := [
				Vector3(sway0 - w0, -length * t0, 0.0),
				Vector3(sway0 + w0, -length * t0, 0.0),
				Vector3(sway1 + w1, -length * t1, 0.0),
				Vector3(sway1 - w1, -length * t1, 0.0)]
			var q := []
			for p in raw:
				q.append(Vector3(p.x * cos(rot) - p.z * sin(rot), p.y, p.x * sin(rot) + p.z * cos(rot)))
			mb._quad_uv(q[0], q[1], q[2], q[3], Color(1.0, 1.0, 1.0),
					Vector2(0.0, t0), Vector2(1.0, t0), Vector2(1.0, t1), Vector2(0.0, t1))
	return mb.commit()


func _build_vent_ring() -> ArrayMesh:
	var mb := MeshBuilder.new()
	_tube(mb, Vector3(0.0, 0.9, 0.0), Vector3(0.0, -0.25, 0.0), 1.5, 0.75, 10,
			Color(0.58, 0.53, 0.50))
	return mb.commit()


## 地面裂缝：参考图里岩板之间透出的橙光是整个画面的灵魂。
## 用一批贴地的细长条带模拟（比改贴图 / 逐顶点发光省事，也不会破坏地形网格）。
## 顶点色直接当发光色（材质是 unshaded），越靠近岩浆池越亮。
func _build_cracks(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MeshBuilder.new()
	for _i in CRACK_COUNT:
		var a := rng.randf() * TAU
		# 幂次偏向近处；但出生点 14 m 内留空，否则裂缝会从玩家脚边穿过去
		var rad := 14.0 + pow(rng.randf(), 0.85) * 155.0
		var p := Vector3(cos(a) * rad, 0.0, sin(a) * rad)
		var blocked := false
		for pool in _pools:
			if Vector2(p.x - pool.x, p.z - pool.z).length() < pool.bowl * 1.02:
				blocked = true
				break
		if blocked:
			continue
		# 靠岩浆越近越亮；远处靠雾收掉，不会出现"全屏都亮"的地板灯
		var near := 0.0
		for pool in _pools:
			var d := Vector2(p.x - pool.x, p.z - pool.z).length()
			near = maxf(near, 1.0 - clampf((d - pool.radius) / 34.0, 0.0, 1.0))
		# 近处压暗、只有靠近岩浆的才亮：否则整块地面会像发光的电路板
		var col := Color(1.10, 0.26, 0.05) * (0.16 + 0.95 * near)
		var dir := rng.randf() * TAU
		var width := 0.05 + rng.randf() * 0.09
		var steps := 3 + rng.randi() % 4
		for _s in steps:
			var seg_len := 1.5 + rng.randf() * 3.0
			var nxt := p + Vector3(cos(dir) * seg_len, 0.0, sin(dir) * seg_len)
			var side := Vector3(-sin(dir), 0.0, cos(dir)) * width
			# 抬 4.5 cm 贴地：太低会被地形 z-fighting，太高会像浮在空中的光带
			var y0 := _terrain_height(p.x, p.z) + 0.045
			var y1 := _terrain_height(nxt.x, nxt.z) + 0.045
			mb._quad(Vector3(p.x, y0, p.z) - side, Vector3(nxt.x, y1, nxt.z) - side,
					Vector3(nxt.x, y1, nxt.z) + side, Vector3(p.x, y0, p.z) + side, col)
			p = nxt
			dir += rng.randf_range(-0.5, 0.5)
			width *= 0.9
	return mb.commit()


## 帐篷里的吊灯：从尖顶垂下一根细绳 + 一颗自发光灯泡。
## 灯泡的顶点色给到 3.4（> 1 才会被 glow 吃到），绳子 / 灯口是正常亮度。
## 坐标按帐篷局部空间写：尖顶 y = 1.9，灯泡挂在 1.40（帐篷整体再放大 2 倍）。
func _build_tent_lamp() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var cord := Color(0.40, 0.33, 0.26)
	var socket := Color(0.62, 0.58, 0.52)
	_tube(mb, Vector3(0.0, 1.90, 0.0), Vector3(0.0, 1.60, 0.0), 0.012, 0.012, 4, cord)
	_tube(mb, Vector3(0.0, 1.60, 0.0), Vector3(0.0, 1.50, 0.0), 0.050, 0.075, 8, socket)
	_blob(mb, Vector3(0.0, 1.40, 0.0), 0.115, 88, Color(3.4, 2.20, 1.05), 1.1)
	return mb.commit()


## 萤石簇：一小块底座 + 几根棱面尖晶石，冷色（青 / 紫 / 蓝绿）自发光。
## 顶点色直接当发光色（材质 unshaded，不参与光照），所以不需要给每簇配灯。
func _build_fluorite(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var pick := rng.randf()
	var col := Color(0.45, 1.45, 1.30)
	if pick < 0.4:
		col = Color(0.95, 0.72, 1.90)
	elif pick < 0.75:
		col = Color(0.60, 1.35, 1.90)
	# 底座压暗，只让晶石本身发光
	_blob(mb, Vector3.ZERO, 0.20, seedv + 5, col * 0.20, 0.55)
	var n := 3 + rng.randi() % 4
	for k in n:
		var a := rng.randf() * TAU
		var rad := rng.randf_range(0.0, 0.17)
		var off := Vector3(cos(a) * rad, -0.02, sin(a) * rad)
		var h := 0.22 + rng.randf() * 0.40
		var r := 0.05 + rng.randf() * 0.055
		# 上尖 + 下尖（埋进岩石里的一段），5 个面做出晶石的棱角
		_cone(mb, off, r, h, 5, col)
		_cone(mb, off, r * 0.85, -h * 0.28, 5, col * 0.5)
	return mb.commit()


# ------------------------------------------------- 营地装备（探险者 / 生活用品）
# 统一约定：物体底面落在 y = 0，+Z 为正面，尺寸按真实物件（0.3~1.6 m）。

## 背包：主包体 + 顶盖 + 两条背带 + 侧袋 + 捆扎绳 + 卷起的毯子
func _build_backpack(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var cloth := Color(0.46, 0.36, 0.24)
	var flap := Color(0.38, 0.29, 0.19)
	var strap := Color(0.26, 0.19, 0.13)
	var buckle := Color(0.78, 0.74, 0.62)
	_box(mb, Vector3(0.0, 0.34, 0.0), Vector3(0.52, 0.62, 0.30), cloth)
	_box(mb, Vector3(0.0, 0.60, 0.02), Vector3(0.55, 0.22, 0.34), flap)
	for sx in [-0.16, 0.16]:
		_tube(mb, Vector3(sx, 0.62, -0.17), Vector3(sx, 0.06, -0.19), 0.045, 0.040, 6, strap)
		_box(mb, Vector3(sx, 0.30, -0.18), Vector3(0.09, 0.06, 0.03), buckle)
	_box(mb, Vector3(0.30, 0.22, 0.0), Vector3(0.12, 0.28, 0.22), flap)
	_box(mb, Vector3(-0.30, 0.22, 0.0), Vector3(0.12, 0.28, 0.22), flap)
	_tube(mb, Vector3(-0.27, 0.50, 0.0), Vector3(0.27, 0.50, 0.0), 0.018, 0.018, 5, strap)
	# 顶上卷着的毯子
	_tube(mb, Vector3(0.0, 0.72, -0.02) + Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, 0.72, 0.30), 0.085, 0.085, 8, cloth * rng.randf_range(0.85, 1.1))
	return mb.commit()


## 斜靠着的十字镐：木柄 + 铁镐头（一侧镐尖、一侧扁铲）
func _build_pickaxe(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var wood := Color(0.44, 0.31, 0.20)
	var iron := Color(0.62, 0.63, 0.68)
	var dark := Color(0.30, 0.31, 0.34)
	_tube(mb, Vector3(-0.34, 0.02, 0.0), Vector3(0.30, 0.86, 0.0), 0.035, 0.028, 7, wood)
	_tube(mb, Vector3(0.10, 0.80, 0.0), Vector3(0.50, 0.92, 0.0), 0.045, 0.038, 6, iron)
	# 镐尖：半径收细成尖
	_tube(mb, Vector3(0.48, 0.92, 0.0), Vector3(0.80, 1.02, 0.0), 0.038, 0.006, 6, dark)
	# 扁铲
	_tube(mb, Vector3(0.12, 0.81, 0.0), Vector3(-0.08, 0.75, 0.0), 0.042, 0.030, 6, iron)
	_box(mb, Vector3(-0.12, 0.72, 0.0), Vector3(0.10, 0.11, 0.05), dark)
	return mb.commit()


## 铁架提灯：底座 + 四根立柱 + 玻璃罩（暖色自发光）+ 顶盖 + 提环
func _build_lantern(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var iron := Color(0.52, 0.53, 0.58)
	var glass := Color(2.60, 1.55, 0.55)
	_box(mb, Vector3(0.0, 0.03, 0.0), Vector3(0.22, 0.06, 0.22), iron)
	_box(mb, Vector3(0.0, 0.11, 0.0), Vector3(0.17, 0.16, 0.17), glass)
	for sx in [-0.09, 0.09]:
		for sz in [-0.09, 0.09]:
			_tube(mb, Vector3(sx, 0.05, sz), Vector3(sx, 0.20, sz), 0.016, 0.016, 5, iron)
	_box(mb, Vector3(0.0, 0.22, 0.0), Vector3(0.24, 0.05, 0.24), iron)
	_cone(mb, Vector3(0.0, 0.25, 0.0), 0.13, 0.09, 6, iron)
	_tube(mb, Vector3(0.0, 0.34, 0.0), Vector3(0.0, 0.42, 0.0), 0.014, 0.014, 5, iron)
	return mb.commit()


## 铺开的睡垫 + 卷起的被褥 + 枕头 + 两条捆带
func _build_bedroll(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var cloth := Color(0.40, 0.33, 0.26)
	var blanket := cloth * 1.12
	var strap := Color(0.24, 0.18, 0.13)
	_box(mb, Vector3(0.0, 0.04, 0.0), Vector3(0.62, 0.08, 1.55), cloth)
	_tube(mb, Vector3(-0.22, 0.14, -0.60), Vector3(0.22, 0.14, -0.60), 0.16, 0.16, 9, blanket)
	_box(mb, Vector3(0.0, 0.16, -0.86), Vector3(0.34, 0.12, 0.22), blanket)
	for sz in [-0.34, 0.30]:
		_tube(mb, Vector3(-0.34, 0.10, sz), Vector3(0.34, 0.10, sz), 0.020, 0.020, 5, strap)
	return mb.commit()


## 帆布套水壶：罐体 + 瓶盖 + 帆布套 + 挂带
func _build_canteen(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var tin := Color(0.55, 0.57, 0.60)
	var cloth := Color(0.42, 0.34, 0.22)
	_tube(mb, Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.20, 0.0), 0.135, 0.125, 12, tin)
	_tube(mb, Vector3(0.0, 0.22, 0.0), Vector3(0.0, 0.28, 0.0), 0.05, 0.045, 8, tin)
	_tube(mb, Vector3(0.0, 0.04, 0.0), Vector3(0.0, 0.14, 0.0), 0.148, 0.142, 12, cloth)
	_tube(mb, Vector3(-0.15, 0.30, 0.0), Vector3(0.15, 0.30, 0.0), 0.017, 0.017, 5, cloth)
	return mb.commit()


## 盘起来的绳圈：三层逐层缩小的环（短管段拼成），带一点高低抖动
func _build_rope_coil(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var rope := Color(0.58, 0.48, 0.32)
	for l in 3:
		var rad := 0.30 - float(l) * 0.06
		var yy := 0.05 + float(l) * 0.07
		var segs := 14
		for s in segs:
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			var p0 := Vector3(cos(a0) * rad, yy, sin(a0) * rad)
			var p1 := Vector3(cos(a1) * rad, yy + rng.randf_range(-0.008, 0.008), sin(a1) * rad)
			_tube(mb, p0, p1, 0.032, 0.032, 5, rope)
	return mb.commit()


## 木工具箱：箱体 + 箱盖 + 铁提手 + 锁扣 + 四角包铁
func _build_toolbox(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var wood := Color(0.40, 0.29, 0.19)
	var lid := Color(0.33, 0.24, 0.16)
	var iron := Color(0.60, 0.61, 0.66)
	_box(mb, Vector3(0.0, 0.16, 0.0), Vector3(0.78, 0.32, 0.34), wood)
	_box(mb, Vector3(0.0, 0.34, 0.0), Vector3(0.80, 0.06, 0.36), lid)
	_tube(mb, Vector3(-0.22, 0.37, 0.0), Vector3(-0.22, 0.48, 0.0), 0.016, 0.016, 5, iron)
	_tube(mb, Vector3(0.22, 0.37, 0.0), Vector3(0.22, 0.48, 0.0), 0.016, 0.016, 5, iron)
	_tube(mb, Vector3(-0.22, 0.48, 0.0), Vector3(0.22, 0.48, 0.0), 0.018, 0.018, 5, iron)
	_box(mb, Vector3(0.0, 0.30, 0.18), Vector3(0.10, 0.10, 0.02), iron)
	for sx in [-0.38, 0.38]:
		_box(mb, Vector3(sx, 0.16, 0.17), Vector3(0.03, 0.30, 0.03), iron)
	return mb.commit()


## 木桶：桶身 + 两道铁箍 + 提梁
func _build_bucket(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var wood := Color(0.46, 0.34, 0.22)
	var iron := Color(0.52, 0.53, 0.58)
	_tube(mb, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.34, 0.0), 0.16, 0.20, 12, wood)
	for yy in [0.06, 0.27]:
		_tube(mb, Vector3(0.0, yy, 0.0), Vector3(0.0, yy + 0.05, 0.0), 0.205, 0.208, 12, iron)
	_tube(mb, Vector3(-0.19, 0.32, 0.0), Vector3(-0.19, 0.44, 0.0), 0.014, 0.014, 5, iron)
	_tube(mb, Vector3(0.19, 0.32, 0.0), Vector3(0.19, 0.44, 0.0), 0.014, 0.014, 5, iron)
	_tube(mb, Vector3(-0.19, 0.44, 0.0), Vector3(0.19, 0.44, 0.0), 0.014, 0.014, 5, iron)
	return mb.commit()


## 板条箱：四面横板（留缝）+ 四根立柱，看得出是木箱而不是一个方块
func _build_crate_wood(seedv: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var plank := Color(0.52, 0.39, 0.25)
	var frame := Color(0.34, 0.25, 0.16)
	var s := 0.62
	var h := 0.55
	for side in 4:
		var a := TAU * float(side) / 4.0 + PI * 0.25
		var n := Vector3(cos(a), 0.0, sin(a))
		var t := Vector3(-sin(a), 0.0, cos(a))
		for k in 3:
			var yy := 0.08 + float(k) * 0.17
			var pc := Vector3(n.x * (s * 0.5), yy, n.z * (s * 0.5))
			var tang := t * (s * 0.92)
			_oriented_quad(mb, pc - tang, pc + tang,
					pc + tang + Vector3(0.0, 0.14, 0.0),
					pc - tang + Vector3(0.0, 0.14, 0.0),
					plank * rng.randf_range(0.88, 1.08), n)
	for sx in [-s * 0.5, s * 0.5]:
		for sz in [-s * 0.5, s * 0.5]:
			_box(mb, Vector3(sx, h * 0.5, sz), Vector3(0.07, h, 0.07), frame)
	return mb.commit()


# ---------------------------------------------------------------- 场景装配
func _make_environment() -> Environment:
	var env := Environment.new()
	# 洞窟内部：天光进不来，只有熔岩的暖光和岩壁反射的冷紫。
	# 背景色只是洞顶合拢之前从缝里漏出来的一点暗光，不再是"室外天空"。
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.05, 0.11)
	sky_mat.sky_horizon_color = Color(0.34, 0.14, 0.08)
	sky_mat.sky_curve = 0.28
	sky_mat.ground_bottom_color = Color(0.05, 0.04, 0.07)
	sky_mat.ground_horizon_color = Color(0.24, 0.10, 0.06)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# 环境光走冷紫：和岩壁的暖橙反光形成参考图那种冷暖对比
	env.ambient_light_color = Color(0.30, 0.27, 0.46)
	env.ambient_light_energy = 0.62
	env.fog_enabled = true
	# 雾只能吃掉远景：太浓会把整个画面糊成橙色（第一版就糊了），
	# 这一版压到 0.0034，150 m 外才明显，近处的岩板保留对比
	env.fog_density = 0.0030
	env.fog_light_color = Color(0.22, 0.08, 0.05)
	env.fog_aerial_perspective = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.80
	env.glow_bloom = 0.50
	env.glow_hdr_threshold = 0.82
	return env


func _make_smoke(radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 26
	p.lifetime = 6.0
	p.lifetime_randomness = 0.4
	p.emitting = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(radius, 0.4)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 26.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.0, 0.12, 0.0)
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.62, 0.62, 0.62, 0.0))
	grad.add_point(0.2, Color(0.64, 0.64, 0.64, 0.40))
	grad.add_point(0.65, Color(0.56, 0.56, 0.56, 0.24))
	grad.add_point(1.0, Color(0.50, 0.50, 0.50, 0.0))
	p.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(1.8, 1.8)
	quad.material = _mats["mat_smoke"]
	p.mesh = quad
	return p


func _static_body(body_name: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = body_name
	b.collision_layer = LAYER_WORLD
	b.collision_mask = 0
	return b


## 帐篷内部的吊灯：一颗自发光灯泡 + 一盏只照亮帐篷内部的小灯。
## 灯挂在帐篷节点的局部空间里（帐篷整体放大 2 倍，所以射程给 3 m 局部 = 6 m 世界），
## 能量压得很低，只求"微微照亮"，不抢熔岩的主光。
func _add_tent_lamp(tent: Node3D, lamp_mesh: ArrayMesh, lamp_mat: Material,
		with_light := true) -> void:
	var bulb := MeshInstance3D.new()
	bulb.name = "TentLamp"
	bulb.mesh = lamp_mesh
	bulb.material_override = lamp_mat
	tent.add_child(bulb)
	# 只有营地那顶帐篷配灯：灯泡网格本身是自发光的（远处帐篷也看得出亮着），
	# 但每盏灯都要占一个 OmniLight 名额，gl_compatibility 下这些名额是有限的
	if not with_light:
		return
	var glow := OmniLight3D.new()
	glow.name = "LampLight"
	glow.light_color = Color(1.0, 0.74, 0.42)
	glow.light_energy = 1.3
	glow.omni_range = 3.0
	glow.omni_attenuation = 1.8
	glow.shadow_enabled = false
	glow.position = Vector3(0.0, 1.40, 0.0)
	tent.add_child(glow)


func _save_mesh(mesh: ArrayMesh, file_name: String) -> ArrayMesh:
	var path := MESH_DIR + "/" + file_name + ".tres"
	var err := ResourceSaver.save(mesh, path)
	if err != OK:
		printerr("网格保存失败: " + path)
	return load(path) as ArrayMesh


func _save_shape(shape: Shape3D, file_name: String) -> Shape3D:
	var path := SHAPE_DIR + "/" + file_name + ".tres"
	var err := ResourceSaver.save(shape, path)
	if err != OK:
		printerr("碰撞体保存失败: " + path)
	return load(path) as Shape3D


## used 的元素可以是 Vector3（占地半径 0），也可以是 [位置, 占地半径]。
## 帐篷（放大后半径 3.1）、灶台（1.5 倍后含柴堆约 1.7）这类大件必须带上自己的半径，
## 否则只按中心点距离判定时，石头会插进灶台里（"灶台和石头穿模"）。
func _free_spot(rng: RandomNumberGenerator, min_r: float, max_r: float,
		used: Array, clearance: float) -> Vector3:
	for _attempt in 120:
		var a := rng.randf() * TAU
		var r := min_r + rng.randf() * (max_r - min_r)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var ok := true
		for pool in _pools:
			if Vector2(p.x - pool.x, p.z - pool.z).length() < pool.bowl + 2.0:
				ok = false
				break
		if ok:
			for u in used:
				var up: Vector3 = u if u is Vector3 else (u as Array)[0]
				var ur: float = 0.0 if u is Vector3 else float((u as Array)[1])
				if Vector2(p.x - up.x, p.z - up.z).length() < clearance + ur:
					ok = false
					break
		if ok:
			p.y = _terrain_height(p.x, p.z)
			return p
	# 找不到位置时也要给一个带随机角度的落点：全部退回同一个点会让物件叠成一堆
	var fa := rng.randf() * TAU
	var fb := Vector3(cos(fa) * min_r, 0.0, sin(fa) * min_r)
	fb.y = _terrain_height(fb.x, fb.z)
	return fb


func _make_pool_spots(rng: RandomNumberGenerator) -> Array:
	var spots := []
	for _guard in 400:
		if spots.size() >= POOL_COUNT:
			break
		var a := rng.randf() * TAU
		var r := 11.0 + rng.randf() * 34.0
		var p := PoolSpot.new()
		p.x = cos(a) * r
		p.z = sin(a) * r
		var ok := true
		for other in spots:
			if Vector2(p.x - other.x, p.z - other.z).length() < 13.0:
				ok = false
				break
		if not ok:
			continue
		p.radius = 1.7 + rng.randf() * 1.4
		p.bowl = p.radius * 2.1
		p.depth = 0.85 + rng.randf() * 0.5
		p.seedv = rng.randi() % 9999
		spots.append(p)
	# 正前方的大熔岩湖：_terrain_height / _terrain_color 会按 bowl 挖出一个盆地，
	# 湖面就落在这个盆地的底部，形成参考图里"岸 → 湖"的层次
	var lake := PoolSpot.new()
	lake.x = 0.0
	lake.z = LAKE_Z
	lake.radius = LAKE_RADIUS
	# 湖盆做浅、做宽：原来挖 3 m 深，平视时湖面整个被近岸挡住，只剩一条亮线
	lake.bowl = LAKE_RADIUS * 1.34
	lake.depth = 1.1
	lake.seedv = 4242
	spots.append(lake)
	return spots


func _count_nodes(node: Node) -> int:
	var total := 1
	for c in node.get_children():
		total += _count_nodes(c)
	return total


func _set_owner(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_set_owner(c, owner)


func _build_scene(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "VolcanoCave"
	var root_script := load(ROOT_SCRIPT) as Script
	if root_script != null:
		root.set_script(root_script)

	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = _make_environment()
	root.add_child(we)

	# 岩浆反射补光：保证远离岩浆池处也能看清地形轮廓
	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	# 冷色补光：只为让远离岩浆的岩面还剩一点冷紫轮廓，不能盖过熔岩的暖光
	var fill := OmniLight3D.new()
	fill.name = "FillLight_LavaBounce"
	fill.light_color = Color(0.62, 0.68, 0.95)
	fill.light_energy = 0.55
	fill.omni_range = 70.0
	fill.omni_attenuation = 1.2
	fill.shadow_enabled = false
	fill.position = Vector3(0.0, 14.0, 4.0)
	lights.add_child(fill)
	# 洞顶微光：洞内没有天光，这盏只补"顶壁不至于纯黑"，亮度必须压得很低
	var ceiling := OmniLight3D.new()
	ceiling.name = "CeilingLight_Top"
	ceiling.light_color = Color(0.95, 0.72, 0.55)
	ceiling.light_energy = 2.4
	ceiling.omni_range = 120.0
	ceiling.omni_attenuation = 0.9
	ceiling.shadow_enabled = false
	ceiling.position = Vector3(0.0, CAVE_HEIGHT * 0.42, 0.0)
	lights.add_child(ceiling)
	# 熔岩的暖反射：洞内没有天光，前景岩板的光其实都来自岩浆。
	# 这盏放在营地与湖之间，把玩家脚下染成参考图那种暖褐色，而不是纯黑。
	var bounce := OmniLight3D.new()
	bounce.name = "LavaBounce_Warm"
	bounce.light_color = Color(1.0, 0.34, 0.12)
	bounce.light_energy = 3.2
	bounce.omni_range = 95.0
	bounce.omni_attenuation = 1.1
	bounce.shadow_enabled = false
	bounce.position = Vector3(0.0, 6.0, -58.0)
	lights.add_child(bounce)

	# ---- 起伏岩石地面（含 trimesh 碰撞，可在其上行走）
	var t := _build_terrain()
	var terrain_mesh := _save_mesh(t[0] as ArrayMesh, "cave_terrain")
	var terrain_body := _static_body("Terrain")
	root.add_child(terrain_body)
	var tm := MeshInstance3D.new()
	tm.name = "TerrainMesh"
	tm.mesh = terrain_mesh
	tm.material_override = _mats["mat_rock"]
	terrain_body.add_child(tm)
	var tshape := ConcavePolygonShape3D.new()
	tshape.set_faces(t[1] as PackedVector3Array)
	var tc := CollisionShape3D.new()
	tc.name = "TerrainCollision"
	tc.shape = _save_shape(tshape, "cave_terrain_shape")
	terrain_body.add_child(tc)

	# ---- 地面裂缝：unshaded + 顶点色当自发光，靠 glow 吃出参考图里岩板之间的橙光
	var crack_mesh := _save_mesh(_build_cracks(rng), "lava_cracks")
	var crack_mat := StandardMaterial3D.new()
	crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crack_mat.vertex_color_use_as_albedo = true
	crack_mat.albedo_color = Color(1, 1, 1, 1)
	var cracks := MeshInstance3D.new()
	cracks.name = "LavaCracks"
	cracks.mesh = crack_mesh
	cracks.material_override = crack_mat
	root.add_child(cracks)

	# ---- 天花板（侧壁已取消，只留头顶岩顶；法线朝下，同样带碰撞）
	var s := _build_ceiling()
	var shell_mesh := _save_mesh(s[0] as ArrayMesh, "cave_ceiling")
	var shell_body := _static_body("CaveShell")
	root.add_child(shell_body)
	var sm := MeshInstance3D.new()
	sm.name = "ShellMesh"
	sm.mesh = shell_mesh
	sm.material_override = _mats["mat_rock_shell"]
	shell_body.add_child(sm)
	var sshape := ConcavePolygonShape3D.new()
	sshape.set_faces(s[1] as PackedVector3Array)
	var sc := CollisionShape3D.new()
	sc.name = "ShellCollision"
	sc.shape = _save_shape(sshape, "cave_ceiling_shape")
	shell_body.add_child(sc)

	# 侧壁取消后没有东西拦人了：补一圈只有碰撞、没有网格的隐形挡墙，
	# 否则玩家能一路走出 399 m 的地形外沿掉下去
	var wall_body := _static_body("BoundaryWall")
	root.add_child(wall_body)
	var wfaces := PackedVector3Array()
	var wsegs := 48
	var wr := TERRAIN_RADIUS - 6.0
	for i in wsegs:
		var a0 := TAU * float(i) / float(wsegs)
		var a1 := TAU * float(i + 1) / float(wsegs)
		var p0 := Vector3(cos(a0) * wr, -12.0, sin(a0) * wr)
		var p1 := Vector3(cos(a1) * wr, -12.0, sin(a1) * wr)
		var p2 := Vector3(cos(a1) * wr, 60.0, sin(a1) * wr)
		var p3 := Vector3(cos(a0) * wr, 60.0, sin(a0) * wr)
		wfaces.append(p0)
		wfaces.append(p1)
		wfaces.append(p2)
		wfaces.append(p0)
		wfaces.append(p2)
		wfaces.append(p3)
	var wshape := ConcavePolygonShape3D.new()
	wshape.set_faces(wfaces)
	var wcs := CollisionShape3D.new()
	wcs.name = "BoundaryCollision"
	wcs.shape = wshape
	wall_body.add_child(wcs)

	# ---- 岩浆池 + 顶部流淌岩浆
	var pool_meshes := []
	for i in 3:
		pool_meshes.append(_save_mesh(_build_pool_surface(101 + i * 37), "lava_pool_%d" % (i + 1)))
	var vent_mesh := _save_mesh(_build_vent_ring(), "ceiling_vent")
	var lava_root := Node3D.new()
	lava_root.name = "LavaPools"
	root.add_child(lava_root)
	var falls_root := Node3D.new()
	falls_root.name = "LavaFalls"
	root.add_child(falls_root)
	for i in _pools.size():
		var pool := _pools[i] as PoolSpot
		pool.surface_y = _terrain_height(pool.x, pool.z) + 0.06
		# 与 _ceiling_height 同一条曲线，瀑布顶才贴在天花板上而不是凭空出现
		var pr := Vector2(pool.x, pool.z).length()
		pool.ceil_y = _ceiling_height(pr, atan2(pool.z, pool.x)) - 1.4

		var group := Node3D.new()
		group.name = "LavaPool_%02d" % [i + 1]
		group.position = Vector3(pool.x, pool.surface_y, pool.z)
		lava_root.add_child(group)

		var surf := MeshInstance3D.new()
		surf.name = "PoolSurface"
		surf.mesh = pool_meshes[i % pool_meshes.size()] as ArrayMesh
		surf.scale = Vector3(pool.radius, 1.0, pool.radius)
		surf.material_override = _mats["mat_lava_pool"]
		group.add_child(surf)

		var glow := OmniLight3D.new()
		glow.name = "PoolGlow"
		# 熔岩是全场唯一的主光源：池子越大光越强、射得越远（大湖要照亮半个洞）
		glow.light_color = Color(1.0, 0.50, 0.20)
		glow.light_energy = 2.0 + pool.radius * 0.10
		glow.omni_range = 14.0 + pool.radius * 2.6
		glow.omni_attenuation = 0.85
		glow.shadow_enabled = false
		glow.position = Vector3(0.0, 1.6, 0.0)
		group.add_child(glow)

		var zone := Area3D.new()
		zone.name = "LavaZone"
		zone.collision_layer = LAYER_LAVA
		zone.collision_mask = LAYER_ACTOR
		zone.monitoring = true
		zone.monitorable = true
		group.add_child(zone)
		var zone_shape := CylinderShape3D.new()
		zone_shape.radius = pool.radius
		zone_shape.height = 1.2
		var zc := CollisionShape3D.new()
		zc.name = "ZoneCollision"
		zc.shape = zone_shape
		zc.position = Vector3(0.0, 0.2, 0.0)
		zone.add_child(zc)

		var smoke := _make_smoke(clampf(pool.radius * 0.7, 0.4, 16.0))
		smoke.position = Vector3(0.0, 0.35, 0.0)
		group.add_child(smoke)

		var fall := Node3D.new()
		fall.name = "LavaFall_%02d" % [i + 1]
		fall.position = Vector3(pool.x, pool.ceil_y, pool.z)
		falls_root.add_child(fall)
		var fall_len := maxf(pool.ceil_y - pool.surface_y, 1.0)
		# 瀑布宽度跟池子走：大湖对应参考图里那道很宽的中央岩浆瀑
		var fall_w := clampf(pool.radius * 0.26, 1.2, 15.0)
		var column := MeshInstance3D.new()
		column.name = "FallColumn"
		column.mesh = _build_fall_column(fall_len + 0.4, pool.seedv, fall_w)
		column.material_override = _mats["mat_lava_fall"]
		fall.add_child(column)
		var vent := MeshInstance3D.new()
		vent.name = "VentRock"
		vent.mesh = vent_mesh
		vent.position = Vector3(0.0, 0.9, 0.0)
		vent.scale = Vector3(fall_w * 1.8, 1.0, fall_w * 1.8)
		vent.material_override = _mats["mat_rock_shell"]
		fall.add_child(vent)
		var fzone := Area3D.new()
		fzone.name = "LavaZone"
		fzone.collision_layer = LAYER_LAVA
		fzone.collision_mask = LAYER_ACTOR
		fall.add_child(fzone)
		var fshape := CylinderShape3D.new()
		fshape.radius = 0.75
		fshape.height = fall_len
		var fzc := CollisionShape3D.new()
		fzc.name = "ZoneCollision"
		fzc.shape = fshape
		fzc.position = Vector3(0.0, -fall_len * 0.5, 0.0)
		fzone.add_child(fzc)
		var fsmoke := _make_smoke(0.35)
		fsmoke.position = Vector3(0.0, -fall_len + 0.2, 0.0)
		fall.add_child(fsmoke)

	# ---- 湖对岸的远景瀑布：参考图背景里从洞顶垂下的几道熔岩，只做视觉，不带伤害区
	var far_falls := Node3D.new()
	far_falls.name = "FarFalls"
	root.add_child(far_falls)
	var far_x := [-46.0, -18.0, 14.0, 44.0]
	for i in far_x.size():
		var fx: float = far_x[i]
		var fz := LAKE_Z - 58.0 + float(i % 2) * 14.0
		var pr := Vector2(fx, fz).length()
		var top := _ceiling_height(pr, atan2(fz, fx)) - 1.0
		if top < 8.0:
			continue
		var fg := Node3D.new()
		fg.name = "FarFall_%02d" % [i + 1]
		fg.position = Vector3(fx, top, fz)
		far_falls.add_child(fg)
		var fcol := MeshInstance3D.new()
		fcol.name = "FallColumn"
		fcol.mesh = _build_fall_column(top + 0.6, 900 + i * 17, 5.5 + float(i % 2) * 3.0)
		fcol.material_override = _mats["mat_lava_fall"]
		fg.add_child(fcol)
		var fglow := OmniLight3D.new()
		fglow.name = "FallGlow"
		fglow.light_color = Color(1.0, 0.45, 0.16)
		fglow.light_energy = 3.0
		fglow.omni_range = 34.0
		fglow.shadow_enabled = false
		fglow.position = Vector3(0.0, -top * 0.45, 0.0)
		fg.add_child(fglow)

	# ---- 湖对岸的宽岩浆帘：参考图里最亮的那道"瀑布墙"
	for i in 2:
		var cz := LAKE_Z - 76.0 - float(i) * 24.0
		var cx := -8.0 + float(i) * 30.0
		var pr2 := Vector2(cx, cz).length()
		var top2 := _ceiling_height(pr2, atan2(cz, cx)) - 1.0
		if top2 < 8.0:
			continue
		var curtain := MeshInstance3D.new()
		curtain.name = "LavaCurtain_%02d" % [i + 1]
		curtain.position = Vector3(cx, top2, cz)
		curtain.mesh = _build_fall_column(top2 + 0.5, 1200 + i * 31, 15.0)
		curtain.material_override = _mats["mat_lava_fall"]
		root.add_child(curtain)

	# ---- 装饰物件（随机分布）
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	var used := []
	# 出生点旁的营地是固定构图（右侧帐篷 / 灶台，左侧枯树与骸骨），
	# 先占位再放随机物件，否则随机物件会压到营地中间
	used.append([Vector3(10.5, 0.0, -7.5), 4.4])
	# 营地装备散在帐篷外这一圈，随机物件（石头 / 厨具）不要插进来
	used.append([Vector3(15.2, 0.0, -6.2), 3.6])
	used.append([Vector3(9.0, 0.0, -6.0), 3.0])
	used.append([Vector3(13.8, 0.0, -9.6), 2.2])
	used.append([Vector3(-10.0, 0.0, -3.0), 1.5])
	used.append([Vector3(-13.2, 0.0, -7.4), 1.5])
	used.append([Vector3(-8.0, 0.0, 1.6), 2.4])

	var trees := Node3D.new()
	trees.name = "DeadTrees"
	props.add_child(trees)
	var tree_meshes := []
	for i in 3:
		tree_meshes.append(_save_mesh(_build_tree(301 + i * 53), "tree_charred_%d" % (i + 1)))
	var bone_meshes := [
		_save_mesh(_build_bone_rib(11), "bone_rib"),
		_save_mesh(_build_bone_skull(12), "bone_skull"),
		_save_mesh(_build_bone_shards(13), "bone_shards")]
	for i in TREE_COUNT:
		var p := _free_spot(rng, 10.0, 48.0, used, 6.0)
		used.append([p, 0.9])
		var tree_group := Node3D.new()
		tree_group.name = "DeadTree_%02d" % [i + 1]
		tree_group.position = p
		tree_group.rotation.y = rng.randf() * TAU
		var sc2 := 0.85 + rng.randf() * 0.5
		tree_group.scale = Vector3(sc2, sc2 * (0.9 + rng.randf() * 0.35), sc2)
		trees.add_child(tree_group)
		var trunk := MeshInstance3D.new()
		trunk.name = "Trunk"
		trunk.mesh = tree_meshes[i % tree_meshes.size()] as ArrayMesh
		trunk.material_override = _mats["mat_charred_tree"]
		tree_group.add_child(trunk)
		var tree_body := _static_body("TreeCollision")
		tree_group.add_child(tree_body)
		var tree_shape := CylinderShape3D.new()
		tree_shape.radius = 0.45
		tree_shape.height = 4.5
		var tsc := CollisionShape3D.new()
		tsc.name = "TreeShape"
		tsc.shape = tree_shape
		tsc.position = Vector3(0.0, 2.0, 0.0)
		tree_body.add_child(tsc)
		var bones := Node3D.new()
		bones.name = "BoneDebris_%02d" % [i + 1]
		tree_group.add_child(bones)
		for b in 3:
			var bone := MeshInstance3D.new()
			bone.name = "Bone_%02d" % [b + 1]
			bone.mesh = bone_meshes[(i + b) % bone_meshes.size()] as ArrayMesh
			bone.material_override = _mats["mat_bone"]
			# 三根骨头按 120° 均分再加抖动：纯随机角会让几根骨头叠成一堆（骨头互相穿模）
			var ba := TAU * float(b) / 3.0 + rng.randf_range(-0.45, 0.45)
			# 下限 1.6 m：树根向外展开约 1.05 m，骨头再留 0.5 m 余量才不会插进树根
			var br := (1.6 + rng.randf() * 0.75) / maxf(sc2, 0.01)
			var wx := p.x + cos(ba) * br * sc2
			var wz := p.z + sin(ba) * br * sc2
			# 逐根按地形高度贴地：树在斜坡上时固定 y 会让骨头悬空或陷进坡里
			var ly := (_terrain_height(wx, wz) - p.y) / maxf(sc2, 0.01) - 0.06
			bone.position = Vector3(cos(ba) * br, ly, sin(ba) * br)
			bone.rotation.y = rng.randf() * TAU
			bones.add_child(bone)
			# 骨头也登记占位（世界坐标 = 树位置 + 偏移 × 树缩放），
			# 否则后面放的石头 / 厨具会直接插进骨头堆
			used.append([p + Vector3(cos(ba) * br * sc2, 0.0, sin(ba) * br * sc2), 0.35])

	var tents := Node3D.new()
	tents.name = "Tents"
	props.add_child(tents)
	var tent_meshes := []
	for i in 2:
		tent_meshes.append(_save_mesh(_build_tent_canvas(401 + i * 71), "tent_canvas_%d" % (i + 1)))
	var pole_mesh := _save_mesh(_build_tent_pole(), "tent_pole")
	# 帐篷内吊灯：灯泡网格 + unshaded 材质（顶点色 > 1，会被 glow 吃出光晕）
	var lamp_mesh := _save_mesh(_build_tent_lamp(), "tent_lamp")
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.vertex_color_use_as_albedo = true
	lamp_mat.albedo_color = Color(1, 1, 1, 1)
	for i in TENT_COUNT:
		# 帐篷放大 2 倍后占地半径约 3.6（含拉绳地钉），所以起点更远、间距更大
		var p := _free_spot(rng, 15.0, 45.0, used, 4.0)
		used.append([p, 3.6])
		var tent := Node3D.new()
		tent.name = "Tent_%02d" % [i + 1]
		tent.position = p - Vector3(0.0, 0.12 * TENT_SCALE, 0.0)
		tent.rotation.y = rng.randf() * TAU
		# 倾斜量要随放大收敛：半径 3.1 m 时 0.3 rad 会让一侧沉进地里近 1 m
		if rng.randf() < 0.4:
			tent.rotation.z = rng.randf_range(0.02, 0.06)
		tent.scale = Vector3.ONE * TENT_SCALE
		tents.add_child(tent)
		var canvas := MeshInstance3D.new()
		canvas.name = "Canvas"
		canvas.mesh = tent_meshes[i % tent_meshes.size()] as ArrayMesh
		canvas.material_override = _mats["mat_canvas"]
		tent.add_child(canvas)
		var pole := MeshInstance3D.new()
		pole.name = "Pole"
		pole.mesh = pole_mesh
		pole.material_override = _mats["mat_charred_tree"]
		tent.add_child(pole)
		var tent_body := _static_body("TentCollision")
		tent.add_child(tent_body)
		var tent_shape := BoxShape3D.new()
		tent_shape.size = Vector3(2.6, 2.0, 2.6)
		var tbc := CollisionShape3D.new()
		tbc.name = "TentShape"
		tbc.shape = tent_shape
		tbc.position = Vector3(0.0, 0.9, 0.0)
		tent_body.add_child(tbc)
		_add_tent_lamp(tent, lamp_mesh, lamp_mat, false)

	var kitchen := Node3D.new()
	kitchen.name = "Kitchen"
	props.add_child(kitchen)
	# 灶台拆三份网格：石体 / 铁件 / 炭火，各自挂不同材质
	var stove_mesh := _save_mesh(_build_stove(), "stove_body")
	var stove_iron_mesh := _save_mesh(_build_stove_iron(), "stove_iron")
	var stove_ember_mesh := _save_mesh(_build_stove_ember(), "stove_ember")
	var utensil_meshes := [
		_save_mesh(_build_pot(), "kitchenware_pot"),
		_save_mesh(_build_pan(), "kitchenware_pan"),
		_save_mesh(_build_crate(21), "kitchenware_crate"),
		_save_mesh(_build_barrel(), "kitchenware_barrel")]
	# 熔岩灶台：当前阶段只作场景装置（视觉 + 碰撞），不挂交互脚本、不做料理
	var station_pos := Vector3(4.5, _terrain_height(4.5, -3.5), -3.5)
	var station := Node3D.new()
	station.name = "Stove_CookingStation"
	# 略微下沉，让基石坐进地面而不是浮在坡上
	station.position = station_pos - Vector3(0.0, 0.08 * STOVE_SCALE, 0.0)
	station.rotation.y = -0.6
	station.scale = Vector3.ONE * STOVE_SCALE
	kitchen.add_child(station)
	var station_mesh := MeshInstance3D.new()
	station_mesh.name = "StoveBody"
	station_mesh.mesh = stove_mesh
	station_mesh.material_override = _mats["mat_stone"]
	station.add_child(station_mesh)
	var station_body := _static_body("StoveCollision")
	station.add_child(station_body)
	var station_shape := BoxShape3D.new()
	station_shape.size = Vector3(1.3, 1.1, 1.0)
	var station_cs := CollisionShape3D.new()
	station_cs.name = "StoveShape"
	station_cs.shape = station_shape
	station_cs.position = Vector3(0.0, 0.55, 0.0)
	station_body.add_child(station_cs)
	var station_pot := MeshInstance3D.new()
	station_pot.name = "Pot"
	station_pot.mesh = utensil_meshes[0] as ArrayMesh
	station_pot.material_override = _mats["mat_metal"]
	station_pot.position = Vector3(0.0, 0.88, 0.1)
	station.add_child(station_pot)
	var station_iron := MeshInstance3D.new()
	station_iron.name = "IronGrate"
	station_iron.mesh = stove_iron_mesh
	station_iron.material_override = _mats["mat_metal"]
	station.add_child(station_iron)
	var station_ember := MeshInstance3D.new()
	station_ember.name = "Ember"
	station_ember.mesh = stove_ember_mesh
	station_ember.material_override = _mats["mat_ember"]
	station.add_child(station_ember)
	# 炉口的暖光：范围小、无阴影，只把灶台前一小圈地面和石面照亮
	var stove_fire := OmniLight3D.new()
	stove_fire.name = "StoveFire"
	stove_fire.light_color = Color(1.0, 0.68, 0.40)
	stove_fire.light_energy = 1.4
	stove_fire.omni_range = 5.0
	stove_fire.omni_attenuation = 1.6
	stove_fire.shadow_enabled = false
	stove_fire.position = Vector3(0.0, 0.34, 0.70)
	station.add_child(stove_fire)
	# 灶台 1.5 倍后含柴堆的占地半径约 1.7，石头按"中心距 > 自身半径 + 1.7"才不会插进来
	used.append([station_pos, 1.7 * STOVE_SCALE])

	var broken := Node3D.new()
	broken.name = "Stove_Broken_01"
	var bp := _free_spot(rng, 14.0, 40.0, used, 4.0)
	used.append([bp, 1.7 * STOVE_SCALE])
	broken.position = bp - Vector3(0.0, 0.08 * STOVE_SCALE, 0.0)
	broken.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU,
			rng.randf_range(-0.2, 0.2))
	broken.scale = Vector3.ONE * STOVE_SCALE
	kitchen.add_child(broken)
	var broken_mesh := MeshInstance3D.new()
	broken_mesh.name = "StoveBody"
	broken_mesh.mesh = stove_mesh
	broken_mesh.material_override = _mats["mat_stone"]
	broken.add_child(broken_mesh)
	# 废弃灶台只留铁箅，不点炭火（与在用灶台形成对比）
	var broken_iron := MeshInstance3D.new()
	broken_iron.name = "IronGrate"
	broken_iron.mesh = stove_iron_mesh
	broken_iron.material_override = _mats["mat_metal"]
	broken.add_child(broken_iron)
	for i in UTENSIL_COUNT:
		var p := _free_spot(rng, 7.0, 36.0, used, 3.0)
		used.append(p)
		var item := MeshInstance3D.new()
		item.name = "Utensil_%02d" % [i + 1]
		item.mesh = utensil_meshes[i % utensil_meshes.size()] as ArrayMesh
		item.material_override = _mats["mat_metal"] if i % 2 == 0 else _mats["mat_canvas"]
		item.position = p
		item.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU,
				rng.randf_range(-0.4, 0.4))
		kitchen.add_child(item)

	var rocks := Node3D.new()
	rocks.name = "Rocks"
	props.add_child(rocks)
	var rock_meshes := []
	# 记下每种石头网格的基础半径：_build_rock_chunk 用 0.55 + seedv%5*0.12，
	# blob 顶点还会向外抖约 30%，所以世界半径 ≈ 基础半径 × 缩放 × 1.35
	var rock_base_r := []
	for i in 3:
		var seedv := 501 + i * 29
		rock_meshes.append(_save_mesh(_build_rock_chunk(seedv), "rock_chunk_%d" % (i + 1)))
		rock_base_r.append(0.55 + float(seedv % 5) * 0.12)
	for i in ROCK_COUNT:
		var p := _free_spot(rng, 6.0, 52.0, used, 2.8)
		var rs := 0.6 + rng.randf() * 0.8
		# 按真实基础半径登记（此前统一写 rs*1.05，最大的那种石头被低估，互相插进去）
		used.append([p, float(rock_base_r[i % rock_base_r.size()]) * rs * 1.35])
		var rock := MeshInstance3D.new()
		rock.name = "Rock_%02d" % [i + 1]
		rock.mesh = rock_meshes[i % rock_meshes.size()] as ArrayMesh
		rock.material_override = _mats["mat_rock_shell"]
		# 下沉一点点让石头坐进地面，而不是浮在坡面上
		rock.position = p - Vector3(0.0, 0.16 * rs, 0.0)
		rock.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU,
				rng.randf_range(-0.3, 0.3))
		rock.scale = Vector3(rs, rs * 0.8, rs)
		rocks.add_child(rock)
		# 石头必须是实心的：碰撞体挂在石头自己下面，跟随它的位移 / 旋转 / 缩放。
		# 半径比网格略小（0.9），贴着石头表面走的时候才不会被"空气墙"挡住。
		var rock_body := _static_body("RockCollision")
		rock.add_child(rock_body)
		var rock_shape := SphereShape3D.new()
		rock_shape.radius = float(rock_base_r[i % rock_base_r.size()]) * 1.15
		var rock_cs := CollisionShape3D.new()
		rock_cs.name = "RockShape"
		rock_cs.shape = rock_shape
		rock_body.add_child(rock_cs)
	var stal_meshes := []
	var stal_lengths := []
	for i in 2:
		var built := _build_stalactite(601 + i * 41)
		stal_meshes.append(_save_mesh(built[0] as ArrayMesh, "stalactite_%d" % (i + 1)))
		stal_lengths.append(float(built[1]))
	# 记下每根钟乳石的 [x, z, 顶部 y, 缩放, 长度]，后面挂萤石簇要用
	var stal_placed := []
	for i in STALACTITE_COUNT:
		var a := rng.randf() * TAU
		# 从出生点上空一直铺到远景：湖对岸也要有垂下来的岩块，头顶才不会空
		var rr := 9.0 + pow(rng.randf(), 0.75) * 150.0
		var cx := cos(a) * rr
		var cz := sin(a) * rr
		# 同上：跟着天花板曲线走，钟乳石根部才贴在顶上
		var cy := _ceiling_height(rr, a) - 0.5
		var st := MeshInstance3D.new()
		st.name = "Stalactite_%02d" % [i + 1]
		st.mesh = stal_meshes[i % stal_meshes.size()] as ArrayMesh
		st.material_override = _mats["mat_rock_shell"]
		st.position = Vector3(cx, cy, cz)
		st.rotation.y = rng.randf() * TAU
		var ss := 0.7 + rng.randf() * 0.9
		st.scale = Vector3(ss, ss, ss)
		rocks.add_child(st)
		stal_placed.append([cx, cz, cy, ss, stal_lengths[i % stal_lengths.size()]])

	# 湖上方再加几根巨大的：参考图里最显眼的垂挂岩块都悬在熔岩湖之上
	for i in 7:
		var a2 := rng.randf() * TAU
		var rr2 := 26.0 + rng.randf() * 92.0
		var cy2 := _ceiling_height(rr2, a2) - 0.2
		var st2 := MeshInstance3D.new()
		st2.name = "StalactiteBig_%02d" % [i + 1]
		st2.mesh = stal_meshes[i % stal_meshes.size()] as ArrayMesh
		st2.material_override = _mats["mat_rock_shell"]
		st2.position = Vector3(cos(a2) * rr2, cy2, sin(a2) * rr2)
		st2.rotation.y = rng.randf() * TAU
		var ss2 := 2.0 + rng.randf() * 1.4
		st2.scale = Vector3(ss2, ss2 * 0.9, ss2)
		rocks.add_child(st2)
		stal_placed.append([cos(a2) * rr2, sin(a2) * rr2, cy2, ss2 * 0.9,
				stal_lengths[i % stal_lengths.size()]])

	# ---- 萤石：钟乳石与洞顶上一簇一簇的冷色发光晶石
	var fluorite := Node3D.new()
	fluorite.name = "Fluorite"
	props.add_child(fluorite)
	var fluo_meshes := []
	for i in 3:
		fluo_meshes.append(_save_mesh(_build_fluorite(701 + i * 53), "fluorite_%d" % (i + 1)))
	# unshaded + 顶点色当发光色：不给每簇配灯（灯在 gl_compatibility 下有数量上限）
	var fluo_mat := StandardMaterial3D.new()
	fluo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fluo_mat.vertex_color_use_as_albedo = true
	fluo_mat.albedo_color = Color(1, 1, 1, 1)
	# 倒挂在洞顶上的：绕 X 翻 180°，晶石尖朝下
	for i in FLUORITE_COUNT:
		var fa := rng.randf() * TAU
		var fr := 12.0 + pow(rng.randf(), 0.7) * 180.0
		var fy := _ceiling_height(fr, fa) - 0.05
		# 洞顶外沿已经压到地面了，太低的位置不放（晶石会插进地形里）
		if fy < 4.0:
			continue
		var fcl := MeshInstance3D.new()
		fcl.name = "Fluorite_%02d" % [i + 1]
		fcl.mesh = fluo_meshes[i % fluo_meshes.size()] as ArrayMesh
		fcl.material_override = fluo_mat
		fcl.position = Vector3(cos(fa) * fr, fy, sin(fa) * fr)
		fcl.rotation = Vector3(PI, rng.randf() * TAU, 0.0)
		var fcs := 0.6 + rng.randf() * 0.9
		fcl.scale = Vector3(fcs, fcs, fcs)
		fluorite.add_child(fcl)
	# 长在钟乳石身上的：按石身长度挂在 25%~75% 的位置，同样尖朝下
	for i in stal_placed.size():
		var sd: Array = stal_placed[i]
		for k in 2:
			if rng.randf() > 0.7:
				continue
			var frac := rng.randf_range(0.25, 0.75)
			var scl := 0.45 + rng.randf() * 0.5
			var scl2 := MeshInstance3D.new()
			scl2.name = "Fluorite_Stal%02d_%d" % [i + 1, k + 1]
			scl2.mesh = fluo_meshes[(i + k) % fluo_meshes.size()] as ArrayMesh
			scl2.material_override = fluo_mat
			# 沿石身下沉 frac 比例，再往侧向挪一点点，让晶石从石面上"长"出来
			var lat := 0.25 + rng.randf() * 0.35
			var la := rng.randf() * TAU
			var sy := float(sd[2]) - float(sd[4]) * float(sd[3]) * frac
			# 长钟乳石 + 低洞顶的组合会让晶石掉到地面以下，直接跳过
			if sy < 3.0:
				continue
			scl2.position = Vector3(float(sd[0]) + cos(la) * lat, sy,
					float(sd[1]) + sin(la) * lat)
			scl2.rotation = Vector3(PI, rng.randf() * TAU, 0.0)
			scl2.scale = Vector3(scl, scl, scl)
			fluorite.add_child(scl2)

	# ---- 中景岩壁：参考图里湖两侧与远处那些大块岩体，用放大的石块拼出来。
	# 它们把"空旷平地"收成"洞窟"，同时挡住地形外沿的边界感。
	var cliffs := Node3D.new()
	cliffs.name = "DistantCliffs"
	props.add_child(cliffs)
	for i in 30:
		var ca := rng.randf() * TAU
		var cr := 92.0 + rng.randf() * 115.0
		var cpos := Vector3(cos(ca) * cr, 0.0, sin(ca) * cr)
		# 正前方的湖面走廊留空，否则大岩体会挡掉熔岩湖
		if absf(cpos.x) < 64.0 and cpos.z < -40.0:
			continue
		cpos.y = _terrain_height(cpos.x, cpos.z)
		var cscale := 9.0 + rng.randf() * 16.0
		var cliff := MeshInstance3D.new()
		cliff.name = "Cliff_%02d" % [i + 1]
		cliff.mesh = rock_meshes[i % rock_meshes.size()] as ArrayMesh
		cliff.material_override = _mats["mat_rock_shell"]
		# 埋掉四分之一，让岩体像从地面长出来
		cliff.position = cpos - Vector3(0.0, cscale * 0.28, 0.0)
		cliff.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU,
				rng.randf_range(-0.12, 0.12))
		cliff.scale = Vector3(cscale, cscale * (1.15 + rng.randf() * 0.7), cscale)
		cliffs.add_child(cliff)
		# 中景岩壁同样是实心的：它们是"地上的岩石"，不能穿过去
		var cliff_body := _static_body("CliffCollision")
		cliff.add_child(cliff_body)
		var cliff_shape := SphereShape3D.new()
		cliff_shape.radius = 1.05
		var cliff_cs := CollisionShape3D.new()
		cliff_cs.name = "CliffShape"
		cliff_cs.shape = cliff_shape
		cliff_body.add_child(cliff_cs)

	# ---- 出生点营地：把参考图的构图摆到玩家眼前
	# 右前方一顶帐篷 + 箱笼，左前方两棵焦树 + 一地骸骨，视线正前方就是熔岩湖
	var camp := Node3D.new()
	camp.name = "Camp"
	props.add_child(camp)
	var camp_tent := Node3D.new()
	camp_tent.name = "CampTent"
	var ctp := Vector3(10.5, _terrain_height(10.5, -7.5), -7.5)
	camp_tent.position = ctp - Vector3(0.0, 0.12 * TENT_SCALE, 0.0)
	camp_tent.rotation.y = -0.9
	camp_tent.scale = Vector3.ONE * TENT_SCALE
	camp.add_child(camp_tent)
	var camp_canvas := MeshInstance3D.new()
	camp_canvas.name = "Canvas"
	camp_canvas.mesh = tent_meshes[0] as ArrayMesh
	camp_canvas.material_override = _mats["mat_canvas"]
	camp_tent.add_child(camp_canvas)
	var camp_pole := MeshInstance3D.new()
	camp_pole.name = "Pole"
	camp_pole.mesh = pole_mesh
	camp_pole.material_override = _mats["mat_charred_tree"]
	camp_tent.add_child(camp_pole)
	var camp_body := _static_body("TentCollision")
	camp_tent.add_child(camp_body)
	var camp_shape := BoxShape3D.new()
	camp_shape.size = Vector3(2.6, 2.0, 2.6)
	var camp_cs := CollisionShape3D.new()
	camp_cs.name = "TentShape"
	camp_cs.shape = camp_shape
	camp_cs.position = Vector3(0.0, 0.9, 0.0)
	camp_body.add_child(camp_cs)
	_add_tent_lamp(camp_tent, lamp_mesh, lamp_mat)

	# ---- 营地的探险装备 / 生活用品：每一件都做出可辨认的结构
	# （背包 / 十字镐 / 提灯 / 睡垫 / 工具箱 / 绳圈 / 水壶 / 木桶 / 板条箱）
	# 统一用一份"按顶点色上色"的材质：木头、皮革、铁件的颜色都在网格里。
	var gear_mat := StandardMaterial3D.new()
	gear_mat.vertex_color_use_as_albedo = true
	gear_mat.vertex_color_is_srgb = false
	gear_mat.albedo_color = Color(1, 1, 1, 1)
	gear_mat.roughness = 0.72
	gear_mat.metallic = 0.05
	var gear_meshes := {
		"backpack": _save_mesh(_build_backpack(31), "gear_backpack"),
		"pickaxe": _save_mesh(_build_pickaxe(32), "gear_pickaxe"),
		"lantern": _save_mesh(_build_lantern(33), "gear_lantern"),
		"bedroll": _save_mesh(_build_bedroll(34), "gear_bedroll"),
		"toolbox": _save_mesh(_build_toolbox(35), "gear_toolbox"),
		"rope": _save_mesh(_build_rope_coil(36), "gear_rope_coil"),
		"canteen": _save_mesh(_build_canteen(37), "gear_canteen"),
		"bucket": _save_mesh(_build_bucket(38), "gear_bucket"),
		"crate": _save_mesh(_build_crate_wood(39), "gear_crate_wood")}
	# [位置, 类型, 朝向, 缩放] —— 围着帐篷外侧摆：
	# 帐篷放大 2 倍后帆布半径 3.1 m、碰撞盒半宽 2.6 m，所以每件都要离帐篷中心
	# 3.5 m 以上，否则会插进帆布 / 碰撞盒里
	var gear_spots := [
		[Vector3(7.6, 0.0, -4.8), "backpack", 0.45, 1.15],
		[Vector3(14.2, 0.0, -6.8), "pickaxe", -0.70, 1.15],
		[Vector3(14.0, 0.0, -9.6), "lantern", 0.20, 1.25],
		[Vector3(9.6, 0.0, -2.8), "bedroll", 0.95, 1.05],
		[Vector3(15.6, 0.0, -3.6), "toolbox", -0.35, 1.15],
		[Vector3(16.0, 0.0, -7.4), "rope", 0.0, 1.15],
		[Vector3(13.4, 0.0, -2.4), "canteen", 0.60, 1.20],
		[Vector3(7.6, 0.0, -10.4), "bucket", 0.30, 1.20],
		[Vector3(17.0, 0.0, -10.0), "crate", 0.50, 1.20]]
	for i in gear_spots.size():
		var gs: Array = gear_spots[i]
		var kind := String(gs[1])
		var gp: Vector3 = gs[0]
		gp.y = _terrain_height(gp.x, gp.z)
		var gear := MeshInstance3D.new()
		gear.name = "CampItem_%02d_%s" % [i + 1, kind]
		gear.mesh = gear_meshes[kind] as ArrayMesh
		gear.material_override = gear_mat
		gear.position = gp
		gear.rotation.y = float(gs[2])
		var gsc := float(gs[3])
		gear.scale = Vector3(gsc, gsc, gsc)
		camp.add_child(gear)
		# 提灯自带一点暖光：营地里唯一的人造光源
		if kind == "lantern":
			var lantern_light := OmniLight3D.new()
			lantern_light.name = "LanternLight"
			lantern_light.light_color = Color(1.0, 0.70, 0.38)
			lantern_light.light_energy = 1.1
			lantern_light.omni_range = 4.5
			lantern_light.omni_attenuation = 1.6
			lantern_light.shadow_enabled = false
			lantern_light.position = gp + Vector3(0.0, 0.30 * gsc, 0.0)
			camp.add_child(lantern_light)

	# 左侧：两棵焦黑枯树 + 一地骸骨（参考图左下的头骨与肋骨）
	for i in 2:
		var tp := Vector3(-10.0 - float(i) * 3.2, 0.0, -3.0 - float(i) * 4.4)
		tp.y = _terrain_height(tp.x, tp.z)
		var tg := Node3D.new()
		tg.name = "CampTree_%02d" % [i + 1]
		tg.position = tp
		tg.rotation.y = rng.randf() * TAU
		var tsc2 := 1.15 + rng.randf() * 0.3
		tg.scale = Vector3(tsc2, tsc2 * 1.25, tsc2)
		camp.add_child(tg)
		var ttrunk := MeshInstance3D.new()
		ttrunk.name = "Trunk"
		ttrunk.mesh = tree_meshes[i % tree_meshes.size()] as ArrayMesh
		ttrunk.material_override = _mats["mat_charred_tree"]
		tg.add_child(ttrunk)
	var camp_bones := [
		[Vector3(-8.0, 0.0, 1.6), 1],
		[Vector3(-6.4, 0.0, 2.9), 0],
		[Vector3(-9.3, 0.0, 3.2), 2]]
	for i in camp_bones.size():
		var ba: Array = camp_bones[i]
		var cbp: Vector3 = ba[0]
		cbp.y = _terrain_height(cbp.x, cbp.z) - 0.05
		var bone := MeshInstance3D.new()
		bone.name = "CampBone_%02d" % [i + 1]
		bone.mesh = bone_meshes[int(ba[1]) % bone_meshes.size()] as ArrayMesh
		bone.material_override = _mats["mat_bone"]
		bone.position = cbp
		bone.rotation.y = rng.randf() * TAU
		camp.add_child(bone)

	# 注：可拾取食材（CaveIngredient）已按需求移除，本章当前阶段为纯场景，
	# 不再生成 Ingredients 节点；恢复时按上面的写法加回即可。
	# ---- 出生点与预览相机
	var spawn := Node3D.new()
	spawn.name = "Spawn"
	root.add_child(spawn)
	var marker := Marker3D.new()
	marker.name = "PlayerSpawn"
	marker.position = Vector3(0.0, _terrain_height(0.0, 0.0) + 0.1, 0.0)
	spawn.add_child(marker)
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(0.0, 5.5, 13.0)
	camera.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	spawn.add_child(camera)
	return root


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESH_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEXTURE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHAPE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/chapter2"))
	_gen_rock_texture()
	_gen_smoke_texture()
	for m in ["mat_rock", "mat_rock_shell", "mat_charred_tree", "mat_bone", "mat_canvas",
			"mat_metal", "mat_stone", "mat_lava_pool", "mat_lava_fall", "mat_smoke", "mat_ember"]:
		_mats[m] = load(MAT_DIR + "/" + m + ".tres")
	_pools = _make_pool_spots(rng)
	var root := _build_scene(rng)
	_set_owner(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		printerr("场景打包失败: %d" % err)
	err = ResourceSaver.save(packed, SCENE_PATH)
	print("场景 -> %s  err=%d  节点数=%d  岩浆池=%d" % [SCENE_PATH, err, _count_nodes(root), _pools.size()])
	quit()


# ---------------------------------------------------------------- 点位数据
class PoolSpot:
	var x: float
	var z: float
	var radius: float
	var bowl: float
	var depth: float
	var seedv: int
	var surface_y: float
	var ceil_y: float
