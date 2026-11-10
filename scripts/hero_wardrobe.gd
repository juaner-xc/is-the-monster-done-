extends RefCounted
## Meshes are authored in the imported rig's coordinates (+Z is the face).
const LEAF := "snowleaf"
const LANTERN := "ember_lantern"
const MEDAL := "banquet_medal"

var skeleton: Skeleton3D
var collar: Node3D
var sprout: Node3D
var helmet: Node3D
var hide_adventure_gear := false
var combat_mode := ""
var pan_received := not RunState.chapter_mode or RunState.snow_opening_seen
var staff_hand: Node3D
var staff_back: Node3D
var lantern: Node3D
var medal: Node3D
var pan: Node3D
var materials: Dictionary = {}

func build(rig: Skeleton3D) -> void:
	skeleton = rig
	collar = _socket("Spine", "SnowleafCollar", Vector3.ZERO)
	_build_collar()
	sprout = _socket("Head", "SnowleafSprig", Vector3(-0.018,0.608,-0.017))
	_build_sprout(sprout)
	helmet = _socket("Head", "SnowleafHelmet", Vector3(-0.018, 0.55, -0.038))
	_oval(helmet, Vector3.ZERO, Vector3(0.24, 0.12, 0.21), _mat(Color("4a6040"), 0.32))
	_oval(helmet, Vector3(0, -0.043, 0.027), Vector3(0.25, 0.026, 0.24), _mat(Color("a59059"), 0.44))
	staff_hand = _socket("Hand.L", "StaffGrip", Vector3(-0.164, 0.227, 0.057))
	_build_staff(staff_hand)
	staff_back = _socket("Spine", "StaffSling", Vector3(0.025, 0.325, -0.146))
	staff_back.rotation.z = -0.31
	_build_staff(staff_back)
	lantern = _socket("Hips", "EmberLantern", Vector3(-0.120, 0.246, -0.121))
	_build_lantern()
	medal = _socket("Spine", "BanquetMedal", Vector3(0.064, 0.347, 0.121))
	_build_medal()
	pan = _socket("Hand.R", "PanGrip", Vector3(0.138, 0.224, 0.049))
	_build_pan()
	update(&"Idle", false)

static func display_piece(parent: Node3D, id: String) -> Node3D:
	var workshop := new()
	var model := Node3D.new()
	parent.add_child(model)
	if id == LANTERN:
		workshop.lantern = model
		workshop._build_lantern()
	elif id == MEDAL:
		workshop.medal = model
		workshop._build_medal()
	return model

static func build_gift_display(parent: Node3D) -> void:
	var workshop := new()
	workshop.collar = Node3D.new()
	workshop.collar.name = "SnowleafCollar"
	parent.add_child(workshop.collar)
	workshop._build_collar()
	var crown := Node3D.new()
	crown.name = "SnowleafSprig"
	parent.add_child(crown)
	crown.position = Vector3(-0.018,0.608,-0.017)
	workshop._build_sprout(crown)
	var staff := Node3D.new()
	staff.name = "BerryStaff"
	parent.add_child(staff)
	staff.position = Vector3(0.227,0.235,0.055)
	staff.rotation.z = -0.10
	workshop._build_staff(staff)

func _build_sprout(parent: Node3D) -> void:
	for i in 3:
		var spread := float(i - 1)
		_leaf(parent, Vector3.ZERO, Vector3(spread * 0.062, 0.092 - absf(spread) * 0.022, -0.022 + spread * 0.013),
			0.026 - absf(spread) * 0.005, Vector3(0, 0.3, 1).normalized(), Color(["608b29", "7ba533", "456d22"][i]))

func update(clip: StringName, moving: bool) -> void:
	var has_leaf: bool = not hide_adventure_gear and RunState.has_gear(LEAF)
	var in_hand := clip in [&"Idle", &"ReceiveGift", &"Wave"] and not moving
	if combat_mode != "":
		in_hand = combat_mode == "staff"
	collar.visible = has_leaf
	sprout.visible = has_leaf
	helmet.visible = has_leaf
	staff_hand.visible = has_leaf and in_hand
	staff_back.visible = has_leaf and not in_hand
	lantern.visible = not hide_adventure_gear and RunState.has_gear(LANTERN)
	medal.visible = not hide_adventure_gear and RunState.has_gear(MEDAL)
	pan.visible = pan_received and (combat_mode == "pan" or clip in [&"PanSwing", &"PanReturn"] or bool(pan.get_meta("overheated", false)))

func _socket(bone_name: String, socket_name: String, origin: Vector3) -> Node3D:
	var index := skeleton.find_bone(bone_name)
	var socket := BoneAttachment3D.new()
	socket.name = socket_name
	socket.bone_idx = index
	skeleton.add_child(socket)
	var item := Node3D.new()
	socket.add_child(item)
	item.transform = skeleton.get_bone_global_rest(index).affine_inverse() * Transform3D(Basis.IDENTITY, origin)
	return item

func _build_collar() -> void:
	var vine := PackedVector3Array()
	for i in 33:
		var a := float(i) * TAU / 32.0
		vine.append(Vector3(-0.012 + 0.138 * sin(a), 0.445 - 0.034 * cos(a), (0.109 + 0.014 * cos(a)) * cos(a)))
	_tube(collar, vine, 0.0049, _mat(Color("624527")), 9)
	for i in 17:
		var a := float(i) * TAU / 17.0
		var normal := Vector3(sin(a), 0, cos(a))
		var base := Vector3(-0.012 + 0.143 * sin(a), 0.444 - 0.035 * cos(a), (0.112 + 0.014 * cos(a)) * cos(a))
		var droop := 0.048 + 0.016 * (0.5 + 0.5 * cos(a))
		var tip := Vector3.DOWN * droop + normal * 0.045 + Vector3.UP.cross(normal) * (0.021 if i % 2 == 0 else -0.020)
		_leaf(collar, base, tip, 0.028, normal, Color(["6d9837", "577e2a", "8aa743", "497525"][i % 4]))
		if i % 2 == 0:
			_leaf(collar, base + Vector3.UP * 0.002, normal * 0.019 + Vector3.UP * 0.037 - Vector3.UP.cross(normal) * 0.019,
				0.014, normal, Color("416823"))
	_oval(collar, Vector3(-0.011, 0.408, 0.139), Vector3(0.026, 0.025, 0.012), _mat(Color("b27c39"), 0.56))
	_oval(collar, Vector3(-0.011, 0.408, 0.145), Vector3(0.016, 0.016, 0.008), _mat(Color("b45831")))

func _leaf(parent: Node3D, origin: Vector3, tip: Vector3, width: float, outward: Vector3, color: Color) -> void:
	var axis := tip.normalized()
	var side := axis.cross(outward).normalized()
	var normal := side.cross(axis)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var rows: Array[PackedVector3Array] = []
	var vein := PackedVector3Array()
	for i in 11:
		var t := float(i) / 10.0
		var full := pow(maxf(0.009, sin(PI * t)), 0.80)
		var center := origin + t * tip + normal * sin(PI * t) * 0.010
		var row := PackedVector3Array()
		for j in 5:
			var s := float(j - 2) / 2.0
			row.append(center + side * (s * width * full) - normal * (s * s * full * 0.007))
		rows.append(row)
		vein.append(center + normal * 0.0012)
	for i in 10:
		for j in 4:
			for vertex in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i,j+1), Vector2i(i,j+1), Vector2i(i+1,j), Vector2i(i+1,j+1)]:
				var tint := 0.15 * float(vertex.x) / 10.0 - 0.06 * absf(float(vertex.y - 2))
				surface.set_color(color.lightened(maxf(0.0, tint)).darkened(maxf(0.0, -tint)))
				surface.add_vertex(rows[vertex.x][vertex.y])
	surface.index()
	surface.generate_normals()
	var material := _mat(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(parent, surface.commit(), material)
	_tube(parent, vein, 0.00125, _mat(color.lightened(0.28)), 5)

func _build_staff(parent: Node3D) -> void:
	var wood := _mat(Color("966135"))
	var dark := _mat(Color("65402b"))
	_tube(parent, PackedVector3Array([Vector3(0.010,-0.203,0.001), Vector3(-0.003,-0.134,0.003),
		Vector3(-0.008,-0.074,0), Vector3.ZERO, Vector3(0.008,0.083,-0.005),
		Vector3(0.015,0.165,-0.002), Vector3(0.009,0.217,0.004), Vector3(0.023,0.276,0.006),
		Vector3(0.032,0.305,0.005)]), 0.012, wood, 12, true)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var v := Vector3(cos(a), 0, sin(a))
		var grain := PackedVector3Array([Vector3(-0.005,-0.1,0.002) + v * 0.0105, v * 0.011,
			Vector3(0.009,0.087,-0.005) + v * 0.011, Vector3(0.015,0.159,-0.002) + v * 0.009])
		_tube(parent, grain, 0.00062, _mat(Color("7d4e2f")), 5)
	var wrap := PackedVector3Array()
	for i in 85:
		var t := float(i) / 84.0
		var a := t * TAU * 7.0
		wrap.append(Vector3(0.0132 * cos(a), -0.028 + t * 0.057, 0.0132 * sin(a)))
	_tube(parent, wrap, 0.0023, _mat(Color("c7a277")), 7)
	_oval(parent, Vector3(0.01,-0.193,0.001), Vector3(0.025,0.030,0.025), dark)
	var bud := Vector3(0.032, 0.305, 0.005)
	_oval(parent, bud, Vector3(0.048,0.071,0.048), _mat(Color("683127")))
	for row in 6:
		var u := (float(row) + 0.5) / 6.0
		var rad := 0.022 * sin(u * PI)
		for i in 7:
			var a := TAU * (float(i) + 0.5 * float(row % 2)) / 7.0
			var berry := bud + Vector3(cos(a) * rad, (u - 0.5) * 0.069, sin(a) * rad)
			_oval(parent, berry, Vector3(0.016,0.020,0.016), _mat(Color(["913a32","a84a39","78332c"][(row + i) % 3])))
	_leaf(parent, bud - Vector3.UP * 0.035, Vector3(-0.049,0.014,0.015), 0.012, Vector3.FORWARD, Color("627d36"))

func _build_lantern() -> void:
	var brass := _mat(Color("a56633"), 0.65)
	var leather := _mat(Color("543126"))
	_oval(lantern, Vector3(0,0.037,0.016), Vector3(0.086,0.066,0.040), leather)
	_cylinder(lantern, Vector3.ZERO, 0.026, 0.025, 0.077, brass)
	var glass := _mat(Color("f7b549"))
	glass.emission_enabled = true
	glass.emission = Color("ff9b36")
	glass.emission_energy_multiplier = 0.6
	_cylinder(lantern, Vector3(0,0,-0.008), 0.027, 0.028, 0.050, glass)
	for y in [-0.034, 0.033]:
		_cylinder(lantern, Vector3(0,y,-0.008), 0.033, 0.033, 0.014, brass)
	for i in 6:
		var a := TAU * float(i) / 6.0
		_cylinder(lantern, Vector3(cos(a)*0.029,0,sin(a)*0.029-0.008), 0.0028, 0.0028, 0.066, leather)
	_oval(lantern, Vector3(0,0.040,-0.008), Vector3(0.022,0.019,0.022), brass)

func _build_medal() -> void:
	var bronze := _mat(Color("9e652d"), 0.60)
	var gold := _mat(Color("eab657"), 0.55)
	var ribbon := _mat(Color("265958"))
	_leaf(medal, Vector3(0,0.017,0), Vector3(0.014,-0.054,0.012), 0.012, Vector3.BACK, Color("285c59"))
	_leaf(medal, Vector3(0,0.017,0.001), Vector3(-0.012,-0.047,0.017), 0.010, Vector3.BACK, Color("3b7771"))
	_oval(medal, Vector3(0,0.005,0.014), Vector3(0.043,0.044,0.013), bronze)
	_oval(medal, Vector3(0,0.005,0.020), Vector3(0.034,0.035,0.011), gold)
	_oval(medal, Vector3(0,0.005,0.025), Vector3(0.023,0.024,0.008), ribbon)
	_leaf(medal, Vector3(-0.004,-0.004,0.030), Vector3(0.009,0.018,0.003), 0.006, Vector3.BACK, Color("edc974"))

func _build_pan() -> void:
	var iron := _mat(Color("3c4146"), 0.68)
	var rim := _mat(Color("7f827c"), 0.74)
	var grip := _mat(Color("71482d"))
	var pan_center := Vector3(0.090, 0.012, 0.0)
	_cylinder(pan, pan_center, 0.089, 0.070, 0.020, iron)
	var edge := TorusMesh.new()
	edge.inner_radius = 0.080
	edge.outer_radius = 0.091
	edge.rings = 24
	edge.ring_segments = 8
	_mesh(pan, edge, rim).position = pan_center + Vector3.UP * 0.010
	var handle := _cylinder(pan, Vector3(-0.003,0.009,0), 0.011, 0.013, 0.062, grip)
	handle.rotation.z = PI * 0.5

func _mat(color: Color, metal := 0.0) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.47 if metal > 0.0 else 0.73
		mat.metallic = metal
		materials[color] = mat
	return materials[color]

func _mesh(parent: Node3D, shape: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	parent.add_child(node)
	return node

func _oval(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var shape := SphereMesh.new()
	shape.radial_segments = 12
	shape.rings = 7
	var node := _mesh(parent, shape, mat)
	node.position = at
	node.scale = size

func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, mat: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.radial_segments = 16
	shape.rings = 1
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	var node := _mesh(parent, shape, mat)
	node.position = at
	return node

func _tube(parent: Node3D, points: PackedVector3Array, radius: float, mat: Material, sides: int, tapered := false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var rings: Array[PackedVector3Array] = []
	for i in points.size():
		var tangent := (points[mini(i+1, points.size()-1)] - points[maxi(i-1,0)]).normalized()
		var reference := Vector3.RIGHT if absf(tangent.x) < 0.9 else Vector3.UP
		var x := tangent.cross(reference).normalized()
		var z := tangent.cross(x)
		var size := radius * (1.20 - 0.42 * float(i) / float(points.size() - 1)) if tapered else radius
		var ring := PackedVector3Array()
		for j in sides:
			var a := float(j) * TAU / float(sides)
			ring.append(points[i] + (cos(a)*x + sin(a)*z)*size)
		rings.append(ring)
	for i in points.size() - 1:
		for j in sides:
			var k := (j+1) % sides
			for vertex in [rings[i][j], rings[i+1][j], rings[i+1][k], rings[i][j], rings[i+1][k], rings[i][k]]:
				surface.add_vertex(vertex)
	surface.index()
	surface.generate_normals()
	_mesh(parent, surface.commit(), mat)

