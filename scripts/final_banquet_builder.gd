extends RefCounted
## Bakes editable native geometry. No plugin or external asset is required.
var root: Node3D
var stone: StandardMaterial3D
var floor_mat: StandardMaterial3D
var dark: StandardMaterial3D
var brass: StandardMaterial3D
var wood: StandardMaterial3D
var gold: StandardMaterial3D
var teal: StandardMaterial3D
var purple: StandardMaterial3D
var font: SystemFont

func build(target: Node3D):
	root = target
	stone = mat("SlateStone", Color("26343b"))
	floor_mat = mat("BlueMarble", Color("35434b"))
	dark = mat("BlackIron", Color("151c24"), 0.65)
	brass = mat("AgedBrass", Color("a88345"), 0.65)
	wood = mat("BanquetWood", Color("604b3c"))
	gold = mat("GoldenLight", Color("e5bd6a"), 0.3, 0.8)
	teal = mat("ResidentBranch", Color("49c7bc"), 0.3, 0.7)
	purple = mat("ExtractingMagic", Color("a263df"), 0.2, 1.3)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_build_shell()
	var ceiling = preload("res://scripts/banquet_ceiling.gd").new()
	ceiling.build()
	root.add_child(ceiling)
	_build_banquet()
	_build_core()
	_build_rooms()
	_build_points()

func mat(label: String, color: Color, metal := 0.0, emission := 0.0):
	var m = StandardMaterial3D.new()
	m.resource_name = label
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.8
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func box(parent, label, pos: Vector3, size: Vector3, material: Material, solid := false):
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	if solid:
		var body = StaticBody3D.new()
		n.add_child(body)
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return n

func rod(parent, label, a: Vector3, b: Vector3, radius: float, material):
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = (a+b)*0.5
	n.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return n

func ring(parent, label, pos: Vector3, radius: float, material):
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius-0.09
	mesh.outer_radius = radius
	mesh.rings = 48
	mesh.ring_segments = 6
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	return n

func text(parent, label, value: String, pos: Vector3, size := 38):
	var n = Label3D.new()
	n.name = label
	n.text = value
	n.font = font
	n.font_size = size
	n.pixel_size = 0.015
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.modulate = Color("e7d29b")
	n.outline_modulate = Color("0b1720")
	n.outline_size = 7
	n.visibility_range_end = 50
	parent.add_child(n)
	n.position = pos
	return n

func room_floor(label, center: Vector2, dimensions: Vector2):
	box(root,label,Vector3(center.x,-0.18,center.y),Vector3(dimensions.x,0.36,dimensions.y),floor_mat,true)
	# Inlaid tile lines and a perimeter brass border.
	for x in range(int(center.x-dimensions.x/2)+1,int(center.x+dimensions.x/2),4):
		box(root,"FloorJoint",Vector3(x,0.008,center.y),Vector3(0.035,0.012,dimensions.y),stone)
	for z in range(int(center.y-dimensions.y/2)+1,int(center.y+dimensions.y/2),4):
		box(root,"FloorJoint",Vector3(center.x,0.009,z),Vector3(dimensions.x,0.012,0.035),stone)
	for side in [-1,1]:
		box(root,"BrassInlay",Vector3(center.x+side*(dimensions.x/2-0.7),0.017,center.y),Vector3(0.08,0.018,dimensions.y-1.4),brass)
		box(root,"BrassInlay",Vector3(center.x,0.017,center.y+side*(dimensions.y/2-0.7)),Vector3(dimensions.x-1.4,0.018,0.08),brass)

func wall_x(x, za, zb):
	box(root,"StoneWall",Vector3(x,4,(za+zb)/2),Vector3(0.65,8,zb-za),stone,true)
	box(root,"WallCornice",Vector3(x,8,(za+zb)/2),Vector3(0.9,0.25,zb-za),brass)

func wall_z(z, xa, xb):
	box(root,"StoneWall",Vector3((xa+xb)/2,4,z),Vector3(xb-xa,8,0.65),stone,true)
	box(root,"WallCornice",Vector3((xa+xb)/2,8,z),Vector3(xb-xa,0.25,0.9),brass)

func _build_shell():
	room_floor("MainHallFloor",Vector2(0,0),Vector2(36,60))
	room_floor("EntranceFloor",Vector2(0,37),Vector2(12,14))
	room_floor("ArchiveFloor",Vector2(-28,9),Vector2(20,22))
	room_floor("ReserveFloor",Vector2(28,9),Vector2(20,22))
	room_floor("DiversionFloor",Vector2(-28,-16),Vector2(20,20))
	room_floor("RecipeApseFloor",Vector2(0,-38),Vector2(18,16))
	for segment in [[-30.0,-19.0],[-13.0,6.0],[12.0,30.0]]: wall_x(-18,segment[0],segment[1])
	for segment in [[-30.0,6.0],[12.0,30.0]]: wall_x(18,segment[0],segment[1])
	for z in [-30,30]:
		wall_z(z,-18,-6)
		wall_z(z,6,18)
	for side in [-1,1]:
		wall_x(side*6,30,44)
		wall_x(side*9,-46,-30)
	wall_z(-46,-9,9)
	wall_z(44,-6,6)
	for x in [-38,38]: wall_x(x,-2,20)
	for z in [-2,20]:
		wall_z(z,-38,-18)
		wall_z(z,18,38)
	wall_x(-38,-26,-6)
	wall_z(-26,-38,-18)
	wall_z(-6,-38,-18)
	# Tall ribs, readable in the cutaway and from the player's viewpoint.
	for z in [-25,-13,0,13,25]:
		for side in [-1,1]:
			box(root,"RibColumn",Vector3(side*16.6,5.5,z),Vector3(1.0,11,1.1),stone,true)
			box(root,"ColumnCapital",Vector3(side*16.6,10.7,z),Vector3(1.6,0.5,1.7),brass)
			box(root,"ColumnFiligree",Vector3(side*16.6,5.6,z+0.57),Vector3(0.10,8.7,0.035),gold)
		for i in 18:
			var a = i*PI/18
			var b = (i+1)*PI/18
			rod(root,"VaultRib",Vector3(cos(a)*16.6,11+sin(a)*6,z),Vector3(cos(b)*16.6,11+sin(b)*6,z),0.17,brass)
	for x in [-15,15]:
		rod(root,"OverheadMainPipe",Vector3(x,5.4,27),Vector3(x,5.4,-25),0.33,dark)
		for z in range(-24,28,6): ring(root,"PipeCollar",Vector3(x,5.4,z),0.44,brass).rotation.x=PI/2
	text(root,"EntranceTitle","终 宴 大 厅",Vector3(0,4.8,31),44)
	text(root,"ArchiveSign","档案回廊",Vector3(-20,4.3,9))
	text(root,"ReserveSign","备用储能库",Vector3(20,4.3,9))
	text(root,"PumpSign","分流泵房",Vector3(-20,4.3,-16))
	text(root,"ApseSign","黄金食谱祭台",Vector3(0,5,-31))

func _build_banquet():
	for side in [-1,1]:
		for z in [5,14]:
			var x = side*10.0
			box(root,"LongBanquetTable",Vector3(x,1.1,z),Vector3(4.2,0.22,6.6),wood,true)
			for dx in [-1.65,1.65]:
				for dz in [-2.7,2.7]: box(root,"TableLeg",Vector3(x+dx,0.5,z+dz),Vector3(0.22,1,0.22),brass)
			for dz in [-2,0,2]:
				ring(root,"EmptyPlate",Vector3(x,1.26,z+dz),0.40,gold)
				for edge in [-1,1]: box(root,"Bench",Vector3(x+edge*2.7,0.47,z+dz),Vector3(0.6,0.9,1.4),wood,true)
	for z in range(-27,29,4):
		box(root,"ProcessionalCarpet",Vector3(0,0.022,z),Vector3(5,0.015,3.9),mat("WornVelvet",Color("43334e")))
	for side in [-1,1]:
		for z in [-22,-1,21]:
			box(root,"HangingBanner",Vector3(side*17.5,6.0,z),Vector3(0.08,3.8,2.3),mat("WineBanner",Color("60324b")))

func _build_core():
	var group = Node3D.new()
	group.name = "MainCore"
	root.add_child(group)
	group.position = Vector3(0,0,-8)
	box(group,"CorePlinth",Vector3(0,0.4,0),Vector3(5.2,0.8,5.2),dark,true)
	for r in [3.4,4.0,7.0]: ring(group,"CoreFloorRune",Vector3(0,0.04,0),r,purple)
	var crystal = MeshInstance3D.new()
	crystal.name = "Crystal"
	var mesh = PrismMesh.new()
	mesh.size = Vector3(3.4,5.6,3.4)
	crystal.mesh = mesh
	crystal.material_override = purple
	group.add_child(crystal)
	crystal.position.y = 5.5
	for y in [2.5,5.5,8.6]:
		var orbit = ring(group,"Orbit",Vector3(0,y,0),3.1,gold)
		orbit.rotation.z = 0.18 if y==5.5 else -0.13
	for side in [-1,1]:
		rod(root,"CoreExtractionPipe",Vector3(side*15,5.4,-8),Vector3(side*4,5.4,-8),0.32,dark)
		rod(root,"CoreEnergyVein",Vector3(side*14,5.75,-8),Vector3(side*4,5.75,-8),0.055,purple)
	var rift = Node3D.new()
	rift.name = "MainRift"
	root.add_child(rift)
	rift.position = Vector3(0,9,-21)
	var halo = ring(rift,"RiftRim",Vector3.ZERO,4.0,purple)
	halo.rotation.x = PI/2
	halo.scale.z = 1.55
	var veil = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(7.5,11.8)
	veil.mesh = quad
	var shader = Shader.new()
	shader.code = """shader_type spatial; render_mode unshaded,cull_disabled;
void fragment(){vec2 p=(UV-0.5)*2.0;float r=length(p);float wave=sin(atan(p.y,p.x)*6.0+r*17.0-TIME*1.2)*0.5+0.5; ALBEDO=mix(vec3(0.018,0.008,0.045),vec3(0.32,0.04,0.48),pow(wave,4.0)*r); ALPHA=1.0-smoothstep(0.80,1.0,r);}
"""
	var sm = ShaderMaterial.new()
	sm.shader = shader
	veil.material_override = sm
	rift.add_child(veil)
	text(root,"CoreCaption","主裂隙  /  供给与抽取共用的核心",Vector3(0,11.7,-8),32)
	# Two resident branches end at visible signal lamps in the preparation area.
	for data in [[-1,"SnowBranch"],[1,"VolcanoBranch"]]:
		var branch = Node3D.new()
		branch.name = data[1]
		root.add_child(branch)
		var x = data[0]*14
		rod(branch,"BranchPipe",Vector3(x,0.22,-3),Vector3(x,0.22,25),0.13,dark)
		rod(branch,"StatusVein",Vector3(x,0.4,-3),Vector3(x,0.4,25),0.045,teal)
		var lamp = box(branch,"StatusLamp",Vector3(x,1.8,25),Vector3(0.5,0.6,0.4),teal)
		lamp.set_meta("resident_branch",data[1])

func _build_rooms():
	for x in [-36,-20]:
		for z in [2,16]:
			box(root,"ArchiveShelf",Vector3(x,1.7,z),Vector3(1.0,3.4,5),wood,true)
			for y in [0.7,1.7,2.7]:
				for i in 6: box(root,"StoredLedger",Vector3(x-0.02,y,z-2+i*0.7),Vector3(0.55,0.45,0.42),brass if i%3==0 else stone)
	for p in [Vector3(24,1,4),Vector3(32,1,15),Vector3(-33,1,-22)]:
		box(root,"EnergyCrate",p,Vector3(2,2,2),dark,true)
		for side in [-1,1]: box(root,"CrateBand",p+Vector3(side*0.7,0,0),Vector3(0.1,2.1,2.1),brass)
	for pos in [Vector3(28,0,9),Vector3(-28,0,-16)]:
		ring(root,"TrialCircle",pos+Vector3.UP*0.035,5.1,gold)
		for i in 3:
			var a = i*TAU/3
			rod(root,"PressureLine",pos+Vector3.UP*2.8, pos+Vector3(cos(a)*5,2.8,sin(a)*5),0.13,dark)
	box(root,"RecipeStand",Vector3(0,0.8,-38),Vector3(5.8,1.6,1.7),stone,true)
	var book = Node3D.new()
	book.name = "GoldenBook"
	root.add_child(book)
	book.position = Vector3(0,1.7,-38)
	box(book,"BlankPages",Vector3(0,0.08,0),Vector3(1.9,0.10,1.2),mat("BlankPaper",Color("f4ecd5")))
	var cover = Node3D.new()
	cover.name = "CoverHinge"
	book.add_child(cover)
	cover.position.x = -0.98
	box(cover,"GoldenCover",Vector3(0.98,0.15,0),Vector3(2.1,0.10,1.35),gold)
	text(root,"BookTitle","传说中的黄金食谱",Vector3(0,3.6,-39),32)
	# A smaller, visibly written notebook contrasts with the blank golden volume.
	box(root,"UsedNotebook",Vector3(2.1,1.7,-38),Vector3(0.9,0.10,0.8),mat("NotebookPaper",Color("ccbc98")))
	for i in 6: box(root,"HandwrittenLine",Vector3(2.1,1.76,-38.3+i*0.1),Vector3(0.58-(i%2)*0.11,0.01,0.016),dark)

func point(id: String, title: String, pos: Vector3, material = null):
	var n = Node3D.new()
	n.name = "Point_"+id
	n.set_meta("interaction_id",id)
	n.set_meta("title",title)
	n.add_to_group("final_hall_points",true)
	root.add_child(n)
	n.position = pos
	ring(n,"InteractionRing",Vector3(0,0.035,0),1.0,gold if material==null else material)
	if id != "book": box(n,"Console",Vector3(0,0.65,0),Vector3(0.9,1.3,0.7),dark,true)
	text(n,"PointLabel",title,Vector3(0,2.25,0),27).visibility_range_end = 20
	return n

func _build_points():
	point("prepare","接应检查 / 补救",Vector3(0,0,25),teal)
	point("upgrade","料理加工 · 消耗核心",Vector3(9,0,26))
	point("contact","备用联络与工具",Vector3(-9,0,26))
	point("pages","残页分发账册",Vector3(-28,0,11))
	point("feed","愿望计量装置",Vector3(12,0,19),purple)
	point("records","运输记录副本",Vector3(-22,0,-17))
	point("book","翻开黄金食谱",Vector3(0,0,-35))
	for i in 3:
		var a = i*TAU/3
		point("snow_valve_"+str(i),"稳压阀 "+str(i+1),Vector3(28+cos(a)*5,0,9+sin(a)*5),teal)
		point("volcano_valve_"+str(i),"分流阀 "+str(i+1),Vector3(-28+cos(a)*5,0,-16+sin(a)*5),teal)
	for data in [["west",Vector3(-10,0,-10)],["north",Vector3(0,0,-19)],["east",Vector3(10,0,-10)]]:
		point("anchor_"+data[0],"抽取控制装置",data[1],purple)
	point("core","主核心 · 最终处理",Vector3(0,0,-2),purple)


