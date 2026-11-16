@tool
extends Node3D
## PM3D 小熊模型容器：glTF 导入的材质默认没开 vertex_color_use_as_albedo，
## 会导致分区顶点色（绿眼/肚皮/爪子）不显示。这里在 ready 时统一修正。

func _ready() -> void:
	fix_vertex_colors(self)


static func fix_vertex_colors(root: Node) -> void:
	for mi in _find_meshes(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var mat := mesh.surface_get_material(si)
			if mat is StandardMaterial3D:
				var std := mat as StandardMaterial3D
				if not std.vertex_color_use_as_albedo:
					# 材质是共享资源，复制后改避免污染其它模型
					std = std.duplicate() as StandardMaterial3D
					std.vertex_color_use_as_albedo = true
					mesh.surface_set_material(si, std)


static func _find_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out
