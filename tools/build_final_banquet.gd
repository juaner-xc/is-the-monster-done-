extends SceneTree
const ROOT_PATH := "res://assets/chapter3/"
var scene: Node3D
var architecture: Node3D
func _initialize(): call_deferred("build")
func material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.55
	m.roughness = 0.4
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m
func box(parent: Node, name_: String, p: Vector3, size_: Vector3, mat_: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name_
	n.position = p
	var mesh := BoxMesh.new()
	mesh.size = size_
	n.mesh = mesh
	n.material_override = mat_
	parent.add_child(n)
	return n
func ring(parent: Node, name_: String, p: Vector3, r: float, mat_: Material):
	var n := MeshInstance3D.new()
	n.name = name_
	var mesh := TorusMesh.new()
	mesh.inner_radius = r - 0.035
	mesh.outer_radius = r + 0.035
	mesh.rings = 48
	mesh.ring_segments = 6
	n.mesh = mesh
	n.material_override = mat_
	parent.add_child(n)
	n.position = p
	return n
func own_all(n: Node):
	for c in n.get_children():
		c.owner = scene
		# Keep imported GLB and existing boss scenes as external instances.
		# Taking ownership of their internal nodes duplicates imported children.
		if c.scene_file_path.is_empty(): own_all(c)
func point(id: String, title: String, p: Vector3):
	var n := Node3D.new()
	n.name = "Point_" + id
	n.position = p
	n.set_meta("interaction_id", id)
	n.set_meta("title", title)
	n.add_to_group("final_hall_points", true)
	architecture.add_child(n)
	ring(n, "InteractionRing", Vector3(0, 0.07, 0), 0.48, material(Color("cfa456"), 0.45))
func build():
	scene = Node3D.new()
	scene.name = "FinalBanquetHall"
	root.add_child(scene)
	architecture = Node3D.new()
	architecture.name = "Architecture"
	scene.add_child(architecture)
	var model = load(ROOT_PATH + "chapter3_final_banquet.glb").instantiate()
	model.name = "BlenderArchitecture"
	architecture.add_child(model)
	var collision_body := StaticBody3D.new()
	collision_body.name = "MapCollision"
	architecture.add_child(collision_body)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT_PATH + "collision_manifest.json"))
	for item in manifest:
		var n := CollisionShape3D.new()
		n.name = item.name.validate_node_name()
		var shape := BoxShape3D.new()
		shape.size = Vector3(item.size[0], item.size[1], item.size[2])
		n.shape = shape
		n.position = Vector3(item.position[0], item.position[1], item.position[2])
		n.rotation.y = item.rotation_y
		collision_body.add_child(n)
	# Required nodes preserve the existing book, facility and ending interfaces.
	var core := Node3D.new()
	core.name = "MainCore"
	core.position = Vector3(0, 0, -36)
	architecture.add_child(core)
	var crystal := MeshInstance3D.new()
	crystal.name = "Crystal"
	var cm := PrismMesh.new()
	cm.size = Vector3(1.5, 3.0, 1.5)
	crystal.mesh = cm
	crystal.material_override = material(Color("f1ac3b"), 1.3)
	crystal.position.y = 5.5
	core.add_child(crystal)
	for y in [2.3, 4.0, 6.4]: ring(core, "CoreOrbit", Vector3(0, y, 0), 1.8, material(Color("c48a35"), 0.3))
	var rift := Node3D.new()
	rift.name = "MainRift"
	rift.position = Vector3(0, 5.0, -41)
	architecture.add_child(rift)
	var rr = ring(rift, "RiftRim", Vector3.ZERO, 2.1, material(Color("e0a644"), 0.6))
	rr.rotation.x = PI / 2
	var book := Node3D.new()
	book.name = "GoldenBook"
	book.position = Vector3(7, 1.66, -24)
	architecture.add_child(book)
	box(book, "BlankPages", Vector3(0, 0.08, 0), Vector3(1.10, 0.14, 0.83), material(Color("efe0b7")))
	var hinge := Node3D.new()
	hinge.name = "CoverHinge"
	hinge.position.x = -0.59
	book.add_child(hinge)
	box(hinge, "GoldenCover", Vector3(0.59, 0.19, 0), Vector3(1.25, 0.08, 0.93), material(Color("d4a445")))
	for pair in [["SnowBranch", -5.1], ["VolcanoBranch", 5.1]]:
		var branch := Node3D.new()
		branch.name = pair[0]
		architecture.add_child(branch)
		box(branch, "StatusLamp", Vector3(pair[1], 1.58, 18.3), Vector3(0.25, 0.25, 0.25), material(Color("985b42"), 0.3))
		box(branch, "StatusVein", Vector3(pair[1], 1.43, 18.3), Vector3(1.1, 0.025, 0.08), material(Color("985b42"), 0.3))
	point("prepare", "接应检查 / 补救", Vector3(0, 0, 20.5))
	point("upgrade", "料理加工", Vector3(5.1, 0, 20.3))
	point("contact", "备用联络与工具", Vector3(-5.1, 0, 20.3))
	point("pages", "残页分发账册", Vector3(-21.8, 0, 22))
	point("feed", "愿望计量装置", Vector3(23.4, 0, 20))
	point("records", "运输记录副本", Vector3(-22, 0, 25))
	point("book", "翻开黄金食谱", Vector3(7, 0, -21.8))
	for i in 3:
		point("snow_valve_" + str(i), "供给稳压阀 " + str(i + 1), Vector3(25, 0, 25 - i * 5))
		point("volcano_valve_" + str(i), "厨房分流阀 " + str(i + 1), Vector3(-18.5, 0, 25 - i * 5))
		box(architecture, "KitchenManualValvePedestal", Vector3(-18.5, 0.7, 25 - i * 5), Vector3(0.6, 1.4, 0.6), material(Color("6c5437")))
		var wheel = ring(architecture, "KitchenValve", Vector3(-18.5, 1.4, 25 - i * 5 + 0.34), 0.27, material(Color("986237")))
		wheel.rotation.x = PI / 2
	for pair in [["west", Vector3(-10, 0, -20)], ["north", Vector3(0, 0, -26)], ["east", Vector3(10, 0, -20)]]:
		point("anchor_" + pair[0], "抽取控制装置", pair[1])
	point("core", "主核心 · 最终处理", Vector3(0, 0, -32))
	var boss = load("res://scenes/final_boss.tscn").instantiate()
	boss.name = "FinalBoss"
	boss.position = Vector3(0, 0.1, -20)
	scene.add_child(boss)
	var ceiling=load("res://assets/chapter3/ornate_ceiling.tscn").instantiate()
	architecture.add_child(ceiling)
	scene.set_script(load("res://scripts/final_banquet_hall.gd"))
	own_all(scene)
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK: error = ResourceSaver.save(packed, "res://scenes/final_banquet_hall.tscn")
	print("CHAPTER3_SCENE_BUILT error=", error, " colliders=", manifest.size())
	quit(error)
