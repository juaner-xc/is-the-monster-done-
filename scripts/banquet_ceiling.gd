extends Node3D
## Editable, baked ceiling geometry. L switches emissive flames and real lights together.
@export var lights_on := true
var _lit_materials: Array[StandardMaterial3D] = []
var _lamps: Array[Light3D] = []
var _cache := {}

func material(label: String, color: String, metallic := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = label
	m.albedo_color = Color(color)
	m.metallic = metallic
	m.roughness = 0.32 if metallic > 0.0 else 0.82
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = glow
	return m

func mesh_at(parent: Node3D, label: String, mesh: Mesh, p: Vector3, m: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	n.material_override = m
	parent.add_child(n, true)
	n.position = p
	return n

func box(parent: Node3D, label: String, p: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var key := str(size)
	if not _cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_cache[key] = mesh
	return mesh_at(parent, label, _cache[key], p, m)

func rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, m: Material):
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var n := mesh_at(parent, label, mesh, (a+b)*0.5, m)
	n.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return n

func ring(parent: Node3D, label: String, p: Vector3, radius: float, thickness: float, m: Material):
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-thickness
	mesh.outer_radius = radius+thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	return mesh_at(parent, label, mesh, p, m)

func jewel(parent: Node3D, label: String, p: Vector3, radius: float, height: float, m: Material):
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh_at(parent, label, mesh, p, m)

func build():
	name = "OrnateCeiling"
	var charcoal := material("Ceiling_WarmCharcoal", "272225")
	var inset := material("Ceiling_OxbloodCoffers", "48252a")
	var gold := material("Ceiling_AntiqueGold", "bd8d42", 0.78)
	var bright := material("Ceiling_PolishedEdges", "e6c17c", 0.65)
	var bronze := material("Ceiling_DarkBronze", "4e3522", 0.72)
	var wax := material("Ceiling_IvoryWax", "f5d5a2")
	var flame := material("Ceiling_CandleEmission", "ffb34f", 0.0, 3.0)
	var cove := material("Ceiling_CoveEmission", "ffd591", 0.0, 1.7)
	# Barrel shell follows the existing ribs: x=16.6*cos(a), y=11+6*sin(a).
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in 48:
		var a := float(i)*PI/48.0
		var b := float(i+1)*PI/48.0
		var v0 := Vector3(cos(a)*16.85, 11.15+sin(a)*6.1, -29.8)
		var v1 := Vector3(cos(b)*16.85, 11.15+sin(b)*6.1, -29.8)
		var v2 := Vector3(v1.x,v1.y,29.8)
		var v3 := Vector3(v0.x,v0.y,29.8)
		for v in [v0,v1,v2,v0,v2,v3]:
			vertices.append(v)
			normals.append(Vector3(-v.x/16.85,-(v.y-11.15)/6.1,0).normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var shell := ArrayMesh.new()
	shell.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	charcoal.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_at(self,"BarrelVaultShell",shell,Vector3.ZERO,charcoal)
	# Molded wall cornices with recessed warm strips, kept above player clearance.
	for side in [-1,1]:
		for tier in 3:
			box(self,"SteppedCornice",Vector3(side*(16.45-tier*0.18),10.35+tier*0.25,0),Vector3(0.65,0.20,59.6),gold if tier==1 else bronze)
		box(self,"RecessedCoveStrip",Vector3(side*15.99,10.99,0),Vector3(0.12,0.06,59.2),cove)
		for z in [-25.0,-13.0,0.0,13.0,25.0]:
			box(self,"CapitalGoldAbacus",Vector3(side*16.6,11.1,z),Vector3(1.9,0.22,1.9),gold)
	# Long gilded ribs and inset burgundy coffers in five bays.
	for x in [-12.0,-7.0,0.0,7.0,12.0]:
		var y := 11.0+sqrt(1.0-pow(x/16.6,2))*6.0
		box(self,"LongitudinalGiltRib",Vector3(x,y-0.10,0),Vector3(0.13,0.12,59.5),gold)
	for z in [-25.0,-13.0,0.0,13.0,25.0]:
		for i in 32:
			var a := float(i)*PI/32.0
			var b := float(i+1)*PI/32.0
			for offset in [-0.24,0.24]:
				rod(self,"DoubleGiltArch",Vector3(cos(a)*16.5,10.98+sin(a)*5.98,z+offset),Vector3(cos(b)*16.5,10.98+sin(b)*5.98,z+offset),0.055,bright)
	for z in [-19.0,-6.5,6.5,19.0]:
		for x in [-9.5,-3.5,3.5,9.5]:
			var y := 11.0+sqrt(1.0-pow(x/16.6,2))*6.0
			var panel := Node3D.new()
			panel.name = "GildedCoffer"
			add_child(panel, true)
			panel.position = Vector3(x,y-0.11,z)
			panel.rotation.z = atan(-6.0*x/(16.6*16.6*sqrt(1.0-pow(x/16.6,2))))
			box(panel,"BurgundyInset",Vector3.ZERO,Vector3(4.4,0.09,8.5),inset)
			for side in [-1,1]:
				box(panel,"FrameLong",Vector3(side*2.15,-0.09,0),Vector3(0.09,0.12,8.5),gold)
				box(panel,"FrameShort",Vector3(0,-0.09,side*4.2),Vector3(4.3,0.12,0.09),gold)
			ring(panel,"CeilingRosette",Vector3(0,-0.19,0),0.60,0.035,bright)
			for petal in 8:
				var a := petal*TAU/8.0
				var ornament = jewel(panel,"GiltPetal",Vector3(cos(a)*0.39,-0.19,sin(a)*0.39),0.11,0.06,gold)
				ornament.scale.z = 2.5
				ornament.rotation.y = -a+PI/2
	for z in [-17.0,3.0,22.0]:
		_chandelier(z, gold, bright, bronze, wax, flame)
	_cache.clear()

func _chandelier(z: float, gold: Material, bright: Material, bronze: Material, wax: Material, flame: Material):
	var g := Node3D.new()
	g.name = "GrandChandelier"
	add_child(g, true)
	g.position = Vector3(0,0,z)
	ring(g,"CeilingRose",Vector3(0,16.79,0),1.2,0.08,gold)
	rod(g,"SuspensionStem",Vector3(0,12.1,0),Vector3(0,16.85,0),0.075,bronze)
	for y in [12.0,12.28,13.45,14.0]:
		jewel(g,"TurnedStemKnop",Vector3(0,y,0),0.24,0.34,gold)
	for tier in 2:
		var y := 11.65+tier*1.5
		var radius := 2.7-tier*0.95
		var count := 12-tier*4
		ring(g,"CrownBand",Vector3(0,y,0),radius,0.10,gold)
		ring(g,"CrownBeadedRim",Vector3(0,y+0.18,0),radius,0.045,bright)
		for i in count:
			var a := i*TAU/count
			var dir := Vector3(cos(a),0,sin(a))
			var end := dir*(radius+0.42)+Vector3.UP*(y+0.25)
			rod(g,"RadialSpoke",Vector3(0,y+0.3,0),dir*radius+Vector3.UP*y,0.045,bronze)
			# Swept curved candle arm, sampled as a continuous raised scroll.
			var last := dir*(radius-0.15)+Vector3.UP*(y-0.10)
			for step in 6:
				var t := float(step+1)/6.0
				var next := dir*(radius-0.15+0.57*t)+Vector3.UP*(y-0.1-0.35*sin(t*PI)+0.35*t)
				rod(g,"ScrollCandleArm",last,next,0.047,gold)
				last = next
			ring(g,"WaxDripSaucer",end,0.20,0.045,bright)
			rod(g,"IvoryCandle",end+Vector3.UP*0.04,end+Vector3.UP*0.52,0.075,wax)
			jewel(g,"LuminousFlame",end+Vector3.UP*0.64,0.075,0.25,flame)
			rod(g,"PendantLink",dir*radius+Vector3.UP*(y-0.1),dir*radius+Vector3.UP*(y-0.48),0.018,bright)
			jewel(g,"AmberPendant",dir*radius+Vector3.UP*(y-0.63),0.10,0.32,bright)
	for i in 6:
		var dir := Vector3(cos(i*TAU/6),0,sin(i*TAU/6))
		rod(g,"CrownSuspension",dir*2.7+Vector3.UP*11.75,Vector3(0,14.3,0),0.035,gold)
	jewel(g,"LowerFinial",Vector3(0,10.9,0),0.28,0.75,bright)
	var lamp := OmniLight3D.new()
	lamp.name = "WarmChandelierLight"
	lamp.position = Vector3(0,10.9,0)
	lamp.light_color = Color("ffc17b")
	lamp.light_energy = 2.2
	lamp.omni_range = 18.0
	lamp.omni_attenuation = 1.35
	lamp.shadow_enabled = false
	g.add_child(lamp)
	# Uplight makes coffer modeling legible with the project's Compatibility renderer.
	var up := SpotLight3D.new()
	up.name = "VaultUplight"
	up.position = Vector3(0,13.5,0)
	up.rotation.x = PI/2
	up.light_color = Color("ffd49a")
	up.light_energy = 2.0
	up.spot_range = 12.0
	up.spot_angle = 70.0
	g.add_child(up)

func _ready():
	for n in find_children("*", "MeshInstance3D", true, false):
		var m = n.material_override
		if m is StandardMaterial3D and m.emission_enabled and not _lit_materials.has(m):
			_lit_materials.append(m)
	for n in find_children("*", "Light3D", true, false):
		_lamps.append(n)
	set_lights(lights_on)

func set_lights(enabled: bool):
	lights_on = enabled
	for m in _lit_materials:
		m.emission_enabled = enabled
	for lamp in _lamps:
		lamp.visible = enabled

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
		set_lights(not lights_on)
		var hall := get_parent().get_parent()
		if hall.has_method("show_notice"):
			hall.show_notice("宴厅吊灯 · 已点亮" if lights_on else "宴厅吊灯 · 已熄灭")
		get_viewport().set_input_as_handled()

func _process(_delta: float):
	var camera := get_viewport().get_camera_3d()
	if camera:
		visible = camera.global_position.y < 24.0


