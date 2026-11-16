extends Node3D
class_name WaterZone

## 湖泊水体区域：按水面网格的真实形状标定水域边界与水深。
## 启动时读取水面网格顶点，按角度分桶预计算每个方向的湖岸半径，
## depth_at 据此精确判定"该点是否在湖内"及水深（中心深、岸边浅）。

@export var center := Vector3(129.5, 0.0, -49.7)
@export var surface_y := 0.05
@export var max_depth := 1.8
@export var mesh_path := "res://assets/models/lake/water_surface.obj"
@export var mesh_origin := Vector2(135.0, -55.0)
@export var mesh_scale := 0.6
@export var bins := 72

var _r_max := PackedFloat32Array()

func _ready() -> void:
	add_to_group("water_zone")
	_build_profile()

## 读取水面网格，按角度分桶记录每个方向距湖心的最大半径。
func _build_profile() -> void:
	_r_max = PackedFloat32Array()
	_r_max.resize(bins)
	_r_max.fill(0.0)
	var mesh: Mesh = load(mesh_path)
	if mesh == null:
		_r_max.fill(33.0)
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var c := Vector2(center.x, center.z)
	# 逐三角形沿边采样（边界决定各方向最大半径），8 段细分避免稀疏顶点漏桶
	if idx.size() > 0:
		for i in range(0, idx.size(), 3):
			_sample_edge(verts[idx[i]], verts[idx[i + 1]], c)
			_sample_edge(verts[idx[i + 1]], verts[idx[i + 2]], c)
			_sample_edge(verts[idx[i + 2]], verts[idx[i]], c)
	else:
		for i in range(0, verts.size(), 3):
			_sample_edge(verts[i], verts[i + 1], c)
			_sample_edge(verts[i + 1], verts[i + 2], c)
			_sample_edge(verts[i + 2], verts[i], c)
	# 补齐可能为 0 的桶：取相邻非零桶均值，仍为 0 则用全局最大
	var global_max: float = 0.0
	for b in bins:
		if _r_max[b] > global_max:
			global_max = _r_max[b]
	for pass_i in range(2):
		for b in bins:
			if _r_max[b] > 0.0:
				continue
			var prev: float = _r_max[(b - 1 + bins) % bins]
			var next: float = _r_max[(b + 1) % bins]
			if prev > 0.0 and next > 0.0:
				_r_max[b] = (prev + next) * 0.5
			elif prev > 0.0:
				_r_max[b] = prev
			elif next > 0.0:
				_r_max[b] = next
			else:
				_r_max[b] = global_max

func _sample_edge(a_local: Vector3, b_local: Vector3, c: Vector2) -> void:
	var a := Vector2(mesh_origin.x + a_local.x * mesh_scale, mesh_origin.y + a_local.z * mesh_scale)
	var b := Vector2(mesh_origin.x + b_local.x * mesh_scale, mesh_origin.y + b_local.z * mesh_scale)
	for s in range(9):
		var p: Vector2 = a.lerp(b, float(s) / 8.0)
		var rel: Vector2 = p - c
		var r: float = rel.length()
		if r <= 0.001:
			continue
		var bin := int((atan2(rel.y, rel.x) + PI) / (2.0 * PI) * float(bins))
		bin = clampi(bin, 0, bins - 1)
		if r > _r_max[bin]:
			_r_max[bin] = r

## 返回该世界坐标处的水深（米）：不在湖内返回 -1。
func depth_at(world_pos: Vector3) -> float:
	if _r_max.size() == 0:
		return -1.0
	var dx: float = world_pos.x - center.x
	var dz: float = world_pos.z - center.z
	var d: float = Vector2(dx, dz).length()
	var bin := int((atan2(dz, dx) + PI) / (2.0 * PI) * float(bins))
	bin = clampi(bin, 0, bins - 1)
	var r_max: float = _r_max[bin]
	if d >= r_max:
		return -1.0
	var t := 1.0 - clampf(d / r_max, 0.0, 1.0)
	return lerpf(0.12, max_depth, t * t)
