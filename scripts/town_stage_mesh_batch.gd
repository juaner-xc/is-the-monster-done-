extends RefCounted


static func combine(parent: Node3D, parts: Array[MeshInstance3D], batch_name: String) -> void:
	if parts.is_empty():
		return
	var surfaces: Dictionary[Material, SurfaceTool] = {}
	for part in parts:
		var material := part.material_override
		if not surfaces.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			surfaces[material] = surface
		surfaces[material].append_from(part.mesh, 0, part.transform)
		part.free()
	var mesh := ArrayMesh.new()
	for surface in surfaces.values():
		surface.commit(mesh)
	var batch := MeshInstance3D.new()
	batch.name = batch_name
	batch.mesh = mesh
	parent.add_child(batch)
