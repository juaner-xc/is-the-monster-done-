extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	# 1) 基准：引擎自带 BoxMesh 的 +Z 面三角形绕序方向（BoxMesh 渲染必然正确）
	var bm := BoxMesh.new()
	var arrays: Array = bm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var plus := 0
	var minus := 0
	if idx.size() > 0:
		for t in range(0, idx.size(), 3):
			var a: Vector3 = verts[idx[t]]
			var b: Vector3 = verts[idx[t + 1]]
			var c: Vector3 = verts[idx[t + 2]]
			if a.z > 0.4 and b.z > 0.4 and c.z > 0.4:
				var n: Vector3 = (b - a).cross(c - a)
				if n.z > 0.0:
					plus += 1
				else:
					minus += 1
	print("BOX_ZFACE rhs_plus=", plus, " rhs_minus=", minus)

	# 2) 雪堆网格：存储法线是否朝外（generate_normals 按引擎约定生成，可直接判定绕序是否正确）
	var mesh: Mesh = load("res://assets/meshes/snow_berm.tres")
	var arr2: Array = mesh.surface_get_arrays(0)
	var v2: PackedVector3Array = arr2[Mesh.ARRAY_VERTEX]
	var n2: PackedVector3Array = arr2[Mesh.ARRAY_NORMAL]
	var i2: PackedInt32Array = PackedInt32Array()
	if arr2[Mesh.ARRAY_INDEX] != null:
		i2 = arr2[Mesh.ARRAY_INDEX]
	var center := Vector3.ZERO
	for v in v2:
		center += v
	center = center / float(v2.size())
	var out_cnt := 0
	var in_cnt := 0
	if i2.size() > 0:
		for t in range(0, i2.size(), 3):
			var fc: Vector3 = (v2[i2[t]] + v2[i2[t + 1]] + v2[i2[t + 2]]) / 3.0
			var fn: Vector3 = n2[i2[t]]
			if fn.dot(fc - center) > 0.0:
				out_cnt += 1
			else:
				in_cnt += 1
	else:
		for t in range(0, v2.size(), 3):
			var fc: Vector3 = (v2[t] + v2[t + 1] + v2[t + 2]) / 3.0
			var fn: Vector3 = n2[t]
			if fn.dot(fc - center) > 0.0:
				out_cnt += 1
			else:
				in_cnt += 1
	print("BERM normals outward=", out_cnt, " inward=", in_cnt, " tris=", (i2.size() / 3) if i2.size() > 0 else v2.size() / 3)
	quit()
