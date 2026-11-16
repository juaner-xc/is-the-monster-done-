extends SceneTree
var hall
var failures := 0
func _initialize(): call_deferred("run")
func check_route(label_: String, route: Array):
	var shape := CapsuleShape3D.new()
	shape.radius = 0.30
	shape.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [hall.player.get_rid()]
	for i in route.size()-1:
		var a: Vector3 = route[i]
		var b: Vector3 = route[i+1]
		var steps := maxi(1, int(a.distance_to(b)/0.25))
		for j in steps+1:
			var p = a.lerp(b, float(j)/steps)
			query.transform = Transform3D(Basis.IDENTITY, p+Vector3.UP*0.9)
			var hits = hall.get_world_3d().direct_space_state.intersect_shape(query, 1)
			if not hits.is_empty():
				print("BLOCKED_ROUTE ", label_, " at=", p, " collider=", hits[0].collider.name)
				failures += 1
				return
	print("ROUTE_OK ", label_)
func run():
	hall = load("res://scenes/final_banquet_hall.tscn").instantiate()
	root.add_child(hall)
	current_scene = hall
	await create_timer(0.7).timeout
	hall.player.set_physics_process(false)
	print("CHAPTER3_PLAYER=", hall.player.global_position, " POINTS=", hall.points.size())
	hall._toggle_design_view()
	var roof=hall.get_node("Architecture").find_child("OrnateCeiling",true,false)
	if roof!=null:
		print("PRESERVED_CEILING_MESHES=",roof.find_children("*","MeshInstance3D",true,false).size())
		print("PRESERVED_CHANDELIERS=",roof.find_children("GrandChandelier*","Node3D",true,false).size())
		roof.set_lights(false)
		if roof.lights_on:failures+=1
		roof.set_lights(true)
	if roof==null or roof.visible:
		print("ROOF_TOGGLE_FAILED")
		failures+=1
	hall._toggle_design_view()
	check_route("entry_to_arena", [Vector3(0,0,39),Vector3(0,0,13),Vector3(6,0,12),Vector3(6,0,-15)])
	check_route("foyer_to_kitchen", [Vector3(0,0,25),Vector3(-12,0,25),Vector3(-21,0,23)])
	check_route("kitchen_to_preparation", [Vector3(-21,0,17),Vector3(0,0,17)])
	check_route("foyer_to_supply", [Vector3(0,0,25),Vector3(15.5,0,25),Vector3(16.5,0,22),Vector3(23,0,22)])
	check_route("supply_to_preparation", [Vector3(23,0,17),Vector3(0,0,17)])
	check_route("arena_to_core", [Vector3(6,0,-15),Vector3(6,0,-26),Vector3(0,0,-27),Vector3(0,0,-32)])
	hall.show_book()
	if not hall.book_seen: failures += 1
	hall.close_panel()
	for room in ["snow", "volcano"]:
		for i in 3: hall.operate_valve(room,i)
	print("CHAPTER3_CORES=",hall.rare_cores)
	if hall.rare_cores != 2: failures += 1
	print("CHAPTER3_VERIFY_FAILURES=",failures)
	var result := failures
	hall.queue_free()
	hall = null
	current_scene = null
	await process_frame
	await process_frame
	quit(result)
