extends Node3D
## Chapter one's fixed skyline, aligned with the old transport tunnel.

const PASS := Vector3(-39, 0, -168)
const SNOW_PALETTE := [Color("526581"), Color("8ca1bc"), Color("e0eaf4")]
const FOOTHILL_PALETTE := [Color("63515a"), Color("a57767"), Color("d4dbe1")]
const VOLCANO_PALETTE := [Color("4a3034"), Color("a2563d"), Color("874537")]
const SAMPLES := 28


static func make_pass_cliff() -> MeshInstance3D:
	# The front opening frames the whole furnace. The old tunnel narrows behind it.
	var opening := PackedVector3Array([
		Vector3(-6.3, -0.35, 1.1), Vector3(-6.2, 4.3, 1.1),
		Vector3(-5.8, 9.1, 0.4), Vector3(-3.2, 12.3, 0.8),
		Vector3(0.1, 13.8, 0.0), Vector3(3.8, 12.5, 0.5),
		Vector3(6.1, 8.9, 1.1), Vector3(6.6, 4.4, 1.4),
		Vector3(6.7, -0.35, 1.8)
	])
	var crest := PackedVector3Array([
		Vector3(-29, -0.5, -10), Vector3(-25, 6.0, -13),
		Vector3(-20, 15.0, -17), Vector3(-11, 23.0, -23),
		Vector3(-2, 29.0, -29), Vector3(8, 25.0, -26),
		Vector3(17, 18.0, -20), Vector3(23, 8.0, -15),
		Vector3(28, -0.5, -11)
	])
	var footing := PackedVector3Array([
		Vector3(-34, -0.5, -42), Vector3(-29, -0.5, -49),
		Vector3(-22, -0.5, -56), Vector3(-12, -0.5, -60),
		Vector3(-2, -0.5, -64), Vector3(10, -0.5, -60),
		Vector3(22, -0.5, -54), Vector3(29, -0.5, -47),
		Vector3(33, -0.5, -40)
	])
	var shoulder := PackedVector3Array()
	for i in opening.size():
		var point := opening[i].lerp(crest[i], 0.48)
		point.z += 1.2 + sin(float(i) * 2.1) * 0.9
		shoulder.append(point)

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.96
	var terrain := SurfaceTool.new()
	terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
	terrain.set_smooth_group(-1)
	terrain.set_material(material)
	var recess := PackedVector3Array()
	for point in opening:
		recess.append(Vector3(point.x * 0.57, point.y * 0.46, -7.0))

	var profiles: Array[PackedVector3Array] = [recess, opening, shoulder, crest, footing]
	for row in profiles.size() - 1:
		for i in opening.size() - 1:
			var a := profiles[row][i]
			var b := profiles[row][i + 1]
			var c := profiles[row + 1][i]
			var d := profiles[row + 1][i + 1]
			_add_cliff_face(terrain, a, c, b, row, i)
			_add_cliff_face(terrain, b, c, d, row, i + 1)
	terrain.generate_normals()

	var cliff := MeshInstance3D.new()
	cliff.name = "SnowPassCliff"
	cliff.mesh = terrain.commit()
	return cliff


static func _add_cliff_face(terrain: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, row: int, facet: int) -> void:
	var rock := Color("4e6175").lerp(Color("8596a7"), 0.4 + 0.25 * sin(float(facet) * 2.3 + row))
	for point in [a, b, c]:
		var snowline := 7.8 + 1.7 * sin(point.x * 0.31)
		var snow := 0.0 if row == 0 else smoothstep(snowline - 2.0, snowline + 2.0, point.y)
		terrain.set_color(rock.lerp(Color("dce9f3"), snow))
		terrain.add_vertex(point)


func build(steam_material: StandardMaterial3D) -> void:
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.vertex_color_is_srgb = true
	surface.roughness = 0.96

	# Lower ridges lead the eye from the transport pass to the two distant summits.
	_build_peak("SnowPassSummit", Vector3(-44, 0, -140), Vector2(82, 49), 96.0, SNOW_PALETTE, surface, 1.3)
	_build_peak("EastSnowShoulder", Vector3(19, 0, -87), Vector2(14, 19), 14.0, SNOW_PALETTE, surface, 4.3)
	_build_peak("ThawingRidge", Vector3(24, 0, -121), Vector2(27, 30), 22.0, FOOTHILL_PALETTE, surface, 3.4)
	_build_peak("VolcanicRidge", Vector3(58, 0, -156), Vector2(27, 28), 33.0, VOLCANO_PALETTE, surface, 1.0)
	var crater := Vector3(48, 0, -175)
	var volcano_height := 75.0
	_build_peak("SmokingVolcano", crater, Vector2(60, 47), volcano_height, VOLCANO_PALETTE, surface, 0.6, true)
	_add_plume(crater + Vector3.UP * volcano_height * 0.98, steam_material)


func _build_peak(node_name: String, center: Vector3, footprint: Vector2, height: float,
		palette: Array, material: StandardMaterial3D, phase: float, crater := false) -> void:
	# Each profile point is a footprint scale and a height fraction.
	var profile: Array[Vector2] = [
		Vector2(1.0, -0.09), Vector2(0.81, 0.19), Vector2(0.62, 0.39),
		Vector2(0.44, 0.60), Vector2(0.29, 0.79)
	]
	if crater:
		profile.append_array([Vector2(0.20, 0.98), Vector2(0.14, 1.0),
			Vector2(0.10, 0.86), Vector2(0.025, 0.83)])
	else:
		profile.append_array([Vector2(0.14, 0.93), Vector2(0.025, 1.0)])

	var rings: Array[PackedVector3Array] = []
	for band in profile.size():
		var ring := PackedVector3Array()
		var section := profile[band]
		for i in SAMPLES:
			var angle := TAU * float(i) / SAMPLES + 0.07 * sin(float(band) * 1.9)
			var ridge := 1.0 + 0.10 * sin(angle * 3.0 + phase) + 0.07 * sin(angle * 7.0 - phase)
			var height_variation := sin(angle * 5.0 + phase) * 0.042 + sin(angle * 9.0 + band) * 0.022
			var point := Vector3(cos(angle) * footprint.x * section.x * ridge,
				(section.y + height_variation) * height, sin(angle) * footprint.y * section.x * ridge)
			if not crater:
				point.x += 5.0 * section.y
				point.z -= 4.0 * section.y
			ring.append(point)
		rings.append(ring)

	var terrain := SurfaceTool.new()
	terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
	terrain.set_material(material)
	for band in rings.size() - 1:
		for i in SAMPLES:
			var next := (i + 1) % SAMPLES
			var a := rings[band][i]
			var b := rings[band][next]
			var c := rings[band + 1][i]
			var d := rings[band + 1][next]
			_add_face(terrain, a, b, c, height, palette, crater, band)
			_add_face(terrain, b, d, c, height, palette, crater, band)
	var cap := rings.back() as PackedVector3Array
	var summit := Vector3.ZERO
	for point in cap:
		summit += point
	summit /= cap.size()
	for i in SAMPLES:
		_add_face(terrain, cap[i], cap[(i + 1) % SAMPLES], summit, height, palette, crater, rings.size() - 1)

	var peak := MeshInstance3D.new()
	peak.name = node_name
	peak.mesh = terrain.commit()
	peak.position = center
	add_child(peak)
	peak.create_trimesh_collision()

	if crater:
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("842916")
		glow.emission_enabled = true
		glow.emission = Color("e35725")
		glow.emission_energy_multiplier = 0.7
		var vent := CylinderMesh.new()
		vent.top_radius = 3.0
		vent.bottom_radius = 3.0
		vent.height = 0.15
		vent.radial_segments = 14
		vent.material = glow
		var glow_mesh := MeshInstance3D.new()
		glow_mesh.name = "CraterGlow"
		glow_mesh.mesh = vent
		glow_mesh.position.y = height * 0.89
		peak.add_child(glow_mesh)


func _add_face(terrain: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, height: float,
		palette: Array, crater: bool, band: int) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var middle := (a + b + c) / 3.0
	var strata := sin(middle.y * 1.2 + middle.x * 0.35 + middle.z * 0.27)
	var rock: Color = palette[0].lerp(palette[1], clampf(0.48 + 0.22 * strata + 0.18 * normal.y, 0.0, 1.0))
	if crater and band >= 6:
		rock = Color("462325").lerp(Color("7a392d"), 0.5 + 0.24 * strata)
	for point in [a, b, c]:
		var snowline := 0.32 + 0.09 * sin(point.x * 0.24 + point.z * 0.12) + 0.22 * (1.0 - normal.y)
		var cover := smoothstep(snowline, snowline + 0.20, point.y / height)
		if crater or palette == VOLCANO_PALETTE:
			cover = 0.0
		terrain.set_normal(normal)
		terrain.set_color(rock.lerp(palette[2], cover))
		terrain.add_vertex(point)


func _add_plume(vent: Vector3, steam_material: StandardMaterial3D) -> void:
	var material := steam_material.duplicate() as StandardMaterial3D
	material.albedo_color = Color.WHITE
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	var cloud := QuadMesh.new()
	cloud.size = Vector2(1.65, 1.65)
	cloud.material = material

	var smoke := CPUParticles3D.new()
	smoke.name = "VolcanoSmoke"
	smoke.position = vent
	smoke.mesh = cloud
	smoke.amount = 88
	smoke.lifetime = 9.0
	smoke.preprocess = smoke.lifetime
	smoke.direction = Vector3(0.38, 1.0, 0.06).normalized()
	smoke.spread = 17.0
	smoke.gravity = Vector3(0.22, 0.06, 0)
	smoke.initial_velocity_min = 1.45
	smoke.initial_velocity_max = 2.25
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.8
	smoke.scale_amount_min = 8.0
	smoke.scale_amount_max = 13.0
	var expansion := Curve.new()
	expansion.add_point(Vector2(0, 0.45))
	expansion.add_point(Vector2(1, 1.0))
	smoke.scale_amount_curve = expansion
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 0.64, 1.0])
	fade.colors = PackedColorArray([Color(0.26, 0.18, 0.20, 0.60), Color(0.27, 0.22, 0.25, 0.93),
		Color(0.50, 0.44, 0.46, 0.52), Color(0.60, 0.53, 0.55, 0.0)])
	smoke.color_ramp = fade
	add_child(smoke)
