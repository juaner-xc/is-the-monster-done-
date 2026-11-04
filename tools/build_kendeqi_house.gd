extends SceneTree
## Rebuilds editable native meshes and a portable model without external DCC tools.
var scene_root: Node3D
var mats: Dictionary = {}

func _initialize() -> void:
	call_deferred("build")

func mat(key: String, hex: String, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = Color(hex)
	m.roughness = 0.94
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = emission
	mats[key] = m
	return m

func group(parent: Node, label: String, pos := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = pos
	parent.add_child(node)
	node.owner = scene_root
	return node

func mesh_part(parent: Node, label: String, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	n.position = pos
	n.material_override = material
	parent.add_child(n)
	n.owner = scene_root
	return n

func box(parent: Node, label: String, size: Vector3, pos: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := mesh_part(parent, label, mesh, pos, material)
	if solid:
		collision_box(parent, label + "Collision", size, pos)
	return n

func collision_box(parent: Node, label: String, size: Vector3, pos: Vector3, layer := 1) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	body.owner = scene_root
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	shape.owner = scene_root

func orb(parent: Node, label: String, pos: Vector3, size: Vector3, material: Material, sides := 12) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = sides
	s.rings = 6
	var n := mesh_part(parent, label, s, pos, material)
	n.scale = size
	return n

func cylinder(parent: Node, label: String, pos: Vector3, radius: float, height: float, material: Material, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh_part(parent, label, mesh, pos, material)

func rod(parent: Node, label: String, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var n := cylinder(parent, label, (a+b)*0.5, radius, a.distance_to(b), material)
	var up := (b-a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	n.basis = Basis(right, up, right.cross(up).normalized())
	return n

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a,b,c]:
		st.add_vertex(p)

func lathe(parent: Node, label: String, rings: Array, material: Material, sides := 16) -> MeshInstance3D:
	# Each ring is (height, radius_x, radius_z, offset_x, offset_z).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for j in range(rings.size()-1):
		for i in sides:
			var pts: Array[Vector3] = []
			for pair in [Vector2i(j,i),Vector2i(j,i+1),Vector2i(j+1,i+1),Vector2i(j+1,i)]:
				var r: Array = rings[pair.x]
				var angle: float = TAU*pair.y/sides
				pts.append(Vector3(sin(angle)*r[1]+r[3],r[0],cos(angle)*r[2]+r[4]))
			triangle(st,pts[0],pts[2],pts[1])
			triangle(st,pts[0],pts[3],pts[2])
	st.generate_normals()
	return mesh_part(parent,label,st.commit(),Vector3.ZERO,material)

func apron(parent: Node) -> void:
	var rows := [[1.51,0.17,0.285],[1.25,0.30,0.39],[0.95,0.39,0.43],[0.59,0.43,0.40]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 3:
		for i in 8:
			var pts: Array[Vector3] = []
			for pair in [Vector2i(j,i),Vector2i(j,i+1),Vector2i(j+1,i+1),Vector2i(j+1,i)]:
				var row: Array = rows[pair.x]
				var t := (float(pair.y)/8.0-0.5)*2.0
				pts.append(Vector3(t*row[1],row[0],row[2]-t*t*0.11))
			triangle(st,pts[0],pts[1],pts[2])
			triangle(st,pts[0],pts[2],pts[3])
	st.generate_normals()
	var cloth := mats.Linen.duplicate() as StandardMaterial3D
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_part(parent,"ApronTailoredPanel",st.commit(),Vector3.ZERO,cloth)
	box(parent,"ApronPocket",Vector3(0.24,0.20,0.035),Vector3(0.10,1.0,0.43),mats.LinenShade)
	box(parent,"NotebookLeather",Vector3(0.14,0.18,0.045),Vector3(0.11,1.11,0.439),mats.Leather)
	box(parent,"NotebookPages",Vector3(0.115,0.15,0.012),Vector3(0.11,1.12,0.469),mats.Linen)
	rod(parent,"Pencil",Vector3(0.23,1.04,0.443),Vector3(0.24,1.28,0.43),0.012,mats.Mustard)
	box(parent,"ApronPatch",Vector3(0.15,0.13,0.014),Vector3(-0.20,0.72,0.389),mats.CoatLight).rotation.z = 0.12
	for i in 4:
		rod(parent,"PatchStitch",Vector3(-0.273+i*0.043,0.655,0.40),Vector3(-0.269+i*0.043,0.681,0.40),0.004,mats.Linen)
	for side in [-1.0,1.0]:
		rod(parent,"ApronStrap",Vector3(side*0.16,1.5,0.30),Vector3(side*0.25,1.61,0.10),0.032,mats.Linen)
		orb(parent,"ApronButton",Vector3(side*0.16,1.47,0.312),Vector3.ONE*0.036,mats.Brass)
	box(parent,"BackWaistTie",Vector3(0.86,0.052,0.035),Vector3(0,1.15,-0.34),mats.Linen)
	for side in [-1.0,1.0]:
		var ribbon := box(parent,"BowRibbon",Vector3(0.15,0.04,0.035),Vector3(side*0.07,1.15,-0.37),mats.Linen)
		ribbon.rotation.z = side*0.4
		rod(parent,"ApronTieTail",Vector3(0,1.14,-0.38),Vector3(side*0.12,0.94,-0.38),0.018,mats.Linen)

func build_cook() -> void:
	scene_root = Node3D.new()
	scene_root.name = "Kendeqi"
	var visual := group(scene_root,"Visual")
	for side in [-1.0,1.0]:
		orb(visual,"SnowBoot",Vector3(side*0.20,0.16,0.11),Vector3(0.32,0.31,0.52),mats.Leather)
		box(visual,"BootSole",Vector3(0.30,0.055,0.45),Vector3(side*0.20,0.045,0.10),mats.Dark)
		cylinder(visual,"TrouserLeg",Vector3(side*0.20,0.45,0),0.145,0.45,mats.Trousers,0.17)
		for i in 3:
			cylinder(visual,"BootWrap",Vector3(side*0.20,0.28+i*0.055,0),0.16,0.038,mats.LinenShade)
	lathe(visual,"WoolCoat",[[0.52,0.44,0.31,0,0],[0.63,0.49,0.35,0,0],[0.95,0.48,0.37,0,0],[1.22,0.43,0.33,0,0],[1.48,0.34,0.26,0,0],[1.61,0.23,0.19,0,0]],mats.Coat)
	lathe(visual,"CreamTunic",[[1.25,0.24,0.25,0,0.06],[1.54,0.17,0.19,0,0.06],[1.62,0.14,0.15,0,0.04]],mats.Linen)
	for side in [-1.0,1.0]:
		var seam := box(visual,"CoatFrontSeam",Vector3(0.045,0.79,0.035),Vector3(side*0.32,1.08,0.29),mats.CoatShade)
		seam.rotation.z = side*0.12
		var arm := group(visual,"RightArm" if side > 0 else "LeftArm",Vector3(side*0.31,1.44,0))
		rod(arm,"CoatUpperSleeve",Vector3.ZERO,Vector3(side*0.22,-0.27,0.04),0.185,mats.Coat)
		rod(arm,"RolledLinenCuff",Vector3(side*0.22,-0.27,0.04),Vector3(side*0.20,-0.32,0.12),0.185,mats.LinenShade)
		rod(arm,"Forearm",Vector3(side*0.20,-0.32,0.12),Vector3(side*0.13,-0.40,0.34),0.105,mats.Skin)
		orb(arm,"WorkingHand",Vector3(side*0.13,-0.39,0.37),Vector3(0.17,0.18,0.20),mats.Skin)
		orb(arm,"Thumb",Vector3(side*0.05,-0.37,0.40),Vector3(0.075,0.095,0.10),mats.SkinLight)
		if side > 0:
			rod(arm,"LadleHandle",Vector3(0.13,-0.41,0.38),Vector3(-0.13,-0.20,0.72),0.026,mats.Wood)
			orb(arm,"LadleBowl",Vector3(-0.15,-0.20,0.74),Vector3(0.18,0.065,0.12),mats.Wood)
		else:
			cylinder(arm,"SoupBowl",Vector3(-0.11,-0.32,0.48),0.18,0.14,mats.Wood,0.23)
			cylinder(arm,"SoupSurface",Vector3(-0.11,-0.243,0.48),0.206,0.01,mats.Soup)
	apron(visual)
	cylinder(visual,"Neck",Vector3(0,1.65,0),0.16,0.20,mats.Skin)
	lathe(visual,"WoolScarf",[[1.52,0.25,0.22,0,0.01],[1.59,0.28,0.24,0,0.01],[1.69,0.24,0.20,0,0.01]],mats.Mustard)
	var flap := box(visual,"ScarfLooseEnd",Vector3(0.15,0.31,0.05),Vector3(0.17,1.44,0.32),mats.Mustard)
	flap.rotation.z = -0.18
	for i in 5:
		rod(visual,"ScarfFringe",Vector3(0.1+i*0.03,1.285,0.32),Vector3(0.105+i*0.03,1.23,0.32),0.009,mats.Mustard)
	var head := group(visual,"HeadPivot",Vector3(0,1.73,0.025))
	orb(head,"Face",Vector3(0,0.28,0),Vector3(0.64,0.68,0.55),mats.Skin,16)
	for side in [-1.0,1.0]:
		orb(head,"Ear",Vector3(side*0.315,0.27,0),Vector3(0.13,0.20,0.09),mats.Skin)
		orb(head,"Cheek",Vector3(side*0.15,0.22,0.235),Vector3(0.20,0.17,0.10),mats.SkinLight)
		orb(head,"EyeSocket",Vector3(side*0.135,0.34,0.25),Vector3(0.13,0.082,0.045),mats.SkinShade)
		orb(head,"Eye",Vector3(side*0.135,0.345,0.271),Vector3(0.074,0.059,0.023),mats.EyeWhite)
		orb(head,"Pupil",Vector3(side*0.132,0.344,0.285),Vector3(0.031,0.039,0.014),mats.Dark)
		rod(head,"KindEyebrow",Vector3(side*0.077,0.419,0.259),Vector3(side*0.206,0.405,0.252),0.028,mats.Hair)
		orb(head,"Sideburn",Vector3(side*0.275,0.25,0.04),Vector3(0.13,0.27,0.28),mats.Hair)
		orb(head,"HairTuft",Vector3(side*0.28,0.51,0.015),Vector3(0.19,0.17,0.35),mats.Hair)
		for i in 3:
			orb(head,"BeardTuft",Vector3(side*(0.08+i*0.064),0.015+i*0.036,0.17),Vector3(0.17,0.21-i*0.012,0.24),mats.Hair if i%2==0 else mats.HairShade)
		var moustache := orb(head,"Moustache",Vector3(side*0.09,0.155,0.28),Vector3(0.22,0.095,0.105),mats.Hair)
		moustache.rotation.z = side*0.14
		rod(head,"SmileCrease",Vector3(side*0.10,0.115,0.266),Vector3(side*0.17,0.143,0.255),0.009,mats.SkinShade)
	orb(head,"Nose",Vector3(0,0.255,0.309),Vector3(0.15,0.16,0.16),mats.SkinLight)
	orb(head,"ChinBeard",Vector3(0,-0.035,0.19),Vector3(0.22,0.17,0.24),mats.Hair)
	lathe(head,"SoftCap",[[0.47,0.30,0.26,0,-0.015],[0.61,0.30,0.26,0,-0.025],[0.77,0.23,0.21,-0.025,-0.03],[0.86,0.15,0.14,-0.13,-0.025],[0.80,0.08,0.08,-0.28,-0.02],[0.69,0.015,0.015,-0.34,-0.02]],mats.Coat,12)
	lathe(head,"CapFoldedBrim",[[0.46,0.315,0.272,0,-0.015],[0.56,0.32,0.278,0,-0.015]],mats.CoatLight,12)
	orb(head,"CapPom",Vector3(-0.34,0.69,-0.02),Vector3.ONE*0.13,mats.Mustard)
	box(head,"CapPatch",Vector3(0.10,0.075,0.025),Vector3(-0.11,0.66,0.223),mats.LinenShade).rotation.z = 0.2
	# Readable small service bell at the waist.
	rod(visual,"BellLeatherLoop",Vector3(-0.43,1.18,0.12),Vector3(-0.47,1.02,0.18),0.022,mats.Leather)
	cylinder(visual,"ServiceBell",Vector3(-0.47,0.94,0.18),0.09,0.13,mats.Brass,0.035)
	cylinder(visual,"BellLip",Vector3(-0.47,0.875,0.18),0.10,0.018,mats.Brass)
	orb(visual,"BellClapper",Vector3(-0.47,0.86,0.18),Vector3.ONE*0.035,mats.Dark)
	DirAccess.make_dir_recursive_absolute("res://assets/models/npcs")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(scene_root,state)
	if error == OK:
		error = document.write_to_filesystem(state,"res://assets/models/npcs/kendeqi.glb")
	assert(error == OK,"Could not export Kendeqi GLB")
	collision_box(scene_root,"BodyCollision",Vector3(1.1,1.8,0.9),Vector3(0,0.9,0))
	scene_root.set_script(load("res://scripts/kendeqi_npc.gd"))
	save_scene("res://scenes/npcs/kendeqi.tscn")
	scene_root.free()

func save_scene(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packed := PackedScene.new()
	var error := packed.pack(scene_root)
	if error == OK:
		error = ResourceSaver.save(packed,path)
	assert(error == OK,"Failed to save " + path)
	print("BUILT ",path)

func window(parent: Node3D, x: float, y: float, z: float) -> void:
	box(parent,"WarmWindow",Vector3(1.4,1.25,0.05),Vector3(x,y,z),mats.Window)
	for side in [-1,1]:
		box(parent,"WindowJamb",Vector3(0.12,1.5,0.15),Vector3(x+side*0.79,y,z+0.02),mats.Timber)
		box(parent,"WindowSill",Vector3(1.7,0.12,0.20),Vector3(x,y+side*0.72,z+0.02),mats.Wood)
	box(parent,"WindowMullion",Vector3(0.06,1.32,0.12),Vector3(x,y,z+0.04),mats.Timber)
	box(parent,"WindowTransom",Vector3(1.5,0.06,0.12),Vector3(x,y,z+0.04),mats.Timber)

func wall(parent: Node, label: String, pos: Vector3, rotation_y: float, width: float, holes: Array) -> Node3D:
	var node := group(parent,label,pos)
	node.rotation.y = rotation_y
	var cuts: Array[float] = [-width*0.5,width*0.5]
	for hole in holes:
		cuts.append(hole.position.x)
		cuts.append(hole.end.x)
	cuts.sort()
	for i in range(cuts.size()-1):
		var left := cuts[i]
		var right := cuts[i+1]
		if right-left < 0.001:
			continue
		var low := 0.0
		var high := 4.2
		var opening := false
		for hole in holes:
			if (left+right)*0.5 > hole.position.x and (left+right)*0.5 < hole.end.x:
				low = hole.position.y
				high = hole.end.y
				opening = true
				break
		if opening:
			if low > 0:
				box(node,"SillWall",Vector3(right-left,low,0.24),Vector3((left+right)*0.5,low*0.5,0),mats.Plaster,true)
			box(node,"HeaderWall",Vector3(right-left,4.2-high,0.24),Vector3((left+right)*0.5,(4.2+high)*0.5,0),mats.Plaster,true)
		else:
			box(node,"WallPanel",Vector3(right-left,4.2,0.24),Vector3((left+right)*0.5,2.1,0),mats.Plaster,true)
	for x in [-width*0.5,width*0.5]:
		box(node,"OakPost",Vector3(0.22,4.3,0.32),Vector3(x,2.15,0),mats.Timber)
	box(node,"TopBeam",Vector3(width+0.2,0.22,0.34),Vector3(0,4.1,0),mats.Timber)
	return node

func table(parent: Node, pos: Vector3) -> void:
	var t := group(parent,"DiningTable",pos)
	box(t,"Tabletop",Vector3(2.35,0.14,1.3),Vector3(0,0.95,0),mats.Wood,true)
	for x in [-0.9,0.9]:
		box(t,"Trestle",Vector3(0.16,0.88,0.95),Vector3(x,0.44,0),mats.Timber)
	for z in [-1.0,1.0]:
		box(t,"Bench",Vector3(2.2,0.15,0.36),Vector3(0,0.46,z),mats.Wood,true)
		for x in [-0.8,0.8]:
			box(t,"BenchLeg",Vector3(0.13,0.42,0.3),Vector3(x,0.21,z),mats.Timber)
	for x in [-0.65,0.65]:
		cylinder(t,"WoodenBowl",Vector3(x,1.06,0),0.14,0.08,mats.WoodShade,0.18)
		cylinder(t,"BowlSoup",Vector3(x,1.103,0),0.16,0.008,mats.Soup)
		orb(t,"BreadRoll",Vector3(x,1.1,0.35),Vector3(0.30,0.16,0.19),mats.Bread)

func build_house() -> void:
	scene_root = Node3D.new()
	scene_root.name = "SnowDiningHouse"
	var exterior := group(scene_root,"Exterior")
	var cutaway := group(scene_root,"CutawayWalls")
	var roof := group(scene_root,"Roof")
	var interior := group(scene_root,"Interior")
	box(interior,"FloorCollision",Vector3(12,0.18,10),Vector3(0,-0.09,0),mats.Timber,true)
	for i in 25:
		box(interior,"Floorboard",Vector3(11.75,0.025,0.386),Vector3(0,0.006,-4.8+i*0.4),mats.Wood if i%3 else mats.WoodShade)
	var front_holes := [Rect2(-1.65,0,3.3,3.35),Rect2(-4.5,1.65,1.5,1.4),Rect2(3.0,1.65,1.5,1.4)]
	var front := wall(cutaway,"FrontWall",Vector3(0,0,5),0,12,front_holes)
	for x in [-3.75,3.75]:
		window(front,x,2.35,0)
		box(front,"LowerTimber",Vector3(4.2,0.15,0.28),Vector3(signf(x)*3.85,1.15,0.01),mats.Timber)
	var back := wall(exterior,"BackWall",Vector3(0,0,-5),0,12,[Rect2(-0.8,1.65,1.6,1.4)])
	window(back,0,2.35,0)
	wall(exterior,"WestWall",Vector3(-6,0,0),PI/2,10,[])
	wall(exterior,"EastWall",Vector3(6,0,0),PI/2,10,[])
	for x in [-6.0,6.0]:
		for z in [-3.3,0.0,3.3]:
			box(exterior,"SidePost",Vector3(0.31,4.2,0.2),Vector3(x,2.1,z),mats.Timber)
		box(exterior,"SideSill",Vector3(0.31,0.16,10),Vector3(x,0.6,0),mats.Timber)
	for x in [-1.73,1.73]:
		box(exterior,"DoorOakJamb",Vector3(0.22,3.45,0.36),Vector3(x,1.725,5.03),mats.Wood)
	box(exterior,"DoorLintel",Vector3(3.8,0.24,0.4),Vector3(0,3.46,5.03),mats.Wood)
	# The leaf is visibly open, and never blocks the 3.3 metre opening.
	var door := group(exterior,"OpenDoor",Vector3(-1.64,0,5.10))
	door.rotation.y = -1.30
	box(door,"PlankedDoor",Vector3(1.45,3.15,0.10),Vector3(0.73,1.575,0),mats.WoodShade,true)
	for y in [0.3,1.5,2.8]:
		box(door,"DoorBrace",Vector3(1.4,0.11,0.05),Vector3(0.73,y,0.08),mats.Wood)
	for x in [0.25,0.5,0.75,1.0,1.25]:
		box(door,"DoorPlankSeam",Vector3(0.014,3.05,0.012),Vector3(x,1.575,0.065),mats.Timber)
	orb(door,"DoorHandle",Vector3(1.23,1.5,0.12),Vector3(0.08,0.08,0.07),mats.Brass)
	# Protect the room from enemies while the player can freely cross the threshold.
	collision_box(scene_root,"ShelterEnemyBarrier",Vector3(3.3,3.35,0.20),Vector3(0,1.675,5),16)
	box(exterior,"Porch",Vector3(7,0.08,2.5),Vector3(0,-0.04,6.3),mats.WoodShade)
	for i in 7:
		box(exterior,"PorchBoard",Vector3(6.9,0.015,0.32),Vector3(0,0.008,5.25+i*0.36),mats.Wood)
	for x in [-3.5,3.5]:
		box(exterior,"PorchPost",Vector3(0.19,3.0,0.19),Vector3(x,1.5,7.1),mats.Timber)
	var awning := box(exterior,"PorchAwning",Vector3(7.4,0.13,2.9),Vector3(0,3.45,6.25),mats.Roof)
	awning.rotation.x = 0.12
	for side in [-1.0,1.0]:
		var panel := box(roof,"BlueSlateRoof",Vector3(7.05,0.20,11.6),Vector3(side*3.10,5.65,0),mats.Roof)
		panel.rotation.z = -side*deg_to_rad(26)
		for row in 6:
			for col in 9:
				var tile := box(panel,"SlateTile",Vector3(1.12,0.045,1.2),Vector3(-2.93+row*1.16,0.122,-5.1+col*1.25+(row%2)*0.18),mats.RoofLight if (row+col)%4==0 else mats.Roof)
				if (row+col*3)%5 == 0:
					box(tile,"SettledSnow",Vector3(0.95,0.045,0.88),Vector3(0,0.047,-0.1),mats.Snow)
		var gable := PrismMesh.new()
		gable.size = Vector3(12.4,3.0,0.22)
		mesh_part(roof,"PlasterGable",gable,Vector3(0,5.7,side*5.0),mats.Plaster)
		rod(roof,"GableRafter",Vector3(-6.2,4.2,side*5.12),Vector3(0,7.2,side*5.12),0.13,mats.Timber)
		rod(roof,"GableRafter",Vector3(0,7.2,side*5.12),Vector3(6.2,4.2,side*5.12),0.13,mats.Timber)
		box(roof,"GableKingPost",Vector3(0.22,2.8,0.26),Vector3(0,5.6,side*5.12),mats.Timber)
	rod(roof,"RoofRidge",Vector3(0,7.21,-5.8),Vector3(0,7.21,5.8),0.16,mats.Timber)
	box(roof,"StoneChimney",Vector3(1.0,3.5,1.0),Vector3(-4.2,6.1,-3.2),mats.Stone)
	box(roof,"ChimneyCap",Vector3(1.2,0.18,1.2),Vector3(-4.2,7.9,-3.2),mats.Snow)
	for i in 6:
		box(roof,"ChimneyCourse",Vector3(1.04,0.035,1.04),Vector3(-4.2,4.6+i*0.48,-3.2),mats.Plaster)
	# Sign and entry lanterns remain visible when the cutaway is open.
	box(exterior,"HangingSign",Vector3(2.1,0.65,0.12),Vector3(0,3.0,5.38),mats.WoodShade)
	label(exterior,"TavernSign","肯德齐的食堂",Vector3(0,3.0,5.46),0.0058,Color("ffe5b2"))
	for x in [-2.15,2.15]:
		box(exterior,"LanternBracket",Vector3(0.09,0.12,0.6),Vector3(x,2.9,5.24),mats.Dark)
		box(exterior,"LanternGlow",Vector3(0.23,0.40,0.23),Vector3(x,2.60,5.48),mats.Window)
		box(exterior,"LanternCap",Vector3(0.32,0.07,0.32),Vector3(x,2.84,5.48),mats.Dark)
		light(exterior,"DoorLantern",Vector3(x,2.55,5.8),Color("ffbf73"),0.7,6)
	# Two tables flank a generous central aisle.
	table(interior,Vector3(-3.6,0,1.6))
	table(interior,Vector3(3.6,0,1.6))
	box(interior,"CentralRug",Vector3(2.4,0.018,6.2),Vector3(0,0.025,0.6),mats.Rug)
	for x in [-1.13,1.13]:
		box(interior,"RugBorder",Vector3(0.06,0.022,6),Vector3(x,0.03,0.6),mats.Mustard)
	box(interior,"ServingCounter",Vector3(4.4,0.92,0.74),Vector3(0.65,0.46,-1.7),mats.WoodShade,true)
	box(interior,"Countertop",Vector3(4.65,0.14,0.92),Vector3(0.65,0.99,-1.7),mats.Wood)
	for i in 6:
		box(interior,"CounterPanel",Vector3(0.64,0.74,0.025),Vector3(-1.12+i*0.71,0.47,-1.312),mats.Wood)
	for x in [-0.9,0.0,1.0,2.1]:
		cylinder(interior,"WaitingSoupBowl",Vector3(x,1.10,-1.7),0.15,0.09,mats.WoodShade,0.20)
		cylinder(interior,"SoupInBowl",Vector3(x,1.15,-1.7),0.177,0.009,mats.Soup)
	box(interior,"PreparationBench",Vector3(3.5,0.13,0.8),Vector3(3.1,1.0,-3.95),mats.Wood,true)
	for x in [1.6,4.6]:
		box(interior,"PrepLeg",Vector3(0.16,1,0.6),Vector3(x,0.5,-3.95),mats.Timber)
	box(interior,"ChoppingBoard",Vector3(0.65,0.04,0.45),Vector3(2.1,1.095,-3.95),mats.WoodShade)
	for i in 3:
		orb(interior,"Bread",Vector3(3+i*0.35,1.16,-3.95),Vector3(0.36,0.2,0.24),mats.Bread)
	var shelf := group(interior,"KitchenShelf",Vector3(3.4,2.3,-4.65))
	for y in [0.0,0.75]:
		box(shelf,"ShelfPlank",Vector3(3.4,0.10,0.45),Vector3(0,y,0),mats.Wood)
		for i in 5:
			cylinder(shelf,"StorageJar",Vector3(-1.3+i*0.65,y+0.21,0),0.16,0.33,mats.CoatLight if i%2 else mats.LinenShade)
	var hearth := group(interior,"Hearth",Vector3(-4.25,0,-3.4))
	box(hearth,"FireBack",Vector3(2.3,2.9,0.35),Vector3(0,1.45,-0.55),mats.Stone)
	for x in [-0.9,0.9]:
		box(hearth,"StoneJamb",Vector3(0.5,1.8,1.2),Vector3(x,0.9,0),mats.Stone,true)
	box(hearth,"Hood",Vector3(2.4,0.65,1.3),Vector3(0,2.0,0),mats.Plaster)
	box(hearth,"SootBlackInterior",Vector3(1.3,1.3,0.06),Vector3(0,0.85,-0.34),mats.Dark)
	for i in 4:
		var log := cylinder(hearth,"Firewood",Vector3(-0.45+i*0.3,0.2,0.08),0.12,0.75,mats.WoodShade)
		log.rotation.x = PI/2
		orb(hearth,"CozyFlame",Vector3(-0.4+i*0.27,0.45,0.03),Vector3(0.20,0.5+(i%2)*0.13,0.2),mats.Fire)
	cylinder(hearth,"SoupPot",Vector3(0,1.1,0.05),0.44,0.5,mats.Dark,0.49)
	cylinder(hearth,"SimmeringSoup",Vector3(0,1.357,0.05),0.43,0.012,mats.Soup)
	light(hearth,"FireLight",Vector3(0,1,1),Color("ffb764"),1.2,7)
	light(interior,"RoomGlow",Vector3(0,3.5,0),Color("ffe4bb"),0.8,12)
	for pos in [Vector3(-5.2,0,4),Vector3(5.1,0,-1.9)]:
		cylinder(interior,"FlourBarrel",pos+Vector3(0,0.52,0),0.4,1.0,mats.WoodShade)
		for y in [0.15,0.85]:
			cylinder(interior,"BarrelBand",pos+Vector3(0,y,0),0.415,0.05,mats.Dark)
	var elder_scene := load("res://scenes/npcs/kendeqi.tscn") as PackedScene
	var elder := elder_scene.instantiate() as Node3D
	elder.name = "Kendeqi"
	elder.position = Vector3(0.65,0.02,-3.0)
	scene_root.add_child(elder)
	elder.owner = scene_root
	label(elder,"Nameplate","肯德齐",Vector3(0,2.85,0),0.0048,Color("fff0cf"),true)
	scene_root.set_script(load("res://scripts/snow_dining_house.gd"))
	save_scene("res://scenes/snow_dining_house.tscn")
	scene_root.free()

func light(parent: Node, label_: String, pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var n := OmniLight3D.new()
	n.name = label_
	n.position = pos
	n.light_color = color
	n.light_energy = energy
	n.omni_range = radius
	parent.add_child(n)
	n.owner = scene_root

func label(parent: Node, label_: String, text: String, pos: Vector3, pixel: float, color: Color, billboard := false) -> void:
	var n := Label3D.new()
	n.name = label_
	n.text = text
	n.position = pos
	n.pixel_size = pixel
	n.font_size = 64
	n.modulate = color
	n.outline_size = 8
	if billboard:
		n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(n)
	n.owner = scene_root

func build() -> void:
	mat("Coat","728b8b")
	mat("CoatLight","91a6a0")
	mat("CoatShade","536e70")
	mat("Linen","e8debf")
	mat("LinenShade","c7b99b")
	mat("Mustard","c5a166")
	mat("Skin","d6a17c")
	mat("SkinLight","e3b795")
	mat("SkinShade","ab795d")
	mat("Hair","efead8")
	mat("HairShade","d4d1c0")
	mat("EyeWhite","e4e1cb")
	mat("Leather","6c4d39")
	mat("Trousers","716953")
	mat("Dark","393b39")
	mat("Brass","b69958",0.3)
	mat("Wood","a27b50")
	mat("WoodShade","795937")
	mat("Timber","55432f")
	mat("Plaster","dfd5b9")
	mat("Roof","667e9c")
	mat("RoofLight","8099af")
	mat("Stone","a2a39a")
	mat("Snow","ebf0ec")
	mat("Window","e9bb71",0,0.35)
	mat("Soup","cda156")
	mat("Bread","c19151")
	mat("Rug","63817c")
	mat("Fire","efa354",0,1.4)
	build_cook()
	build_house()
	print("KENDEQI_AND_DINING_HOUSE_BUILT")
	quit()
