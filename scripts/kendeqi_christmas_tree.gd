@tool
extends Node3D
## Hand-shaped fir sprays and old brass ornaments, grouped by material.

const LOWEST_BOUGH := 2.3
const FIR_TIP := 16.1
const SWAG_TURNS := 4.4


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 614
	_build_fir(rng)
	_build_trimmings()
	_build_crown()


func _radius_at(y: float) -> float:
	var height := clampf((y - LOWEST_BOUGH) / (FIR_TIP - LOWEST_BOUGH), 0.0, 1.0)
	return lerpf(4.15, 0.10, pow(height, 0.88))


func _build_fir(rng: RandomNumberGenerator) -> void:
	var shaded: Array[Transform3D] = []
	var tips: Array[Transform3D] = []
	var snow: Array[Transform3D] = []
	for tier in 18:
		var y := lerpf(LOWEST_BOUGH, FIR_TIP - 0.18, tier / 17.0)
		var reach := _radius_at(y)
		var branch_count := maxi(5, roundi(7.0 + reach * 2.1))
		for branch in branch_count:
			var angle := TAU * branch / branch_count + tier * 0.66 + rng.randf_range(-0.14, 0.14)
			var radial := Vector3(cos(angle), 0, sin(angle))
			var level := y + rng.randf_range(-0.20, 0.24)
			var base := radial * reach * 0.08 + Vector3.UP * (level + 0.49)
			var end := radial * reach * rng.randf_range(0.86, 1.08) + Vector3.UP * level
			shaded.append(_bough_pose(base, end, reach * 0.43 + 0.11, 0.44))
			for side: float in [-1.0, 1.0]:
				var twig_base := base.lerp(end, 0.39)
				var offshoot := radial.rotated(Vector3.UP, 0.22 * side)
				var twig_end := offshoot * reach * rng.randf_range(0.92, 1.04) + Vector3.UP * (level + rng.randf_range(-0.19, 0.17))
				tips.append(_bough_pose(twig_base, twig_end, reach * 0.19 + 0.075, 0.21))
			if (branch + tier * 2) % 5 == 0:
				var snow_start := base.lerp(end, 0.35) + Vector3.UP * 0.22
				var snow_end := base.lerp(end, 0.90) + Vector3.UP * 0.14
				snow.append(_bough_pose(snow_start, snow_end, reach * 0.25 + 0.05, 0.15))

	var branch_mesh := _fir_spray_mesh()
	_batch("DeepFirBoughs", branch_mesh, shaded, _material(Color("#204636")))
	_batch("BlueGreenFirTips", branch_mesh, tips, _material(Color("#38674f")))
	_batch("SnowOnBoughs", branch_mesh, snow, _material(Color("#d0e2de")))


func _bough_pose(from: Vector3, to: Vector3, width: float, thickness: float) -> Transform3D:
	var axis := to - from
	var forward := axis.normalized()
	var across := Vector3.UP.cross(forward).normalized()
	var normal := forward.cross(across)
	return Transform3D(Basis(across * width, normal * thickness, forward * axis.length()), from)


func _fir_spray_mesh() -> ArrayMesh:
	# A ruffled three-dimensional spray. Thin side shoots break the silhouette.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := PackedVector2Array([
		Vector2(0, 0), Vector2(0.67, 0.29), Vector2(0.49, 0.32),
		Vector2(0.86, 0.51), Vector2(0.53, 0.50), Vector2(0.69, 0.70),
		Vector2(0.36, 0.65), Vector2(0.44, 0.88), Vector2(0.22, 0.81),
		Vector2(0.0, 1.05),
	])
	var ridge := Vector3(0, 0.62, 0.44)
	var underside := Vector3(0, -0.29, 0.47)
	for side: float in [-1.0, 1.0]:
		for i in outline.size() - 1:
			var v := Vector3(outline[i].x * side, 0.0, outline[i].y)
			var next := Vector3(outline[i + 1].x * side, 0.0, outline[i + 1].y)
			if side > 0.0:
				_triangle(surface, ridge, v, next)
				_triangle(surface, underside, next, v)
			else:
				_triangle(surface, ridge, next, v)
				_triangle(surface, underside, v, next)
	surface.generate_normals()
	return surface.commit()


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _build_trimmings() -> void:
	var lanterns: Array[Transform3D] = []
	var lantern_gold: Array[Transform3D] = []
	var red: Array[Transform3D] = []
	var amber: Array[Transform3D] = []
	var beads: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	var hooks: Array[Transform3D] = []
	var bow_loops: Array[Transform3D] = []
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6

	_ribbon_strip("BurgundyVelvet", 0.0, 0.40, _material(Color("#8f263b")))
	_ribbon_strip("GoldRibbonEdging", -0.193, 0.023, _material(Color("#e2b866"), 0.15, 0.45))
	_ribbon_strip("GoldRibbonEdging", 0.193, 0.023, _material(Color("#e2b866"), 0.15, 0.45))
	for index in 10:
		var progress := (index + 0.4) / 10.4
		var center := _swag_point(progress, 0.0, 0.065)
		var radial := Vector3(center.x, 0, center.z).normalized()
		var tangent := Vector3.UP.cross(radial)
		var basis := Basis(tangent, Vector3.UP, radial)
		for side: float in [-1, 1]:
			var loop := basis * Basis(Vector3.BACK, side * 0.42)
			bow_loops.append(Transform3D(loop.scaled_local(Vector3(0.36, 0.21, 0.105)), center + tangent * side * 0.19))
		beads.append(_pose(center, 0, Vector3.ONE * 0.15))
	for index in 196:
		var t := index / 195.0
		var pos := _swag_point(t, 0.29, 0.05)
		var diameter := lerpf(0.11, 0.055, t)
		beads.append(_pose(pos, 0, Vector3.ONE * diameter))
		if index % 2 == 0:
			lights.append(_pose(_swag_point(t, -0.48, 0.14), 0, Vector3(0.12, 0.18, 0.12) * lerpf(1.0, 0.62, t)))
	for tier in 9:
		var y := 2.75 + tier * 1.35
		var reach := _radius_at(y) + 0.04
		for index in 8:
			var angle := index * TAU / 8.0 + tier * 0.46
			var point := Vector3(cos(angle) * reach, y - 0.34 + sin(index * 4.2) * 0.13, sin(angle) * reach)
			var size := lerpf(0.47, 0.26, tier / 8.0)
			hooks.append(_rod(point + Vector3.UP * size * 0.45, point + Vector3.UP * size, 0.021))
			if (tier + index) % 5 == 0:
				lanterns.append(_pose(point, angle, Vector3(0.51, 0.82, 0.51) * size * 1.75))
				for end: float in [-1, 1]:
					lantern_gold.append(_pose(point + Vector3.UP * size * 0.65 * end, angle, Vector3(0.57, 0.12, 0.57) * size * 1.75))
				for corner in 4:
					var offset := Vector3(1, 0, 1).rotated(Vector3.UP, angle + corner * PI * 0.5) * size * 0.46
					hooks.append(_rod(point + offset - Vector3.UP * size * 0.69, point + offset + Vector3.UP * size * 0.69, 0.045))
			elif (tier + index) % 2 == 0:
				red.append(_pose(point, angle, Vector3(size, size * 1.10, size)))
			else:
				amber.append(_pose(point, angle, Vector3(size, size * 1.05, size)))

	var brass := _material(Color("#d7a74c"), 0.19, 0.55)
	var cube := BoxMesh.new()
	_batch("GoldBeadGarland", sphere, beads, brass)
	_batch("Candlelights", sphere, lights, _material(Color("#ffcf80"), 2.7))
	_batch("RubyGlass", sphere, red, _material(Color("#a62c40"), 0.18, 0.28))
	_batch("VelvetBows", sphere, bow_loops, _material(Color("#a22d42")))
	_batch("GoldBaubles", sphere, amber, brass)
	_batch("LanternCaps", cube, lantern_gold, brass)
	_batch("LanternGlass", cube, lanterns, _material(Color("#ffd488"), 1.7))
	_batch("BrassHooks", CylinderMesh.new(), hooks, brass)


func _swag_point(progress: float, vertical_offset: float, outward_offset: float) -> Vector3:
	var angle := progress * SWAG_TURNS * TAU + 0.57
	var y := lerpf(2.9, 14.8, progress) + sin(angle * 2.0) * 0.23 + vertical_offset
	var radius := _radius_at(y - vertical_offset) + 0.10 + outward_offset + sin(angle * 3.0) * 0.08
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


func _ribbon_strip(label: String, height: float, width: float, material: StandardMaterial3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 240:
		var start := index / 240.0
		var end := (index + 1) / 240.0
		var lower := height - width * 0.5
		var upper := height + width * 0.5
		var a := _swag_point(start, lower, 0.021)
		var b := _swag_point(start, upper, 0.010)
		var c := _swag_point(end, upper, 0.010)
		var d := _swag_point(end, lower, 0.021)
		_triangle(surface, a, b, c)
		_triangle(surface, a, c, d)
	surface.generate_normals()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth := MeshInstance3D.new()
	cloth.name = label
	cloth.mesh = surface.commit()
	cloth.material_override = material
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloth, true)


func _build_crown() -> void:
	var hub := Vector3(0, 16.46, 0)
	var spokes: Array[Transform3D] = []
	for index in 16:
		var angle := index * TAU / 16.0
		var next_angle := (index + 1) * TAU / 16.0
		var radius := 0.92 if index % 2 == 0 else 0.39
		var next_radius := 0.39 if index % 2 == 0 else 0.92
		var a := hub + Vector3(sin(angle), cos(angle), 0) * radius
		var b := hub + Vector3(sin(next_angle), cos(next_angle), 0) * next_radius
		spokes.append(_rod(a, b, 0.065))
		if index % 2 == 0:
			spokes.append(_rod(a, hub + Vector3(sin(angle), cos(angle), 0.0) * 0.30, 0.027))
	spokes.append(_rod(Vector3(0, 15.64, 0), hub, 0.065))
	_batch("OpenworkBrassStar", CylinderMesh.new(), spokes, _material(Color("#f4c86a"), 0.95, 0.4))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.68
	ring.outer_radius = 0.725
	ring.rings = 28
	ring.ring_segments = 8
	var halo := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hub + Vector3.BACK * 0.12)
	_batch("CrownHalo", ring, [halo], _material(Color("#eab651"), 0.65, 0.45))
	var gem := PrismMesh.new()
	_batch("CrownGem", gem, [_pose(hub, PI * 0.25, Vector3(0.32, 0.46, 0.28))], _material(Color("#ffd486"), 2.3))
	var sparks: Array[Transform3D] = []
	for index in 21:
		var angle := index * 2.4
		var y := 3.0 + index * 0.61
		var r := _radius_at(y) + 0.52 + sin(index * 3.0) * 0.22
		sparks.append(_pose(Vector3(cos(angle) * r, y, sin(angle) * r), angle, Vector3(0.042, 0.11, 0.042)))
	_batch("GoldenMagicMotes", gem, sparks, _material(Color("#ffe6a7"), 1.7))


func _rod(from: Vector3, to: Vector3, diameter: float) -> Transform3D:
	var axis := to - from
	var basis := Basis(Quaternion(Vector3.UP, axis.normalized()))
	return Transform3D(basis.scaled_local(Vector3(diameter, axis.length() * 0.5, diameter)), from.lerp(to, 0.5))


func _pose(center: Vector3, yaw: float, size: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), center)


func _material(color: Color, glow := 0.0, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.82 - metallic * 0.65
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _batch(batch_name: String, mesh: Mesh, poses: Array[Transform3D], material: Material) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = poses.size()
	for index in poses.size():
		instances.set_instance_transform(index, poses[index])
	var model := MultiMeshInstance3D.new()
	model.name = batch_name
	model.multimesh = instances
	model.material_override = material
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)
