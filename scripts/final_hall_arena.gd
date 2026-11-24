
extends Node3D

const SOUTH := -28.0
const NORTH := -65.0
const HALF_WIDTH := 21.0
const CENTER := (SOUTH + NORTH) * 0.5
const SEAL_Z := -50.3
const CORE_SHIFT := Vector3(0, 0, NORTH - SOUTH)
const PLAYER_START := Vector3(0, 0.14, -38)
const BOSS_START := Vector3(0, 0.10, -48)
const VALVE := Vector3(-15, 0, -42)
const SERVING := Vector3(6, 0, -34)
const STEAM_WIDTH := 10.5
const STEAM_LENGTH := 23.0
const STEAM_OFFSET := 10.0

var roof: Node3D
var gates: Array[CollisionShape3D] = []
var gate_lights: Array[MeshInstance3D] = []
var stone := _mat("554b50", 0.0, 0.83)
var stone_trim := _mat("978479", 0.0, 0.72)
var dark := _mat("29232d", 0.0, 0.88)
var bronze := _mat("967346", 0.64, 0.40)
var gold := _mat("c1a16a", 0.60, 0.34)
var velvet := _mat("461b2b", 0.0, 0.90)
var teal := _mat("6fb2ac", 0.28, 0.40, 0.26)
var ember := _mat("eea05a", 0.30, 0.40, 0.44)
var floor_mats: Array[StandardMaterial3D] = [_mat("67585b", 0.0, 0.74), _mat("726366", 0.0, 0.78), _mat("62555b", 0.0, 0.76)]


func _ready() -> void:
	name = "OldCouncilArena"
	var shell := StaticBody3D.new()
	shell.name = "ArenaCollision"
	add_child(shell)
	_collision(shell, Vector3(0, -0.4, CENTER), Vector3(42.8, 0.8, 37.03))
	_box(self, Vector3(0, -0.145, CENTER), Vector3(42.0, 0.18, 37.0), dark)
	_build_floor()
	for side in [-1.0, 1.0]:
		_build_side(side, shell)
	_end_wall(SOUTH - 0.30, shell)
	_end_wall(NORTH + 0.30, shell)
	_build_ceiling()
	_build_fixtures()
	_bake_static_meshes(roof)
	_bake_static_meshes(self)
	for z in [SOUTH - 0.6, NORTH + 0.6]:
		var gate := _collision(shell, Vector3(0, 2.6, z), Vector3(5.54, 5.2, 0.24))
		gates.append(gate)
		var silk := _mat("dd9467", 0.0, 0.5, 0.8)
		silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		silk.albedo_color.a = 0.18
		var screen := _box(self, gate.position, Vector3(5.54, 5.2, 0.07), silk)
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for x in [-2.67, 2.67]:
			_box(screen, Vector3(x, 0, 0), Vector3(0.055, 5.2, 0.06), ember)
		gate_lights.append(screen)
	set_battle_locked(false)


func set_battle_locked(locked: bool) -> void:
	for gate in gates:
		gate.set_deferred("disabled", not locked)
	for light in gate_lights:
		light.visible = locked


func _build_floor() -> void:
	# Large regular flagstones leave combat telegraphs readable at ground level.
	for row in 10:
		var depth := 3.7
		for column in 12:
			var x := (column + 0.5) * 3.5 - HALF_WIDTH
			var z := SOUTH - (row + 0.5) * depth
			_box(self, Vector3(x, -0.053, z), Vector3(3.47, 0.1, depth - 0.024), floor_mats[(row * 5 + column * 7) % floor_mats.size()])
	for x in [-19.2, -18.9, 18.9, 19.2]:
		_box(self, Vector3(x, 0.008, CENTER), Vector3(0.052, 0.016, 36.1), bronze)
	# The circular inlay uses the old council's fourteen seats as its motif.
	for radius in [2.0, 8.15, 8.48]:
		_ring(Vector3(0, 0.016, SEAL_Z), radius, 0.075 if radius > 2.0 else 0.044, gold)
	for i in 14:
		var angle := TAU * i / 14.0
		var at := Vector3(sin(angle) * 8.32, 0.024, cos(angle) * 8.32 + SEAL_Z)
		var inset := _box(self, at, Vector3(0.41, 0.026, 0.34), bronze)
		inset.rotation.y = angle + PI / 4.0
	for x in [-15.4, -4.75, 4.75, 15.4]:
		for i in 24:
			_box(self, Vector3(x, 0.009, NORTH + 1.3 + i * 1.49), Vector3(0.056, 0.012, 0.35), bronze)


func _build_side(side: float, shell: StaticBody3D) -> void:
	var x := side * HALF_WIDTH
	_collision(shell, Vector3(x, 4.8, CENTER), Vector3(0.56, 9.6, 37.6))
	_box(self, Vector3(x, 4.8, CENTER), Vector3(0.56, 9.6, 37.6), stone)
	for band in [0.35, 1.40, 7.30, 8.85]:
		_box(self, Vector3(x - side * 0.28, band, CENTER), Vector3(0.19, 0.16, 37.0), stone_trim)
	for z in [-29.6, -36.3, -43.0, -50.0, -57.0, -63.8]:
		var at := Vector3(x - side * 0.60, 0, z)
		for band in [Vector2(0.16, 1.10), Vector2(0.44, 0.83), Vector2(6.85, 0.92), Vector2(7.22, 1.10)]:
			_box(self, at + Vector3.UP * band.x, Vector3(band.y, 0.26, band.y), stone_trim)
		_cylinder(self, at + Vector3.UP * 3.6, 6.25, 0.35, 0.41, stone_trim, 10)
	for z in [-33.0, -39.65, -46.5, -53.5, -60.4]:
		var window := Node3D.new()
		add_child(window)
		window.position = Vector3(x - side * 0.30, 1.55, z)
		window.rotation.y = -side * PI / 2.0
		_box(window, Vector3(0, 2.07, 0), Vector3(3.10, 4.16, 0.07), dark)
		for lane in [-1.0, 0.0, 1.0]:
			for row in 5:
				var glass_height := 0.61
				_box(window, Vector3(lane * 0.87, 0.53 + row * 0.67, 0.058), Vector3(0.77, glass_height, 0.035), teal if row == 4 or lane == 0.0 else velvet)
		_arch(window, 1.66, 3.55, 0.19, gold)
		var crest := _box(window, Vector3(0, 4.20, 0.12), Vector3(0.84, 0.84, 0.05), bronze)
		crest.rotation.z = PI / 4.0
		_box(crest, Vector3(0, 0, 0.036), Vector3(0.66, 0.66, 0.04), teal)
		_box(window, Vector3(0, 0.09, 0.12), Vector3(3.55, 0.19, 0.35), stone_trim)
	for z in [-40.0, -52.8, -60.2]:
		# Empty galleries sit behind the fighting lanes.
		_box(self, Vector3(side * 19.75, 0.42, z), Vector3(1.46, 0.75, 3.4), dark)
		_box(self, Vector3(side * 19.75, 0.81, z), Vector3(1.44, 0.15, 3.23), velvet)
		_box(self, Vector3(side * 20.19, 1.35, z), Vector3(0.17, 1.0, 3.28), bronze)
		_collision(shell, Vector3(side * 19.75, 0.43, z), Vector3(1.45, 0.86, 3.4))
	for z in [-35.5, -61.0]:
		_box(self, Vector3(side * 20.34, 5.65, z), Vector3(0.085, 2.6, 1.58), velvet)
		for dz in [-0.72, 0.72]:
			_box(self, Vector3(side * 20.27, 5.65, z + dz), Vector3(0.058, 2.6, 0.048), gold)
		_cylinder(self, Vector3(side * 20.24, 7.0, z), 1.92, 0.065, 0.065, bronze).rotation.x = PI / 2.0


func _end_wall(z: float, shell: StaticBody3D) -> void:
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 12.0, 4.8, z)
		_collision(shell, at, Vector3(18.1, 9.6, 0.54))
		_box(self, at, Vector3(18.1, 9.6, 0.54), stone)
		for band in [0.45, 1.25, 7.65, 8.85]:
			_box(self, Vector3(at.x, band, z), Vector3(18.1, 0.16, 0.73), stone_trim)
	_box(self, Vector3(0, 7.66, z), Vector3(6.08, 3.9, 0.54), stone)
	_collision(shell, Vector3(0, 7.66, z), Vector3(6.08, 3.9, 0.54))
	var portal := Node3D.new()
	add_child(portal)
	portal.position = Vector3(0, 0, z)
	_arch(portal, 2.93, 3.48, 0.24, stone_trim)
	if z < CENTER:
		_build_council_wall(z + 0.30)
	portal.position.z += 0.23 if z < CENTER else -0.23
	if z > CENTER:
		portal.rotation.y = PI


func _build_council_wall(z: float) -> void:
	# The old voting benches and empty nameplates stay against the wall.
	for side in [-1.0, 1.0]:
		for bay in 3:
			var x: float = side * (6.4 + 4.9 * bay)
			var alcove := Node3D.new()
			add_child(alcove)
			alcove.position = Vector3(x, 1.50, z)
			_box(alcove, Vector3(0, 2.15, 0.055), Vector3(3.30, 4.32, 0.08), dark)
			_box(alcove, Vector3(0, 1.77, 0.12), Vector3(2.46, 3.48, 0.055), velvet)
			_arch(alcove, 1.65, 3.72, 0.24, stone_trim)
			for offset in [-0.77, 0.0, 0.77]:
				var tablet := _box(alcove, Vector3(offset, 1.66, 0.18), Vector3(0.57, 1.24, 0.06), bronze)
				_box(tablet, Vector3(0, 0.36, 0.042), Vector3(0.42, 0.16, 0.015), gold)
				_box(tablet, Vector3(0, -0.12, 0.045), Vector3(0.33, 0.041, 0.019), stone_trim)
			var crest := _ring(alcove.position + Vector3(0, 4.07, 0.22), 0.46, 0.10, bronze)
			crest.rotation.x = PI / 2.0
		for x in [3.95, 8.9, 13.8, 18.7]:
			var post := Vector3(side * x, 0, z + 0.25)
			_box(self, post + Vector3.UP * 3.8, Vector3(0.55, 7.45, 0.50), stone)
			for y in [0.28, 2.1, 7.35]:
				_box(self, post + Vector3.UP * y, Vector3(0.83, 0.23, 0.67), stone_trim)
			_box(self, post + Vector3(0, 4.58, 0.27), Vector3(0.19, 0.39, 0.24), bronze)
			_cylinder(self, post + Vector3(0, 4.84, 0.44), 0.36, 0.15, 0.11, ember, 8)


func _build_ceiling() -> void:
	roof = Node3D.new()
	roof.name = "CouncilVault"
	add_child(roof)
	for segment in 12:
		var start := PI * segment / 12.0
		var finish := PI * (segment + 1) / 12.0
		var a := Vector3(cos(start) * HALF_WIDTH, 8.9 + sin(start) * 4.0, CENTER)
		var b := Vector3(cos(finish) * HALF_WIDTH, 8.9 + sin(finish) * 4.0, CENTER)
		var span := b - a
		var panel := _box(roof, (a + b) * 0.5, Vector3(span.length() + 0.10, 0.21, 37.5), dark if segment % 2 == 0 else velvet)
		panel.rotation.z = atan2(span.y, span.x)
		for z in [-28.5, -35.5, -43.0, -50.0, -57.5, -64.5]:
			var rib := _box(roof, Vector3(panel.position.x, panel.position.y - 0.17, z), Vector3(span.length() + 0.07, 0.23, 0.29), stone_trim)
			rib.rotation.z = panel.rotation.z
			var trim := _box(roof, rib.position - Vector3.UP * 0.12, Vector3(span.length(), 0.073, 0.09), bronze)
			trim.rotation.z = panel.rotation.z


func _build_fixtures() -> void:
	# Brass pipe runs show why the old chamber still feeds the main core.
	for side in [-1.0, 1.0]:
		var x: float = side * 19.08
		for y in [2.5, 2.92]:
			_cylinder(self, Vector3(x, y, CENTER), 36.0, 0.125, 0.125, bronze).rotation.x = PI / 2.0
			for z in [-30, -35, -40, -45, -50, -55, -60, -64]:
				_cylinder(self, Vector3(x, y, z), 0.22, 0.20, 0.20, gold).rotation.x = PI / 2.0
	var valve_base := VALVE + Vector3(-1.20, 0, 0)
	_cylinder(self, valve_base + Vector3.UP * 0.53, 1.06, 0.38, 0.60, bronze, 12)
	_cylinder(self, valve_base + Vector3.UP * 1.04, 0.16, 0.48, 0.48, stone_trim)
	var wheel := _ring(valve_base + Vector3(0, 1.42, 0), 0.53, 0.13, gold)
	wheel.rotation.z = PI / 2.0
	for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		_box(wheel, Vector3.ZERO, Vector3(0.075, 0.075, 0.98), bronze).rotation.y = angle
	_cylinder(self, SERVING + Vector3(0, 0.38, 1.35), 0.76, 0.36, 0.60, dark, 12)
	_cylinder(self, SERVING + Vector3(0, 0.79, 1.35), 0.13, 0.69, 0.61, bronze, 24)
	for location in [Vector3(-11.8, 4.55, -37.5), Vector3(11.8, 4.55, -37.5), Vector3(-11.8, 4.55, -55.5), Vector3(11.8, 4.55, -55.5)]:
		var light := OmniLight3D.new()
		light.position = location
		light.omni_range = 18.0
		light.light_color = Color("ffd396") if location.z > -45.0 else Color("98c9c4")
		light.light_energy = 1.05
		add_child(light)
	for z in [-39.0, -54.0]:
		var at := Vector3(0, 8.30, z)
		_cylinder(roof, at + Vector3.UP * 2.2, 4.2, 0.05, 0.05, bronze)
		_ring(at, 2.06, 0.15, bronze, roof)
		_ring(at - Vector3.UP * 0.28, 1.62, 0.075, gold, roof)
		for i in 12:
			var a := TAU * i / 12.0
			var candle := at + Vector3(sin(a) * 1.97, 0.22, cos(a) * 1.97)
			_cylinder(roof, candle, 0.38, 0.071, 0.075, stone_trim, 8)
			_cylinder(roof, candle + Vector3.UP * 0.25, 0.13, 0.015, 0.044, ember, 8)


func _bake_static_meshes(parent: Node3D) -> void:
	var regions: Array[Dictionary] = [{}, {}, {}]
	var local_transform := parent.global_transform.affine_inverse()
	for part in parent.find_children("*", "MeshInstance3D", true, false):
		if parent == self and roof.is_ancestor_of(part):
			continue
		var mesh_part := part as MeshInstance3D
		var transform_in_parent := local_transform * mesh_part.global_transform
		var region := clampi(floori((SOUTH - transform_in_parent.origin.z) / 13.0), 0, 2)
		var builders := regions[region]
		var material := mesh_part.material_override
		if not builders.has(material):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(material)
			builders[material] = builder
		builders[material].append_from(mesh_part.mesh, 0, transform_in_parent)
		mesh_part.hide()
		mesh_part.queue_free()
	for i in regions.size():
		var section := ArrayMesh.new()
		for builder in regions[i].values():
			builder.commit(section)
		_mesh(parent, Vector3.ZERO, section, null).name = "CouncilMasonry%d" % (i + 1)


func _arch(parent: Node3D, radius: float, spring: float, width: float, material: Material) -> void:
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(radius * side, spring * 0.5, 0.14), Vector3(width, spring, 0.27), material)
	for i in 13:
		var from := PI * i / 13.0
		var to := PI * (i + 1) / 13.0
		var a := Vector2(cos(from), sin(from)) * radius
		var b := Vector2(cos(to), sin(to)) * radius
		var mid := (a + b) * 0.5
		var section := _box(parent, Vector3(mid.x, mid.y + spring, 0.14), Vector3(a.distance_to(b) + 0.026, width, 0.33), material)
		section.rotation.z = (b - a).angle()


func _collision(parent: StaticBody3D, at: Vector3, dimensions: Vector3) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	node.shape = shape
	node.position = at
	parent.add_child(node)
	return node


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, at, mesh, material)


func _cylinder(parent: Node3D, at: Vector3, height: float, top: float, bottom: float, material: Material, sides := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.radial_segments = sides
	mesh.rings = 1
	return _mesh(parent, at, mesh, material)


func _ring(at: Vector3, radius: float, band: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - band * 0.5
	mesh.outer_radius = radius + band * 0.5
	mesh.rings = 64
	mesh.ring_segments = 8
	return _mesh(self if parent == null else parent, at, mesh, material)


func _mesh(parent: Node3D, at: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)
	return part


func _mat(hex: String, metallic: float, roughness: float, glow := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.metallic = metallic
	material.roughness = roughness
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = glow
	return material
