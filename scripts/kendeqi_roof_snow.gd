@tool
extends MeshInstance3D
## Samples the authored slate so the snow follows each cross-gable and valley.

@export var depth := 0.30
@export var spacing := 0.15


func _ready() -> void:
	var slate := get_parent() as MeshInstance3D
	if slate == null or slate.mesh == null:
		return
	var bounds := slate.mesh.get_aabb()
	var columns := ceili(bounds.size.x / spacing) + 1
	var rows := ceili(bounds.size.z / spacing) + 1
	var step := Vector2(bounds.size.x / (columns - 1), bounds.size.z / (rows - 1))
	var origin := Vector2(bounds.position.x, bounds.position.z)
	var heights := _sample_roof(slate.mesh.get_faces(), origin, step, columns, rows)
	mesh = _build_blanket(heights, origin, step, columns, rows)
	var snow := StandardMaterial3D.new()
	snow.vertex_color_use_as_albedo = true
	snow.roughness = 0.91
	material_override = snow
	_add_eave_icicles(heights, origin, step, columns, rows)


func _sample_roof(faces: PackedVector3Array, origin: Vector2, step: Vector2, columns: int, rows: int) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(columns * rows)
	heights.fill(-INF)
	for index in range(0, faces.size(), 3):
		var a := Vector2(faces[index].x, faces[index].z)
		var b := Vector2(faces[index + 1].x, faces[index + 1].z)
		var c := Vector2(faces[index + 2].x, faces[index + 2].z)
		var cross := (b - a).cross(c - a)
		if absf(cross) < 0.00001:
			continue
		var min_grid := (a.min(b).min(c) - origin) / step
		var max_grid := (a.max(b).max(c) - origin) / step
		for row in range(maxi(0, ceili(min_grid.y - 0.001)), mini(rows, floori(max_grid.y + 0.001) + 1)):
			for col in range(maxi(0, ceili(min_grid.x - 0.001)), mini(columns, floori(max_grid.x + 0.001) + 1)):
				var point := origin + Vector2(col, row) * step - a
				var u := point.cross(c - a) / cross
				var v := (b - a).cross(point) / cross
				if u >= -0.001 and v >= -0.001 and u + v <= 1.001:
					var y := faces[index].y * (1.0 - u - v) + faces[index + 1].y * u + faces[index + 2].y * v
					var cell := row * columns + col
					heights[cell] = maxf(heights[cell], y)
	return heights


func _build_blanket(heights: PackedFloat32Array, origin: Vector2, step: Vector2, columns: int, rows: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 891
	noise.frequency = 0.56
	var positions := PackedVector3Array()
	var tones := PackedColorArray()
	positions.resize(heights.size())
	tones.resize(heights.size())
	for row in rows:
		for col in columns:
			var index := row * columns + col
			if not is_finite(heights[index]):
				continue
			var point := origin + Vector2(col, row) * step
			var drift := noise.get_noise_2dv(point)
			var lip := 1.0 - smoothstep(0.0, 2.8, mini(mini(col, columns - col - 1), mini(row, rows - row - 1)))
			var cover := 0.12 + depth * (0.57 + drift * 0.57 + lip * 0.42)
			positions[index] = Vector3(point.x, heights[index] + cover, point.y)
			tones[index] = Color("#bdd1df").lerp(Color("#f3f7fb"), clampf(0.78 + drift * 0.28, 0.0, 1.0))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows - 1:
		for col in columns - 1:
			var a := row * columns + col
			var b := a + 1
			var c := a + columns
			var d := c + 1
			_add_top(surface, positions, tones, heights, a, b, d)
			_add_top(surface, positions, tones, heights, a, d, c)
			if row == 0:
				_add_lip(surface, positions, tones, heights, a, b)
			if row == rows - 2:
				_add_lip(surface, positions, tones, heights, d, c)
			if col == 0:
				_add_lip(surface, positions, tones, heights, c, a)
			if col == columns - 2:
				_add_lip(surface, positions, tones, heights, b, d)
	surface.index()
	surface.generate_normals()
	return surface.commit()


func _add_top(surface: SurfaceTool, points: PackedVector3Array, tones: PackedColorArray, heights: PackedFloat32Array, a: int, b: int, c: int) -> void:
	var low := minf(heights[a], minf(heights[b], heights[c]))
	var high := maxf(heights[a], maxf(heights[b], heights[c]))
	if not is_finite(low) or high - low > spacing * 3.4:
		return
	for index: int in [a, b, c]:
		surface.set_color(tones[index])
		surface.add_vertex(points[index])


func _add_lip(surface: SurfaceTool, points: PackedVector3Array, tones: PackedColorArray, heights: PackedFloat32Array, a: int, b: int) -> void:
	if not is_finite(heights[a]) or not is_finite(heights[b]) or absf(heights[a] - heights[b]) > spacing * 3.4:
		return
	var horizontal := points[b] - points[a]
	horizontal.y = 0
	var outward := Vector3.UP.cross(horizontal).normalized() * depth * 0.32
	var lower_a := Vector3(points[a].x, heights[a] - 0.055, points[a].z)
	var lower_b := Vector3(points[b].x, heights[b] - 0.055, points[b].z)
	var rim_a := points[a].lerp(lower_a, 0.40) + outward
	var rim_b := points[b].lerp(lower_b, 0.40) + outward
	surface.set_color(tones[a].darkened(0.04))
	for point: Vector3 in [points[b], points[a], rim_a, points[b], rim_a, rim_b]:
		surface.add_vertex(point)
	surface.set_color(tones[a].darkened(0.14))
	for point: Vector3 in [rim_b, rim_a, lower_a, rim_b, lower_a, lower_b]:
		surface.add_vertex(point)


func _add_eave_icicles(heights: PackedFloat32Array, origin: Vector2, step: Vector2, columns: int, rows: int) -> void:
	var poses: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 127 + columns
	for col in range(2, columns - 2, 2):
		var y := heights[(rows - 1) * columns + col]
		if not is_finite(y) or rng.randf() > 0.62:
			continue
		var length := rng.randf_range(0.10, 0.48) * clampf(depth / 0.3, 0.65, 1.05)
		var width := rng.randf_range(0.023, 0.059)
		var pos := Vector3(origin.x + col * step.x, y + 0.04 - length * 0.5, origin.y + (rows - 1) * step.y + depth * 0.12)
		poses.append(Transform3D(Basis.from_scale(Vector3(width, length, width)), pos))
	var spike := CylinderMesh.new()
	spike.radial_segments = 6
	spike.top_radius = 0.5
	spike.bottom_radius = 0.015
	spike.height = 1.0
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = spike
	instances.instance_count = poses.size()
	for index in poses.size():
		instances.set_instance_transform(index, poses[index])
	var icicles := MultiMeshInstance3D.new()
	icicles.name = "EaveIcicles"
	icicles.multimesh = instances
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color("#a4d3e4")
	ice.roughness = 0.29
	icicles.material_override = ice
	add_child(icicles)
