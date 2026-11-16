extends SceneTree
# 只读诊断：打印奶蛙 GLB 在 Godot 中的节点树、骨骼层级与动画列表。
# 运行：Godot --headless --path <项目> --script res://tools/inspect_player_model.gd


func _dump(node: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var extra := ""
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		extra = " verts=%d surfaces=%d" % [_mesh_verts(mi.mesh), mi.mesh.get_surface_count()] if mi.mesh else " mesh=null"
	elif node is AnimationPlayer:
		extra = " clips=%s" % str((node as AnimationPlayer).get_animation_list())
	print("%s- %s [%s]%s" % [pad, node.name, node.get_class(), extra])
	for c in node.get_children():
		_dump(c, depth + 1)


func _mesh_verts(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		total += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size()
	return total


func _dump_skeleton(sk: Skeleton3D) -> void:
	print("-- skeleton %s bones=%d --" % [sk.name, sk.get_bone_count()])
	for i in sk.get_bone_count():
		var parent := sk.get_bone_parent(i)
		print("   [%2d] %-24s parent=%s rest_len=%.3f" % [
			i, sk.get_bone_name(i),
			("-1" if parent < 0 else "%d:%s" % [parent, sk.get_bone_name(parent)]),
			sk.get_bone_rest(i).origin.length(),
		])


func _dump_clips(ap: AnimationPlayer) -> void:
	print("-- animation clips --")
	for name in ap.get_animation_list():
		var anim := ap.get_animation(name)
		var tracks := anim.get_track_count()
		var paths := []
		for t in tracks:
			paths.append(anim.track_get_path(t).get_concatenated_subnames() if anim.track_get_path(t).get_subname_count() > 0 else anim.track_get_path(t).get_concatenated_names())
		print("   %s  len=%.2fs loop=%d tracks=%d" % [name, anim.length, anim.loop_mode, tracks])
		print("     paths=%s" % str(paths))


func _init() -> void:
	var path := "res://assets/models/nailong_runner.glb"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			path = a.substr("--model=".length())
	var res := load(path)
	if res is PackedScene:
		print("=== node tree of %s ===" % path)
		var inst: Node = (res as PackedScene).instantiate()
		_dump(inst, 0)
		var skel := _find(inst, "Skeleton3D") as Skeleton3D
		if skel:
			_dump_skeleton(skel)
		var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
		if ap:
			_dump_clips(ap)
		else:
			print("!! no AnimationPlayer in model")
		inst.free()
	else:
		print("!! %s is not a PackedScene: %s" % [path, str(res)])
	quit()


func _find(root: Node, cls: String) -> Node:
	if root.get_class() == cls:
		return root
	for c in root.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null
