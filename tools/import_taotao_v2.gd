extends SceneTree
func _initialize(): call_deferred("run")
func own(n,scene):
	for c in n.get_children():
		c.owner=scene
		own(c,scene)
func run():
	var document=GLTFDocument.new()
	var state=GLTFState.new()
	var result=document.append_from_file(ProjectSettings.globalize_path("res://assets/models/taotao/taotao.glb"),state)
	if result!=OK: quit(result); return
	var imported=document.generate_scene(state)
	for mesh in imported.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var material=mesh.mesh.surface_get_material(i)
			if material is StandardMaterial3D:
				material.vertex_color_use_as_albedo=true
				material.vertex_color_is_srgb=false
	root.add_child(imported)
	var model=Node3D.new()
	model.name="TaoTaoModel"
	root.add_child(model)
	for group in ["Head","PonytailLeft","PonytailRight","ClampArm","WrenchArm","Body","Boiler"]:
		var part=imported.find_child(group,true,false)
		if part==null: push_error("Missing group: "+group); quit(1); return
		part.reparent(model,true)
	own(model,model)
	var packed=PackedScene.new()
	packed.pack(model)
	result=ResourceSaver.save(packed,"res://assets/models/taotao/taotao_model.tscn")
	print("REBUILT_NATIVE_MODEL error=",result," surfaces=",model.find_children("*","MeshInstance3D",true,false).size())
	quit(result)
