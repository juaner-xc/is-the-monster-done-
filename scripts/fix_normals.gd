extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var mesh: Mesh = load("res://assets/meshes/snow_berm.tres")
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	# 法线整体翻转（generate_normals 对顺时针绕序生成了反向法线）
	for i in norms.size():
		norms[i] = -norms[i]
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var err := ResourceSaver.save(new_mesh, "res://assets/meshes/snow_berm.tres")
	print("FIX_SAVE err=", err)
	# 复核：法线应全部朝外
	var arr2: Array = new_mesh.surface_get_arrays(0)
	var v2: PackedVector3Array = arr2[Mesh.ARRAY_VERTEX]
	var n2: PackedVector3Array = arr2[Mesh.ARRAY_NORMAL]
	var center := Vector3.ZERO
	for v in v2:
		center += v
	center = center / float(v2.size())
	var out_cnt := 0
	var in_cnt := 0
	for t in range(0, v2.size(), 3):
		var fc: Vector3 = (v2[t] + v2[t + 1] + v2[t + 2]) / 3.0
		if n2[t].dot(fc - center) > 0.0:
			out_cnt += 1
		else:
			in_cnt += 1
	print("VERIFY outward=", out_cnt, " inward=", in_cnt)
	quit()
