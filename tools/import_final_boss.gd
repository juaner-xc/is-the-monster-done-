extends SceneTree
func _initialize(): call_deferred("run")
func own(n,scene):
	for c in n.get_children():
		c.owner=scene
		own(c,scene)
func run():
	var doc=GLTFDocument.new()
	var state=GLTFState.new()
	var error=doc.append_from_file(ProjectSettings.globalize_path("res://assets/models/final_boss/final_boss.glb"),state)
	if error!=OK: quit(error);return
	var imported=doc.generate_scene(state)
	root.add_child(imported)
	for mesh in imported.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var mat=mesh.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				mat.vertex_color_use_as_albedo=true
				mat.vertex_color_is_srgb=false
	var model=Node3D.new()
	model.name="FinalBossModel"
	root.add_child(model)
	for id in ["Body","Head","Cloche","LeftArm","RightArm","Sauce","OrbitPlates","Costume"]:
		var group=imported.find_child(id,true,false)
		if group!=null:group.reparent(model,true)
	own(model,model)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models/final_boss"))
	var packed=PackedScene.new()
	packed.pack(model)
	error=ResourceSaver.save(packed,"res://assets/models/final_boss/final_boss_model.tscn")
	print("FINAL_BOSS_NATIVE_SAVED error=",error," surfaces=",model.find_children("*","MeshInstance3D",true,false).size())
	quit(error)
