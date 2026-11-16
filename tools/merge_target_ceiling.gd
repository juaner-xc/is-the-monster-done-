extends SceneTree
func _initialize(): call_deferred("run")
func own_native(n: Node, scene: Node):
	for child in n.get_children():
		child.owner=scene
		if child.scene_file_path.is_empty(): own_native(child,scene)
func run():
	var previous=load("res://scenes/final_banquet_hall.tscn").instantiate()
	var source=previous.get_node_or_null("Architecture/OrnateCeiling")
	if source==null:
		push_error("Original ornate ceiling missing; merge stopped")
		quit(1)
		return
	var ceiling=source.duplicate()
	var map=load("res://scenes/final_banquet_hall_design.tscn").instantiate()
	map.scene_file_path=""
	map.get_node("Architecture").add_child(ceiling)
	ceiling.name="OrnateCeiling"
	ceiling.position=Vector3(0,0.1574,-7)
	ceiling.scale=Vector3(32.0/33.7,4.4/6.1,42.0/59.6)
	ceiling.owner=map
	own_native(ceiling,map)
	var standalone=ceiling.duplicate()
	standalone.owner=null
	own_native(standalone,standalone)
	var ceiling_pack=PackedScene.new()
	ceiling_pack.pack(standalone)
	ResourceSaver.save(ceiling_pack,"res://assets/chapter3/ornate_ceiling.tscn")
	standalone.free()
	var packed=PackedScene.new()
	var error=packed.pack(map)
	if error==OK:error=ResourceSaver.save(packed,"res://scenes/final_banquet_hall.tscn")
	print("MERGE_DONE error=",error," ceiling_meshes=",ceiling.find_children("*","MeshInstance3D",true,false).size()," chandeliers=",ceiling.find_children("GrandChandelier*","Node3D",true,false).size())
	previous.free()
	map.free()
	quit(error)
