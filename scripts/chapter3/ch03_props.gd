class_name Ch03Props
extends RefCounted
## 第三章终局三件装置：献祭装置 / 紧急断开装置 / 分流阀。
##
## 造型口径与 final_banquet_builder.gd 完全一致：
##   · 材质一律 StandardMaterial3D，命名沿用 SlateStone / BlackIron / AgedBrass / GoldenLight ...
##   · 网格一律 BoxMesh / CylinderMesh / TorusMesh / PrismMesh / SphereMesh，不引入外部资源
##   · 文字一律 Label3D + 微软雅黑，pixel_size 0.015，描边 #0b1720
##   · 原点在装置落地中心，+Z 为正对玩家的正面
##
## 三件装置的剧情职责（见《大结局》与总流程第八章）：
##   献祭装置   —— 奶蛙推下它，主核心持续燃烧、异界崩塌（恶线入口）
##   紧急断开   —— 拉下它，主通道收拢、炉罩松开一道缝（归途）
##   分流阀     —— 有序关闭时切开主供给，把食堂与工坊接到备用小灶（白纸公之于世）

var stone: StandardMaterial3D
var marble: StandardMaterial3D
var iron: StandardMaterial3D
var brass: StandardMaterial3D
var gold: StandardMaterial3D
var ember: StandardMaterial3D
var soot: StandardMaterial3D
var teal: StandardMaterial3D
var purple: StandardMaterial3D
var paper: StandardMaterial3D
var font: SystemFont


func _init() -> void:
	stone = mat("SlateStone", Color("26343b"))
	marble = mat("BlueMarble", Color("35434b"))
	iron = mat("BlackIron", Color("151c24"), 0.65)
	brass = mat("AgedBrass", Color("a88345"), 0.65)
	gold = mat("GoldenLight", Color("e5bd6a"), 0.3, 0.8)
	ember = mat("SacrificeEmber", Color("ff8b3d"), 0.0, 1.4)
	soot = mat("BurntSoot", Color("1b1512"), 0.0, 0.0)
	teal = mat("ResidentBranch", Color("49c7bc"), 0.3, 0.7)
	purple = mat("ExtractingMagic", Color("a263df"), 0.2, 1.3)
	paper = mat("LedgerPaper", Color("ccbc98"))
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])


# ---------------------------------------------------------------- 公共工具

func mat(label: String, color: Color, metal := 0.0, emission := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.resource_name = label
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func box(parent: Node3D, label: String, pos: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
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
		body.name = "Body"
		n.add_child(body)
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return n


func cyl(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, material: Material, segments := 12, top_radius := -1.0) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	return n


func rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, material: Material, segments := 10) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(a.distance_to(b), 0.001)
	mesh.radial_segments = segments
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = (a + b) * 0.5
	n.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return n


func ring(parent: Node3D, label: String, pos: Vector3, radius: float, material: Material, thickness := 0.09, segments := 40) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius
	mesh.rings = segments
	mesh.ring_segments = 6
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	return n


func ball(parent: Node3D, label: String, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	return n


func prism(parent: Node3D, label: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = PrismMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	return n


func label(parent: Node3D, name_: String, value: String, pos: Vector3, size := 32, color := Color("e7d29b")) -> Label3D:
	var n = Label3D.new()
	n.name = name_
	n.text = value
	n.font = font
	n.font_size = size
	n.pixel_size = 0.012
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.modulate = color
	n.outline_modulate = Color("0b1720")
	n.outline_size = 7
	n.visibility_range_end = 34
	parent.add_child(n)
	n.position = pos
	return n


func group(parent: Node3D, name_: String) -> Node3D:
	var n = Node3D.new()
	n.name = name_
	parent.add_child(n)
	return n


# ---------------------------------------------------------------- 献祭装置

## 圆形石台 + 铁火盆 + 四爪悬冠。正面一根可推下的闸杆，推到底即点火。
## 台外三重暗红环 = 食堂 / 工坊 / 居民，点火时会一起亮。
func sacrifice(parent: Node3D) -> Node3D:
	var root = group(parent, "Prop_Sacrifice")
	var g = group(root, "Brazier")

	cyl(g, "Dais", Vector3(0, 0.13, 0), 1.72, 0.26, stone, 8, 1.55)
	ring(g, "DaisTrim", Vector3(0, 0.27, 0), 1.52, brass, 0.07)
	for i in 3:
		ring(g, "DoomRing_" + str(i), Vector3(0, 0.045, 0), 2.08 + i * 0.2, soot, 0.035, 48)
	cyl(g, "Plinth", Vector3(0, 0.53, 0), 0.98, 0.46, iron, 12)
	for y in [0.4, 0.53, 0.66]:
		ring(g, "PlinthRune", Vector3(0, y, 0), 1.0, gold, 0.035)
	cyl(g, "Collar", Vector3(0, 0.9, 0), 0.62, 0.3, stone, 12)
	cyl(g, "Bowl", Vector3(0, 1.27, 0), 0.58, 0.44, iron, 16, 0.95)
	ring(g, "BowlRim", Vector3(0, 1.5, 0), 0.98, brass, 0.07)
	cyl(g, "SootBed", Vector3(0, 1.47, 0), 0.86, 0.06, soot, 16)
	var coals = group(g, "Coals")
	cyl(coals, "EmberBed", Vector3(0, 1.51, 0), 0.74, 0.05, ember, 16)
	var coal_mat := mat("CoalEmber", Color("3a1d12"), 0.0, 0.55)
	coal_mat.emission = Color("ff8b3d")
	for i in 6:
		var a = i * TAU / 6.0
		box(coals, "Coal", Vector3(cos(a) * 0.42, 1.55, sin(a) * 0.42), Vector3(0.26, 0.14, 0.26), coal_mat)
	var flame := cyl(coals, "Flame", Vector3(0, 1.72, 0), 0.16, 0.34, ember, 10, 0.03)

	# 四爪把火盆收成一只笼，笼顶挂着一枚待燃的符文。
	var crown = group(g, "Crown")
	for i in 4:
		var a = i * TAU / 4.0 + PI / 4.0
		var foot = Vector3(cos(a) * 0.92, 1.52, sin(a) * 0.92)
		var knee = Vector3(cos(a) * 1.06, 2.02, sin(a) * 1.06)
		var tip = Vector3(cos(a) * 0.5, 2.16, sin(a) * 0.5)
		rod(crown, "ProngLow", foot, knee, 0.06, brass)
		rod(crown, "ProngHigh", knee, tip, 0.05, brass)
		ball(crown, "ProngFoot", foot, 0.09, gold)
	ball(crown, "Sigil", Vector3(0, 1.98, 0), 0.3, purple)
	prism(crown, "SigilShard", Vector3(0, 2.36, 0), Vector3(0.3, 0.56, 0.3), purple)
	ring(crown, "SigilHalo", Vector3(0, 2.16, 0), 0.56, gold, 0.03)

	# 正面闸杆：竖直导轨 + 可推下的横杆。
	var lever = group(root, "Lever")
	box(lever, "Post", Vector3(0, 0.62, -1.16), Vector3(0.36, 1.24, 0.36), iron, true)
	ring(lever, "PostBrace", Vector3(0, 1.2, -1.16), 0.24, brass, 0.05)
	box(lever, "Rail", Vector3(0, 1.62, -1.16), Vector3(0.1, 0.86, 0.1), brass)
	var handle = group(lever, "Handle")
	handle.position = Vector3(0, 1.86, -1.16)
	box(handle, "HandleBar", Vector3(0, 0, 0), Vector3(0.74, 0.11, 0.16), iron)
	for side in [-1, 1]:
		ball(handle, "HandleCap", Vector3(side * 0.36, 0, 0), 0.1, gold)
	label(root, "Plate", "献 祭", Vector3(0, 1.62, -0.96), 34, Color("f0c98a"))

	# 底座碰撞：玩家不能走进火盆里。
	box(root, "Collision", Vector3(0, 0.7, 0), Vector3(1.9, 1.4, 1.9), soot, true).visible = false
	return root


# ---------------------------------------------------------------- 紧急断开装置

## 立式铁壳闸柜：黄铜边框、压力表、下方拉杆、一条会崩断的安全链。
## 拉杆行程 0.55 米，拉到底代表主通道收拢。
func build_disconnect(parent: Node3D) -> Node3D:
	var root = group(parent, "Prop_Disconnect")
	var g = group(root, "Cabinet")

	box(g, "Plinth", Vector3(0, 0.18, 0), Vector3(1.74, 0.36, 1.74), stone, true)
	ring(g, "PlinthInlay", Vector3(0, 0.37, 0), 0.62, brass, 0.05, 32)
	box(g, "Backboard", Vector3(0, 1.24, -0.56), Vector3(1.3, 2.2, 0.12), marble, true)
	box(g, "Housing", Vector3(0, 1.22, -0.24), Vector3(0.92, 2.0, 0.36), iron)
	for side in [-1, 1]:
		box(g, "HousingRib", Vector3(side * 0.46, 1.22, -0.22), Vector3(0.08, 2.06, 0.42), brass)
	box(g, "HousingCap", Vector3(0, 2.24, -0.24), Vector3(1.0, 0.12, 0.44), brass)
	for side in [-1, 1]:
		box(g, "BaseFoot", Vector3(side * 0.66, 0.42, -0.24), Vector3(0.22, 0.18, 0.5), brass)

	# 顶部引出的一段主管：暗示它连着主通道。
	rod(g, "MainPipe", Vector3(0, 2.3, -0.24), Vector3(0, 3.16, -0.24), 0.14, iron)
	for y in [2.52, 2.94]:
		ring(g, "PipeCollar", Vector3(0, y, -0.24), 0.19, brass, 0.05, 24)

	# 压力表：黄铜壳 + 指针 + 刻度。
	var gauge = group(g, "Gauge")
	gauge.position = Vector3(0.62, 1.82, -0.08)
	rod(gauge, "GaugeCase", Vector3(0, 0, 0), Vector3(0, 0, 0.12), 0.27, brass, 20)
	rod(gauge, "GaugeFace", Vector3(0, 0, 0.12), Vector3(0, 0, 0.14), 0.23, paper, 20)
	box(gauge, "Needle", Vector3(0.07, 0.05, 0.15), Vector3(0.22, 0.02, 0.012), ember).rotation.z = -0.7
	for i in 3:
		box(gauge, "Tick", Vector3(cos(-2.2 + i * 0.9) * 0.17, sin(-2.2 + i * 0.9) * 0.17, 0.15), Vector3(0.03, 0.03, 0.01), iron)

	# 警示铭牌：倒三角 + 铭文。
	box(g, "Plaque", Vector3(0, 2.0, -0.03), Vector3(0.66, 0.46, 0.06), soot)
	prism(g, "PlaqueMark", Vector3(0, 2.04, 0.02), Vector3(0.26, 0.24, 0.04), ember).rotation.z = PI
	label(root, "Plate", "紧急断开", Vector3(0, 1.62, -0.02), 34, Color("f4b26a"))

	# 拉杆：轴套 + 斜向上的臂 + 横向握把 + 安全链。
	var lever = group(root, "Lever")
	lever.position = Vector3(0, 1.46, 0.06)
	rod(lever, "Pivot", Vector3(-0.26, 0, 0), Vector3(0.26, 0, 0), 0.15, brass, 16)
	rod(lever, "Arm", Vector3(0, 0, 0), Vector3(0, 0.86, 0.44), 0.07, iron)
	rod(lever, "Grip", Vector3(-0.26, 0.86, 0.44), Vector3(0.26, 0.86, 0.44), 0.1, brass, 14)
	for side in [-1, 1]:
		ball(lever, "GripCap", Vector3(side * 0.28, 0.86, 0.44), 0.11, gold)
	var chain = group(lever, "Chain")
	for i in 7:
		var t = i / 6.0
		var link = ring(chain, "Link", Vector3(0, 0.8 - t * 0.66, 0.44 - t * 0.02), 0.06, brass, 0.018, 12)
		link.rotation.x = PI / 2.0
		link.rotation.z = 0.0 if i % 2 == 0 else PI / 2.0

	box(root, "Collision", Vector3(0, 1.1, -0.2), Vector3(1.5, 2.2, 1.2), soot, true).visible = false
	return root


# ---------------------------------------------------------------- 分流阀

## 立管 + 铸铁阀体 + 大轮。左右两支各自的支管：右侧黄铜亮脉（备用小灶），左侧暗脉（主供给）。
## 轮子转到 90° 即切换供给。
func divider(parent: Node3D) -> Node3D:
	var root = group(parent, "Prop_Divider")
	var g = group(root, "Valve")

	cyl(g, "Plinth", Vector3(0, 0.15, 0), 1.24, 0.3, stone, 24)
	ring(g, "PlinthTrim", Vector3(0, 0.31, 0), 1.26, brass, 0.06, 40)
	for i in 4:
		var a = i * TAU / 4.0 + PI / 4.0
		box(g, "PlinthStud", Vector3(cos(a) * 1.02, 0.33, sin(a) * 1.02), Vector3(0.16, 0.08, 0.16), brass)

	cyl(g, "Riser", Vector3(0, 0.99, 0), 0.3, 1.5, iron, 16)
	for y in [0.4, 0.72, 1.7]:
		ring(g, "RiserFlange", Vector3(0, y, 0), 0.36, brass, 0.055, 24)

	ball(g, "Body", Vector3(0, 1.15, 0), 0.46, iron)
	ring(g, "BodyBand", Vector3(0, 1.15, 0), 0.47, brass, 0.05, 32)
	for i in 3:
		var a = i * TAU / 3.0
		box(g, "BodyRib", Vector3(cos(a) * 0.42, 1.15, sin(a) * 0.42), Vector3(0.09, 0.78, 0.09), brass).rotation.y = -a

	# 手轮：正面 +Z，带四根辐条。
	rod(g, "Stem", Vector3(0, 1.15, 0), Vector3(0, 1.15, 0.56), 0.1, brass)
	var wheel = group(g, "Handwheel")
	wheel.position = Vector3(0, 1.15, 0.62)
	var rim = ring(wheel, "Rim", Vector3.ZERO, 0.66, gold, 0.07, 40)
	rim.rotation.x = PI / 2.0
	cyl(wheel, "Hub", Vector3.ZERO, 0.16, 0.2, brass, 14).rotation.x = PI / 2.0
	for i in 4:
		var a = i * TAU / 4.0 + PI / 4.0
		rod(wheel, "Spoke", Vector3(cos(a) * 0.16, sin(a) * 0.16, 0), Vector3(cos(a) * 0.6, sin(a) * 0.6, 0), 0.045, gold)
		ball(wheel, "SpokeStud", Vector3(cos(a) * 0.68, sin(a) * 0.68, 0), 0.07, brass)

	# 两条支管：右侧接备用小灶，左侧是主供给。管外套一层会发亮的能量套管，
	# 哪条支路在供，一眼就能看出来。
	for data in [[1, "Backup", Color("49c7bc"), 0.9], [-1, "Main", Color("a263df"), 0.18]]:
		var side: int = data[0]
		var branch = group(g, "Branch_" + String(data[1]))
		var near := Vector3(side * 0.42, 1.15, 0)
		var elbow := Vector3(side * 1.05, 1.15, 0)
		var far := Vector3(side * 2.05, 1.15, 0)
		rod(branch, "PipeA", near, elbow, 0.19, iron, 14)
		rod(branch, "PipeB", elbow, far, 0.17, iron, 14)
		ring(branch, "CollarA", Vector3(side * 0.72, 1.15, 0), 0.23, brass, 0.05, 24).rotation.z = PI / 2.0
		ring(branch, "CollarB", Vector3(side * 1.7, 1.15, 0), 0.21, brass, 0.05, 24).rotation.z = PI / 2.0
		ball(branch, "Cap", far, 0.2, brass)
		var glow := mat("BranchGlow", data[2], 0.0, data[3])
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.albedo_color = Color(data[2].r, data[2].g, data[2].b, 0.42)
		rod(branch, "GlowA", near, elbow, 0.205, glow, 12)
		rod(branch, "GlowB", elbow, far, 0.185, glow, 12)

	# 正面的压力表，与紧急断开装置同一制式。
	var gauge = group(g, "Gauge")
	gauge.position = Vector3(0, 1.68, 0.42)
	rod(gauge, "GaugeCase", Vector3(0, 0, 0), Vector3(0, 0, 0.1), 0.24, brass, 20)
	rod(gauge, "GaugeFace", Vector3(0, 0, 0.1), Vector3(0, 0, 0.12), 0.2, paper, 20)
	box(gauge, "Needle", Vector3(0.06, 0.05, 0.13), Vector3(0.19, 0.02, 0.012), ember).rotation.z = -0.6
	for i in 3:
		box(gauge, "Tick", Vector3(cos(-2.2 + i * 0.9) * 0.15, sin(-2.2 + i * 0.9) * 0.15, 0.13), Vector3(0.028, 0.028, 0.01), iron)
	label(root, "Plate", "分流阀", Vector3(0, 2.18, 0.2), 32, Color("8fe3d6"))

	box(root, "Collision", Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 1.1), soot, true).visible = false
	return root


# ---------------------------------------------------------------- 组装入口

## kind: "sacrifice" / "disconnect" / "divider"
func build(kind: String, parent: Node3D) -> Node3D:
	match kind:
		"disconnect":
			return build_disconnect(parent)
		"divider":
			return divider(parent)
		_:
			return sacrifice(parent)
