extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var scn = load("res://assets/Blender/SnowBarrier.blend")
	if scn == null:
		print("SB_LOAD_FAIL")
		quit()
		return
	var inst = scn.instantiate()
	root.add_child(inst)
	await create_timer(0.2).timeout
	var mesh_nodes: Array = []
	var stack: Array = [inst]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			mesh_nodes.append(n)
		for c in n.get_children():
			stack.push_back(c)
	for mn in mesh_nodes:
		var m = mn.mesh
		if m is ArrayMesh:
			var arr: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var miny = 1e9; var maxy = -1e9
			var minz = 1e9; var maxz = -1e9
			var minx = 1e9; var maxx = -1e9
			for v in arr:
				miny = min(miny, v.y); maxy = max(maxy, v.y)
				minz = min(minz, v.z); maxz = max(maxz, v.z)
				minx = min(minx, v.x); maxx = max(maxx, v.x)
			print("SB_MESH y=", snappedf(miny,0.01), "..", snappedf(maxy,0.01),
				" z=", snappedf(minz,0.01), "..", snappedf(maxz,0.01),
				" x=", snappedf(minx,0.01), "..", snappedf(maxx,0.01),
				" verts=", arr.size())
		elif m is PrimitiveMesh:
			print("SB_PRIM type=", m.get_class(), " size=", m.get("size") if m is BoxMesh else "n/a")
	print("SB_MESH_DONE")
	quit()
